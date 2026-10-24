extends SceneTree
var failed := false
func _initialize() -> void:call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value:failed = true;push_error("FAIL: "+label)
func check_brand(parent: Node) -> void:
	var logo: TextureRect = parent.get_node_or_null("ZOrixLogo")
	var credit: Label = parent.get_node_or_null("DeveloperCredit")
	check(logo != null and logo.texture != null and logo.material != null,"Original ZOrix logo is visible through the grayscale material")
	check(credit != null and credit.text == "Developed by ZOrix","Explicit developer credit is displayed")
func run() -> void:
	root.size = Vector2i(1600,900)
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot)
	check_brand(boot.canvas)
	var deadline := Time.get_ticks_msec()+90000
	while (current_scene == null or not current_scene.get("initialized")) and not boot.failed and Time.get_ticks_msec() < deadline:await process_frame
	check(current_scene != null and not boot.failed,"Threaded startup reaches a real initialized game")
	if current_scene == null:quit(1);return
	var game: Node3D = current_scene
	var samples: Array = game.get_meta("boot_progress",[])
	check(samples.size() > 6 and float(samples.back()) == 100.0 and game.get_meta("boot_stages",0) == 6,"Launch progress includes resources and all six actual initialization stages")
	for i in range(1,samples.size()):check(float(samples[i]) >= float(samples[i-1]),"Progress never runs backwards")
	check(game.ui.panel_kind == "menu" and game.ui.intro_timer.is_stopped(),"Loading hands off to the lobby without the duplicate timed splash")
	await create_timer(.35).timeout
	check(not is_instance_valid(boot),"Loader releases its layer and retained resources after handoff")
	var probe = load("res://scripts/backrooms.gd").new();check(probe.language == "en","A fresh game defaults to English");probe.free()
	for language in ["en","zh"]:
		game.language = language
		game.ui.open_settings()
		check_brand(game.ui.panels)
		var found := false
		for label in game.ui.panels.find_children("*","Label",true,false):
			if label.text.contains("NULRYTH") and label.text.contains("Faceless 2"):found = true
		check(found,"Settings names NULRYTH and its previous title in both languages")
		for page in [0,8]:
			game.ui.season_page = page;game.ui.open_season()
			var cards := 0
			for panel in game.ui.panels.get_children():
				if not panel.name.begins_with("Tier"):continue
				cards += 1
				for child in panel.get_children():
					if child is Control:check(Rect2(Vector2.ZERO,panel.size).encloses(child.get_rect()),"Reward labels and actions stay within their card")
			check(cards == 10,"Manual pages 1 and 45 retain both five-level tracks")
	check(game.rooms.room_name == "NULRYTH","Default public room branding uses the new title")
	var original_profile = game.season
	game.season = preload("backrooms_season.gd").new()
	game.season.profile_path = "user://nulryth_claim_check.cfg"
	game.ui.season_page = 0;game.ui.open_season();await process_frame
	var claim: Button = game.ui.panels.get_node("Tier01Free/Claim")
	var at: Vector2 = claim.get_global_transform_with_canvas()*(claim.size*.5)
	for pressed in [true,false]:
		var touch := InputEventScreenTouch.new();touch.index = 0;touch.position = at;touch.pressed = pressed;root.push_input(touch,true)
	await process_frame
	check(game.season.tokens == 55 and game.season.claimed.has(1),"Real viewport touch claims the available FREE reward")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.season.profile_path))
	game.season = original_profile
	game.interface_motion = false;game.ui.menu()
	check_brand(game.ui.panels)
	var art: Control = game.ui.panels.get_node("SignalAtlas")
	var before: float = art.phase
	art._process(.5)
	check(art.phase == before,"Disabled interface motion stops decorative animation")
	for extent in [Vector2i(1280,720),Vector2i(2560,1080)]:
		root.size = extent;await process_frame;game.ui._fit()
		for control in game.ui.panels.get_children():
			if control is Button:
				var t: Transform2D = control.get_global_transform_with_canvas()
				check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(Rect2(t.origin,control.size*t.get_scale())),"Lobby actions fit widescreen safe layout")
	game.net.leave();game.queue_free();game = null
	await create_timer(.3).timeout
	if not failed:print("NULRYTH_BOOT_UI_PASS real resource/stage progress, English default, legacy settings label, grayscale manual bounds and motion toggle")
	quit(1 if failed else 0)
