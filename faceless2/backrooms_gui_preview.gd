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
	# This preview intentionally freezes the main game timeline. Refresh the
	# objective explicitly so screenshots never display stale quest text.
	if is_instance_valid(game) and is_instance_valid(game.ui): game.ui.refresh()
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
	var entity = game.wakeup_room.smiler
	if entity is Sprite3D:
		var tex := (entity as Sprite3D).texture
		print("SMILER_SPRITE_DEBUG imported=", tex != null,
			" size=", tex.get_size() if tex != null else Vector2.ZERO,
			" billboard=", (entity as Sprite3D).billboard, " pos=",entity.position)
		# Do not request a GPU texture readback during GUI scene execution;
		# the exact source PNG is copied into the artifact in the workflow.
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
	# Player must actively turn to trigger the direction-dependent entity.
	await _capture("09_waiting_no_smiler")
	for i in range(18): prologue.advance(0.15)
	await _capture("10_still_no_smiler")
	if prologue.phase != "smiler_wait_turn": failures.append("Sight event auto-triggered without looking")
	# Pixel-identical paired frames with the same camera and same room. This
	# detects a real renderer-invisible sprite instead of trusting only state.
	game.ui.prologue_wake_clear()
	game.wakeup_room.smiler_stage(0.0, "hidden")
	await _capture("10a_hidden_comparison")
	game.wakeup_room.smiler_stage(0.0, "watch")
	await _capture("10b_forced_visible_comparison")
	game.wakeup_room.smiler_stage(0.0, "hidden")
	prologue.look_before_smiler(Vector2(-590,0))
	for i in range(8):
		prologue.advance(0.15)
		await process_frame
		if prologue.phase == "smiler_watch":
			prologue.advance(0.08)
			await process_frame
			await _capture("11_smiler_far_flash")
			break
	for i in range(5): prologue.advance(0.15)
	await _capture("12_smiler_disappears")
	for i in range(8):
		prologue.advance(0.15)
		await process_frame
		if prologue.phase == "smiler_near":
			prologue.advance(0.07)
			await process_frame
			await _capture("13_smiler_near_flash")
			break
	for i in range(3): prologue.advance(0.15)
	if prologue.phase == "ended":
		await _capture("14_controls_unlocked")
		# Visual QA: the actual held GLB and light drive a separate Smiler fade.
		game.player.global_position = game.wakeup_room.flashlight_pickup_position
		game.player.interact_or_locked_door()
		game.player.camera.rotation.x = -0.12
		await _capture("14a_glb_flashlight_held")
		if game.player.viewmodel_root.visible: failures.append("Hands must disappear entirely with the carried GLB flashlight")
		if not game.player.flashlight_model.visible: failures.append("Independent Poly Haven GLB flashlight is missing from view")
		game.player.toggle_torch()
		game.player.camera.look_at(game.wakeup_room.smiler.global_position)
		await _capture("14b_smiler_lit_before_banish")
		# Invoke the real player spotlight cone/range check, not the banish method.
		game.player._physics_process(0.22)
		if not game.wakeup_room.smiler_flashlight_faded:
			failures.append("Light cone aiming did not make visible Smiler disappear")
		await create_timer(0.40).timeout
		await _capture("14c_smiler_banished")
		game.player.pitch = -1.15
		game.player.camera.rotation.x = -1.15
		game.player.leg_root.visible = true
		await _capture("14d_actual_glb_feet_downlook")
		game.player.pitch = 0.0
		game.player.camera.rotation.x = 0.0
		game.player.global_position = Vector3(0,0.10,-3.1)
		game.wakeup_room.begin_frowner()
		game.player.camera.look_at(game.wakeup_room.frowner.global_position)
		await create_timer(0.8).timeout
		await _capture("14e_frowner_second_door")
		game.wakeup_room.update_frowner(4.8)
		await create_timer(1.8).timeout
		await _capture("14f_frowner_fades")
		game.player.look(Vector2(90,0))
		await _capture("15_player_looks_around")
		var door: Node3D = game.wakeup_room.openable_door
		if is_instance_valid(door):
			game.player.global_position = door.global_position + Vector3(0,0.10,0.65)
			game.player.interact_or_locked_door()
			if not game.extra_levels.visible or game.extra_levels.current != 0: failures.append("GLB threshold must lead straight to Level 0")
			await _capture("16_kenney_glb_threshold_into_level_0")
		else: failures.append("Missing authored transition doorway")
	else: failures.append("Second apparition did not release movement")
	# Desktop-rendered stage inspection must exercise licensed real GLB imports.
	for number in [0,1,2,5,6,130,131,132,133]:
		game.open_backrooms_level(number)
		game.player.global_position = Vector3(0,0.10,1.3)
		game.player.camera.look_at(Vector3(-1.5,1.4,-13.0))
		await _capture("30_level_%d_entrance_authored_glb" % number)
		game.player.global_position = Vector3(0,0.10,-13.0)
		game.player.camera.look_at(Vector3(-1.8,1.4,-19.0))
		game.extra_levels.update_player(game.player.global_position,.15)
		await _capture("31_level_%d_passive_entity" % number)
		game.player.global_position = Vector3(0,0.10,-21.5)
		game.player.camera.look_at(Vector3(0,1.6,-27.0))
		await _capture("32_level_%d_real_depth" % number)
	game.extra_levels.clear()
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
