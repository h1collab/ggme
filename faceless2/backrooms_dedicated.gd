extends SceneTree
# JS supervises a genuine headless authoritative Godot room. Server never
# occupies a seat, fires or contributes a dummy score. Key comes via stdin.
var game: Node3D
var tick := 0.0
var idle := 0.0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=",true,1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	var port := int(options.get("port",0))
	var slots := int(options.get("slots",6))
	var map_id := int(options.get("map",-1))
	var key := OS.read_string_from_stdin().strip_edges()
	if port < 1024 or port > 65535 or slots < 2 or slots > 6 or map_id < 0 or map_id > 3 or key.length() != 24:
		quit(2); return
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop()
	if game.net.host(port,key,false,slots,true) != OK: quit(3); return
	game.start_fps_arena(map_id)
	game.player.set_physics_process(false)
	game.ui.hide()
	game.fps_arena.set_process(false)
	game.fps.set_process(false)
	print("FAC2_DEDICATED_READY")
func _process(delta: float) -> bool:
	if not is_instance_valid(game) or not game.net.dedicated: return false
	# Normal gameplay authority and net process remain running; viewmodel-only
	# frame animation is disabled. Round/reload clocks use the server monotonic time.
	game.fps.finish_server_reloads()
	game.fps._advance_match_clock()
	tick += delta
	idle = idle+delta if game.net.members.is_empty() else 0.0
	if tick >= 1.0:
		tick = 0.0
		print("FAC2_DEDICATED_STATE ",JSON.stringify({"players":game.net.members.size()}))
	if idle > 120: quit(0)
	return false
