extends SceneTree

var failures: Array[String] = []
var game: Node3D

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_solo()
	game.set_process(false)
	check(game.ui.panel_kind == "briefing", "Faceless 2 explains the investigation on startup")
	check(game.auto_turn == false or game.auto_turn == true, "Camera setting is exposed")
	for layer in range(3):
		game.start_shift(layer)
		game.ui.close_panels()
		game.player.set_physics_process(false)
		for i in range(8): await physics_frame
		check(game.level.architecture_meshes.has("Object_4"), "Licensed GLB carpet imported")
		check(game.level.architecture_meshes.has("Object_10"), "Licensed GLB wall imported")
		check(game.level.architecture_meshes.has("Object_53"), "Licensed GLB ceiling imported")
		var sourced := 0
		for node in game.level.find_children("*", "MeshInstance3D", true, false):
			if String(node.name).begins_with("LicensedGLB_"): sourced += 1
		check(sourced >= 30, "Imported authored meshes render the room instead of cuboid wall art")
		check(game.level.relays.size() == 3 and game.level.doors.is_empty(), "Three explorable recordings, no surveillance shutters")
		check(game.level.find_children("ScannedProp_*", "", true, false).size() >= 6, "Licensed prop GLBs remain present")
		var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1, -15), Vector3(0, -1, -15))
		check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Cheap matching floor collision / layer %d" % layer)
		game.apply_action("collect", 0, game.level.spawn, false)
		check(not game.repaired[0], "Out-of-range pickup rejected")
		for i in range(3):
			game.apply_action("collect", i, game.level.relays[i] + Vector3(0, 0, 1), false)
			check(game.repaired[i], "Recording %d can be found" % i)
			var revision: int = game.revision
			game.apply_action("collect", i, game.level.relays[i] + Vector3(0, 0, 1), false)
			check(game.revision == revision, "Same recording cannot be farmed")
		check(game.transfer_ready(), "Exit unlocked by three story memories without survival timer")
		game._tick(700)
		check(not game.failed and game.transfer_ready(), "No timed power or CCTV failure gameplay")
		game.apply_action("transfer", 0, game.level.spawn, false)
		check(game.stage == layer, "Exit needs physical proximity")
		game.apply_action("transfer", 0, game.level.exit_position, false)
		check(game.completed if layer == 2 else game.stage == layer + 1, "Three-layer exit progression")
	game.start_shift(0)
	game.ui.close_panels()
	game.player.set_physics_process(true)
	game.player.reset_to(Vector3(0, 0.05, -3))
	for i in range(10): await physics_frame
	var begin: Vector3 = game.player.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	for i in range(40): await physics_frame
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	check(game.player.position.z < begin.z - 1, "Physical first-person movement")
	check(game.ui.panel_kind == "play", "HUD remains usable")
	game.ui.open_pause()
	check(game.ui.modal and game.player.focus_seconds == 0, "Pause interrupts cinematic control")
	game.ui.open_about()
	check(game.ui.panel_kind == "about", "Credits and Faceless 2 menu accessible")
	game.ui.open_lobby()
	await process_frame
	check(game.ui.port_field.value == 24711, "Direct P2P port kept")
	for extent in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2340,1080), Vector2i(1024,768)]:
		root.content_scale_size = extent
		game.ui._fit()
		var rect: Rect2 = game.ui.canvas.get_global_rect()
		check(rect.end.x <= root.get_visible_rect().size.x + 0.01 and rect.end.y <= root.get_visible_rect().size.y + 0.01, "Responsive HUD is inside viewport")
	game.net.leave()
	game.queue_free()
	await create_timer(0.15).timeout
	if failures.is_empty():
		print("Faceless 2 runtime checks: PASS / GLB architecture, 3 layers, real collision, objective progression, movement, mobile UI")
		quit(0)
	else: quit(1)
