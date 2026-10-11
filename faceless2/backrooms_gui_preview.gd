extends SceneTree
# A real Godot desktop viewport preview, not an APK, emulator or headless render.
# Run only after assets have been imported into the temporary desktop project.
var game: Node3D
var prologue: Node3D
var output_dir := ""
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func _capture(tag: String) -> void:
	for i in range(5): await process_frame
	var picture: Image = root.get_texture().get_image()
	var file := output_dir.path_join(tag + ".png")
	var result := picture.save_png(file)
	if result != OK: failures.append("Could not capture Godot viewport: " + tag)
	else: print("GODOT_GUI_PREVIEW " + tag + " " + str(picture.get_width()) + "x" + str(picture.get_height()))
	print("PREVIEW_CAMERA " + tag + " camera=" + str(root.get_camera_3d().global_position))

func _advance_frames(count: int) -> void:
	for i in range(count):
		prologue.advance(0.15)
		await process_frame

func run() -> void:
	output_dir = OS.get_environment("FACELESS_PREVIEW_DIR")
	if output_dir.is_empty(): output_dir = OS.get_user_data_dir().path_join("preview_frames")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1600, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.ui.menu()
	await _capture("00_title")
	game.start_prologue()
	prologue = game.prologue
	prologue.set_process(false)
	await _capture("01_surveillance_far")
	await _advance_frames(11)
	await _capture("02_camera_push")
	await _advance_frames(8)
	await _capture("03_phone_ringing")
	prologue.answer()
	await _advance_frames(4)
	await _advance_frames(6)
	await _capture("04_distortion")
	await _advance_frames(12)
	await _advance_frames(9)
	await _capture("05_blackout")
	await _advance_frames(8)
	await _capture("06_wake_floor_blur")
	await _advance_frames(19)
	await _capture("07_wake_mid")
	await _advance_frames(20)
	await _capture("08_wake_dark")
	await _advance_frames(4)
	if prologue.phase == "ended":
		await _capture("09_after_wake_live_scene")
		prologue.look_after_wake(Vector2(90,0))
		await _capture("10_look_around")
	if prologue.phase != "wake" and prologue.phase != "ended":
		failures.append("Wrong cinematic phase: " + prologue.phase)
	game.net.leave()
	for kind in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for sound in game.find_children("*", kind, true, false):
			sound.stop()
			sound.stream = null
	game.queue_free()
	for i in range(8): await process_frame
	if failures.is_empty():
		print("GODOT_GUI_PREVIEW_PASS (independent desktop viewport, not APK)")
		quit(0)
	else:
		for reason in failures: push_error(reason)
		quit(1)
