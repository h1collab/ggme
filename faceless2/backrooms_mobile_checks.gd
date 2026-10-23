extends SceneTree
var game: Node3D
var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL: "+message)
func point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*.5)
func touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event,true)
func drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	root.push_input(event,true)
func run() -> void:
	root.size = Vector2i(1600,900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop()
	game.net.leave()
	game.ui.touch_preview = true
	game.start_fps_arena(0)
	for i in range(35): await physics_frame
	game.ui.refresh()
	check(game.ui.fps_corner_hud.stamina_bar.size.y <= 5 and game.ui.fps_corner_hud.reload_bar.size.y <= 5,"Actual themed status bars retain compact height after deferred layout")
	var skin: Control = game.ui.fps_corner_hud
	check(not skin.timer_card.visible and skin.map_text.text != "","Solo HUD shows one map/mode heading without a duplicate central title")
	check(skin.weapon_buttons[3].position.x+skin.weapon_buttons[3].size.x < game.ui.reload_button.position.x,"Compact weapon row leaves the right-hand action cluster clear")
	var layout_before: int = skin.static_layout_updates
	var paint_before: int = skin.weapon_presentation_updates
	for i in range(300): skin.refresh(0.0)
	check(skin.static_layout_updates == layout_before and skin.weapon_presentation_updates == paint_before,"Stable HUD avoids 300 repeated layout/style rebuilds")
	for button in skin.weapon_buttons:
		check(button.modulate == Color.WHITE and button.get_theme_color("font_color") == Color.WHITE,"All weapon names retain white text and full opacity")
		check(button.get_theme_color("font_disabled_color").r > .6 and is_equal_approx(button.get_theme_color("font_disabled_color").r,button.get_theme_color("font_disabled_color").b),"Disabled text retains readable grayscale contrast")
		check(button.has_method("set_selection"),"Weapon controls use original signal skin")
	check(not game.ui.theme.has_stylebox("normal","Label"),"Typography keeps transparent label backgrounds")
	check(game.ui.theme.get_icon("checked","CheckBox") != null,"Custom vector settings marks are installed")
	print("FPS_SIGNAL_INTERFACE_PASS monochrome typography, original vector skin, stable HUD cache")
	var controls: Array[Control] = [game.ui.joystick,game.ui.sprint_button,game.ui.jump_button,game.ui.shoot_button,game.ui.aim_button,game.ui.reload_button,game.ui.pause_button,game.ui.fps_corner_hud.view_button]
	for slot in game.ui.fps_corner_hud.weapon_buttons: controls.append(slot)
	for extent in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(2560,1080)]:
		root.size = extent
		await process_frame
		game.ui._fit()
		for a in range(controls.size()):
			check(controls[a].is_visible_in_tree(),"Mobile action visible")
			var transform := controls[a].get_global_transform_with_canvas()
			var rect := Rect2(transform.origin,controls[a].size*transform.get_scale())
			check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(rect),"Action fits the horizontal viewport")
			for b in range(a+1,controls.size()): check(not rect.intersects(Rect2(controls[b].get_global_transform_with_canvas().origin,controls[b].size*controls[b].get_global_transform_with_canvas().get_scale())),"Mobile actions do not overlap: %s / %s" % [controls[a].get("text"),controls[b].get("text")])
	root.size = Vector2i(1600,900)
	await process_frame
	game.ui._fit()
	# Actual imported SVG controls must retain their requested size, not
	# inherit the texture's 64px minimum and overlap neighboring labels.
	for picture in game.ui.fps_corner_hud.find_children("*","TextureRect",true,false):
		check(picture.size.x <= 77 and picture.size.y <= 42,"SVG controls use explicit bounded extents")
		for sibling in picture.get_parent().get_children():
			if sibling is Label: check(not picture.get_rect().intersects(sibling.get_rect()),"SVG and adjacent state text do not overlap")
	var start: Vector3 = game.player.position
	var ammo: int = game.fps.magazine
	var yaw: float = game.player.yaw
	var joy := point(game.ui.joystick)+Vector2(0,-70)
	touch(0,joy,true)
	check(game.ui.joystick.pointer_id == 0 and game.ui.joystick.value.y < -.5,"Viewport-routed joystick captures touch and forward input")
	touch(1,Vector2(950,440),true)
	drag(1,Vector2(990,440),Vector2(40,0))
	check(game.player.aim_pointer == 1 and absf(game.player.yaw-yaw) > .03,"Independent right-side touch changes actual camera yaw")
	touch(2,point(game.ui.aim_button),true)
	touch(3,point(game.ui.shoot_button),true)
	touch(4,point(game.ui.sprint_button),true)
	check(game.fps.aiming and game.ui.fire_held and game.ui.run_held,"Five simultaneous pointer IDs retain aim/fire/sprint/move/look")
	await create_timer(.65).timeout
	check(game.player.position.distance_to(start) > .5,"Actual CharacterBody moves from virtual joystick")
	check(game.fps.magazine <= ammo-2,"Holding FIRE creates repeated authoritative shots")
	var jumps: int = game.player.jump_count
	touch(5,point(game.ui.jump_button),true)
	for i in range(4): await physics_frame
	check(game.player.jump_count == jumps+1,"Touch-down JUMP triggers actual jump physics")
	touch(5,point(game.ui.jump_button),false)
	for index in range(5): touch(index,Vector2(1590,890),false)
	check(not game.ui.fire_held and not game.ui.run_held and not game.fps.aiming and game.player.aim_pointer == -1,"Release outside buttons clears all held actions")
	check(game.ui.joystick.value == Vector2.ZERO,"Joystick release outside rectangle stops movement input")
	game.ui.refresh()
	check(game.ui.fps_corner_hud.ammo_text.text == "%d / %d" % [game.fps.magazine,game.fps.reserve],"Ammo HUD follows real shots and authoritative reserve")
	check(game.ui.fps_corner_hud.health_text.text == str(game.fps.health),"Health icon is bound to actual HP")
	check(game.ui.shoot_button.icon != null and game.ui.jump_button.icon != null,"Original SVG touch icons are imported")
	var stock: int = game.fps.reserve
	touch(6,point(game.ui.reload_button),true)
	touch(6,point(game.ui.reload_button),false)
	check(game.fps.reload_time > 0.0,"Touch RELOAD starts host-timed reload")
	await create_timer(1.9).timeout
	check(game.fps.magazine == game.fps.MAGAZINE_CAPACITY and game.fps.reserve < stock,"Reload consumes reserve and refills after authoritative delay")
	touch(7,point(game.ui.shoot_button),true)
	var empty_deadline := Time.get_ticks_msec()+6500
	while game.fps.magazine > 4 and Time.get_ticks_msec() < empty_deadline: await create_timer(.04).timeout
	game.ui.refresh()
	check(game.fps.magazine <= 5 and game.ui.fps_corner_hud.ammo_hint.text == "LOW AMMO","Real held shots trigger low-ammo HUD")
	while game.fps.magazine > 0 and Time.get_ticks_msec() < empty_deadline: await create_timer(.04).timeout
	touch(7,point(game.ui.shoot_button),false)
	game.ui.refresh()
	check(game.fps.magazine == 0 and game.ui.fps_corner_hud.ammo_hint.text == "RELOAD / R","Actually emptied magazine triggers reload prompt")
	touch(0,joy,true)
	touch(3,point(game.ui.shoot_button),true)
	game.ui.open_pause()
	check(game.ui.modal and not game.ui.fire_held and game.ui.joystick.value == Vector2.ZERO,"Opening a menu cancels captured touches")
	game.ui.close_panels()
	check(game.ui.facility_hud_mode and game.ui.shoot_button.visible and not game.ui.light_button.visible,"Resume preserves FPS controls and hides legacy exploration controls")
	# Scoreboard button must respond to real viewport input and display real state.
	touch(9,point(game.ui.fps_corner_hud.score_toggle),true)
	touch(9,point(game.ui.fps_corner_hud.score_toggle),false)
	game.ui.refresh()
	check(game.ui.fps_corner_hud.scoreboard.visible and game.ui.fps_corner_hud.scoreboard_text.text.contains("P1"),"Touch scoreboard displays authenticated combat roster")
	touch(9,point(game.ui.fps_corner_hud.score_toggle),true)
	touch(9,point(game.ui.fps_corner_hud.score_toggle),false)
	# Actual viewport events exercise new camera and weapon controls too.
	touch(10,point(game.ui.fps_corner_hud.view_button),true)
	touch(10,point(game.ui.fps_corner_hud.view_button),false)
	check(game.player.third_person,"Touch toggles actual third-person camera")
	for i in range(4): await physics_frame
	check(not game.fps.weapon_pivot.visible,"Third person hides duplicate camera rifle")
	touch(10,point(game.ui.fps_corner_hud.view_button),true)
	touch(10,point(game.ui.fps_corner_hud.view_button),false)
	check(not game.player.third_person,"Second camera press restores first person")
	touch(11,point(game.ui.fps_corner_hud.weapon_buttons[1]),true)
	touch(11,point(game.ui.fps_corner_hud.weapon_buttons[1]),false)
	check(game.fps.selected_weapon == 1,"Touch selects real sidearm inventory")
	await create_timer(.3).timeout
	touch(11,point(game.ui.fps_corner_hud.weapon_buttons[0]),true)
	touch(11,point(game.ui.fps_corner_hud.weapon_buttons[0]),false)
	check(game.fps.selected_weapon == 0 and game.fps.magazine == 0,"Touch cycling cannot refill the emptied rifle")
	# Measure actual accelerated CharacterBody velocity, not assigned constants.
	game.ui.touch_preview = false
	game.player.reset_to(Vector3(0,.12,0))
	game.player.yaw = 0
	game.player.rotation.y = 0
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(.7).timeout
	check(absf(Vector2(game.player.velocity.x,game.player.velocity.z).length()-3.8) < .1,"Actual FPS walking reaches 3.8m/s")
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift)
	await create_timer(.5).timeout
	check(absf(Vector2(game.player.velocity.x,game.player.velocity.z).length()-6.2) < .1,"Actual FPS sprint reaches 6.2m/s")
	game.player.stamina = 4.8
	await create_timer(.25).timeout
	check(not game.player.sprinting and game.player.stamina > 6.0,"Exhausted sprint recovers continuously without rapid speed toggling")
	game.player.stamina = 26.0
	await create_timer(.1).timeout
	check(game.player.sprinting,"Sprint resumes only after a useful stamina recovery")
	key.pressed = false
	shift.pressed = false
	Input.parse_input_event(key)
	Input.parse_input_event(shift)
	game.fps.reload()
	await create_timer(1.9).timeout
	var before: int = game.fps.magazine
	func_mouse(true)
	func_mouse(false)
	await create_timer(.045).timeout
	func_mouse(true)
	func_mouse(false)
	await create_timer(.18).timeout
	check(game.fps.magazine == before-2,"Real rapid mouse taps retain a shot across cooldown")
	game.player.request_fire()
	game.ui.open_pause()
	await create_timer(.2).timeout
	check(game.player.trigger_buffer == 0.0,"Menu opening cancels a buffered trigger")
	print("FPS_RESPONSIVE_HANDLING_PASS walk=3.8 sprint=6.2 cadence=120ms tap-buffer scoreboard")
	game.net.leave()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for sound in game.find_children("*",kind,true,false): sound.stop(); sound.set("stream",null)
	game.queue_free()
	for i in range(12): await process_frame
	if failed: quit(1)
	else:
		print("FPS_MOBILE_REAL_INPUT_PASS joystick/move/look/ADS/hold-fire/jump/reload, five fingers, release, menus and three aspect ratios")
		quit(0)

func func_mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(800,450)
	root.push_input(event,true)
