extends SceneTree

var output := "/tmp/faceless2-qa"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func capture(game: Node3D, name: String, pos: Vector3, heading: float, pitch: float, rifle := false, aim := false) -> void:
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
	for i in range(3): await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(name + ".png")) != OK:
		push_error("Screenshot failed: " + name)
		quit(1)
		return
	print("Visual capture: ", name)

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
	game.interface.finish_brand_intro()
	await capture_page("00b-main-menu")
	game.interface.open_about()
	await capture_page("00c-about-us")
	game.interface.close_about()
	paused = false
	game.set_process(false)
	game.selected_mode = "EXPLORATION"
	game._spawn_player_and_enemies(false)
	game.main_menu.hide()
	game.game_started = true
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
	for node in game.find_children("*", "AudioStreamPlayer", true, false): node.stop(); node.stream = null
	for node in game.find_children("*", "AudioStreamPlayer3D", true, false): node.stop(); node.stream = null
	game.queue_free()
	await process_frame
	print("Visual captures: PASS")
	quit()
