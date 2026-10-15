extends SceneTree
var game: Node3D
var failed := false
func check(ok: bool, msg: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL: "+msg)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,900)
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
	var physical_capsule := StaticBody3D.new()
	physical_capsule.collision_layer = 8
	physical_capsule.position = Vector3(0,.12,-5)
	var capsule_shape := CollisionShape3D.new()
	capsule_shape.shape = game.player.get_child(0).shape.duplicate()
	capsule_shape.position.y = game.player.COLLISION_CENTER_Y
	physical_capsule.add_child(capsule_shape)
	game.add_child(physical_capsule)
	await physics_frame
	await physics_frame
	for height in [.10,.50,1.0,1.60,1.80]:
		for lateral in [-.40,0.0,.28]:
			var eye := Vector3(lateral,height,0)
			var actual_ray := PhysicsRayQueryParameters3D.create(eye,eye+Vector3.FORWARD*10,8)
			var physical_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(actual_ray)
			var distance: float = game.fps._capsule_entry(eye,Vector3.FORWARD,physical_capsule.position)
			check(is_finite(distance) == not physical_hit.is_empty(),"Authoritative hit volume matches real physics capsule at head/torso/leg/miss height")
			if not physical_hit.is_empty(): check(absf(distance-eye.distance_to(physical_hit.position)) < .005,"Capsule entry matches actual physics surface within 5mm")
	physical_capsule.queue_free()
	await physics_frame
	print("FPS_CAPSULE_RAY_PARITY_PASS 15 real head/torso/leg/lateral rays, rifle range 70m")

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
	for ads in [false,true]:
		fps.set_aim(ads)
		for i in range(100): fps.advance(1.0/60.0)
		check_arm_boundaries(fps)
	check(fps.weapon_model != null and fps.weapon_model.find_children("*","MeshInstance3D",true,false).size() >= 2, "Licensed original multi-mesh firearm")
	check(fps.weapon_finish_ready,"Original atlas and verified PBR finish loaded")
	var rifle_triangles := 0
	for mesh in fps.weapon_model.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var finish: StandardMaterial3D = mesh.get_active_material(surface)
			check(finish.albedo_texture != null and finish.normal_texture != null and finish.roughness_texture != null and finish.metallic_texture != null,"Original M4A1 embeds all four real publisher PBR maps")
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			rifle_triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
	check(rifle_triangles == 9258 and fps.rifle_magazine != null and fps.rifle_handle != null,"Actual source M4A1 inventory and separate moving parts")
	check(fps.wall_support_points.size() <= 104 and fps.wall_support_points.size() < fps.weapon_vertices.size()/20,"Near-wall path caches small per-part bounds once")
	for angles in [Vector3.ZERO,Vector3(-.79,-.08,.1),Vector3(.2,.3,-.2),Vector3(-1.1,.6,.3)]:
		var basis := Basis.from_euler(angles)
		var actual_extent := -INF
		var support_extent := -INF
		for vertex in fps.weapon_vertices: actual_extent = maxf(actual_extent,-(basis*vertex).z)
		for point in fps.wall_support_points: support_extent = maxf(support_extent,-(basis*point).z)
		check(support_extent+.000001 >= actual_extent,"Cached part bounds conservatively contain every actual firearm vertex")
	var timings: Array[int] = []
	var result := 0.0
	var benchmark_basis := Basis.from_euler(Vector3(-.6,-.08,.1))
	for points in [fps.weapon_vertices,fps.wall_support_points]:
		var begin := Time.get_ticks_usec()
		for iteration in range(100):
			for point in points: result = maxf(result,-(benchmark_basis*point).z)
		timings.append(Time.get_ticks_usec()-begin)
	print("FPS_WALL_CPU_SAMPLE 100 iterations original_us=",timings[0]," cached_us=",timings[1]," vertices=",fps.weapon_vertices.size()," supports=",fps.wall_support_points.size()," checksum=",result)
	var preserved_kenney: Node3D = load("res://assets/vendor/fps_blaster_f.glb").instantiate()
	check(preserved_kenney.find_children("*","MeshInstance3D",true,false).size() >= 2,"Original licensed Kenney rifle retained as historical source")
	preserved_kenney.free()
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
	fps.set_aim(true)
	for i in range(60): fps.advance(1.0/60.0)
	var peep: Vector3 = fps.weapon_pivot.transform*Vector3(-.000824,.0773845,.066138)
	check(absf(peep.x) < .001 and absf(peep.y) < .001,"Actual rear aperture rim center aligns within 1mm of camera sight axis")
	var blocked_aperture := 0
	for triangle in range(0,fps.weapon_triangles.size(),3):
		var a: Vector3 = fps.weapon_pivot.transform*fps.weapon_triangles[triangle]
		var b: Vector3 = fps.weapon_pivot.transform*fps.weapon_triangles[triangle+1]
		var c: Vector3 = fps.weapon_pivot.transform*fps.weapon_triangles[triangle+2]
		var intersection: Variant = Geometry3D.segment_intersects_triangle(Vector3.ZERO,Vector3(0,0,-.60),a,b,c)
		if intersection != null: blocked_aperture += 1
	check(blocked_aperture == 0,"Actual imported rear sight triangles leave the camera aim ray unobstructed")
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
	fps.reload_visual_seconds = fps.RELOAD_SECONDS*.5
	fps.advance(0.01)
	check(fps.rifle_magazine.position.distance_to(fps.magazine_rest) > .12,"Real authored magazine moves out during reload")
	check(fps.grip_hands.get_child(1).position.distance_to(fps.left_hand_rest.origin) > .1,"Support hand releases fore-end for reload")
	fps.reload_visual_seconds = 0.0
	fps.advance(0.01)
	check(fps.rifle_magazine.position.is_equal_approx(fps.magazine_rest) and fps.grip_hands.get_child(1).transform.is_equal_approx(fps.left_hand_rest),"Reload restores source magazine and calibrated support-hand grip")
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
	check(fps.impact_serial > 0 and fps.impact_sprites.size() > 0,"Accepted shot produces a real physics surface mark")
	var impact_count: int = fps.impact_sprites.size()
	fps.receive_fps_state(fps.health_by_peer,fps.ammo_by_peer,fps.scores,fps.combat_state())
	check(fps.impact_sprites.size() == impact_count,"Repeated host state never duplicates ballistic marks")
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
	game.player.reset_to(Vector3(0,.12,0))
	game.player.yaw = 0
	game.player.rotation.y = 0
	fps.toggle_training()
	await physics_frame
	await physics_frame
	check(fps.training_enabled and fps.training_targets.size() == 3,"Solo drill spawns only explicit original GLB targets")
	var target_direction: Vector3 = (fps.training_targets[1].global_position-game.player.camera.global_position).normalized()
	game.player.pitch = asin(target_direction.y)
	await create_timer(.2).timeout
	check(fps.server_fire(1,target_direction) and fps.training_hits == 1,"Actual host raycast registers optional drill hit")
	check(fps.training_shots == 1 and fps.training_accuracy() == 100,"Drill accuracy counts only host-accepted rounds")
	check(not fps.server_fire(1,target_direction) and fps.training_shots == 1,"Duplicate cooldown request cannot inflate drill attempts")
	await create_timer(.2).timeout
	var miss_direction := Vector3(.09,0,-1).normalized()
	game.player.pitch = 0.0
	check(fps.server_fire(1,miss_direction) and fps.training_shots == 2 and fps.training_hits == 1 and fps.training_accuracy() == 50,"Accepted miss lowers actual accuracy while preserving hit count")
	game.ui.modal = true
	var drill_remaining: float = fps.training_time
	fps.advance(2.0)
	check(is_equal_approx(fps.training_time,drill_remaining),"Solo pause never consumes challenge time")
	game.ui.modal = false
	fps.training_time = .01
	fps.advance(.02)
	check(fps.training_finished and not fps.training_enabled and fps.training_targets.is_empty() and fps.training_best >= 1,"45-second drill expires, removes ray targets and retains actual score/best")
	var saved := ConfigFile.new()
	check(saved.load("user://faceless2.cfg") == OK and int(saved.get_value("training","best_hits",0)) == fps.training_best,"Challenge best persists through the actual settings file")
	fps.toggle_training()
	check(fps.training_enabled and fps.training_time == fps.TRAINING_SECONDS and fps.training_hits == 0 and fps.training_shots == 0,"Finished challenge restarts with a clean timer and score")
	fps.toggle_training()
	check(not fps.training_enabled and fps.training_targets.is_empty(),"Drill target toggle cleans its physics bodies")
	print("FPS_REFERENCE_COMBAT_PASS original M4A1/PBR, moving magazine/handle, physics marks, idempotent state and optional raycast drill")
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
	call_deferred("_finish_fixture")

func check_arm_boundaries(fps: Node3D) -> void:
	for mount in fps.grip_mounts:
		var skel: Skeleton3D = mount.skeleton
		var side := "r" if str(mount.hand.name).contains("_r_") else "l"
		var wrist := skel.to_global(skel.get_bone_global_pose(skel.find_bone("wrist."+side)).origin)
		var tested := 0
		var visible := 0
		for mesh in mount.hand.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var posed: PackedVector3Array = fps.skinned_surface_points(mesh,skel,surface)
				var keys: Array[String] = []
				for v in vertices: keys.append("%.4f,%.4f,%.4f" % [v.x,v.y,v.z])
				# Merge coincident UV/normal seam positions before finding real
				# open source-mesh edges. Inspect the posed arm end, not palm seams.
				var edges := {}
				for i in range(0,indices.size(),3):
					for j in range(3):
						var a: int = indices[i+j]
						var b: int = indices[i+(j+1)%3]
						var key: String = keys[a]+"|"+keys[b] if keys[a]<keys[b] else keys[b]+"|"+keys[a]
						if not edges.has(key): edges[key] = {"count":0,"a":a,"b":b}
						edges[key].count += 1
				for edge in edges.values():
					if edge.count != 1: continue
					for v in [edge.a,edge.b]:
						if posed[v].distance_to(wrist) < .15: continue
						tested += 1
						var screen: Vector2 = game.player.camera.unproject_position(posed[v])
						if not game.player.camera.is_position_behind(posed[v]) and Rect2(Vector2.ZERO,Vector2(root.size)).has_point(screen): visible += 1
		check(tested > 0 and visible == 0,"Actual CPU-skinned open arm boundary lies outside the hip/ADS viewport")
		print("FPS_ARM_BOUNDARY ads=",fps.aiming," side=",side," samples=",tested," visible=",visible)

func _finish_fixture() -> void:
	game = null
	var drain_until := Time.get_ticks_msec()+200
	while Time.get_ticks_msec() < drain_until: await process_frame
	if not failed: print("FACELESS2_FPS_CHECKS_PASS")
	call_deferred("quit",1 if failed else 0)
