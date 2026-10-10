extends SceneTree

var game: Node3D
var output := "user://visual-qa"
var captures := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func shot(filename: String) -> void:
	game.ui.refresh()
	game.level.update_state(game.doors, game.lights_on, game.anomaly, game.repaired, 0.2, game.ui.monitor_camera.position if game.ui.monitoring else game.player.position, 3)
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var result := picture.save_png(output.path_join(filename + ".png"))
	if result != OK:
		push_error("Capture failed: " + filename)
		quit(1)
	captures += 1
	print("Captured " + filename)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.ui.intro_timer.stop()
	game.set_quality(2)
	await shot("00-team-intro")
	game.ui.menu()
	await shot("01-main-menu")
	game.ui.open_about()
	await shot("02-about-us")
	game.ui.open_guide()
	await shot("03-field-guide")
	game.start_shift(0)
	game.ui.close_panels()
	game.player.reset_to(Vector3(0, 0.05, 0))
	game.player.yaw = -0.42
	game.player.rotation.y = -0.42
	await shot("04-level-zero")
	game.player.reset_to(Vector3(0, 0.05, 8))
	game.ui.open_monitor()
	game.ui.select_camera(0)
	game.anomaly = 0
	game.level.update_state(game.doors, true, 0, game.repaired, 0.2)
	await shot("05-level-zero-monitor")
	game.start_shift(1)
	game.ui.close_panels()
	game.player.reset_to(Vector3(8, 0.05, -11))
	game.player.yaw = 0.18
	game.player.rotation.y = 0.18
	await shot("06-service-depths")
	game.player.reset_to(Vector3(0, 0.05, 8))
	game.ui.open_monitor()
	game.ui.select_camera(1)
	await shot("07-service-monitor")
	game.start_shift(2)
	game.ui.close_panels()
	game.player.reset_to(Vector3(7, 0.05, -10))
	game.player.yaw = -0.35
	game.player.rotation.y = -0.35
	await shot("08-still-water")
	game.ui.open_lobby()
	await shot("09-p2p-lobby")
	game.completed = true
	game.notice = "All three layers surveyed. Your crew made it through."
	game.ui.open_result()
	await shot("10-survey-complete")
	for layer in range(3):
		game.start_shift(layer)
		game.ui.open_monitor()
		for cam in range(3):
			if (layer == 0 and cam == 0) or (layer == 1 and cam == 1): continue
			game.ui.select_camera(cam)
			await shot("%02d-layer-%02d-camera-%02d" % [captures, layer, cam + 1])
	game.ui.monitor_view.world_3d = null
	game.net.leave()
	game.queue_free()
	await create_timer(0.15).timeout
	print("Backrooms visual captures: PASS / %d actual Mobile views" % captures)
	quit(0)
