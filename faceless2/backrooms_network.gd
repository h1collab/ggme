extends Node

# Android-native ENet direct peer hosting. No account, matchmaking or paid API.
# Host owns the clock and all consequential actions; clients submit intentions.
const PROTOCOL := 11
const MAX_CREW := 4
var game: Node
var peer: ENetMultiplayerPeer
var mode := "solo"
var status := "Offline / solo"
var port := 24711
var members: Dictionary = {}
var poses: Dictionary = {}
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

func _ready() -> void:
	name = "DirectSession"
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_lost_host)

func authoritative() -> bool:
	return mode != "client"

func host(selected_port: int, key: String, map_router: bool) -> Error:
	leave()
	port = selected_port
	password = key.substr(0, 24)
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_server(port, MAX_CREW - 1, 3)
	if result != OK:
		peer = null
		status = "Port unavailable. Choose another UDP port."
		return result
	multiplayer.multiplayer_peer = peer
	mode = "host"
	members = {1:true}
	status = "Hosting / %s:%d / 1 of 4" % [local_address(), port]
	if map_router and upnp_thread == null:
		upnp_thread = Thread.new()
		upnp_thread.start(_map_router.bind(generation, port))
	return OK

func join(address: String, selected_port: int, key: String) -> Error:
	leave()
	if address.strip_edges().is_empty():
		status = "Enter the host IP or hostname."
		return ERR_INVALID_PARAMETER
	password = key.substr(0, 24)
	port = selected_port
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_client(address.strip_edges(), port, 3)
	if result != OK:
		peer = null
		status = "Cannot open connection. Check the address and port."
		return result
	multiplayer.multiplayer_peer = peer
	mode = "client"
	status = "Connecting…"
	connect_elapsed = 0
	return OK

func leave() -> void:
	generation += 1
	if is_instance_valid(peer): peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	mode = "solo"
	members.clear()
	poses.clear()
	monitor_flags.clear()
	action_times.clear()
	pose_times.clear()
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
		mapped = gateway.add_port_mapping(selected_port, selected_port, "Zorix Backrooms", "UDP", 3600) == UPNP.UPNP_RESULT_SUCCESS
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
	monitor_flags.erase(id)
	pose_times.erase(id)
	action_times.erase(id)
	disconnected_count += 1
	game.remove_crew(id)

func _connected() -> void:
	peer.get_peer(1).set_timeout(32, 5000, 15000)
	_hello.rpc_id(1, PROTOCOL, password)

@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(version: int, key: String) -> void:
	if mode != "host": return
	var id := multiplayer.get_remote_sender_id()
	if version != PROTOCOL or key != password or members.size() >= MAX_CREW:
		_reject.rpc_id(id, "Version or room key mismatch, or room full.")
		return
	members[id] = true
	poses[id] = {"p":game.level.spawn + Vector3(0.9 * (members.size() - 1), 0, 0), "y":0.0}
	pose_times[id] = Time.get_ticks_msec()
	_welcome.rpc_id(id, game.snapshot(), poses[id].p)
	status = "Hosting / %s:%d / %d of 4" % [local_address(), port, members.size()]

@rpc("authority", "call_remote", "reliable", 0)
func _welcome(state: Dictionary, spawn: Vector3) -> void:
	if mode != "client": return
	members[1] = true
	status = "Connected / cooperative shift"
	game.revision = -1
	game.receive_state(state)
	game.player.reset_to(spawn)
	game.ui.close_panels()

@rpc("authority", "call_remote", "reliable", 0)
func _reject(reason: String) -> void:
	leave()
	status = reason
	game.running = false
	game.ui.open_lobby()

func _failed() -> void:
	leave()
	status = "Connection failed. Check host IP, UDP port and network."
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
		if mode == "client": _submit_pose.rpc_id(1, p, game.player.yaw, game.ui.monitoring)
		else:
			poses[1] = {"p":p, "y":game.player.yaw}
			_pose_bundle.rpc(poses)
	if mode == "host" and state_elapsed >= 0.2:
		state_elapsed = 0
		_shared_state.rpc(game.snapshot())

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_pose(pos: Vector3, yaw: float, monitoring: bool) -> void:
	if mode != "host" or not pos.is_finite() or not is_finite(yaw): return
	var id := multiplayer.get_remote_sender_id()
	if not members.has(id): return
	var now := Time.get_ticks_msec()
	var elapsed := clampf(float(now - int(pose_times.get(id, now))) / 1000, 0.05, 1.0)
	var old: Vector3 = poses[id].p
	if absf(pos.x) > 14.6 or pos.z < -29.6 or pos.z > 11.6 or pos.y < -0.5 or pos.y > 1.0: return
	if pos.distance_to(old) > elapsed * 5.0 + 0.8: return
	poses[id] = {"p":pos, "y":yaw}
	pose_times[id] = now
	monitor_flags[id] = monitoring and pos.distance_to(game.level.console_position) < 3.5
	game.update_crew(poses)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _pose_bundle(bundle: Dictionary) -> void:
	poses = bundle
	game.update_crew(poses)

@rpc("authority", "call_remote", "reliable", 2)
func _shared_state(state: Dictionary) -> void:
	game.receive_state(state)

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
	_shared_state.rpc(game.snapshot())
