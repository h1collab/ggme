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
	check(game.find_children("*Faceless*", "", true, false).is_empty(), "No monster nodes")
	check(game.find_children("*Soldier*", "", true, false).is_empty(), "No hostile nodes")
	for layer in range(3):
		game.start_shift(layer)
		game.ui.close_panels()
		game.player.set_physics_process(false)
		for i in range(8): await physics_frame
		check(game.level.fixtures.size() == 12, "12 bounded indoor fixtures")
		check(game.level.doors.size() == 2, "Two physical isolation shutters")
		check(game.level.relays.size() == 3, "Three repair nodes")
		check(game.level.cameras.size() == 3, "Three real camera transforms")
		var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1, -15), Vector3(0, -1, -15))
		check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Floor collision layer %d" % layer)
		var initial: float = game.power
		game.apply_action("repair", 0, game.level.spawn, false)
		check(not game.repaired[0], "Cannot repair remotely")
		game.apply_action("report", 0, game.level.console_position, false)
		check(game.mistakes == 0, "Reports require monitoring")
		game.power = 80
		game.apply_action("report", 0, game.level.console_position, true)
		check(game.power == 74 and game.mistakes == 1, "False reports cost exactly 6%")
		game.apply_action("door", -1, game.level.console_position, true)
		check(game.doors == [false, false], "Reject invalid shutter index")
		game.apply_action("door", 0, game.level.console_position, true)
		check(game.doors[0], "Door toggle")
		for i in range(40): game.level.update_state(game.doors, true, -1, game.repaired, 0)
		var closed_ray := PhysicsRayQueryParameters3D.create(Vector3(-5, 1, 3), Vector3(-2, 1, 3))
		await physics_frame
		var closed_hit := game.get_world_3d().direct_space_state.intersect_ray(closed_ray)
		check(not closed_hit.is_empty() and str(closed_hit.collider.name).begins_with("IsolationShutter"), "Closed shutter blocks the passage")
		game.apply_action("door", 0, game.level.console_position, true)
		for i in range(40): game.level.update_state(game.doors, true, -1, game.repaired, 0)
		await physics_frame
		check(game.get_world_3d().direct_space_state.intersect_ray(closed_ray).is_empty(), "Open shutter provides full headroom")
		for i in range(3):
			game.apply_action("repair", i, game.level.relays[i] + Vector3(0, 0, 1), false)
			var charge: float = game.power
			game.apply_action("repair", i, game.level.relays[i] + Vector3(0, 0, 1), false)
			check(game.power == charge, "Repeated repairs do not farm charge")
		check(not game.repaired.has(false), "All nodes can be restored")
		game.ui.monitoring = true
		game._tick(18)
		check(game.anomaly >= 0, "Timed circuit anomaly is triggered")
		var fault: int = game.anomaly
		game.apply_action("report", fault, game.level.console_position, true)
		check(game.reports == 1 and game.anomaly == -1, "Correct camera report resolves circuit")
		game.apply_action("generator", 0, game.level.console_position, true)
		var charge: float = game.power
		game.apply_action("generator", 0, game.level.console_position, true)
		check(game.power == charge and game.heat > 0, "Generator cooldown and heat tradeoff")
		for i in range(2):
			game._tick(25)
			game.apply_action("report", game.anomaly, game.level.console_position, true)
		check(game.reports == 3, "Three actual anomalies resolved")
		game._tick(120)
		check(game.transfer_ready(), "All shift conditions permit transfer")
		game.apply_action("transfer", 0, game.level.spawn, false)
		check(game.stage == layer, "Transfer requires reaching lift")
		game.apply_action("transfer", 0, game.level.exit_position, false)
		check(game.completed if layer == 2 else game.stage == layer + 1, "Physical lift advances layer or completes survey")
		check(initial == 100, "Fresh layer has full reserve")
	# Real player movement/collision, driven through the same keyboard path as gameplay.
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
	check(game.player.position.z < begin.z - 1, "Keyboard movement works in the actual physics loop")
	game.player.reset_to(Vector3(0, 0.05, -28))
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	for i in range(90): await physics_frame
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	check(game.player.position.z > -29.4, "Boundary and lift stop the player")
	# A resource failure is a calm survey end, with a functional restart.
	game.power = 0.01
	game._tick(1)
	check(game.failed and not game.completed, "Exhausted power ends the survey")
	game.ui.open_result()
	check(game.ui.panel_kind == "result", "Failure UI is shown")
	game.start_shift(0)
	game.ui.close_panels()
	check(not game.failed and game.power == 100, "Layer restart restores a valid state")
	for extent in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2340,1080), Vector2i(1024,768)]:
		root.content_scale_size = extent
		game.ui._fit()
		var bounds: Rect2 = game.ui.canvas.get_global_rect()
		check(bounds.position.x >= -0.01 and bounds.position.y >= -0.01, "Responsive layout stays inside viewport")
	game.ui.open_about()
	check(game.ui.panel_kind == "about", "About page available")
	game.ui.open_lobby()
	await process_frame
	for child in game.ui.panels.get_children():
		if child is Label:
			check(child.position.x + child.size.x <= 1600, "Lobby text stays within canvas")
	check(game.ui.port_field.value == 24711, "P2P lobby exposes configurable port")
	game.ui.close_panels()
	check(game.ui.monitor_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden feed does not render on Android")
	game.net.leave()
	game.ui.monitor_view.world_3d = null
	game.queue_free()
	await create_timer(0.15).timeout
	if failures.is_empty():
		print("Backrooms runtime checks: PASS / 3 layers, physics, gameplay, UI, resource failure")
		quit(0)
	else: quit(1)
