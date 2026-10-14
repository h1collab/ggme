extends SceneTree

var failures: Array[String] = []
var game: Node3D
var role := "host"
var directory := ""
var code := ""
var game_port := 24711

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--directory="): directory = arg.trim_prefix("--directory=")
		if arg.begins_with("--room="): code = arg.trim_prefix("--room=")
		if arg.begins_with("--udp-port="): game_port = int(arg.trim_prefix("--udp-port="))
	call_deferred("run")

func check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		push_error("FAIL: " + role + ": " + msg)

func wait_for(checker: Callable, seconds: float = 8.0) -> bool:
	for i in range(int(seconds * 10.0)):
		if checker.call(): return true
		await create_timer(0.1).timeout
	return false

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.ui.intro_timer.stop()
	game.rooms.configure(directory)
	game.rooms.game_port = game_port
	check(game.net.PROTOCOL == 17 and game.rooms.VERSION == 17, "wire protocol 17")
	if role == "host":
		game.rooms.create_room(true, 2, "Black Corridor")
		check(await wait_for(func(): return game.rooms.room_code.length() == 8), "HTTP JS registration returns room code")
		check(game.net.mode == "host" and game.net.max_crew == 2, "host imposes 2-person limit")
		check(not game.fps.match_can_fire(), "One connected host must wait for second player")
		print("ROOM_READY ", game.rooms.room_code)
		check(await wait_for(func(): return game.net.members.size() == 2, 12.0), "real ENet peer joined by room code")
		check(game.fps_arena.visible and game.fps.active and game.fps.match_can_fire(), "Two players can start immediately, no need to wait for four")
		check(await wait_for(func(): return game.fps.ammo_by_peer.values().has(23),7.0), "Remote FPS fire reaches authoritative host via actual ENet UDP")
		await create_timer(1.0).timeout
	elif role == "client":
		game.rooms.join_code(code)
		check(await wait_for(func(): return game.net.mode == "client" and game.net.members.has(1), 12.0), "no-IP code resolves JS room into native UDP connection")
		check(game.net.mode == "client" and game.rooms.room_code == code, "joined exact room")
		check(await wait_for(func(): return game.fps_arena.visible and game.fps.active, 7.0), "Actual FPS arena state synchronized over ENet")
		check(game.fps.match_can_fire(), "Client sees match available at two players")
		game.net.request_fps_fire(Vector3.FORWARD)
		check(await wait_for(func(): return game.fps.magazine == 23,7.0), "Authoritative host ammo update replicated to client")
	else:
		check(false, "unknown test role")
	game.net.leave()
	game.queue_free()
	await create_timer(0.45).timeout
	if failures.is_empty(): print("Faceless 2 room directory %s: PASS" % role)
	quit(0 if failures.is_empty() else 1)
