extends SceneTree
# Native desktop Godot OpenGL capture, independent of Android APK.
var game: Node3D
var output_dir := ""
var issues: Array[String] = []
func _initialize() -> void: call_deferred("run")
func _shot(name: String, position: Vector3, target: Vector3) -> void:
	game.player.global_position = position
	game.player.camera.look_at(target)
	game.ui.refresh()
	for i in range(40): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.is_empty() or image.save_png(output_dir.path_join(name + ".png")) != OK:
		issues.append("Native frame missing: " + name)
	else: print("GODOT_GUI_PREVIEW " + name)
func run() -> void:
	output_dir = OS.get_environment("FACELESS_PREVIEW_DIR")
	if output_dir.is_empty(): output_dir = OS.get_user_data_dir().path_join("preview_frames")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1600,900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop()
	game.net.leave()
	game.start_fps_arena()
	game.player.set_physics_process(false)
	game.set_process(false)
	if not game.fps_arena.visible: issues.append("FPS playfield invisible")
	if game.fps_arena.floor_modules.size() != 16: issues.append("Real GLB ground modules incomplete")
	if not is_instance_valid(game.fps.weapon_model): issues.append("Licensed firearm GLB missing")
	await _shot("00_empty_fps_arena_kenney_glb",Vector3(-7,.12,7),Vector3(7,1.6,-7))
	await _shot("01_glb_blaster_hip_fov",Vector3(-4,.12,3),Vector3(0,1.6,-12))
	game.fps.set_aim(true)
	for i in range(70): await process_frame
	await _shot("02_glb_blaster_aim_down_sights",Vector3(-4,.12,3),Vector3(0,1.6,-12))
	game.fps.set_aim(false)
	game.fps.fire()
	await _shot("03_original_glb_weapon_recoil",Vector3(-2,.12,1),Vector3(0,1.5,-15))
	await _shot("04_blank_playfield_distance",Vector3(5,.12,6),Vector3(-12,1.5,-14))
	await _shot("05_texture_uv_real_glb_ground",Vector3(1,.12,1),Vector3(1,0,-4))
	await _shot("06_weapon_left_sweep",Vector3(0,.12,2),Vector3(-17,1.6,-5))
	await _shot("07_weapon_right_sweep",Vector3(0,.12,2),Vector3(17,1.6,-5))
	await _shot("08_interior_gun_at_low_view",Vector3(0,.12,0),Vector3(0,.15,-3))
	game.fps.set_aim(false)
	game.player.velocity = Vector3(0,0,-2.6)
	game.player.motion_clock += 1.2
	await _shot("09_walk_grip_contact",Vector3(0,.12,0),Vector3(0,1.6,-12))
	game.player.sprinting = true
	game.player.velocity = Vector3(0,0,-4.3)
	game.player.motion_clock += 1.2
	await _shot("10_run_grip_contact",Vector3(0,.12,0),Vector3(0,1.6,-12))
	game.player.velocity = Vector3.ZERO
	game.player.sprinting = false
	game.player.landing_dip = .04
	await _shot("11_landing_grip_contact",Vector3(0,.12,0),Vector3(0,1.6,-12))
	game.player.landing_dip = 0
	game.fps.reload_visual_seconds = .8
	await _shot("12_reload_grip_contact",Vector3(0,.12,0),Vector3(0,1.6,-12))
	await _shot("13_near_boundary_retraction",Vector3(0,.12,-23.6),Vector3(0,1.6,-26))
	game.fps.measure_grip()
	print("PREVIEW_GRIP socket=",game.fps.grip_error," skin=",game.fps.grip_mesh_error)
	game.net.leave()
	game.queue_free()
	for i in range(8): await process_frame
	if not issues.is_empty():
		for issue in issues: push_error(issue)
		quit(1)
	else:
		print("GODOT_PREVIEW_PASS empty FPS arena native frames")
		quit(0)
