extends SceneTree
var game: Node3D
var failed := false
func check(ok: bool, msg: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL: "+msg)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop()
	game.net.leave()
	game.start_fps_arena()
	game.player.set_physics_process(false)
	var fps: Node3D = game.fps
	check(game.fps_arena.visible and game.fps_arena.floor_modules.size() == 16, "One open arena of sixteen real imported CC0 GLB tiles")
	check(fps.active and fps.level_id == -2, "FPS has no level ID or elevator")
	check(is_instance_valid(fps.grip_hands) and is_instance_valid(fps.grip_skeleton), "Original WRAD CC0 skinned GLB hands imported")
	check(fps.grip_ready and fps.grip_error < .002 and fps.grip_mesh_error < .045, "Both authored wrist bones solve at the rifle grip without detached hands")

	var hand: Node3D = fps.grip_hands.get_child(0)
	var before: Vector3 = hand.position
	hand.position += Vector3(.1,0,0)
	fps.measure_grip()
	check(fps.grip_error > .09,"Grip measurement detects a real 10cm hand detachment")
	hand.position = before
	fps.measure_grip()
	check(fps.grip_error < .002,"Restored bone grip measurement")
	check(not game.player.viewmodel_root.visible, "Original floating Sketchfab hands hidden while holding FPS weapon")
	check(fps.grip_hands.get_parent() == fps.weapon_pivot, "Rifle and rigged hands share one animated parent")
	check(fps.grip_hands.get_child_count() == 2, "Two independent authored WRAD skinned hand GLBs grip one weapon, no loose elbows")
	check(fps.weapon_model != null and fps.weapon_model.find_children("*","MeshInstance3D",true,false).size() >= 2, "Licensed original multi-mesh firearm")
	check(fps.sentries.is_empty(), "Arena has no scripted Level 2 enemies or Backrooms narrative targets")
	check(fps.health_by_peer.has(1) and fps.ammo_by_peer.has(1), "Authoritative host initializes HP and ammo")
	check(fps.match_can_fire(), "Solo training remains playable")
	check(not fps.server_fire(1,Vector3(100,0,0)), "Invalid arbitrary firing vector rejected")
	var ammo: int = fps.ammo_by_peer[1]
	check(fps.server_fire(1,Vector3.FORWARD), "Host accepts normalized authoritative shot")
	check(int(fps.ammo_by_peer[1]) == ammo-1,"Server subtracts ammo once")
	check(not fps.server_fire(1,Vector3.FORWARD), "Server fire rate limit blocks duplicate shots")
	check(fps.server_reload(1),"Reload is server-authorized")
	check(int(fps.ammo_by_peer[1]) == ammo-1,"Reload does not instantly refill the magazine")
	check(not fps.server_reload(1),"Repeated reload requests rejected")
	check(not fps.server_fire(1,Vector3.FORWARD),"Host rejects firing during reload")
	var reload_started := Time.get_ticks_msec()
	var reload_deadline := reload_started+5000
	while int(fps.ammo_by_peer[1]) != fps.MAGAZINE_CAPACITY and Time.get_ticks_msec() < reload_deadline:
		await create_timer(.05).timeout
	check(Time.get_ticks_msec()-reload_started >= 1600,"Reload completion follows real host monotonic time")
	check(int(fps.ammo_by_peer[1]) == fps.MAGAZINE_CAPACITY,"Delayed host reload updates magazine")
	check(int(fps.reserve_by_peer[1]) == 119,"Reload consumes actual host-owned reserve ammo")
	# Real headless physics LOS, damage, death/score and authoritative respawn.
	fps.register_peer(2)
	game.net.seats[2] = 2
	game.net.poses[2] = {"p":game.player.position+Vector3(0,0,-4),"y":0.0,"pitch":0.0}
	var direction: Vector3 = (game.net.poses[2].p+Vector3(0,1.0,0)-game.player.camera.global_position).normalized()
	game.player.pitch = asin(direction.y)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,3,.2)
	shape.shape = box
	wall.add_child(shape)
	wall.position = game.player.position+Vector3(0,1.0,-2)
	game.add_child(wall)
	await physics_frame
	await physics_frame
	check(fps.server_fire(1,direction),"Valid shot against real occluding collision is processed")
	check(int(fps.health_by_peer[2]) == 100,"Real physics wall prevents damage through it")
	# Move the real physics fixture close to the camera and test the actual
	# imported gun vertex clearance; screenshots separately check appearance.
	wall.position.z = game.player.position.z-.4
	await physics_frame
	await physics_frame
	for i in range(20): fps.advance(.05)
	var nearest_weapon_z := 0.0
	for vertex in fps.weapon_vertices:
		nearest_weapon_z = minf(nearest_weapon_z,(fps.weapon_pivot.transform*vertex).z)
	check(nearest_weapon_z >= -fps.wall_clearance+.024,"Actual original firearm vertices retract behind the physics wall")
	wall.queue_free()
	await physics_frame
	await physics_frame
	for i in range(4):
		await create_timer(.22).timeout
		check(fps.server_fire(1,direction),"Authorized damage shot after cooldown")
	check(int(fps.scores[1]) == 1 and int(fps.health_by_peer[2]) == 100,"Four hits yield one score and reset victim HP")
	check(game.net.poses[2].p == game.fps_arena.spawn_for(2),"Authoritative respawn applies a bounded arena spawn")
	check(not fps.server_fire(999,direction),"Unknown peer never acquires firing authority")
	fps.remove_peer(2)
	game.net.poses.erase(2)
	game.net.seats.erase(2)
	game.player.pitch = 0
	check(game.fps_arena.spawn_for(1).distance_to(game.fps_arena.spawn_for(2)) > 5,"Players spawn in separate positions")
	game.show_title_room()
	check(not fps.active and not game.fps_arena.visible,"Leaving arena unloads combat and collision")
	game.net.leave()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for sound in game.find_children("*",kind,true,false):
			sound.stop()
			sound.set("stream",null)
	game.queue_free()
	for i in range(12): await process_frame
	if failed: quit(1)
	else:
		print("FACELESS2_FPS_CHECKS_PASS")
		quit(0)
