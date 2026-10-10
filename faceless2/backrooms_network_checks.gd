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

func check(ok: bool, detail: String) -> void:
	if not ok:
		failure = true
		push_error("FAIL: " + role + ": " + detail)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout

func wait_join() -> void:
	for i in range(65):
		if not game.net.members.is_empty() or game.net.mode == "solo": return
		await wait_seconds(0.1)
	check(false, "Handshake timed out")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.ui.intro_timer.stop()
	check(game.net.PROTOCOL == 16, "Protocol v16 keeps authoritative evidence and choice synchronization")
	if role == "host":
		check(game.net.host(port, "faceless16", false) == OK, "Host opened")
		game.start_shift(0)
		print("HOST_READY")
		await wait_seconds(3)
		check(game.net.members.size() >= 2, "Authenticated client joined")
		check(not game.repaired[0], "Unauthorized distant client collection rejected")
		check(game.crew.size() >= 1, "Remote crew GLB populated")
		var moved := false
		for id in game.net.poses:
			if id != 1 and game.net.poses[id].p.z < 8.8: moved = true
		check(moved, "Real client motion replicated")
		game.apply_action("collect", 0, game.level.relays[0] + Vector3(0,0,1), false)
		check(game.repaired[0], "Host collects real story clue")
		await wait_seconds(2)
		game.start_shift(1)
		await wait_seconds(5)
		check(game.net.disconnected_count >= 2, "Wrong-key and graceful disconnect cleaned")
		check(game.net.members.size() == 2, "Late join still occupies one slot")
		game.net.leave()
		await wait_seconds(1)
	elif role == "client":
		check(game.net.join("127.0.0.1", port, "faceless16") == OK, "Client socket open")
		await wait_join()
		check(game.running and game.stage == 0 and game.repaired == [false,false,false], "Authoritative initial state received")
		game.net.request("collect", 0)
		await wait_seconds(0.35)
		check(not game.repaired[0], "Distance validation rejects remote clue pickup")
		game.ui.close_panels()
		game.player.set_physics_process(true)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_W
		key.pressed = true
		Input.parse_input_event(key)
		await wait_seconds(0.85)
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
		game.player.set_physics_process(false)
		for i in range(70):
			if game.repaired[0]: break
			await wait_seconds(0.1)
		check(game.repaired[0], "Shared clue propagated from host")
		for i in range(70):
			if game.stage == 1: break
			await wait_seconds(0.1)
		check(game.stage == 1 and game.repaired == [false,false,false], "New layer and clue reset synchronized")
		check(game.player.position.distance_to(game.level.spawn) < 3, "Client safely respawned")
		game.net.leave()
	elif role == "late":
		check(game.net.join("127.0.0.1", port, "faceless16") == OK, "Late client socket open")
		await wait_join()
		for i in range(25):
			if game.repaired[0]: break
			await wait_seconds(0.1)
		check(game.repaired[0] and game.stage == 0, "Late client gets current shared clue")
		await wait_seconds(8)
		check(game.net.mode == "solo" and not game.running, "Host loss returns to lobby")
		check(game.ui.panel_kind == "lobby", "Disconnect leaves usable lobby")
	elif role == "reject":
		check(game.net.join("127.0.0.1", port, "wrong-key") == OK, "Wrong key socket opened")
		await wait_join()
		check(game.net.mode == "solo" and game.net.status.contains("mismatch"), "Wrong key rejected")
	elif role == "drophost":
		check(game.net.host(port, "faceless16", false) == OK, "Abrupt-disconnect host opened")
		game.start_shift(0)
		print("DROP_HOST_READY")
		for i in range(120):
			if game.net.members.size() == 2: break
			await wait_seconds(0.1)
		check(game.net.members.size() == 2, "Real remote peer joined")
		game.apply_action("collect", 0, game.level.relays[0] + Vector3(0,0,1), false)
		check(game.repaired[0], "Host collected clue")
		print("DROP_ACTION_RECEIVED")
		for i in range(210):
			if game.net.members.size() == 1: break
			await wait_seconds(0.1)
		check(game.net.members.size() == 1 and game.crew.is_empty(), "Killed peer seat and avatar reclaimed")
	elif role == "dropclient":
		check(game.net.join("127.0.0.1", port, "faceless16") == OK, "Drop client socket open")
		await wait_join()
		for i in range(75):
			if game.repaired[0]: break
			await wait_seconds(0.1)
		check(game.repaired[0], "Authoritative clue replicated")
		if not failure: print("DROP_ACTION_REPLICATED")
		await wait_seconds(40)
		check(false, "Harness must kill dropclient before clean exit")
	else:
		check(false, "Unknown network test role")
	game.net.leave()
	game.queue_free()
	await wait_seconds(0.15)
	if not failure: print("P2P " + role + ": PASS")
	quit(1 if failure else 0)
