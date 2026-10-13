extends SceneTree
# REAL Godot desktop viewport recording: consecutive rendered frames, not stills.
var game: Node3D
var camera: Camera3D
var output_dir: String
var total := 0
var problems: Array[String] = []

func _initialize() -> void:
	call_deferred("record")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var im: Image = root.get_texture().get_image()
	if im.is_empty():
		problems.append("Empty renderer image")
		return
	im.resize(960,540,Image.INTERPOLATE_BILINEAR)
	var path := "%s/%05d.png" % [output_dir,total]
	if im.save_png(path) != OK: problems.append("PNG capture failed: "+path)
	total += 1

func travel(a: Vector3, b: Vector3, look_a: Vector3, look_b: Vector3, count: int) -> void:
	for i in range(count):
		var t := float(i)/float(maxi(count-1,1))
		t = t*t*(3.0-2.0*t)
		game.player.global_position = a.lerp(b,t)
		camera.look_at(look_a.lerp(look_b,t))
		await frame()

func record() -> void:
	output_dir = OS.get_environment("F2_CAPTURE_DIR")
	if output_dir.is_empty():
		push_error("F2_CAPTURE_DIR must be set")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(10): await process_frame
	if is_instance_valid(game.ui.intro_timer): game.ui.intro_timer.stop()
	game.net.leave()
	game.prologue.active = false
	game.prologue.phase = "ended"
	# Movie capture skips the timed black/wake transition. Without explicitly
	# hiding its persistent sibling GLBs, the original iPhone and desk-scene
	# silhouette leaked into the underground facility and appeared to float.
	game.prologue.hide_opening_props()
	game.prologue_room.visible = false
	if game.prologue.phone.visible or game.prologue.witness.visible:
		problems.append("Cinematic iPhone or figure still drawn in gameplay")
	game.running = true
	game.ui.close_panels()
	game.ui.modal = false
	game.ui.prologue_finished()
	game.wakeup_room.visible = true
	game.wakeup_room.set_physics_active(true)
	game.player.visible = true
	game.player.set_physics_process(false)
	game.player.reset_to(Vector3(0,0.1,2.5))
	camera = game.player.camera
	camera.make_current()
	if is_instance_valid(game.ui.wakeup_veil): game.ui.wakeup_veil.visible = false
	game.wakeup_room.smiler_stage(0.0,"hidden")
	await travel(Vector3(-0.5,0.1,2.6),Vector3(0.1,0.1,1.8),Vector3(-2.6,1.4,-4.3),Vector3(0,1.6,-7.0),45)
	game.wakeup_room.smiler_stage(1.0,"watch")
	await travel(Vector3(0.1,0.1,1.8),Vector3(0.6,0.1,0.2),Vector3(0,1.5,-5.4),Vector3(0,1.5,-5.4),45)
	# Pan behind the wall: the lone source Smiler must be depth occluded.
	await travel(Vector3(0.6,0.1,0.2),Vector3(3.15,0.1,-0.7),Vector3(0,1.5,-5.4),Vector3(5.5,1.5,-3.0),40)
	game.player.global_position = game.wakeup_room.flashlight_pickup_position
	if game.wakeup_room.door_result(game.wakeup_room.flashlight_pickup_position) == "FLASHLIGHT":
		game.player.take_flashlight()
	game.player.toggle_torch()
	await travel(Vector3(0.6,0.1,1.4),Vector3(0,0.1,-0.3),Vector3(1.7,1.0,-2.6),Vector3(0,1.5,-5.4),45)
	await travel(Vector3(0,0.1,-0.3),Vector3(-0.4,0.1,-2.0),Vector3(0,-0.1,-2.5),Vector3(-1.3,-0.1,-4.2),40)
	game.wakeup_room.smiler_stage(0.0,"hidden")
	# Genuine sequential frames show textured plaster, real end-door depth
	# and an actual low-angle viewmodel inspection. No static PNG montage.
	await travel(Vector3(-0.4,0.1,-2.0),Vector3(-1.8,0.1,-3.1),Vector3(-3.6,1.35,-2.2),Vector3(-3.6,1.10,-4.7),25)
	await travel(Vector3(-1.8,0.1,-3.1),Vector3(-0.1,0.1,-3.0),Vector3(-0.8,0.05,-3.3),Vector3(0,-0.2,-4.1),25)
	await travel(Vector3(-0.1,0.1,-3.0),Vector3(0,0.1,-5.3),Vector3(0,1.6,-9.5),Vector3(0,1.5,-9.5),25)
	for level_number in [0,5,6,131]:
		game.open_backrooms_level(level_number)
		game.player.set_physics_process(false)
		camera = game.player.camera
		camera.make_current()
		await travel(Vector3(0,0.1,2.0),Vector3(-0.5,0.1,-8.0),Vector3(2,1.5,-10),Vector3(-2,1.5,-19),35)
	game.extra_levels.clear()
	game.net.leave()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for sound in game.find_children("*",kind,true,false):
			sound.stop()
			sound.stream = null
	game.queue_free()
	for i in range(10): await process_frame
	if total < 410: problems.append("Not enough native frames: %d" % total)
	if not problems.is_empty():
		for issue in problems: push_error(issue)
		quit(1)
	else:
		print("GODOT_CONTINUOUS_VIDEO_FRAMES_PASS %d" % total)
		quit(0)
