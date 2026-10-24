extends SceneTree
# User-authorized native screenshots of six arenas, illustrated S1 and map reveal.
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
	for i in range(2): await process_frame
	if fire:
		game.fps.fire()
		for i in range(2): await process_frame
		game.ui.refresh()
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.is_empty() or img.save_png(output_dir.path_join(label+".png")) != OK: issues.append(label)
	else: print("GODOT_GUI_PREVIEW ",label)
func wait_switch() -> void:
	# Host cooldowns use monotonic time. A fixed-fps offline renderer can be
	# slower than real time; do not turn 1.1 seconds into 33 expensive frames.
	var deadline := Time.get_ticks_msec()+1100
	while Time.get_ticks_msec() < deadline: await process_frame
func interface_shot(label: String) -> void:
	for i in range(4):
		game.ui.refresh()
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.save_png(output_dir.path_join("interface_"+label+".png")) != OK: issues.append(label)
	else: print("GODOT_SIGNAL_INTERFACE_CAPTURE ",label)
func ground_shot(map_id: int) -> void:
	# Inspect the real shipped geometry, hiding only the warehouse roof/trusses
	# so its actual floor plan remains visible in the review image.
	var camera: Camera3D = game.player.camera
	var saved: Transform3D = camera.global_transform
	var projection := camera.projection;var extent := camera.size
	var hidden: Array[Node3D] = []
	for node in game.fps_arena.map_roots[map_id].get_children():
		if str(node.name).begins_with("DepotRoof") or str(node.name).begins_with("DepotTruss"):
			hidden.append(node);node.visible = false
	game.ui.visible = false;game.fps.weapon_pivot.visible = false
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL;camera.size = 108
	camera.global_position = Vector3(0,85,0);camera.look_at(Vector3.ZERO,Vector3.FORWARD)
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output_dir.path_join("map%d_ground_actual.png" % map_id)) != OK:issues.append("ground_plan")
	for node in hidden:node.visible = true
	camera.projection = projection;camera.size = extent;camera.global_transform = saved
	game.ui.visible = true;game.fps.weapon_pivot.visible = true
func run() -> void:
	output_dir = OS.get_environment("FACELESS_PREVIEW_DIR")
	if output_dir.is_empty(): output_dir = OS.get_user_data_dir().path_join("preview_frames")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1600,900)
	var boot = load("res://boot.tscn").instantiate()
	root.add_child(boot)
	var middle := false
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join("interface_boot_00_start.png"))
	while current_scene == null:
		await process_frame
		if not middle and boot.progress_value >= 35:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output_dir.path_join("interface_boot_01_loading.png"))
			middle = true
		if boot.failed: issues.append("boot_load_failed");quit(1);return
	game = current_scene
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join("interface_boot_02_ready.png"))
	await create_timer(.35).timeout
	print("NULRYTH_NATIVE_BOOT_PASS stages=",game.get_meta("boot_stages"))
	game.ui.intro_timer.stop()
	game.net.leave()
	game.set_process(false)
	game.language = "en"
	game.ui.menu()
	await interface_shot("00_menu_en")
	game.language = "zh"
	game.ui.menu()
	await interface_shot("01_menu_zh")
	game.language = "en"
	game.ui.open_lobby()
	await interface_shot("02_lobby")
	game.ui.open_settings()
	await interface_shot("03_settings")
	game.ui.menu()
	for i in range(30): await process_frame
	await interface_shot("04_stable_home")
	game.ui.open_lobby()
	game.ui._quick_match()
	await interface_shot("05_match_search")
	var reel: Control = game.ui.map_reveal
	var limit := Time.get_ticks_msec()+25000
	while reel.visible and reel.state == "searching" and Time.get_ticks_msec() < limit:await process_frame
	while reel.visible and reel.state == "settling" and Time.get_ticks_msec() < limit:await process_frame
	if reel.state == "locked":
		reel.set_process(false)
		await interface_shot("map_confirmed")
		if reel.current != game.fps_arena.map_id:issues.append("Native confirmed map differs from actual arena")
		reel.set_process(true)
	else:issues.append("Native matchmaking did not reach a confirmed map")
	reel.cancel()
	game.net.leave()
	game.language = "en"
	game.ui.open_maps()
	await interface_shot("map_archive")
	game.ui.season_page = 0
	game.ui.open_season()
	await interface_shot("s1_manual_01")
	game.ui.season_page = 8
	game.ui.open_season()
	await interface_shot("s1_manual_45")
	game.language = "zh";game.ui.open_season()
	await interface_shot("s1_manual_45_zh")
	game.ui.open_collection()
	await interface_shot("s1_collection")
	game.language = "en"
	for map_id in range(6):
		game.ui.touch_preview = false
		game.start_fps_arena(map_id)
		game.player.set_physics_process(false)
		await ground_shot(map_id)
		var prefix := "map%d_" % map_id
		await shot(prefix+"00_overview",Vector3(-2.5,.12,7),Vector3(1,1.6,-18))
		await shot(prefix+"01_hip",Vector3(0,.12,0),Vector3(0,1.6,-18))
		game.fps.set_aim(true)
		await shot(prefix+"02_ads",Vector3(0,.12,0),Vector3(0,1.6,-18))
		game.fps.set_aim(false)
		await shot(prefix+"03_fire_finish",Vector3(0,.12,0),Vector3(0,1.6,-18),true)
		await shot(prefix+"04_original_scanned_cover",Vector3(0,.12,12),Vector3(3,1.3,15))
		await shot(prefix+"05_near_shipped_wall",Vector3(0,.12,-47.45),Vector3(0,1.6,-50))
		await shot(prefix+"06_ground_material_shadow",Vector3(0,.12,0),Vector3(1.2,0,-.4))
		game.ui.touch_preview = true
		game.ui.prologue_finished()
		await shot(prefix+"07_mobile_hud",Vector3(-2.5,.12,7),Vector3(1,1.6,-18))
		game.ui.fps_corner_hud.scoreboard_open = true
		await shot(prefix+"08_scoreboard",Vector3(-2.5,.12,7),Vector3(1,1.6,-18))
		game.ui.fps_corner_hud.scoreboard_open = false
		game.ui.touch_preview = false
		game.ui.prologue_finished()
		await shot(prefix+"09_reference_lane_impact",Vector3(-10.5,.12,-6.5),Vector3(-10.5,1.6,-11.5),true)
		game.fps.reload()
		await shot(prefix+"10_reload_authored_magazine",Vector3(0,.12,0),Vector3(0,1.6,-18))
		# An additional native grasp phase is required: the old still showed
		# a fist floating above a separately moving magazine.
		game.fps.reload_visual_seconds = game.fps.RELOAD_SECONDS*.75
		game.fps.advance(0.0)
		game.ui.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		var grasp_image: Image = root.get_texture().get_image()
		if grasp_image.save_png(output_dir.path_join(prefix+"13_reload_actual_magazine_contact.png")) != OK: issues.append(prefix+"reload_contact")
		print("NATIVE_RELOAD_CONTACT_METERS ",game.fps.reload_contact_error())
		game.fps.toggle_training()
		await shot(prefix+"11_optional_drill",Vector3(0,.12,0),Vector3(0,1.6,-9),true)
		game.fps.toggle_training()
		for weapon in [1,2,3]:
			await wait_switch()
			game.fps.select_weapon(weapon)
			await shot(prefix+"14_weapon_"+str(weapon),Vector3(0,.12,0),Vector3(0,1.6,-18))
			if weapon == 2:
				game.fps.set_aim(true)
				await shot(prefix+"17_precision_scope",Vector3(0,.12,0),Vector3(0,1.6,-18))
				game.fps.set_aim(false)
		await wait_switch()
		game.fps.select_weapon(0)
		game.player.set_third_person(true)
		game.player.global_position = Vector3(0,.12,24)
		game.player.yaw = 0; game.player.rotation.y = 0; game.player.pitch = -.13
		game.player.update_combat_camera(.1)
		game.fps_arena.update_local_actor(.1)
		game.ui.refresh()
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir.path_join(prefix+"15_third_person_extended_sector.png"))
		if map_id == 0:
			for frame_case in ["rifle_aim","sniper_aim","left_shoulder"]:
				await wait_switch()
				game.fps.select_weapon(2 if frame_case == "sniper_aim" else 0)
				game.fps.set_aim(true)
				game.player.shoulder = -1.0 if frame_case == "left_shoulder" else 1.0
				for frame in range(60):
					game.fps.advance(1.0/60.0)
					game.player.update_combat_camera(1.0/60.0)
				game.fps_arena.update_local_actor(.1)
				await interface_shot("third_"+frame_case)
			game.fps.set_aim(false)
			await wait_switch()
			game.fps.select_weapon(0)
			game.player.shoulder = 1.0
		game.player.set_third_person(false)
		await shot(prefix+"16_extended_flank",Vector3(33,.12,45),Vector3(16,1.6,25))
		game.fps.measure_grip()
		print("PREVIEW_MAP ",map_id," GEOMETRY ",game.fps_arena.geometry_digest())
	game.player.reset_to(Vector3(0,.12,0))
	game.player.pitch = -.13
	game.player.set_third_person(true)
	game.fps_arena.set_process(false)
	for pose in ["run","rise","fall"]:
		game.fps_arena.local_shadow.update_combat(6.2,pose != "run",0,0,.016,0,5.0 if pose == "rise" else -4.0)
		if pose == "run": game.fps_arena.local_shadow.animation.advance(.18)
		await interface_shot("s1_motion_"+pose)
	game.fps_arena.set_process(true)
	game.player.set_third_person(false)
	game.player.reset_to(Vector3(0,.12,0))
	game.player.pitch = -1.2
	game.player.camera.rotation = Vector3(-1.2,0,0)
	game.player.set_physics_process(true)
	for i in range(4): await physics_frame
	game.player.set_physics_process(false)
	await interface_shot("06_void_feet")
	# Review the actual result HUD with a second authenticated, independent
	# headless ENet peer. Only the fixture timer is shortened; round outcome
	# and snapshots follow the normal host code, never a fake player count.
	game.net.leave()
	if game.net.host(24719,"native-round-review",false,2) == OK:
		game.start_fps_arena(0)
		game.player.set_physics_process(false)
		var child := OS.create_process(OS.get_executable_path(),["--headless","--max-fps","30","--path",ProjectSettings.globalize_path("res://"),"--script","res://scripts/backrooms_fps_session_checks.gd","--","--role=capture_client","--room=native-round-review","--port=24719","--label=native_peer","--output="+output_dir])
		var deadline := Time.get_ticks_msec()+25000
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
	await create_timer(.25).timeout
	if not issues.is_empty():
		for issue in issues: push_error("Missing native frame "+issue)
		quit(1)
	else:
		print("GODOT_PREVIEW_PASS four native maps, illustrated S1, authority map reel, hands, cover and mobile HUD")
		quit(0)
