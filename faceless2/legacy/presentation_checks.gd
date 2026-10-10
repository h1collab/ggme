extends SceneTree

var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := load("res://scripts/game.gd").new() as Node3D
	root.add_child(game)
	var ui: Control = game.interface
	check(str(ProjectSettings.get_setting("application/boot_splash/image")) == "res://ui/team_splash.png", "Native boot splash must use supported PNG encoding")
	var splash := Image.new()
	check(splash.load_png_from_buffer(FileAccess.get_file_as_bytes("res://ui/team_splash.png")) == OK, "Native boot splash must decode successfully")
	for light in game.street_lights: check(light is SpotLight3D, "Nearby street shadows must use one projected view instead of six cube faces")
	check(ui.brand_panel.visible, "Team presentation must appear before main menu")
	check(ui.brand_credit.text == "Made By Zorix GAme Team", "Startup must use requested credit exactly")
	check(ui.OFFICIAL_WEBSITE == "https://zorix.it", "About Us must point to official website")
	check(load("res://ui/game_icon.png") != null and load("res://ui/team_logo.jpg") != null, "Both supplied branding images must be imported")
	var picture_count := 0
	for picture in ui.find_children("*", "TextureRect", true, false):
		if not picture.has_meta("layout_extent"): continue
		picture_count += 1
		check(picture.size.is_equal_approx(picture.get_meta("layout_extent")), "Native logo size must not override fitted UI dimensions")
	check(picture_count == 4, "All four branding image placements must be checked")
	await create_timer(3.5, true).timeout
	check(not ui.brand_panel.visible and game.main_menu.visible, "Startup must finish while the game is paused")
	ui.show_brand_intro(false)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	ui._unhandled_input(escape)
	check(not ui.brand_panel.visible, "Startup must be skippable without changing game pause")
	ui.open_about()
	check(ui.about_panel.visible and not game.main_menu.visible and paused, "About Us must keep gameplay suspended")
	ui._unhandled_input(escape)
	check(not ui.about_panel.visible and game.main_menu.visible, "Back must return from About Us to main menu")
	for extent in [Vector2i(1280,720),Vector2i(2400,1080),Vector2i(1024,768)]:
		root.size = extent
		await process_frame
		ui._fit_layout()
		var viewport_extent: Vector2 = ui.get_viewport_rect().size
		var bounds: Rect2 = Rect2(ui.design.position, ui.design.size * ui.design.scale)
		check(bounds.position.x >= -0.1 and bounds.position.y >= -0.1 and bounds.end.x <= viewport_extent.x + 0.1 and bounds.end.y <= viewport_extent.y + 0.1, "Menus must fit phone and tablet displays")
		for control in [ui.website_button,ui.brand_credit]:
			check(Rect2(Vector2.ZERO,ui.DESIGN).encloses(Rect2(control.position,control.size)), "Branding and website controls must stay inside fitted canvas")
	var road := game.get_node("RoadTile0").get_child(0) as MeshInstance3D
	var material := road.mesh.surface_get_material(0) as ShaderMaterial
	check(material != null and material.get_shader_parameter("gravel") != null, "Ground must keep original photographic gravel detail")
	check(material != null and not material.get_shader_parameter("forest_floor"), "Road and forest materials must remain distinct")
	for x in [-8.8,-4.2,0.0,4.2,8.8]:
		check(is_zero_approx(game.GroundSurface.forest_height(x, -47)), "Accessible ground must stay aligned with collision")
	var foliage_count := 0
	for mesh in game.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null: continue
		for surface in range(mesh.mesh.get_surface_count()):
			var mat := mesh.get_active_material(surface) as BaseMaterial3D
			if mat != null and mat.resource_name == "M_TreeAtlas":
				foliage_count += 1
				check(mat.metallic_specular <= 0.01 and mat.roughness >= 0.9, "Nearby foliage must not retain white plastic-like reflections")
	check(foliage_count > 0, "Foliage material test must cover visible nearby trees")
	for batch in game.world_detail.forest_batches:
		var mat := batch.material_override as BaseMaterial3D
		check(mat != null and mat.metallic_specular <= 0.01 and mat.roughness >= 0.9, "Distant forest must match matte nearby foliage")
	# Scatter must be rooted on visual soil and stay outside accessible collision.
	for batch in game.world_detail.undergrowth_batches + game.world_detail.rock_batches:
		for placement in batch.get_meta("placements"):
			var position: Vector3 = placement.origin
			check(absf(position.x) >= 9.3, "Decorative scatter must not obstruct the walkable shoulder or objectives")
			var extent: AABB = placement * batch.multimesh.mesh.get_aabb()
			check(extent.position.x > 8.55 or extent.end.x < -8.55, "Full decorative mesh extents must stay beyond the collision boundary")
			var soil: float = game.GroundSurface.forest_height(position.x, position.z) - 0.035
			check(position.y >= soil - 0.01 and position.y < soil + 0.3, "Scatter must follow terrain rather than float or sink")
	check(game.world_detail.undergrowth_batches.size() == 4 and game.world_detail.rock_batches.size() == 4, "Detail must be divided into independently culled sectors")
	check(game.world_detail.get_node("BoundaryPosts").multimesh.instance_count == 76, "Both existing side boundaries need visible fence posts")
	for tier in range(4):
		game.world_detail.apply_quality(tier)
		for batch in game.world_detail.undergrowth_batches:
			check(batch.multimesh.visible_instance_count == [32,64,96,128][tier], "Undergrowth budget must respect selected quality")
		for batch in game.world_detail.rock_batches:
			check(batch.multimesh.visible_instance_count == [8,16,24,32][tier], "Rock budget must respect selected quality")
	game.world_detail.apply_quality(int(game.settings["quality"]))
	var rectangles: Array[Rect2] = []
	for control in ui.touch_controls.get_children():
		if control is Button:
			var rectangle := Rect2(control.position,control.size)
			for other in rectangles: check(not rectangle.intersects(other), "Touch buttons must not overlap")
			rectangles.append(rectangle)
	game.selected_mode = "EXPLORATION"
	game._spawn_player_and_enemies(false)
	var guard: Node3D = game.soldiers[0]
	var cloth_count := 0
	for mesh in guard.visual.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var mat: BaseMaterial3D = mesh.get_active_material(surface)
			check(mat.metallic == 0, "Character skin and cloth must not be metallic")
			if "guard_" in mat.resource_name:
				cloth_count += 1
				check(mat.roughness >= 0.8, "Uniform must use matte fabric instead of glossy plastic")
	check(cloth_count >= 5, "Fabric test must cover imported guard surfaces")
	var heading: float = guard.rotation.y
	guard._turn_toward(Vector3.RIGHT, 1.0 / 60.0)
	check(absf(angle_difference(heading, guard.rotation.y)) <= 0.054, "Guard must turn at a bounded rate instead of snapping instantly")
	guard.velocity = Vector3(0,0,2.0)
	guard._animate_gait(0.3)
	guard.velocity = Vector3.ZERO
	for i in range(20): guard._animate_gait(0.1)
	check(guard.movement_blend < 0.001 and guard.visual.scale.is_equal_approx(guard.visual_scale), "Gait must settle smoothly while preserving fitted character scale")
	check(not guard.torso_rotations.is_empty(), "Breathing must animate the actual torso rig")
	paused = false
	game.set_process(false)
	game.player.set_physics_process(false)
	for hostile in game.soldiers: hostile.set_physics_process(false)
	if is_instance_valid(game.enemy): game.enemy.set_physics_process(false)
	guard.global_position = game.player.global_position - Vector3(0,0,7)
	guard.rotation.y = 0
	guard.memory = 5
	guard.sense_cd = 0
	guard.attack_cd = 0
	guard.windup = 0
	await physics_frame
	await physics_frame
	guard._physics_process(1.0 / 60.0)
	check(guard.has_sight and guard.windup == 0, "Aware guards with a clear sightline must turn their weapon toward the player before starting a shot")
	for node in game.find_children("*","AudioStreamPlayer",true,false): node.stop(); node.stream = null
	for node in game.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	game.queue_free()
	await process_frame
	print("Presentation checks: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
