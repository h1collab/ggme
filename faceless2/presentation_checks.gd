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
	for node in game.find_children("*","AudioStreamPlayer",true,false): node.stop(); node.stream = null
	for node in game.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	game.queue_free()
	await process_frame
	print("Presentation checks: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
