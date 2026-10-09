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
	check(AssetVisual.bounds(player.hands_model.get_node("RightHand")).size.length() < 0.5 and AssetVisual.bounds(player.hands_model.get_node("LeftHand")).size.length() < 0.5, "Cropped hands must remain at first-person scale")
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
	game.queue_free()
	await process_frame
	print("Rendering/gameplay checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
