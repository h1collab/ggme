extends SceneTree

var output := "/tmp/faceless2-qa"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func capture(game: Node3D, name: String, pos: Vector3, heading: float, pitch: float, rifle := false, aim := false) -> void:
	print("Visual stage: preparing ", name)
	game.player.global_position = pos
	game.player.rotation.y = heading
	game.player.pitch = pitch
	game.player.current_weapon = "RIFLE" if rifle else "PISTOL"
	game.player.ammo_in_mag = game.player.rifle_mag if rifle else game.player.pistol_mag
	game.player.reserve_ammo = game.player.rifle_reserve if rifle else game.player.pistol_reserve
	game.player.set_touch_aiming(aim)
	game.player._apply_weapon_pose()
	game.interface.notice_time = 0
	game.update_hud(game.player.health, game.player.stamina, game.player.battery, game.player.current_weapon, game.player.ammo_in_mag, game.player.reserve_ammo)
	for i in range(3):
		await process_frame
		print("Visual frame: ", name, " / ", i + 1)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(name + ".png")) != OK:
		push_error("Screenshot failed: " + name)
		quit(1)
		return
	print("Visual capture: ", name)

func _decode_software_ground(game: Node3D) -> void:
	# Software Vulkan samples decoded source pixels; physical GPUs keep the
	# exported compressed textures. Geometry, materials and camera are identical.
	if not RenderingServer.get_video_adapter_name().to_lower().contains("llvmpipe"): return
	var decoded := {}
	for mesh in game.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material == null or not material.shader.code.contains("uniform sampler2D gravel"): continue
			var texture := material.get_shader_parameter("gravel") as Texture2D
			if texture == null: continue
			var key := texture.get_instance_id()
			if not decoded.has(key):
				var image := texture.get_image()
				if image.is_compressed(): assert(image.decompress() == OK)
				decoded[key] = ImageTexture.create_from_image(image)
				print("Visual software gravel decoded: ", image.get_size())
			material.set_shader_parameter("gravel", decoded[key])

func capture_page(name: String) -> void:
	for i in range(3): await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(name + ".png")) != OK:
		push_error("Screenshot failed: " + name)
		quit(1)
		return
	print("Visual capture: ", name)

func run() -> void:
	var game := load("res://scripts/game.gd").new() as Node3D
	root.add_child(game)
	game.interface.show_brand_intro(false)
	await capture_page("00a-team-intro")
	# Verify the actual GPU transform buffers, alongside headless placement checks.
	for batch in game.world_detail.undergrowth_batches + game.world_detail.rock_batches:
		for i in range(batch.multimesh.instance_count):
			var uploaded: Transform3D = batch.multimesh.get_instance_transform(i)
			var intended: Transform3D = batch.get_meta("placements")[i]
			if not uploaded.origin.is_equal_approx(intended.origin):
				push_error("Scatter GPU transform differs from terrain placement")
				quit(1)
				return
	game.interface.finish_brand_intro()
	await capture_page("00b-main-menu")
	game.interface.open_about()
	await capture_page("00c-about-us")
	game.interface.close_about()
	paused = false
	game.set_process(false)
	game.selected_mode = "EXPLORATION"
	print("Visual stage: spawning player and guards")
	game._spawn_player_and_enemies(false)
	print("Visual stage: player and guards ready")
	game.main_menu.hide()
	game.game_started = true
	_decode_software_ground(game)
	game.interface.force_touch = true
	game.interface.refresh_state()
	game.player.set_controls_enabled(true)
	game.player.camera.current = true
	game.player.set_physics_process(false)
	for guard in game.soldiers: guard.set_physics_process(false)
	game.player.unlock_rifle()
	game._update_objective()
	await capture(game, "01-road-pistol", Vector3(0, 0.02, 5), 0, -0.10)
	await capture(game, "02-rifle", Vector3(0, 0.02, -38), 0, -0.10, true)
	await capture(game, "03-rifle-ads", Vector3(0, 0.02, -38), 0, -0.05, true, true)
	var guard: CharacterBody3D = game.soldiers[0]
	guard.global_position = Vector3(0, 0.02, -7)
	guard.rotation.y = PI
	await capture(game, "04-guard", Vector3(0, 0.02, -3), 0, -0.08)
	await capture(game, "05-extraction", Vector3(0, 0.02, -101), 0, -0.04, true)
	await capture(game, "06-checkpoint", Vector3(0, 0.02, 1), PI * 0.76, -0.05)
	await capture(game, "07-forest-shoulder", Vector3(7.2, 0.02, -18), -PI * 0.5, -0.15)
	await capture(game, "08-field-sign", Vector3(-5.5, 0.02, 3), 0.48, -0.02)
	for node in game.find_children("*", "AudioStreamPlayer", true, false): node.stop(); node.stream = null
	for node in game.find_children("*", "AudioStreamPlayer3D", true, false): node.stop(); node.stream = null
	game.queue_free()
	await process_frame
	print("Visual captures: PASS")
	quit()
