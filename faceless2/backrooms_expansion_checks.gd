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
	var fps: Node3D = game.fps
	var player: CharacterBody3D = game.player
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
	player.set_third_person(false)
	check(player.camera.position.distance_to(Vector3(0,1.58,0)) < .00001,"Switching back exactly restores first-person camera")
	wall.queue_free()
	var sources := {}
	for seat in range(1,5):
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
	check(sources.size() == 4,"Every server seat uses a different original character")
	var hud: Control = game.ui.fps_corner_hud
	game.ui.refresh()
	check(hud.weapon_buttons.size() == 4 and hud.health_bar.value == fps.health,"HUD weapon slots and health bind real state")
	check(game.ui.sprint_button.position.x < 800,"Run button is left-hand accessible")
	check(hud.ranking_text().contains("K / D") and hud.ranking_text().contains("P2"),"Real ranking includes kills/deaths and seat labels")
	check(fps.shot_sounds.size() == 4 and fps.shot_sounds.all(func(sound): return sound != null),"All four offline weapon sounds packaged")
	game.net.leave()
	game.queue_free()
	for i in range(12): await process_frame
	if not failed: print("FPS_EXPANSION_PASS four weapons, finite inventories, monotonic reload/cadence, real melee occlusion, shoulder camera, four source rigs, HUD and offline sounds")
	quit(1 if failed else 0)
