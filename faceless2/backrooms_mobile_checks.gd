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
	var controls: Array[Control] = [game.ui.joystick,game.ui.sprint_button,game.ui.jump_button,game.ui.shoot_button,game.ui.aim_button,game.ui.reload_button,game.ui.pause_button]
	for extent in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(2560,1080)]:
		root.size = extent
		await process_frame
		game.ui._fit()
		for a in range(controls.size()):
			check(controls[a].is_visible_in_tree(),"Mobile action visible")
			var transform := controls[a].get_global_transform_with_canvas()
			var rect := Rect2(transform.origin,controls[a].size*transform.get_scale())
			check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(rect),"Action fits the horizontal viewport")
			for b in range(a+1,controls.size()): check(not rect.intersects(Rect2(controls[b].get_global_transform_with_canvas().origin,controls[b].size*controls[b].get_global_transform_with_canvas().get_scale())),"Mobile actions do not overlap")
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
	await create_timer(3.8).timeout
	game.ui.refresh()
	check(game.fps.magazine <= 5 and game.ui.fps_corner_hud.ammo_hint.text == "LOW AMMO","Real held shots trigger low-ammo HUD")
	await create_timer(1.0).timeout
	touch(7,point(game.ui.shoot_button),false)
	game.ui.refresh()
	check(game.fps.magazine == 0 and game.ui.fps_corner_hud.ammo_hint.text == "RELOAD / R","Actually emptied magazine triggers reload prompt")
	touch(0,joy,true)
	touch(3,point(game.ui.shoot_button),true)
	game.ui.open_pause()
	check(game.ui.modal and not game.ui.fire_held and game.ui.joystick.value == Vector2.ZERO,"Opening a menu cancels captured touches")
	game.ui.close_panels()
	check(game.ui.facility_hud_mode and game.ui.shoot_button.visible and not game.ui.light_button.visible,"Resume preserves FPS controls and hides legacy exploration controls")
	game.net.leave()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for sound in game.find_children("*",kind,true,false): sound.stop(); sound.set("stream",null)
	game.queue_free()
	for i in range(12): await process_frame
	if failed: quit(1)
	else:
		print("FPS_MOBILE_REAL_INPUT_PASS joystick/move/look/ADS/hold-fire/jump/reload, five fingers, release, menus and three aspect ratios")
		quit(0)
