extends SceneTree
# Genuine consecutive rendered frames at fixed 20Hz, NO still montage.
var game: Node3D
var camera: Camera3D
var output_dir := ""
var total := 0
var issues: Array[String] = []
func _initialize() -> void: call_deferred("record")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.is_empty():
		issues.append("Empty native viewport")
		return
	img.resize(960,540,Image.INTERPOLATE_BILINEAR)
	if img.save_png(output_dir.path_join("%05d.png" % total)) != OK:
		issues.append("Failed to encode native frame")
	total += 1
func move(start: Vector3, finish: Vector3, look_from: Vector3, look_to: Vector3, frames: int) -> void:
	for i in range(frames):
		var t: float = float(i) / float(maxi(1,frames-1))
		t = t*t*(3.0-2.0*t)
		game.player.global_position = start.lerp(finish,t)
		camera.look_at(look_from.lerp(look_to,t))
		await frame()
func record() -> void:
	output_dir = OS.get_environment("F2_CAPTURE_DIR")
	if output_dir.is_empty():
		push_error("F2_CAPTURE_DIR required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await process_frame
	game.ui.intro_timer.stop()
	game.net.leave()
	game.start_fps_arena()
	game.player.set_physics_process(false)
	camera = game.player.camera
	camera.make_current()
	if not game.fps_arena.visible or not is_instance_valid(game.fps.weapon_model):
		issues.append("Blank FPS GLB arena/weapon unavailable")
	await move(Vector3(-7,.12,7),Vector3(-3,.12,4),Vector3(3,1.58,-10),Vector3(0,1.58,-8),80)
	game.fps.set_aim(true)
	await move(Vector3(-3,.12,4),Vector3(-2,.12,0),Vector3(0,1.58,-8),Vector3(-1,1.5,-16),78)
	game.fps.set_aim(false)
	game.fps.fire()
	await move(Vector3(-2,.12,0),Vector3(4,.12,-6),Vector3(-1,1.5,-16),Vector3(15,1.5,-15),84)
	await move(Vector3(4,.12,-6),Vector3(-4,.12,-8),Vector3(15,1.5,-15),Vector3(-16,1.5,-18),84)
	await move(Vector3(-4,.12,-8),Vector3(0,.12,0),Vector3(-16,1.5,-18),Vector3(0,.35,-3),64)
	game.net.leave()
	game.queue_free()
	for i in range(10): await process_frame
	if total < 390: issues.append("Insufficient real consecutive FPS frames")
	if not issues.is_empty():
		for issue in issues: push_error(issue)
		quit(1)
	else:
		print("GODOT_CONTINUOUS_VIDEO_FRAMES_PASS ",total)
		quit(0)
