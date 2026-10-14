extends Node

# Android-native ENet direct peer hosting. No account, matchmaking or paid API.
# Host owns the clock and all consequential actions; clients submit intentions.
const PROTOCOL := 18
const MAX_CREW := 4
var game: Node
var peer: ENetMultiplayerPeer
var mode := "solo"
var status := "Offline / solo"
var port := 24711
var members: Dictionary = {}
var poses: Dictionary = {}
var seats: Dictionary = {}
var pose_elapsed := 0.0
var state_elapsed := 0.0
var connect_elapsed := 0.0
var upnp_thread: Thread
var mapped_gateway: UPNP
var mapping_port := 0
var generation := 0
var password := ""
var monitor_flags: Dictionary = {}
var action_times: Dictionary = {}
var pose_times: Dictionary = {}
var disconnected_count := 0
var max_crew := 4

func _ready() -> void:
	name = "DirectSession"
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_lost_host)

func authoritative() -> bool:
	return mode != "client"

func host(selected_port: int, key: String, map_router: bool, slots: int = 4) -> Error:
	leave()
	port = selected_port
	max_crew = clampi(slots, 2, MAX_CREW)
	password = key.substr(0, 24)
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_server(port, max_crew - 1, 3)
	if result != OK:
		peer = null
		status = "Port unavailable. Choose another UDP port."
		return result
	multiplayer.multiplayer_peer = peer
	mode = "host"
	members = {1:true}
	seats = {1:1}
	status = "Hosting / 1 of %d" % max_crew
	if map_router and upnp_thread == null:
		upnp_thread = Thread.new()
		upnp_thread.start(_map_router.bind(generation, port))
	return OK

func join(address: String, selected_port: int, key: String) -> Error:
	leave()
	if address.strip_edges().is_empty():
		status = "Invalid room endpoint. Ask the host to check connectivity."
		return ERR_INVALID_PARAMETER
	password = key.substr(0, 24)
	port = selected_port
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_client(address.strip_edges(), port, 3)
	if result != OK:
		peer = null
		status = "连接失败：房主网络暂不可达"
		return result
	multiplayer.multiplayer_peer = peer
	mode = "client"
	status = "Connecting…"
	connect_elapsed = 0
	return OK

func leave() -> void:
	generation += 1
	if is_instance_valid(game) and is_instance_valid(game.rooms): game.rooms.leave_room()
	if is_instance_valid(peer): peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	mode = "solo"
	members.clear()
	poses.clear()
	seats.clear()
	monitor_flags.clear()
	action_times.clear()
	pose_times.clear()
	if is_instance_valid(game) and is_instance_valid(game.fps): game.fps.leave_level()
	status = "Offline / solo"
	if is_instance_valid(game): game.clear_crew()
	if mapped_gateway != null:
		# Remove our mapping away from the main loop, so leaving never stalls input.
		var gateway := mapped_gateway
		var old_port := mapping_port
		mapped_gateway = null
		WorkerThreadPool.add_task(func(): gateway.delete_port_mapping(old_port, "UDP"))

func local_address() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."): return address
	return "127.0.0.1"

func _map_router(token: int, selected_port: int) -> void:
	var gateway := UPNP.new()
	var result := gateway.discover(1500, 2)
	var public_ip := ""
	var mapped := false
	if result == UPNP.UPNP_RESULT_SUCCESS and gateway.get_gateway() != null:
		mapped = gateway.add_port_mapping(selected_port, selected_port, "Faceless 2", "UDP", 3600) == UPNP.UPNP_RESULT_SUCCESS
		if mapped: public_ip = gateway.query_external_address()
	_mapping_complete.call_deferred(token, selected_port, gateway, mapped, public_ip)

func _mapping_complete(token: int, selected_port: int, gateway: UPNP, mapped: bool, address: String) -> void:
	if upnp_thread != null and upnp_thread.is_started(): upnp_thread.wait_to_finish()
	upnp_thread = null
	if token != generation or mode != "host":
		if mapped: WorkerThreadPool.add_task(func(): gateway.delete_port_mapping(selected_port, "UDP"))
		return
	if mapped:
		mapped_gateway = gateway
		mapping_port = selected_port
		status = "Public endpoint / %s:%d" % [address, selected_port]
	else: status = "LAN / %s:%d · Router mapping unavailable" % [local_address(), selected_port]

func _exit_tree() -> void:
	if upnp_thread != null and upnp_thread.is_started(): upnp_thread.wait_to_finish()

func _peer_connected(id: int) -> void:
	# An app killed by Android cannot send a normal leave message. Bound
	# reliable-packet timeout so its avatar and room slot are reclaimed.
	if mode == "host": peer.get_peer(id).set_timeout(32, 5000, 15000)
	# Membership still requires the version/password handshake.

func _peer_disconnected(id: int) -> void:
	members.erase(id)
	poses.erase(id)
	seats.erase(id)
	monitor_flags.erase(id)
	pose_times.erase(id)
	action_times.erase(id)
	disconnected_count += 1
	game.remove_crew(id)
	if is_instance_valid(game.fps):
		game.fps.remove_peer(id)
		if mode == "host" and game.fps_arena.visible:
			broadcast_fps_state(game.fps.health_by_peer,game.fps.ammo_by_peer,game.fps.scores)
	status = "Room / %d of %d" % [members.size(),max_crew] if mode == "host" else status

func _connected() -> void:
	peer.get_peer(1).set_timeout(32, 5000, 15000)
	_hello.rpc_id(1, PROTOCOL, password)

@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(version: int, key: String) -> void:
	if mode != "host": return
	var id := multiplayer.get_remote_sender_id()
	if members.has(id): return
	if version != PROTOCOL or key != password or members.size() >= max_crew:
		_reject.rpc_id(id, "Version or room key mismatch, or room full.")
		return
	# A repeated handshake must never reset a living player's HP/ammo.
	if members.has(id): return
	var seat := 2
	while seats.values().has(seat): seat += 1
	if seat > max_crew: return
	seats[id] = seat
	members[id] = true
	poses[id] = {"p":game.fps_arena.spawn_for(seat) if game.fps_arena.visible else game.level.spawn + Vector3(0.9 * (members.size() - 1), 0, 0), "y":0.0,"pitch":0.0}
	if game.fps_arena.visible: game.fps.register_peer(id)
	pose_times[id] = Time.get_ticks_msec()
	_welcome.rpc_id(id, game.snapshot(), poses[id].p)
	if game.fps_arena.visible: _fps_join.rpc_id(id, poses[id].p,game.fps.health_by_peer,game.fps.ammo_by_peer,game.fps.scores,game.fps.combat_state())
	if game.fps_arena.visible: broadcast_fps_state(game.fps.health_by_peer,game.fps.ammo_by_peer,game.fps.scores)
	status = "Room / %d of %d" % [members.size(), max_crew]

@rpc("authority", "call_remote", "reliable", 0)
func _welcome(state: Dictionary, spawn: Vector3) -> void:
	if mode != "client": return
	members[1] = true
	status = "Connected / Faceless 2 co-op"
	game.revision = -1
	game.receive_state(state)
	game.player.reset_to(spawn)
	# Briefing is local UI only; the host controls shared time and never
	# drives the joining player's camera. The client can dismiss it anytime.
	if not game.fps_arena.visible: game.ui.open_briefing()

@rpc("authority", "call_remote", "reliable", 0)
func _reject(reason: String) -> void:
	leave()
	status = reason
	game.running = false
	game.ui.open_lobby()

func _failed() -> void:
	leave()
	status = "连接失败：房主 UDP 不可达（需要端口映射或同一局域网）"
	game.ui.open_lobby()

func _lost_host() -> void:
	leave()
	status = "Host disconnected. Return to solo or reconnect."
	game.running = false
	game.ui.open_lobby()

func _process(delta: float) -> void:
	if mode == "solo": return
	if mode == "client" and members.is_empty():
		connect_elapsed += delta
		if connect_elapsed > 12: _failed()
		return
	if not game.running: return
	pose_elapsed += delta
	state_elapsed += delta
	if pose_elapsed >= 0.05:
		pose_elapsed = 0
		var p: Vector3 = game.player.position
		if mode == "client": _submit_pose.rpc_id(1, p, game.player.yaw, game.ui.monitoring,game.player.pitch)
		else:
			poses[1] = {"p":p, "y":game.player.yaw,"pitch":game.player.pitch}
			send_members("_pose_bundle",[poses])
	if mode == "host" and state_elapsed >= 0.2:
		state_elapsed = 0
		send_members("_shared_state",[game.snapshot()])
		if game.fps_arena.visible: broadcast_fps_state(game.fps.health_by_peer,game.fps.ammo_by_peer,game.fps.scores)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_pose(pos: Vector3, yaw: float, monitoring: bool, pitch: float) -> void:
	if mode != "host" or not pos.is_finite() or not is_finite(yaw) or not is_finite(pitch) or pitch < -1.37 or pitch > 1.31: return
	var id := multiplayer.get_remote_sender_id()
	if not members.has(id): return
	var now := Time.get_ticks_msec()
	var elapsed := clampf(float(now - int(pose_times.get(id, now))) / 1000, 0.05, 1.0)
	var old: Vector3 = poses[id].p
	if game.fps_arena.visible:
		if absf(pos.x) > 23.6 or absf(pos.z) > 23.6 or pos.y < -.5 or pos.y > 3.1: return
	else:
		if absf(pos.x) > 14.6 or pos.z < -29.6 or pos.z > 11.6 or pos.y < -0.5 or pos.y > 1.0: return
	if pos.distance_to(old) > elapsed * 5.0 + 0.8: return
	poses[id] = {"p":pos, "y":yaw,"pitch":pitch}
	pose_times[id] = now
	monitor_flags[id] = false
	game.update_crew(poses)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _pose_bundle(bundle: Dictionary) -> void:
	poses = bundle
	game.update_crew(poses)

@rpc("authority", "call_remote", "reliable", 2)
func _shared_state(state: Dictionary) -> void:
	game.receive_state(state)

# SceneMultiplayer broadcasts include unauthenticated and closing peers.
# Only send game state to authenticated, live ENet transports; a recently
# disconnected transport can remain in the scene peer list with 0 channels.
func can_send(id: int) -> bool:
	if not is_instance_valid(peer) or not multiplayer.get_peers().has(id): return false
	var transport := peer.get_peer(id)
	return transport != null and transport.is_active() and transport.get_state() == ENetPacketPeer.STATE_CONNECTED and transport.get_channels() > 2

func send_members(method: String, arguments: Array) -> void:
	if mode != "host": return
	for id in members:
		if int(id) == 1 or not can_send(int(id)): continue
		callv("rpc_id",[int(id),StringName(method)]+arguments)

func request(action: String, index: int = 0) -> void:
	if authoritative(): game.apply_action(action, index, game.player.position, game.ui.monitoring)
	elif not members.is_empty(): _submit_action.rpc_id(1, action, index, game.ui.monitoring)

@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_action(action: String, index: int, monitoring: bool) -> void:
	if mode != "host": return
	var id := multiplayer.get_remote_sender_id()
	if not members.has(id) or not poses.has(id): return
	var now := Time.get_ticks_msec()
	if now - int(action_times.get(id, 0)) < 180: return
	action_times[id] = now
	# Carry monitor intent on this reliable message. A pose on channel 1 can
	# arrive after an action on channel 0 when the monitor is first raised.
	# The host still checks the authoritative position before every action.
	game.apply_action(action, index, poses[id].p, monitoring)
	send_members("_shared_state",[game.snapshot()])

# FPS is a separate arena session. ENet room/password/version handshake and
# real UDP movement stay intact; actions are authenticated and host-authoritative.
func request_fps_fire(direction: Vector3) -> void:
	if not game.fps_arena.visible: return
	if mode == "client":
		if members.has(1): _fps_fire.rpc_id(1,direction)
	elif authoritative():
		game.fps.server_fire(1,direction)

@rpc("any_peer","call_remote","reliable",0)
func _fps_fire(direction: Vector3) -> void:
	if mode != "host" or not game.fps_arena.visible: return
	var id: int = multiplayer.get_remote_sender_id()
	if not members.has(id): return
	game.fps.server_fire(id,direction)

func request_fps_reload() -> void:
	if not game.fps_arena.visible: return
	if mode == "client":
		if members.has(1): _fps_reload.rpc_id(1)
	elif authoritative(): game.fps.server_reload(1)

@rpc("any_peer","call_remote","reliable",0)
func _fps_reload() -> void:
	if mode != "host" or not game.fps_arena.visible: return
	var id: int = multiplayer.get_remote_sender_id()
	if members.has(id): game.fps.server_reload(id)

func broadcast_fps_state(hp: Dictionary, ammo: Dictionary, points: Dictionary) -> void:
	if not authoritative() or not game.fps_arena.visible: return
	game.fps.receive_fps_state(hp,ammo,points,game.fps.combat_state())
	if mode == "host": send_members("_fps_state",[hp,ammo,points,game.fps.combat_state()])

@rpc("authority","call_remote","reliable",2)
func _fps_state(hp: Dictionary, ammo: Dictionary, points: Dictionary, combat: Dictionary) -> void:
	if game.fps_arena.visible: game.fps.receive_fps_state(hp,ammo,points,combat)

@rpc("authority","call_remote","reliable",0)
func _fps_join(spawn: Vector3, hp: Dictionary, ammo: Dictionary, points: Dictionary, combat: Dictionary) -> void:
	if mode != "client": return
	game.start_fps_arena()
	# Actual authoritative peer spawn (ENet peer IDs are not seat numbers).
	game.player.reset_to(spawn)
	game.fps.receive_fps_state(hp,ammo,points,combat)

func send_fps_respawn(id: int, pos: Vector3) -> void:
	if not authoritative() or not game.fps_arena.visible: return
	if id == 1: game.player.reset_to(pos)
	elif mode == "host" and can_send(id): _fps_respawn.rpc_id(id,pos)
	poses[id] = {"p":pos,"y":0.0,"pitch":0.0}

@rpc("authority","call_remote","reliable",0)
func _fps_respawn(pos: Vector3) -> void:
	if mode == "client" and game.fps_arena.visible: game.player.reset_to(pos)
