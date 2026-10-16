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
	var direction: Vector3 = -game.player.camera.global_basis.z
	game.player.yaw = atan2(-direction.x,-direction.z)
	game.player.pitch = asin(direction.y)
	game.ui.refresh()
	# Settle the real rig through its normal advance function before rendering
	# static review poses. The MP4 separately renders every consecutive frame.
	for i in range(60): game.fps.advance(1.0/60.0)
	for i in range(8): await process_frame
	if fire:
		game.fps.fire()
		for i in range(2): await process_frame
		game.ui.refresh()
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
		game.ui.fps_corner_hud.scoreboard_open = true
		await shot(prefix+"08_scoreboard",Vector3(-7,.12,7),Vector3(8,1.6,-13))
		game.ui.fps_corner_hud.scoreboard_open = false
		game.ui.touch_preview = false
		game.ui.prologue_finished()
		await shot(prefix+"09_reference_lane_impact",Vector3(-10.5,.12,-6.5),Vector3(-10.5,1.6,-11.5),true)
		game.fps.reload()
		await shot(prefix+"10_reload_authored_magazine",Vector3(0,.12,0),Vector3(0,1.6,-18))
		game.fps.toggle_training()
		await shot(prefix+"11_optional_drill",Vector3(0,.12,0),Vector3(0,1.6,-9),true)
		game.fps.toggle_training()
		game.fps.measure_grip()
		print("PREVIEW_MAP ",map_id," GEOMETRY ",game.fps_arena.geometry_digest())
	# Review the actual result HUD with a second authenticated, independent
	# headless ENet peer. Only the fixture timer is shortened; round outcome
	# and snapshots follow the normal host code, never a fake player count.
	game.net.leave()
	if game.net.host(24719,"native-round-review",false,2) == OK:
		game.start_fps_arena(0)
		game.player.set_physics_process(false)
		var child := OS.create_process(OS.get_executable_path(),["--headless","--max-fps","30","--path",ProjectSettings.globalize_path("res://"),"--script","res://scripts/backrooms_fps_session_checks.gd","--","--role=capture_client","--room=native-round-review","--port=24719","--label=native_peer","--output="+output_dir])
		var deadline := Time.get_ticks_msec()+12000
		while game.net.members.size() < 2 and Time.get_ticks_msec() < deadline: await process_frame
		if game.net.members.size() == 2:
			game.fps.round_remaining = .01
			while not game.fps.round_over and Time.get_ticks_msec() < deadline: await process_frame
			if game.fps.round_over:
				# Freeze only after the real timer result, for static inspection.
				game.fps.set_process(false)
				game.ui.refresh()
				await process_frame
				await RenderingServer.frame_post_draw
				var img: Image = root.get_texture().get_image()
				if img.save_png(output_dir.path_join("map0_12_real_two_peer_result.png")) != OK: issues.append("result_image")
				print("NATIVE_RESULT_ACTUAL_ENET_PEERS ",game.net.members.size()," ",game.fps.combat_state().get("round"))
			else: issues.append("actual_round_expiry")
		else: issues.append("native_result_second_peer")
		if child > 0 and OS.is_process_running(child): OS.kill(child)
	else: issues.append("native_result_host")
	game.net.leave()
	game.queue_free()
	for i in range(10): await process_frame
	if not issues.is_empty():
		for issue in issues: push_error("Missing native frame "+issue)
		quit(1)
	else:
		print("GODOT_PREVIEW_PASS two shipped FPS maps, source materials, hands, cover, wall and mobile HUD")
		quit(0)
