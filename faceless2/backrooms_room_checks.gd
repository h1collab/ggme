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
	check(game.net.PROTOCOL == 16 and game.rooms.VERSION == 16, "wire protocol 16")
	if role == "host":
		game.rooms.create_room(true, 2, "Black Corridor")
		check(await wait_for(func(): return game.rooms.room_code.length() == 8), "HTTP JS registration returns room code")
		check(game.net.mode == "host" and game.net.max_crew == 2, "host imposes 2-person limit")
		print("ROOM_READY ", game.rooms.room_code)
		check(await wait_for(func(): return game.net.members.size() == 2, 12.0), "real ENet peer joined by room code")
		game.apply_action("pickup", 0, game.level.water_position, false)
		check(game.water_picked and int(game.inventory["almond_water"]) == 1, "real authoritative shared almond-water pickup")
		await create_timer(1.0).timeout
	elif role == "client":
		game.rooms.join_code(code)
		check(await wait_for(func(): return game.net.mode == "client" and game.net.members.has(1), 12.0), "no-IP code resolves JS room into native UDP connection")
		check(game.net.mode == "client" and game.rooms.room_code == code, "joined exact room")
		check(await wait_for(func(): return game.water_picked and int(game.inventory["almond_water"]) == 1, 7.0), "authoritative pickup synchronized over ENet")
	else:
		check(false, "unknown test role")
	game.net.leave()
	game.queue_free()
	await create_timer(0.45).timeout
	if failures.is_empty(): print("Faceless 2 room directory %s: PASS" % role)
	quit(0 if failures.is_empty() else 1)
