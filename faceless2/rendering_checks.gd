extends SceneTree

const AssetVisual = preload("res://scripts/asset_visual.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run_checks() -> void:
	var game := load("res://scripts/game.gd").new() as Node3D
	root.add_child(game)
	check(not game.interface.combat.visible and not game.interface.touch_controls.is_visible_in_tree(), "Main menu must hide combat HUD and touch controls")
	paused = false
	game.set_process(false)
	game.selected_mode = "EXPLORATION"
	game._spawn_player_and_enemies(false)
	var player: CharacterBody3D = game.player
	player.set_controls_enabled(true)
	player.camera.current = true
	player.set_physics_process(false)
	for soldier in game.soldiers: soldier.set_physics_process(false)
	await physics_frame
	await physics_frame
	for i in range(6):
		var tile := game.get_node("RoadTile%d" % i) as Node3D
		var box := tile.transform * AssetVisual.bounds(tile)
		check(absf(box.size.x - 18.0) < 0.01, "Road width must match collision")
		check(absf(box.size.z - 25.0) < 0.01, "Road tile length must match collision")
		check(absf(box.end.y) < 0.001 and box.position.y >= -0.021, "Visible road must meet collision at y=0")
		var mesh := tile.get_child(0) as MeshInstance3D
		var normal_basis := mesh.global_basis.inverse().transposed()
		var sum := 0.0
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				sum += (normal_basis * normal).normalized().y
		check(sum > 0.0, "Imported road normals must face upward")
	for model in [player.pistol_model, player.rifle_model, player.hands_model]:
		check(model != null, "First-person asset must load")
	player.unlock_rifle()
	check(AssetVisual.bounds(player.weapon_holder).get_center().length() < 0.001, "Rifle's off-centre origin must be removed")
	for side in ["RightHand", "LeftHand"]:
		var hand: Node3D = player.hands_model.get_node(side)
		for part in hand.get_children():
			if part.name != "Sleeve": check(AssetVisual.bounds(part).size.length() < 0.5, "Cropped hands must remain at first-person scale")
	var rifle_box := AssetVisual.bounds(player.weapon_holder)
	check(rifle_box.size.z > rifle_box.size.y * 2.0, "Rifle barrel must run forward, not vertically")
	player.set_touch_aiming(true)
	player._physics_process(1.0 / 60.0)
	check(player.aiming, "Touch AIM must survive a physics frame without a mouse")
	player.set_field_of_view(90.0)
	player.set_touch_aiming(false)
	player._process(1.0)
	check(absf(player.camera.fov - 90.0) < 0.01, "Returning from AIM must respect selected FOV")
	player.fire_weapon()
	check(player.ammo_in_mag == 29, "Firing must consume one round")
	player.weapon_cooldown = 0.0
	player.reload_weapon()
	check(player.reloading, "Reload must start")
	player.restore_full()
	for i in range(90):
		await process_frame
	check(not player.reloading and player.ammo_in_mag == 29, "Reset must cancel stale reload callbacks")
	var soldier: CharacterBody3D = game.soldiers[0]
	var original_scale: Vector3 = soldier.visual.scale
	soldier.take_bullet(1.0, Vector3.ZERO)
	for i in range(30):
		await process_frame
	check(soldier.visual.scale.is_equal_approx(original_scale), "Hit feedback must preserve imported soldier scale")
	# Exercise actual screen bounds and transitions, including multitouch capture.
	game.main_menu.hide()
	game.game_started = true
	game.interface.force_touch = true
	game.interface.refresh_state()
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 864), Vector2i(1024, 768), Vector2i(960, 540)]:
		root.size = resolution
		await process_frame
		game.interface._fit_layout()
		var canvas: Control = game.interface.design
		var extent: Vector2 = canvas.position + canvas.size * canvas.scale
		check(canvas.position.x >= -0.1 and canvas.position.y >= -0.1 and extent.x <= game.interface.get_viewport_rect().size.x + 0.1 and extent.y <= game.interface.get_viewport_rect().size.y + 0.1, "Interface must fit 16:9, ultrawide, tablet and small displays")
	var joystick: Control = game.joystick
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.pressed = true
	touch.position = joystick.size * 0.5 + Vector2(50, 0)
	joystick._gui_input(touch)
	check(joystick.value.x > 0.5, "Joystick must use the visual centre")
	touch.pressed = false
	touch.position = Vector2(4000, 4000)
	joystick._input(touch)
	check(joystick.value == Vector2.ZERO and joystick.pointer_id == -1, "Releasing outside joystick must stop movement")
	var fire: Button
	var aim: Button
	for button in game.interface.touch_controls.get_children():
		if button is Button and button.text == "FIRE": fire = button
		if button is Button and button.text == "AIM": aim = button
	touch.pressed = true
	touch.index = 1
	touch.position = fire.get_global_transform_with_canvas() * (fire.size * 0.5)
	fire._input(touch)
	touch.index = 2
	touch.position = aim.get_global_transform_with_canvas() * (aim.size * 0.5)
	aim._input(touch)
	check(player.fire_touch and player.aim_touch, "Separate fingers must be able to fire and aim together")
	var before_pause: int = player.ammo_in_mag
	game.toggle_pause()
	check(paused and not player.controls_enabled and not game.interface.touch_controls.is_visible_in_tree(), "Pause must suspend the world and hide combat controls")
	check(not player.fire_touch and not player.aim_touch and fire.pointer_id == -1 and aim.pointer_id == -1, "Pause must release all held touches")
	player.fire_weapon()
	check(player.ammo_in_mag == before_pause, "Paused player must not fire")
	game.interface.open_settings(game.interface.pause_panel)
	game.interface.close_settings()
	check(paused and game.interface.pause_panel.visible, "Settings must return to pause without resuming combat")
	game.toggle_pause()
	check(not paused and player.controls_enabled and game.interface.touch_controls.is_visible_in_tree(), "Resume must restore gameplay controls")
	game._set_cinematic_active(true)
	check(not game.interface.combat.visible and not soldier.is_physics_processing() and not player.controls_enabled, "Cinematic must hide the full HUD and suspend hostile attacks")
	game._set_cinematic_active(false)
	check(game.interface.combat.visible and player.controls_enabled, "Cinematic ending must restore HUD")
	game._start_cinematic_intro()
	game.skip_cinematic()
	await process_frame
	await process_frame
	check(not game.cinematic_running and player.controls_enabled and not game.cinematic_overlay.visible, "Skipping a shot must restore gameplay without starting the next shot")
	player.set_touch_aiming(true)
	player.camera.fov = 55
	player.ammo_in_mag = 1
	player.weapon_cooldown = 0
	player.reload_weapon()
	player._process(1.0)
	check(absf(player.camera.fov - player.base_fov) < 0.01, "Reload from ADS must restore camera FOV")
	var settings_path := "user://faceless2_settings.cfg"
	var had_settings := FileAccess.file_exists(settings_path)
	var original_settings := FileAccess.get_file_as_bytes(settings_path) if had_settings else PackedByteArray()
	var saved_profile: Dictionary = game.settings.duplicate()
	game.settings["fov"] = 84
	game.settings["volume"] = 0.35
	game._save_settings()
	game.settings["fov"] = 60
	game.settings["volume"] = 1
	game._load_settings()
	check(game.settings["fov"] == 84 and is_equal_approx(game.settings["volume"], 0.35), "Settings must survive saving and loading")
	game.settings = saved_profile
	if had_settings:
		var original_file := FileAccess.open(settings_path, FileAccess.WRITE)
		original_file.store_buffer(original_settings)
		original_file.close()
	else: DirAccess.remove_absolute(settings_path)
	var checkpoint_path := "user://faceless2_save.cfg"
	var had_checkpoint := FileAccess.file_exists(checkpoint_path)
	var original_checkpoint := FileAccess.get_file_as_bytes(checkpoint_path) if had_checkpoint else PackedByteArray()
	player.restore_full()
	player.current_weapon = "RIFLE"
	player.ammo_in_mag = 17
	player.reserve_ammo = 62
	player.global_position = Vector3(3.5, 0.9, -21)
	game.evidence_nodes[0].visible = false
	game.pickups[0].visible = false
	game.evidence_collected = 1
	game.story_flags = {"armed": true}
	game._save_checkpoint()
	player.reset_loadout()
	game.evidence_nodes[0].visible = true
	game.pickups[0].visible = true
	game.story_flags = {}
	game._continue_game()
	check(player.rifle_unlocked and player.current_weapon == "RIFLE" and player.ammo_in_mag == 17 and player.reserve_ammo == 62, "Continue must restore weapon ownership and ammunition")
	check(not game.evidence_nodes[0].visible and not game.pickups[0].visible and game.story_flags.has("armed"), "Continue must preserve collected items and completed story beats")
	check(absf(player.global_position.x - 3.5) < 0.01, "Continue must restore lateral position")
	if had_checkpoint:
		var original_file := FileAccess.open(checkpoint_path, FileAccess.WRITE)
		original_file.store_buffer(original_checkpoint)
		original_file.close()
	else: DirAccess.remove_absolute(checkpoint_path)
	# Telegraphs, snapshot shots and sight checks must reward movement/cover.
	for hostile in game.soldiers: hostile.set_physics_process(false)
	var guard: CharacterBody3D = game.soldiers[0]
	for i in range(1, game.soldiers.size()): game.soldiers[i].global_position = Vector3(100 + i, 0, 100)
	guard.global_position = Vector3(0, 0.05, -5)
	guard.look_at(Vector3(0, 0.05, 0), Vector3.UP)
	guard.attack_cd = 0
	guard.windup = 0
	guard.sense_cd = 0
	guard.memory = 0
	guard.has_sight = false
	player.global_position = Vector3(0, 0.05, 0)
	player.health = 100
	var wall := StaticBody3D.new()
	var blocker := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 3, 0.5)
	blocker.shape = shape
	wall.position = Vector3(0, 1.5, -2.5)
	wall.add_child(blocker)
	game.add_child(wall)
	await physics_frame
	await physics_frame
	check(not guard._can_see_player(), "Opaque cover must block soldier vision")
	guard.hear_shot(player.global_position)
	guard._physics_process(0.18)
	check(guard.memory > 0 and guard.windup == 0 and player.health == 100, "Gunfire may alert an occluded soldier but must not permit shooting through cover")
	wall.queue_free()
	await physics_frame
	await physics_frame
	guard.sense_cd = 0
	guard._physics_process(0.18)
	check(guard.windup > 0 and player.health == 100 and guard.muzzle_signal.visible, "Soldier must visibly wind up before a shot")
	player.global_position.x = 2.5
	await physics_frame
	await physics_frame
	guard._physics_process(0.6)
	check(player.health == 100, "Moving away from the snapshot aim point must dodge the shot")
	guard.windup = 0.3
	var guard_health: float = guard.health
	guard.take_bullet(10, guard.global_position + Vector3(0, 0.8, 0))
	check(guard.windup == 0 and guard.stagger > 0 and is_equal_approx(guard.health, guard_health - 10), "A body hit must interrupt the shooting tell")
	guard_health = guard.health
	guard.take_bullet(10, guard.global_position + Vector3(0, 1.7, 0))
	check(is_equal_approx(guard.health, guard_health - 18), "Head hits must receive the intended damage multiplier")
	var entity := CharacterBody3D.new()
	entity.set_script(load("res://scripts/faceless.gd"))
	entity.game = game
	entity.player = player
	entity.position = Vector3(0, 0.05, -10)
	game.add_child(entity)
	entity.set_physics_process(false)
	var entity_scale: Vector3 = entity.visual.scale
	check(absf((entity.visual.transform * AssetVisual.bounds(entity.visual)).size.y - 2.05) < 0.05, "Faceless model must match its intended game height")
	entity.take_bullet(1, Vector3.ZERO)
	for i in range(20): await process_frame
	check(entity.visual.scale.is_equal_approx(entity_scale), "Faceless hit feedback must preserve imported scale")
	entity.queue_free()
	player.aiming = false
	player.crouched = false
	player.last_move_strength = 0
	var hip_spread: float = player.get_shot_spread()
	player.last_move_strength = 1
	check(player.get_shot_spread() > hip_spread, "Moving hip fire must have greater spread")
	player.aiming = true
	check(player.get_shot_spread() < hip_spread * 0.4, "Aim must materially improve accuracy")
	player.aiming = false
	player.last_move_strength = 0
	player.crouched = true
	check(player.get_shot_spread() < hip_spread, "Crouching must improve accuracy")
	player.crouched = false
	game.world_detail.apply_quality(0)
	check(game.world_detail.forest_batches[0].multimesh.visible_instance_count == 18 and not game.world_detail.relay_lights[0].visible, "Low quality must reduce forest density and secondary lights")
	game.world_detail.apply_quality(3)
	check(game.world_detail.forest_batches[0].multimesh.visible_instance_count == 72, "Ultra must enable the full instanced forest")
	var effects_count: int = game.effects.get_child_count()
	for i in range(100): game.effects.shot(Vector3(0, 1, 0), Vector3(0, 1, -4), Vector3.BACK)
	check(game.effects.get_child_count() == effects_count, "Repeated fire must reuse effect pools without growing the scene")
	game.effects.clear_effects()
	game.effects.quality = 0
	game.effects.shot(Vector3(0, 1, 0), Vector3(0, 1, -4), Vector3.BACK)
	var visible_tracers := 0
	for tracer in game.effects.tracers:
		if tracer.visible: visible_tracers += 1
	check(visible_tracers == 0, "Performance quality must suppress tracer effects")
	game.effects.clear_effects()
	# Stop deferred actions before destroying the scene.
	player.restore_full()
	touch = null
	for hostile in game.soldiers: hostile.set_physics_process(false)
	if is_instance_valid(game.enemy): game.enemy.set_physics_process(false)
	for sound in game.find_children("*", "AudioStreamPlayer", true, false):
		sound.stop()
		sound.stream = null
	for sound in game.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
		sound.stream = null
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	print("Rendering/gameplay checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
