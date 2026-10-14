extends SceneTree
# User-authorized Linux+xvfb native screenshots of both shipped FPS maps.
var game: Node3D
var output_dir := ""
var issues: Array[String] = []
func _initialize() -> void: call_deferred("run")
func shot(label: String, at: Vector3, target: Vector3, fire: bool = false) -> void:
	game.player.velocity = Vector3.ZERO
	game.player.global_position = at
	game.player.camera.look_at(target)
	game.ui.refresh()
	for i in range(35): await process_frame
	if fire:
		game.fps.fire()
		for i in range(2): await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.is_empty() or img.save_png(output_dir.path_join(label+".png")) != OK: issues.append(label)
	else: print("GODOT_GUI_PREVIEW ",label)
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
	game.set_process(false)
	for map_id in [0,1]:
		game.ui.touch_preview = false
		game.start_fps_arena(map_id)
		game.player.set_physics_process(false)
		var prefix := "map%d_" % map_id
		await shot(prefix+"00_overview",Vector3(-7,.12,7),Vector3(8,1.6,-13))
		await shot(prefix+"01_hip",Vector3(0,.12,0),Vector3(0,1.6,-18))
		game.fps.set_aim(true)
		await shot(prefix+"02_ads",Vector3(0,.12,0),Vector3(0,1.6,-18))
		game.fps.set_aim(false)
		await shot(prefix+"03_fire_finish",Vector3(0,.12,0),Vector3(0,1.6,-18),true)
		await shot(prefix+"04_original_scanned_cover",Vector3(9,.12,9),Vector3(15,1.3,5))
		await shot(prefix+"05_near_shipped_wall",Vector3(0,.12,-23.45),Vector3(0,1.6,-26))
		await shot(prefix+"06_ground_material_shadow",Vector3(0,.12,0),Vector3(1.2,0,-.4))
		game.ui.touch_preview = true
		game.ui.prologue_finished()
		await shot(prefix+"07_mobile_hud",Vector3(-7,.12,7),Vector3(8,1.6,-13))
		game.fps.measure_grip()
		print("PREVIEW_MAP ",map_id," GEOMETRY ",game.fps_arena.geometry_digest())
	game.net.leave()
	game.queue_free()
	for i in range(10): await process_frame
	if not issues.is_empty():
		for issue in issues: push_error("Missing native frame "+issue)
		quit(1)
	else:
		print("GODOT_PREVIEW_PASS two shipped FPS maps, source materials, hands, cover, wall and mobile HUD")
		quit(0)
