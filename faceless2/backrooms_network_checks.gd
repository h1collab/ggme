extends SceneTree

var game: Node3D
var role := ""
var port := 24712
var failure := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failure = true
		push_error("FAIL: " + role + ": " + message)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout

func wait_join() -> void:
	for i in range(60):
		if not game.net.members.is_empty() or game.net.mode == "solo": return
		await wait_seconds(0.1)
	check(false, "Timed out waiting for handshake")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.ui.intro_timer.stop()
	if role == "host":
		check(game.net.host(port, "survey11", false) == OK, "ENet server opened")
		game.start_shift(0)
		game.power = 75
		print("HOST_READY")
		await wait_seconds(3)
		check(game.net.members.size() >= 2, "Real client passed handshake")
		await wait_seconds(2)
		check(game.doors[0], "Client shutter intention changed host state")
		check(not game.repaired[0], "Remote repair without proximity rejected")
		check(game.crew.size() >= 1, "Remote player rendered as crew")
		var moved := false
		for id in game.net.poses:
			if id != 1 and game.net.poses[id].p.z < 8.8: moved = true
		print("HOST_POSES ", game.net.poses)
		check(moved, "Real client movement replicated")
		game.start_shift(1)
		await wait_seconds(5)
		check(game.net.disconnected_count >= 2, "Rejected peer and normal leave cleaned up")
		check(game.net.members.size() == 2, "Late client remains; primary client left")
		game.net.leave()
		await wait_seconds(1)

	elif role == "drophost":
		check(game.net.host(port, "survey11", false) == OK, "Abrupt disconnect host opened")
		game.start_shift(0)
		game.power = 75
		print("DROP_HOST_READY")
		for i in range(120):
			if game.net.members.size() == 2: break
			await wait_seconds(0.1)
		check(game.net.members.size() == 2, "Real headless client joined")
		for i in range(100):
			if game.doors[0]: break
			await wait_seconds(0.1)
		check(game.doors[0], "Reliable shutter action reached host")
		print("DROP_ACTION_RECEIVED")
		for i in range(200):
			if game.net.members.size() == 1: break
			await wait_seconds(0.1)
		check(game.net.members.size() == 1, "Killed client releases room slot without graceful leave")
		check(game.crew.is_empty(), "Killed client avatar removed")
	elif role == "dropclient":
		check(game.net.join("127.0.0.1", port, "survey11") == OK, "Abrupt disconnect client opened")
		await wait_join()
		check(game.running and game.power == 75, "Initial shared state received")
		game.ui.open_monitor()
		game.net.request("door", 0)
		for i in range(100):
			if game.doors[0]: break
			await wait_seconds(0.1)
		check(game.doors[0], "Reliable shutter action replicated")
		if not failure: print("DROP_ACTION_REPLICATED")
		await wait_seconds(40)
		check(false, "Client must be killed by the headless test orchestrator")
	elif role == "androidhost":
		check(game.net.host(port, "", false) == OK, "Android integration host opened")
		game.start_shift(0)
		game.power = 75
		print("ANDROID_HOST_READY")
		for i in range(900):
			if game.net.members.size() == 2: break
			await wait_seconds(0.1)
		check(game.net.members.size() == 2, "Installed Android APK joined via ENet")
		print("ANDROID_PEER_JOINED")
		for i in range(500):
			if game.doors[0]: break
			await wait_seconds(0.1)
		check(game.doors[0], "Android touch shutter action reached host")
		print("ANDROID_ACTION_RECEIVED")
		for i in range(200):
			if game.net.members.size() == 1: break
			await wait_seconds(0.1)
		check(game.net.members.size() == 1, "Android app shutdown removed peer")
	elif role == "client":
		check(game.net.join("127.0.0.1", port, "survey11") == OK, "ENet client opened")
		await wait_join()
		check(game.running and game.power == 75, "Authoritative initial state received")
		game.net.request("door", 0)
		await wait_seconds(0.25)
		check(not game.doors[0], "Console actions without an open monitor rejected")
		game.ui.open_monitor()
		await wait_seconds(0.01)
		game.net.request("door", 0)
		await wait_seconds(0.4)
		check(game.doors[0], "Host shutter state replicated back to client")
		game.net.request("repair", 0)
		await wait_seconds(0.4)
		check(not game.repaired[0], "Client cannot repair distant node")
		game.ui.close_panels()
		game.player.set_physics_process(true)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_W
		key.pressed = true
		Input.parse_input_event(key)
		await wait_seconds(0.8)
		print("CLIENT_MOTION ", game.player.position, " / ", game.player.velocity, " / ", Input.is_physical_key_pressed(KEY_W))
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
		game.player.set_physics_process(false)
		for i in range(60):
			if game.stage == 1: break
			await wait_seconds(0.1)
		check(game.stage == 1 and game.repaired == [false,false,false], "Level transition and fresh objectives synchronized")
		check(game.player.position.distance_to(game.level.spawn) < 3, "Client safely respawned in new layer")
		game.net.leave()
	elif role == "late":
		check(game.net.join("127.0.0.1", port, "survey11") == OK, "Late client opened")
		await wait_join()
		check(game.power == 75 and game.doors[0], "Late join receives current shared state")
		await wait_seconds(7)
		check(game.net.mode == "solo" and not game.running, "Host disconnect returns client to a usable lobby")
		check(game.ui.panel_kind == "lobby", "Disconnect UI visible")
	elif role == "reject":
		check(game.net.join("127.0.0.1", port, "wrong-key") == OK, "Rejected client opened")
		await wait_join()
		check(game.net.mode == "solo" and game.net.status.contains("mismatch"), "Wrong room key rejected gracefully")
	else: check(false, "Unknown test role")
	game.net.leave()
	game.ui.monitor_view.world_3d = null
	game.queue_free()
	await wait_seconds(0.15)
	if not failure: print("P2P " + role + ": PASS")
	quit(1 if failure else 0)
