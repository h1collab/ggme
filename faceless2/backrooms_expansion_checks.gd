extends SceneTree
var game: Node3D
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; push_error("FAIL: "+message)
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
	# A malformed directory must never silently create a local UDP room.
	for payload in ["<html>gateway failure</html>","{}",'{"code":"BAD","key":"x","owner_token":"x"}']:
		game.rooms.operation = "create"
		game.rooms._http_complete(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),payload.to_utf8_buffer())
		check(game.net.mode == "solo","Invalid HTTP response cannot start a host")
	game.rooms.operation = "resolve"
	game.rooms._http_complete(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),"{}".to_utf8_buffer())
	check(game.net.mode == "solo","Invalid resolved endpoint rejected without ENet errors")
	var fps: Node3D = game.fps
	var player: CharacterBody3D = game.player
	# The former native flank fixture was inside a real cargo collision.
	var digests := {}
	for map_id in [0,1,2,3]:
		game.fps_arena.activate(map_id)
		await physics_frame
		await physics_frame
		digests[game.fps_arena.geometry_digest()] = true
		for seat in range(1,7):
			var spawn: Vector3 = game.fps_arena.spawn_for(seat)
			check(game.net.movement_path_clear(spawn,spawn),"All six spawns clear on every map")
		var shape := CapsuleShape3D.new()
		shape.radius = .32; shape.height = 1.72
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = Vector3(33,1.0,45)
		query.exclude = [player.get_rid()]
		check(game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Both expanded flank preview locations clear actual cargo geometry")
	check(not game.net.movement_path_clear(Vector3(14,.12,1),Vector3(14,.12,9)),"Swept server capsule rejects crossing actual cargo cover")
	check(digests.size() == 4,"Four distinct authoritative map geometries")
	game.fps_arena.activate(0)

	fps.set_process(false)
	player.reset_to(Vector3(0,.12,0))
	player.yaw = 0; player.pitch = 0; player.rotation = Vector3.ZERO
	fps.register_peer(2)
	game.net.seats[2] = 2
	game.net.poses[2] = {"p":Vector3(0,.12,-5),"y":0.0,"pitch":0.0}
	await physics_frame
	await physics_frame
	check(fps.extra_weapons.size() == 3,"Three additional real source GLBs loaded")
	for index in range(1,4):
		var meshes: Array[Node] = fps.extra_weapons[index-1].find_children("*","MeshInstance3D",true,false)
		check(not meshes.is_empty(),"Real imported weapon mesh exists")
		for mesh in meshes: check(mesh.mesh is ArrayMesh and not mesh.mesh is PrimitiveMesh,"No generated visible weapon geometry")
	check(not fps.server_weapon(999,1) and not fps.server_weapon(1,-1) and not fps.server_weapon(1,4),"Unknown sender / out-of-range selection rejected")
	for index in [1,2,3,0]:
		await create_timer(1.1).timeout
		check(fps.server_weapon(1,index),"Server accepts legal weapon switch")
		check(not fps.server_weapon(1,(index+1)%4),"Switch flood rate-limited")
		check(not fps.server_fire(1,Vector3.FORWARD),"Equipping prevents instantaneous bypass shot")
		await create_timer(.27).timeout
		game.net.poses[2].p = Vector3(0,.12,-5)
		var hp: int = fps.health_by_peer[2]
		var ammo: int = fps.ammo_by_peer[1]
		check(fps.server_fire(1,Vector3.FORWARD),"Selected weapon fires using server rules")
		check(not fps.server_fire(1,Vector3.FORWARD),"Duplicate shot rejected by selected cadence")
		if index == 3:
			check(fps.health_by_peer[2] == hp,"Knife cannot hit a target five metres away")
			check(fps.ammo_by_peer[1] == 0,"Knife uses no fictitious ammunition")
		else:
			check(fps.ammo_by_peer[1] == ammo-1,"Only selected magazine consumed")
			check(fps.health_by_peer[2] == (100 if index == 2 else hp-int(fps.Arsenal.spec(index).damage)),"Weapon-specific authoritative damage")
		fps.health_by_peer[2] = 100
	# Return to depleted sidearm: no refill by cycling, host-timed reload.
	await create_timer(.3).timeout
	check(fps.server_weapon(1,1),"Re-select pistol")
	check(fps.ammo_by_peer[1] == 11 and fps.reserve_by_peer[1] == 72,"Per-weapon inventory survives cycling")
	check(fps.server_reload(1),"Pistol reload accepted")
	check(not fps.server_weapon(1,2),"Reload cannot be cancelled through a selection RPC")
	var start := Time.get_ticks_msec()
	while fps.reload_ends.has(1):
		fps.finish_server_reloads()
		await process_frame
	check(Time.get_ticks_msec()-start >= 1240,"Actual monotonic pistol reload duration")
	check(fps.ammo_by_peer[1] == 12 and fps.reserve_by_peer[1] == 71,"Reload transfers finite rounds")
	await create_timer(.3).timeout
	check(fps.server_weapon(1,3),"Select knife for close-range test")
	await create_timer(.27).timeout
	game.net.poses[2].p = Vector3(0,.12,-1.4)
	check(fps.server_fire(1,Vector3.FORWARD) and fps.health_by_peer[2] == 50,"Knife applies real two-metre melee damage")
	await create_timer(.47).timeout
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(3,3,.12)
	wall.add_child(collision)
	wall.position = Vector3(0,1.5,-.6)
	game.add_child(wall)
	await physics_frame
	await physics_frame
	check(fps.server_fire(1,Vector3.FORWARD) and fps.health_by_peer[2] == 50,"Actual world wall blocks knife damage")
	wall.position.z = 1.1
	await physics_frame
	await physics_frame
	player.set_third_person(true)
	player.update_combat_camera(.05)
	check(player.third_person and player.camera.position.z < .92,"Shoulder camera retracts in front of actual wall")
	check(player.eye_position().distance_to(player.global_position+Vector3(0,1.58,0)) < .00001,"Shot origin stays at body eye, never behind-wall camera")
	check(not fps.weapon_pivot.visible,"First-person weapon hidden in third-person view")
	check(absf(player.camera.position.x) > .05,"Shoulder camera keeps a lateral offset after collision fitting")
	player.set_third_person(false)
	check(player.camera.position.distance_to(Vector3(0,1.58,0)) < .00001,"Switching back exactly restores first-person camera")
	wall.queue_free()
	await physics_frame
	await physics_frame
	fps._apply_weapon(0)
	player.set_third_person(true)
	player.camera.rotation = Vector3(.2,PI,.3) # Previous scripted/cinematic look.
	player.update_combat_camera(.1)
	check(absf(player.camera.rotation.y) < .00001 and absf(player.camera.rotation.z) < .00001,"Shoulder camera clears stale cinematic yaw and roll")
	game.fps_arena.update_local_actor(.1)
	for i in range(3): await process_frame
	var visible_points := 0
	var total_points := 0
	for part in game.fps_arena.local_shadow.held_meshes:
		var mesh := part as MeshInstance3D
		check(mesh.is_visible_in_tree() and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"Third-person weapon is actually rendered, not shadow-only")
		for corner in range(8):
			var point: Vector3 = mesh.to_global(mesh.get_aabb().get_endpoint(corner))
			var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,point,1)
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() and not player.camera.is_position_behind(point) and Rect2(Vector2.ZERO,Vector2(root.size)).has_point(player.camera.unproject_position(point)): visible_points += 1
			total_points += 1
	check(game.fps_arena.local_shadow.attachment.global_position.z < player.global_position.z-.1,"Ready-pose authored hand remains in front of the body")
	check(visible_points > total_points/10,"Actual rifle bounds have an unobstructed view around the player's collision capsule")
	print("THIRD_PERSON_RIFLE_VISIBLE_BOUND_POINTS ",visible_points,"/",total_points," camera=",player.camera.global_position," gun=",game.fps_arena.local_shadow.held.global_position," hand=",game.fps_arena.local_shadow.attachment.global_position)
	player.set_third_person(false)
	var sources := {}
	for seat in range(1,7):
		var actor := preload("backrooms_combat_actor.gd").new()
		game.add_child(actor)
		actor.configure(seat)
		sources[actor.get_meta("character_source")] = true
		check(is_instance_valid(actor.skeleton) and is_instance_valid(actor.attachment),"Original skinned character has real weapon-hand attachment")
		actor.update_combat(6.2,false,1,1,.016)
		check(not actor.current_clip.is_empty(),"Imported source animation selected")
		for index in range(4):
			actor.set_weapon(index)
			check(actor.hand_contact_error() < .002,"Actual third-person hand bone remains attached to weapon grip")
		actor.queue_free()
	check(sources.size() == 4,"Four licensed characters with six seat identities")
	var hud: Control = game.ui.fps_corner_hud
	game.ui.refresh()
	check(hud.weapon_buttons.size() == 4 and hud.health_bar.value == fps.health,"HUD weapon slots and health bind real state")
	check(game.ui.sprint_button.position.x < 800,"Run button is left-hand accessible")
	check(hud.ranking_text().contains("K / D") and hud.ranking_text().contains("P2"),"Real ranking includes kills/deaths and seat labels")
	fps._apply_weapon(2)
	fps.magazine = 5
	game.ui.refresh()
	check(not hud.ammo_hint.text.contains("LOW AMMO"),"Full sniper magazine is not a low-ammo warning")
	fps.magazine = 1
	game.ui.refresh()
	check(hud.ammo_hint.text == "LOW AMMO","One sniper round triggers correct weapon-specific warning")
	fps._apply_weapon(3)
	fps.trigger_recoil()
	check(fps.muzzle_flash_time == 0.0,"Knife swing produces no firearm flash")
	check(fps.shot_sounds.size() == 4 and fps.shot_sounds.all(func(sound): return sound != null),"All four offline weapon sounds packaged")
	game.net.leave()
	game.queue_free()
	for i in range(12): await process_frame
	if not failed: print("FPS_EXPANSION_PASS four weapons, finite inventories, monotonic reload/cadence, real melee occlusion, shoulder camera, four source rigs, HUD and offline sounds")
	quit(1 if failed else 0)
