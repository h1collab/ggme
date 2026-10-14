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
	game.start_fps_arena(0)
	game.player.set_physics_process(false)
	# Test real world collision state for both host-selectable maps.
	var layouts: Array[String] = []
	var seen: Dictionary = {}
	for i in range(128): seen[game.fps_arena.random_map()] = true
	check(seen.size() == 2 and seen.has(0) and seen.has(1),"Random picker can produce exactly both map IDs")
	for selected in [0,1]:
		game.fps_arena.activate(selected)
		await physics_frame
		await physics_frame
		layouts.append(game.fps_arena.geometry_digest())
		for body in game.fps_arena.map_roots[selected].find_children("*","StaticBody3D",true,false):
			var bounds := AABB()
			var first_mesh := true
			for mesh in body.find_children("*","MeshInstance3D",true,false):
				var actual: AABB = mesh.global_transform*mesh.get_aabb()
				bounds = actual if first_mesh else bounds.merge(actual)
				first_mesh = false
			for collision in body.get_children():
				if collision is CollisionShape3D and collision.shape is BoxShape3D:
					var extent: Vector3 = collision.shape.size
					var proxy: AABB = collision.global_transform*AABB(-extent*.5,extent)
					check(bounds.position.distance_to(proxy.position) < .002 and bounds.end.distance_to(proxy.end) < .002,"Actual GLB bounds match collision: "+str(body.name))
		for index in range(2):
			check(game.fps_arena.map_roots[index].visible == (index == selected),"Exactly the selected map is visible")
			for body in game.fps_arena.map_roots[index].find_children("*","StaticBody3D",true,false):
				check(body.collision_layer == (1 if index == selected else 0),"Inactive map collisions never obstruct the current map")
		for slot in range(1,5):
			var spawn: Vector3 = game.fps_arena.spawn_for(slot)
			var capsule := CapsuleShape3D.new()
			capsule.radius = .30
			capsule.height = 1.65
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform.origin = spawn+Vector3(0,.85,0)
			query.exclude = [game.player.get_rid()]
			check(game.player.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"All four actual spawn capsules clear authored map geometry")
		var ray := PhysicsRayQueryParameters3D.create(Vector3(14,1,0),Vector3(14,1,8),1)
		var hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and str(hit.collider.name).begins_with("Crate_"),"Real map cover blocks shooting LOS")
	check(layouts[0] != layouts[1],"Two maps have genuinely different collision layouts")
	game.start_fps_arena(0)
	print("FPS_TWO_MAP_PHYSICS_PASS both layouts, 8 spawn capsules, cover LOS, inactive geometry and random picker")

	var fps: Node3D = game.fps
	check(game.fps_arena.visible and game.fps_arena.floor_modules.size() == 16, "One open arena of sixteen real imported CC0 GLB tiles")
	check(fps.active and fps.level_id == -2, "FPS has no level ID or elevator")
	check(is_instance_valid(fps.grip_hands) and is_instance_valid(fps.grip_skeleton), "Original WRAD CC0 skinned GLB hands imported")
	check(fps.grip_ready and fps.grip_error < .002 and fps.grip_mesh_error < .005 and fps.grip_surface_error < .0005, "Both authored wrist bones solve at the rifle grip without detached hands")

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
	check(fps.weapon_finish_ready,"Original atlas and verified PBR finish loaded")
	for mesh in fps.weapon_model.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var finish: ShaderMaterial = mesh.get_active_material(surface)
			for parameter in ["source_atlas","detail_albedo","detail_normal","detail_roughness","detail_metallic"]:
				check(finish.get_shader_parameter(parameter) is Texture2D,"Real texture binding: "+parameter)
	check(game.fps_arena.local_shadow != null,"Original licensed avatar supplies ground shadow")
	game.fps_arena.apply_quality(0)
	check(not game.fps_arena.light.shadow_enabled,"Low quality disables costly directional shadows")
	game.fps_arena.apply_quality(1)
	check(game.fps_arena.light.shadow_enabled,"Standard quality enables real sun shadows")
	# Measure actual rig displacement, settling and stable aim at two frame rates.
	var recoil_metrics: Array[Dictionary] = []
	for ads in [false,true]:
		for frequency in [30.0,120.0]:
			fps.set_aim(ads)
			fps.visual_recoil = 0.0
			for i in range(90): fps.advance(1.0/frequency)
			var rest: Transform3D = fps.weapon_pivot.transform
			var camera_before: Basis = game.player.camera.global_basis
			fps.shot_cooldown = 0.0
			check(fps.fire() == "REQUESTED","Actual training shot triggers gentle rig recoil")
			var peak := 0.0
			var angular_peak := 0.0
			for frame in range(int(frequency*.5)):
				fps.advance(1.0/frequency)
				peak = maxf(peak,fps.weapon_pivot.position.distance_to(rest.origin))
				angular_peak = maxf(angular_peak,rest.basis.get_rotation_quaternion().angle_to(fps.weapon_pivot.basis.get_rotation_quaternion()))
			check(peak < (.007 if ads else .015),"Hip/ADS actual recoil translation remains bounded")
			check(angular_peak < deg_to_rad(.60),"Recoil angular movement below 0.6 degrees")
			check(fps.weapon_pivot.position.distance_to(rest.origin) < .0005,"Rig returns smoothly within 0.5 seconds")
			check(game.player.camera.global_basis.is_equal_approx(camera_before),"Shot never snaps camera or host firing direction")
			recoil_metrics.append({"ads":ads,"fps":frequency,"peak_m":peak,"peak_rad":angular_peak})
	fps.set_aim(false)
	fps.magazine = fps.MAGAZINE_CAPACITY
	fps.ammo_by_peer[1] = fps.MAGAZINE_CAPACITY
	fps.shot_ticks.clear()
	print("FPS_GENTLE_RECOIL_METRICS ",JSON.stringify(recoil_metrics))
	check(fps.sentries.is_empty(), "Arena has no scripted Level 2 enemies or Backrooms narrative targets")
	check(fps.health_by_peer.has(1) and fps.ammo_by_peer.has(1), "Authoritative host initializes HP and ammo")
	check(fps.match_can_fire(), "Solo training remains playable")
	check(not fps.server_fire(1,Vector3(100,0,0)), "Invalid arbitrary firing vector rejected")
	var ammo: int = fps.ammo_by_peer[1]
	check(fps.server_fire(1,Vector3.FORWARD), "Host accepts normalized authoritative shot")
	check(int(fps.ammo_by_peer[1]) == ammo-1,"Server subtracts ammo once")
	check(not fps.server_fire(1,Vector3.FORWARD), "Server fire rate limit blocks duplicate shots")
	var cadence_tick := Time.get_ticks_msec()
	while Time.get_ticks_msec()-cadence_tick < 125: await process_frame
	print("FPS_CADENCE_HOST ",Time.get_ticks_msec()-int(fps.shot_ticks.get(1,0)),"ms hp=",fps.health_by_peer," ammo=",fps.ammo_by_peer," facing=",game.player.yaw,",",game.player.pitch)
	check(fps.server_fire(1,Vector3.FORWARD),"Host accepts next shot after 120ms, before old 185ms threshold")
	check(int(fps.ammo_by_peer[1]) == ammo-2,"Faster host cadence still consumes one bullet per accepted request")
	# Restore one consumed round for the existing reserve/reload fixture.
	fps.ammo_by_peer[1] += 1
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
	# Keep the original LOS/damage fixture in the clear central lane.
	game.player.reset_to(Vector3(0,.12,0))
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
	check(fps.kill_events.size() == 1 and fps.kill_events[0].killer == 1 and fps.kill_events[0].victim == 2,"Kill feed records actual host-authorized shooter/victim only")
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
	# Return from the fixture coroutine before exit: its local Shape3D and
	# physics-query references must be released before ResourceDB shutdown.
	call_deferred("finish")

func finish() -> void:
	game = null
	for i in range(12): await process_frame
	if not failed: print("FACELESS2_FPS_CHECKS_PASS")
	call_deferred("quit",1 if failed else 0)
