extends SceneTree
# Genuine consecutive native Godot frames at fixed 20Hz, not a still montage.
var game: Node3D
var camera: Camera3D
var output_dir := ""
var total := 0
var startup_frames := 0
var presentation_frames := 0
var issues: Array[String] = []
func _initialize() -> void: call_deferred("record")
func frame() -> void:
	if is_instance_valid(game): game.ui.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.is_empty(): issues.append("Empty native frame"); return
	img.resize(960,540,Image.INTERPOLATE_BILINEAR)
	if img.save_png(output_dir.path_join("%05d.png" % total)) != OK: issues.append("Encoding failed")
	total += 1
func move(start: Vector3, finish: Vector3, look_from: Vector3, look_to: Vector3, frames: int) -> void:
	for i in range(frames):
		game.player.velocity = (finish-start)/float(frames)*20.0
		game.player.motion_clock += .05*(10.0 if game.player.sprinting else 7.0)
		var t := float(i)/float(maxi(1,frames-1))
		t = t*t*(3.0-2.0*t)
		game.player.global_position = start.lerp(finish,t)
		camera.look_at(look_from.lerp(look_to,t))
		var direction: Vector3 = -camera.global_basis.z
		game.player.yaw = atan2(-direction.x,-direction.z)
		game.player.pitch = asin(direction.y)
		await frame()
func fire(ads: bool) -> void:
	game.player.global_position = Vector3(0,.12,0)
	game.player.velocity = Vector3.ZERO
	camera.look_at(Vector3(0,1.6,-18))
	game.fps.set_aim(ads)
	for i in range(12): await frame()
	var before: int = game.fps.magazine
	for i in range(30):
		if i%3 == 0: game.fps.fire()
		await frame()
	if game.fps.magazine >= before:
		issues.append("Native firing sequence did not consume ammunition")
func record() -> void:
	root.size = Vector2i(960,540) # render movie at its delivered size; no 1600px readback waste
	output_dir = OS.get_environment("F2_CAPTURE_DIR")
	if output_dir.is_empty(): push_error("F2_CAPTURE_DIR required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var boot = load("res://boot.tscn").instantiate()
	root.add_child(boot)
	while current_scene == null:
		await frame()
		if boot.failed:issues.append("Boot failed");quit(1);return
	game = current_scene
	for i in range(8):await frame()
	startup_frames = total
	print("NULRYTH_NATIVE_BOOT_FRAMES ",startup_frames," stages=",game.get_meta("boot_stages"))
	for i in range(10): await process_frame
	await create_timer(.25).timeout
	game.ui.intro_timer.stop()
	game.net.leave()
	game.set_process(false)
	game.ui.menu()
	for i in range(60): await frame()
	game.ui.open_season()
	for i in range(60):await frame()
	game.ui.season_page = 8;game.ui.open_season()
	for i in range(40):await frame()
	game.ui.open_maps()
	for i in range(45):await frame()
	game.ui.open_lobby()
	game.ui._quick_match()
	var reveal: Control = game.ui.map_reveal
	var reveal_frames := 0
	while reveal.visible and reveal_frames < 300 and reveal.state != "error":
		await frame();reveal_frames += 1
	if reveal.visible or reveal.last_committed != game.fps_arena.map_id:issues.append("Actual match reveal did not enter its confirmed room map")
	print("NULRYTH_NATIVE_MATCH_REEL_FRAMES ",reveal_frames," actual_map=",game.fps_arena.map_id," revealed_map=",reveal.last_committed)
	reveal.cancel()
	presentation_frames = total-startup_frames
	print("NULRYTH_NATIVE_PRESENTATION_FRAMES ",presentation_frames)
	# Software rendering can take longer than the real search deadline, so
	# quick-match may already have opened a one-person room. Leave it before
	# the offline showcase; do not relax the two-player competitive fire lock.
	game.net.leave()
	if game.net.mode != "solo": issues.append("Native showcase did not leave matchmaking")
	for map_id in range(6):
		game.ui.touch_preview = false
		game.start_fps_arena(map_id)
		game.player.set_physics_process(false)
		camera = game.player.camera
		camera.make_current()
		print("GODOT_NATIVE_MAP_SEGMENT ",map_id," BEGIN_FRAME ",total)
		if map_id >= 2:
			# New sectors get their distinct OUTER routes, rather than duplicating
			# the same four-weapon choreography already covered on maps 0/1.
			# All four weapons/near-wall stills remain rendered on every map.
			await move(Vector3(33,.12,15),Vector3(33,.12,21),Vector3(26,1.6,20),Vector3(26,1.6,32),30)
			game.player.set_third_person(true)
			game.player.yaw = 0; game.player.rotation.y = 0; game.player.pitch = -.12
			for i in range(40):
				game.player.global_position = Vector3(0,.12,25-float(i)*.08)
				game.player.velocity = Vector3(0,0,-1.6)
				game.player.update_combat_camera(.05)
				game.fps_arena.update_local_actor(.05)
				var torso: Vector3 = game.player.global_position+Vector3(0,1.0,0)
				if camera.is_position_behind(torso) or not camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(torso)):
					issues.append("Third-person actor outside actual movie viewport")
				await frame()
			game.player.set_third_person(false)
			game.ui.touch_preview = true
			game.ui.prologue_finished()
			await move(Vector3(0,.12,0),Vector3(0,.12,1),Vector3(0,.25,-3),Vector3(5,1.6,-18),20)
			continue
		await move(Vector3(-7,.12,7),Vector3(-3,.12,3),Vector3(8,1.6,-13),Vector3(0,1.6,-18),50)
		await fire(false)
		await fire(true)
		game.fps.set_aim(false)
		game.player.sprinting = true
		await move(Vector3(-3,.12,3),Vector3(4,.12,-4),Vector3(0,1.6,-18),Vector3(3,1.4,15),40)
		game.player.sprinting = false
		game.fps.reload()
		await move(Vector3(4,.12,-4),Vector3(1,.12,-6),Vector3(3,1.4,15),Vector3(3,1.3,15),36)
		await move(Vector3(0,.12,-46.6),Vector3(0,.12,-47.45),Vector3(0,1.6,-50),Vector3(0,1.6,-50),25)
		for weapon in [1,2,3]:
			# Source capture waits real switch cooldowns through rendered frames.
			for i in range(22): await frame()
			game.fps.select_weapon(weapon)
			await move(Vector3(0,.12,24),Vector3(2,.12,25),Vector3(0,1.6,42),Vector3(8,1.6,42),20)
		for i in range(22): await frame()
		game.fps.select_weapon(0)
		game.player.set_third_person(true)
		game.player.yaw = 0; game.player.rotation.y = 0; game.player.pitch = -.12
		if map_id == 0:
			# Real CharacterBody physics and input: tangent wall acceleration,
			# sprint, jump, fall and landing in forty consecutive native frames.
			game.player.reset_to(Vector3(35.45,.12,10))
			game.player.pitch = -.12
			game.player.shoulder = -1.0
			game.player.set_third_person(true)
			game.player.set_physics_process(true)
			for code in [KEY_W,KEY_D,KEY_SHIFT]:
				var press := InputEventKey.new();press.physical_keycode = code;press.pressed = true;Input.parse_input_event(press)
			var fastest := 0.0
			var highest := 0.0
			var before_jump: int = game.player.jump_count
			for i in range(40):
				if i == 10: game.player.request_jump()
				await frame()
				game.fps_arena.update_local_actor(.05)
				fastest = maxf(fastest,Vector2(game.player.velocity.x,game.player.velocity.z).length())
				highest = maxf(highest,game.player.position.y)
			for code in [KEY_W,KEY_D,KEY_SHIFT]:
				var release := InputEventKey.new();release.physical_keycode = code;release.pressed = false;Input.parse_input_event(release)
			game.player.set_physics_process(false)
			game.player.velocity = Vector3.ZERO
			game.player.wall_glide = 0.0
			game.player.wall_glide_active = false
			game.player.shoulder = 1.0
			if fastest < 7.4 or highest < .55 or game.player.jump_count <= before_jump: issues.append("Actual wall glide/jump sequence did not execute")
			print("S1_NATIVE_PHYSICS_WALL_JUMP speed=",fastest," peak=",highest," jumps=",game.player.jump_count-before_jump)
		else:
			for i in range(40):
				game.player.global_position = Vector3(0,.12,25-float(i)*.08)
				game.player.velocity = Vector3(0,0,-1.6)
				game.player.update_combat_camera(.05)
				game.fps_arena.update_local_actor(.05)
				var torso: Vector3 = game.player.global_position+Vector3(0,1.0,0)
				# Camera projection uses the stretched logical viewport, not the
				# 960x540 output framebuffer (the project's UI canvas is 1600x900).
				if camera.is_position_behind(torso) or not camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(torso)):
					issues.append("Third-person actor outside actual movie viewport")
				await frame()
		game.player.set_third_person(false)
		game.ui.touch_preview = true
		game.ui.prologue_finished()
		await move(Vector3(0,.12,0),Vector3(0,.12,1),Vector3(0,.25,-3),Vector3(5,1.6,-18),25)
	game.net.leave()
	game.queue_free()
	for i in range(10): await process_frame
	await create_timer(.25).timeout
	if total != 1256+startup_frames+presentation_frames: issues.append("Gameplay frame sequence changed after real startup/UI capture")
	if not issues.is_empty():
		for issue in issues: push_error(issue)
		quit(1)
	else:
		print("GODOT_CONTINUOUS_VIDEO_FRAMES_PASS ",total)
		quit(0)
