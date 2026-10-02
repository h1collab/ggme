extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const TeacherScript = preload("res://scripts/stalker.gd")
const VirtualJoystickScript = preload("res://scripts/virtual_joystick.gd")

var player: CharacterBody3D
var teachers: Array[CharacterBody3D] = []
var wave := 1
var score := 0
var combo := 0
var combo_timer := 0.0
var hud: Label
var notice: Label
var objective_label: Label
var tutorial_card: ColorRect
var main_menu: ColorRect
var settings_panel: ColorRect
var overlay: ColorRect
var joystick: Control
var game_started := false
var settings := {"quality":2,"fps":60,"volume":0.85,"show_tutorial":true}
var spawn_points: Array[Vector3] = [
	Vector3(-13,0.9,-8),Vector3(13,0.9,-8),Vector3(-13,0.9,8),
	Vector3(13,0.9,8),Vector3(0,0.9,-10),Vector3(0,0.9,10)
]

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	_build_world()
	_build_ui()
	_apply_settings()
	get_tree().paused = true

func _process(delta: float) -> void:
	if not game_started:
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo = 0
	if teachers.is_empty():
		wave += 1
		_spawn_wave()
		_update_objective()
		_show_notice("WAVE %d" % wave)

func _mat(c: Color, rough:=0.85, metal:=0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _mesh_box(parent: Node, pos: Vector3, size3: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size3
	mi.mesh = b
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)

func _static_box(pos: Vector3, size3: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size3
	cs.shape = sh
	body.add_child(cs)

func _spawn_asset(path: String, pos: Vector3, rot_y: float = 0.0, scale3: Vector3 = Vector3.ONE) -> Node3D:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	if inst is Node3D:
		var n := inst as Node3D
		n.position = pos
		n.rotation.y = rot_y
		n.scale = scale3
		add_child(n)
		return n
	return null

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055,0.085,0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52,0.60,0.72)
	env.ambient_light_energy = 0.58
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

	# Visual architecture is a reconstructed GLB rather than runtime box geometry.
	_spawn_asset("res://assets/classroom_shell_sketchfab_rebuild.glb", Vector3.ZERO)

	# Invisible collision shell.
	_static_box(Vector3(0,-0.25,0),Vector3(34,0.5,26),_mat(Color.WHITE))
	_static_box(Vector3(-17,1.6,0),Vector3(0.45,3.2,26),_mat(Color.WHITE))
	_static_box(Vector3(17,1.6,0),Vector3(0.45,3.2,26),_mat(Color.WHITE))
	_static_box(Vector3(0,1.6,-13),Vector3(34,3.2,0.45),_mat(Color.WHITE))
	_static_box(Vector3(0,1.6,13),Vector3(34,3.2,0.45),_mat(Color.WHITE))

	# High-detail classroom furniture.
	for row in [-4.5,0.2,4.9]:
		for col in [-9.0,-3.0,3.0,9.0]:
			_spawn_desk(Vector3(col,0,row),PI)
	for x in [-8.5,-2.8,2.8,8.5]:
		_spawn_desk(Vector3(x,0,-10.0),0.0)

	_spawn_asset("res://assets/teacher_desk_sketchfab_rebuild.glb",Vector3(0,0,-10.8),0.0)
	_spawn_asset("res://assets/blackboard_sketchfab_rebuild.glb",Vector3(0,0,-12.45),0.0,Vector3(1.6,1.0,1.0))
	_spawn_asset("res://assets/lockers_sketchfab_rebuild.glb",Vector3(-15.7,0,-7.5),PI/2.0)
	_spawn_asset("res://assets/lockers_sketchfab_rebuild.glb",Vector3(-15.7,0,-4.9),PI/2.0)
	_spawn_asset("res://assets/classroom_cabinet_sketchfab_rebuild.glb",Vector3(14.8,0,-8.7),-PI/2.0)
	_spawn_asset("res://assets/trash_can_sketchfab_rebuild.glb",Vector3(14.4,0,-6.8))
	_spawn_asset("res://assets/wall_clock_sketchfab_rebuild.glb",Vector3(5.0,2.35,-12.45))
	_spawn_asset("res://assets/school_backpack_sketchfab_rebuild.glb",Vector3(-7.7,0.0,1.0),0.35,Vector3(0.85,0.85,0.85))
	_spawn_asset("res://assets/school_backpack_sketchfab_rebuild.glb",Vector3(4.0,0.0,5.7),-0.6,Vector3(0.8,0.8,0.8))
	_spawn_asset("res://assets/book_stack_sketchfab_rebuild.glb",Vector3(-2.6,0.78,-10.2),0.2)
	_spawn_asset("res://assets/book_stack_sketchfab_rebuild.glb",Vector3(8.6,0.78,-10.1),-0.15)

	# Doors and windows.
	_spawn_asset("res://assets/classroom_door_sketchfab_rebuild.glb",Vector3(14.6,0,-12.45),0.0)
	_spawn_asset("res://assets/classroom_door_sketchfab_rebuild.glb",Vector3(-14.6,0,12.45),PI)
	for x in [-12,-8,-4,0,4,8,12]:
		_spawn_asset("res://assets/school_window_sketchfab_rebuild.glb",Vector3(x,1.0,12.42),PI)

	# Light fixtures are modeled GLBs; OmniLight3D supplies actual illumination.
	for x in [-13,-9,-5,-1,3,7,11]:
		_spawn_asset("res://assets/fluorescent_light_sketchfab_rebuild.glb",Vector3(x,3.05,0))
		var l := OmniLight3D.new()
		l.position = Vector3(x,2.72,0)
		l.omni_range = 8.5
		l.light_energy = 1.55
		l.light_color = Color(0.96,0.98,1.0)
		add_child(l)

func _spawn_desk(pos: Vector3, rot_y: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.6,1.1,1.4)
	cs.shape = sh
	cs.position = Vector3(0,0.55,0)
	body.add_child(cs)
	var packed: PackedScene = load("res://assets/student_desk_sketchfab_rebuild.glb")
	if packed != null:
		var inst := packed.instantiate()
		body.add_child(inst)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	overlay = ColorRect.new()
	overlay.color = Color(0.05,0.07,0.10,0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)

	hud = Label.new()
	hud.position = Vector2(28,22)
	hud.size = Vector2(980,48)
	hud.add_theme_font_size_override("font_size",24)
	layer.add_child(hud)

	objective_label = Label.new()
	objective_label.position = Vector2(28,56)
	objective_label.size = Vector2(980,32)
	objective_label.add_theme_font_size_override("font_size",18)
	objective_label.modulate = Color(0.78,0.86,0.94)
	layer.add_child(objective_label)

	notice = Label.new()
	notice.position = Vector2(360,92)
	notice.size = Vector2(920,70)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size",34)
	layer.add_child(notice)

	joystick = Control.new()
	joystick.set_script(VirtualJoystickScript)
	joystick.position = Vector2(40,650)
	joystick.size = Vector2(190,190)
	layer.add_child(joystick)

	var hit := Button.new()
	hit.text = "HIT"
	hit.position = Vector2(1390,700)
	hit.size = Vector2(150,74)
	hit.add_theme_font_size_override("font_size",26)
	hit.pressed.connect(func():
		if player: player.attack(1.0)
	)
	layer.add_child(hit)

	var kick := Button.new()
	kick.text = "KICK"
	kick.position = Vector2(1218,748)
	kick.size = Vector2(150,74)
	kick.add_theme_font_size_override("font_size",24)
	kick.pressed.connect(func():
		if player: player.attack(1.7)
	)
	layer.add_child(kick)

	tutorial_card = _panel(Vector2(36,430),Vector2(430,205),Color(0.03,0.05,0.08,0.86))
	var tut := Label.new()
	tut.position = Vector2(18,16)
	tut.size = Vector2(395,175)
	tut.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut.add_theme_font_size_override("font_size",17)
	tut.text = "HOW TO PLAY\n• Left joystick: move\n• Right side drag: look\n• HIT: fast attack, low stamina cost\n• KICK: heavy attack, stronger knockback\n• Defeat every teacher NPC in the wave\n• New waves start automatically\n• Build combos for more score"
	tutorial_card.add_child(tut)
	layer.add_child(tutorial_card)

	main_menu = _panel(Vector2(420,120),Vector2(760,620),Color(0.025,0.035,0.055,0.95))
	layer.add_child(main_menu)
	var title := Label.new()
	title.text = "SCHOOL BRAWL"
	title.position = Vector2(46,38)
	title.size = Vector2(660,72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",54)
	main_menu.add_child(title)
	var sub := Label.new()
	sub.text = "CLASSROOM ARCADE FIGHT"
	sub.position = Vector2(46,105)
	sub.size = Vector2(660,36)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size",20)
	sub.modulate = Color(0.65,0.74,0.86)
	main_menu.add_child(sub)
	var by := Label.new()
	by.text = "made by zorix"
	by.position = Vector2(46,145)
	by.size = Vector2(660,34)
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	by.modulate = Color(0.84,0.62,0.96)
	main_menu.add_child(by)

	var play := _menu_button("PLAY",Vector2(180,220),Vector2(400,62))
	play.pressed.connect(_start_game)
	main_menu.add_child(play)
	var settings_btn := _menu_button("SETTINGS",Vector2(180,296),Vector2(400,62))
	settings_btn.pressed.connect(func():
		main_menu.visible = false
		settings_panel.visible = true
	)
	main_menu.add_child(settings_btn)

	var info := Label.new()
	info.position = Vector2(86,390)
	info.size = Vector2(590,160)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size",20)
	info.text = "GAMEPLAY\nClear waves of fictional teacher NPCs in the school arena. Use HIT for quick combo pressure and KICK for bigger damage and knockback. Keep moving, manage stamina, and survive as waves get harder."
	info.modulate = Color(0.80,0.84,0.90)
	main_menu.add_child(info)

	settings_panel = _build_settings_panel()
	layer.add_child(settings_panel)
	settings_panel.visible = false

func _build_settings_panel() -> ColorRect:
	var p := _panel(Vector2(470,150),Vector2(660,560),Color(0.025,0.035,0.055,0.97))
	var title := Label.new()
	title.text = "SETTINGS"
	title.position = Vector2(35,28)
	title.add_theme_font_size_override("font_size",36)
	p.add_child(title)

	var ql := Label.new()
	ql.text = "QUALITY"
	ql.position = Vector2(45,105)
	p.add_child(ql)
	var q := OptionButton.new()
	q.position = Vector2(300,95)
	q.size = Vector2(300,50)
	for t in ["PERFORMANCE","BALANCED","HIGH QUALITY","ULTRA"]:
		q.add_item(t)
	q.select(settings["quality"])
	q.item_selected.connect(func(i):
		settings["quality"] = i
		_apply_settings()
	)
	p.add_child(q)

	var fl := Label.new()
	fl.text = "FPS LIMIT"
	fl.position = Vector2(45,175)
	p.add_child(fl)
	var fps := OptionButton.new()
	fps.position = Vector2(300,165)
	fps.size = Vector2(300,50)
	for t in ["30","60","120"]:
		fps.add_item(t)
	fps.select(1)
	fps.item_selected.connect(func(i):
		settings["fps"] = [30,60,120][i]
		_apply_settings()
	)
	p.add_child(fps)

	var vl := Label.new()
	vl.text = "MASTER VOLUME"
	vl.position = Vector2(45,245)
	p.add_child(vl)
	var v := HSlider.new()
	v.position = Vector2(300,235)
	v.size = Vector2(300,40)
	v.min_value = 0.0
	v.max_value = 1.0
	v.step = 0.05
	v.value = settings["volume"]
	v.value_changed.connect(func(x):
		settings["volume"] = x
		AudioServer.set_bus_volume_db(0,linear_to_db(max(x,0.001)))
	)
	p.add_child(v)

	var tl := Label.new()
	tl.text = "TUTORIAL CARD"
	tl.position = Vector2(45,315)
	p.add_child(tl)
	var tog := CheckButton.new()
	tog.text = "SHOW"
	tog.position = Vector2(300,305)
	tog.button_pressed = settings["show_tutorial"]
	tog.toggled.connect(func(on):
		settings["show_tutorial"] = on
		tutorial_card.visible = on and game_started
	)
	p.add_child(tog)

	var back := _menu_button("BACK",Vector2(180,435),Vector2(300,60))
	back.pressed.connect(func():
		settings_panel.visible = false
		main_menu.visible = true
	)
	p.add_child(back)
	return p

func _panel(pos: Vector2, sz: Vector2, c: Color) -> ColorRect:
	var p := ColorRect.new()
	p.position = pos
	p.size = sz
	p.color = c
	return p

func _menu_button(text_value: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text_value
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size",24)
	return b

func _apply_settings() -> void:
	Engine.max_fps = int(settings["fps"])
	var q := int(settings["quality"])
	get_viewport().scaling_3d_scale = [0.65,0.82,1.0,1.15][q]
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_4X][q]
	if tutorial_card:
		tutorial_card.visible = bool(settings["show_tutorial"]) and game_started

func _start_game() -> void:
	main_menu.visible = false
	settings_panel.visible = false
	get_tree().paused = false
	game_started = true
	_spawn_player()
	_spawn_wave()
	_update_objective()
	_show_notice("WAVE 1")
	tutorial_card.visible = bool(settings["show_tutorial"])

func _spawn_player() -> void:
	if player: return
	player = CharacterBody3D.new()
	player.position = Vector3(0,0.9,10.0)
	player.set_script(PlayerScript)
	player.game = self
	add_child(player)
	player.joystick = joystick

func _spawn_wave() -> void:
	var count := mini(2 + wave,8)
	for i in range(count):
		var t := CharacterBody3D.new()
		t.position = spawn_points[i % spawn_points.size()]
		t.set_script(TeacherScript)
		t.game = self
		t.player = player
		t.hp = 70.0 + wave * 9.0
		t.move_speed = minf(2.5 + wave * 0.12,4.2)
		add_child(t)
		teachers.append(t)

func player_melee_attack(power: float) -> void:
	if not player: return
	var best: CharacterBody3D
	var best_d := 2.35
	for t in teachers:
		if not is_instance_valid(t): continue
		var to_t := t.global_position - player.global_position
		var d := to_t.length()
		if d < best_d:
			var facing := -player.global_transform.basis.z
			if facing.dot(to_t.normalized()) > 0.30:
				best = t
				best_d = d
	if best:
		var dir := (best.global_position - player.global_position).normalized()
		best.take_hit(24.0 * power,dir * (5.0 + power * 2.0))
		combo += 1
		combo_timer = 2.4
		score += int(100.0 * power * maxi(1,combo))
		_show_notice("COMBO x%d" % combo)
	else:
		_show_notice("MISS")

func teacher_ko(t: CharacterBody3D) -> void:
	teachers.erase(t)
	score += 500
	var tw := create_tween()
	tw.tween_property(t,"rotation:z",1.45,0.28)
	tw.parallel().tween_property(t,"position:y",0.25,0.28)
	tw.tween_interval(0.35)
	tw.tween_callback(t.queue_free)
	_update_objective()
	_show_notice("K.O. +500")

func player_hurt() -> void:
	overlay.color = Color(0.55,0.03,0.03,0.28)
	create_tween().tween_property(overlay,"color",Color(0.05,0.07,0.10,0.0),0.25)

func player_knocked_out() -> void:
	game_started = false
	_show_notice("KNOCKED OUT")
	for t in teachers:
		if is_instance_valid(t): t.queue_free()
	teachers.clear()
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(_restart_round)

func _restart_round() -> void:
	player.global_position = Vector3(0,0.9,10.0)
	player.restore()
	wave = 1
	score = 0
	combo = 0
	game_started = true
	_spawn_wave()
	_update_objective()
	_show_notice("ROUND RESTART")

func update_player_hud(h: float, s: float) -> void:
	if hud:
		hud.text = "HEALTH %03d   STAMINA %03d   SCORE %06d   WAVE %02d" % [int(h),int(s),score,wave]

func _update_objective() -> void:
	if not objective_label: return
	objective_label.text = "Objective: defeat all teacher NPCs in this wave. Remaining: %d" % teachers.size()

func _show_notice(t: String) -> void:
	if not notice: return
	notice.text = t
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func():
		if notice.text == t: notice.text = ""
	)
