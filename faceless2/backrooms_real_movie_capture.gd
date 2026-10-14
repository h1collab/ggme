extends SceneTree
const Assets = preload("backrooms_assets.gd")
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
		var displacement: Vector3 = finish-start
		game.player.velocity = displacement/float(frames)*20.0
		game.player.motion_clock += .05*(10.0 if game.player.sprinting else 7.0)
		var t: float = float(i) / float(maxi(1,frames-1))
		t = t*t*(3.0-2.0*t)
		game.player.global_position = start.lerp(finish,t)
		camera.look_at(look_from.lerp(look_to,t))
		await frame()
func firing_sequence(ads: bool) -> void:
	game.player.global_position = Vector3(0,.12,0)
	game.player.velocity = Vector3.ZERO
	camera.look_at(Vector3(0,1.6,-12))
	game.fps.set_aim(ads)
	for i in range(12): await frame()
	for i in range(36):
		if i % 6 == 0: game.fps.fire()
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
	game.player.sprinting = true
	await move(Vector3(4,.12,-6),Vector3(-4,.12,-8),Vector3(15,1.5,-15),Vector3(-16,1.5,-18),84)
	game.player.sprinting = false
	game.fps.reload()
	await move(Vector3(-4,.12,-8),Vector3(0,.12,0),Vector3(-16,1.5,-18),Vector3(0,.35,-3),64)
	game.fps.set_aim(false)
	await move(Vector3(0,.12,0),Vector3(0,1.1,0),Vector3(0,1.6,-8),Vector3(0,1.6,-8),30)
	game.player.landing_dip = .04
	await move(Vector3(0,1.1,0),Vector3(0,.12,0),Vector3(0,1.6,-8),Vector3(0,1.6,-8),30)
	game.player.landing_dip = 0
	await move(Vector3(0,.12,-22.6),Vector3(0,.12,-23.6),Vector3(0,1.6,-26),Vector3(0,1.6,-26),40)
	var wall := StaticBody3D.new()
	wall.position = Vector3(0,0,-10)
	var model: Node3D = Assets.fitted("vendor/wakeup_wall.glb",3.0)
	var dimensions: Vector3 = model.get_meta("dimensions",Vector3.ONE)
	wall.add_child(model)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	collision.position.y = dimensions.y*.5
	wall.add_child(collision)
	game.add_child(wall)
	var wall_front := -10+dimensions.z*.5
	await move(Vector3(0,.12,wall_front+1.5),Vector3(0,.12,wall_front+.34),Vector3(0,1.6,-12),Vector3(0,1.6,-12),40)
	await firing_sequence(false)
	await firing_sequence(true)
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
