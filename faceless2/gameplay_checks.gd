extends SceneTree

const AssetVisual = preload("res://scripts/asset_visual.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func freeze_hostiles(game: Node3D) -> void:
	for guard in game.soldiers: guard.set_physics_process(false)
	if is_instance_valid(game.enemy): game.enemy.set_physics_process(false)

func run() -> void:
	var save_path := "user://faceless2_save.cfg"
	var had_save := FileAccess.file_exists(save_path)
	var old_save := FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	DirAccess.remove_absolute(save_path)
	var game := load("res://scripts/game.gd").new() as Node3D
	root.add_child(game)
	game.selected_mode = "EXPLORATION"
	game._start_new_game()
	game.skip_cinematic()
	game.set_process(false)
	freeze_hostiles(game)
	var player: CharacterBody3D = game.player
	check(FileAccess.file_exists(save_path), "New game must create a checkpoint before the first relay")
	await create_timer(0.6).timeout
	check(player.is_on_floor() and absf(player.global_position.y) < 0.1, "Player must settle onto the visible ground")
	for sign in game.world_detail.field_signs:
		var center: Vector3 = sign.global_transform * Vector3(0,1.75,0)
		var front: Vector3 = sign.global_basis.z
		var query := PhysicsRayQueryParameters3D.create(center + front, center - front * 0.1)
		var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and sign.is_ancestor_of(hit.get("collider")), "Field signs must collide at their visible boards instead of letting shots pass through")
	# Drive actual physics through the virtual joystick, rather than teleporting
	# across the road. Check movement and the playable shoulder boundary.
	var start := player.global_position
	game.joystick.value = Vector2(0, -1)
	await create_timer(1.0).timeout
	game.joystick.value = Vector2.ZERO
	check(player.global_position.z < start.z - 3 and player.is_on_floor(), "Walking must advance on continuous road without falling")
	player.global_position = Vector3(7.8, 0.03, -9)
	game.joystick.value = Vector2(1, 0)
	await create_timer(0.6).timeout
	game.joystick.value = Vector2.ZERO
	check(player.global_position.x < 8.3, "Road boundary must stop the player before leaving the playable ground")
	player.global_position = Vector3(0, 0.03, -120)
	game.joystick.value = Vector2(0, -1)
	await create_timer(0.6).timeout
	game.joystick.value = Vector2.ZERO
	check(player.global_position.z > -121.5 and player.is_on_floor(), "Far boundary must prevent walking beyond collision terrain")
	player.global_position = Vector3(0, 0.03, 26)
	game.joystick.value = Vector2(0, 1)
	await create_timer(0.6).timeout
	game.joystick.value = Vector2.ZERO
	check(player.global_position.z < 27.5 and player.is_on_floor(), "Checkpoint boundary must prevent falling behind the starting area")
	# A real overhead collider must permit crouching but block standing.
	player.global_position = Vector3(0, 0.03, -9)
	player.toggle_crouch()
	check(is_equal_approx((player.body_shape.shape as CapsuleShape3D).height, 1.18), "Crouch must reduce the collider height")
	var ceiling := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 0.2, 3)
	cs.shape = box
	ceiling.position = Vector3(0, 1.48, -9)
	ceiling.add_child(cs)
	game.add_child(ceiling)
	await physics_frame
	await physics_frame
	player.toggle_crouch()
	check(player.crouched, "Standing must be blocked beneath a low ceiling")
	ceiling.queue_free()
	await physics_frame
	await physics_frame
	player.toggle_crouch()
	check(not player.crouched, "Player must stand once the overhead obstruction is removed")
	# Exercise the actual death callback and its timed fade/continue chain.
	player.take_damage(1000)
	await create_timer(1.9).timeout
	check(player.alive and player.controls_enabled and player.health == 100, "Death before Relay 1 must restore a playable checkpoint")
	freeze_hostiles(game)
	# Anchors must coincide with the visible base, even for off-centre GLBs.
	for asset in game.relays + game.evidence_nodes + game.pickups + [game.rifle_pickup, game.extraction_gate]:
		var bounds := AssetVisual.bounds(asset)
		check(absf(bounds.get_center().x) < 0.01 and absf(bounds.get_center().z) < 0.01 and absf(bounds.position.y) < 0.01, "Normalized model anchor must match its visible base: " + asset.name)
	for index in range(game.relays.size()):
		player.global_position = game.relays[index].global_position + Vector3(0, 0.03, 1.5)
		game._update_nearby_prompt()
		check("RELAY" in game.prompt_label.text, "Relay must be interactable next to its visible cabinet")
		game._interact()
		check(game.relay_active[index], "Relay interaction must power the intended cabinet")
		freeze_hostiles(game)
	for evidence in game.evidence_nodes:
		player.global_position = evidence.global_position + Vector3(0, 0.03, 1)
		game._interact()
	check(game.evidence_collected == 3, "All evidence must be reachable at the visible model")
	player.global_position = game.rifle_pickup.global_position + Vector3(0, 0, 1)
	game._interact()
	check(player.rifle_unlocked, "Rifle must be collectible at its visible location")
	player.weapon_cooldown = 0
	player.fire_weapon()
	await create_timer(0.15).timeout
	player.reload_weapon()
	await create_timer(2.0).timeout
	check(player.ammo_in_mag == 30 and not player.reloading, "Rifle reload must finish during running gameplay")
	player.global_position = game.extraction_gate.global_position + Vector3(0, 0.03, 2)
	game._interact()
	check(game.final_wave_started, "Powered gate with evidence must trigger the final wave")
	freeze_hostiles(game)
	# Complete actual enemy death callbacks, then exercise the extraction action.
	for guard in game.soldiers.duplicate(): guard.take_bullet(1000, guard.global_position + Vector3(0, 1.7, 0))
	await create_timer(0.8).timeout
	check(game.final_wave_cleared, "Clearing the counterattack must unlock extraction")
	game._interact()
	check(not game.game_started and paused and game.main_menu.visible, "Extraction must return to the completed-game menu")
	paused = false
	for node in game.find_children("*", "AudioStreamPlayer", true, false): node.stop(); node.stream = null
	for node in game.find_children("*", "AudioStreamPlayer3D", true, false): node.stop(); node.stream = null
	game.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		file.store_buffer(old_save)
		file.close()
	else: DirAccess.remove_absolute(save_path)
	print("Full gameplay checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
