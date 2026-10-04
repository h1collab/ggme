extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/faceless.gd")
const JoystickScript = preload("res://scripts/virtual_joystick.gd")

var player: CharacterBody3D
var enemy: CharacterBody3D
var joystick: Control
var hud: Label
var objective_label: Label
var prompt_label: Label
var notice: Label
var fade: ColorRect
var main_menu: Control
var mode_panel: Control
var settings_panel: Control
var archive_panel: Control
var game_started := false
var selected_mode := "STORY"
var relays: Array[Node3D] = []
var relay_active: Array[bool] = []
var evidence_nodes: Array[Node3D] = []
var evidence_collected := 0
var terminal: Node3D
var extraction_gate: Node3D
var camera_terminal_open := false
var ambience_player: AudioStreamPlayer
var static_player: AudioStreamPlayer
var current_zone := "BLACKWOOD CHECKPOINT"
var settings := {
	"quality": 2,
	"fps": 60,
	"fov": 74.0,
	"sensitivity": 1.0,
	"brightness": 1.0,
	"volume": 0.85,
	"language": 0
}

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	_build_world()
	_build_ui()
	_build_audio()
	_apply_settings()
	get_tree().paused = true

func _process(_delta: float) -> void:
	if not game_started or player == null:
		return
	_update_nearby_prompt()
	_update_zone()

func get_look_sensitivity() -> float:
	return float(settings["sensitivity"])

func _mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _static_box(pos: Vector3, size3: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size3
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size3
	cs.shape = sh
	body.add_child(cs)

func _spawn_asset(path: String, pos: Vector3, rot_y := 0.0, scale3 := Vector3.ONE) -> Node3D:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst := packed.instantiate()
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
	env.background_color = Color(0.015,0.025,0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16,0.22,0.28)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.10,0.14,0.16)
	env.fog_density = 0.022
	env.fog_height = 0.0
	env.fog_height_density = 0.19
	world.environment = env
	add_child(world)

	# Invisible terrain collision + visible GLB road/forest set.
	_static_box(Vector3(0,-0.35,-40),Vector3(18,0.7,130),_mat(Color(0.06,0.06,0.065)))
	_spawn_asset("res://assets/blackwood_road.glb",Vector3(0,0,-40))
	_spawn_asset("res://assets/checkpoint_gate.glb",Vector3(0,0,8))
	_spawn_asset("res://assets/surveillance_tower.glb",Vector3(-7,0,-18),0.2)
	_spawn_asset("res://assets/abandoned_bus_stop.glb",Vector3(6.5,0,-40),PI)
	_spawn_asset("res://assets/ranger_cabin.glb",Vector3(-7.0,0,-67),0.15)
	_spawn_asset("res://assets/dead_zone_fence.glb",Vector3(0,0,-91),0.0)

	for z in range(6,-101,-8):
		_spawn_asset("res://assets/pine_cluster.glb",Vector3(-11.5,0,float(z)),0.15*float(z))
		_spawn_asset("res://assets/pine_cluster.glb",Vector3(11.5,0,float(z)+2.0),-0.11*float(z))

	relay_active = [false,false,false]
	var relay_positions := [Vector3(5.8,0,-12),Vector3(-6.2,0,-51),Vector3(5.5,0,-82)]
	for i in range(3):
		var r := _spawn_asset("res://assets/power_relay.glb",relay_positions[i],0.0)
		if r != null:
			r.set_meta("relay_index",i)
			relays.append(r)

	var evidence_positions := [Vector3(-4.8,0.65,-28),Vector3(5.7,0.65,-63),Vector3(-5.8,0.65,-88)]
	for i in range(3):
		var e := _spawn_asset("res://assets/evidence_case.glb",evidence_positions[i],0.2*float(i))
		if e != null:
			e.set_meta("evidence_index",i)
			evidence_nodes.append(e)

	terminal = _spawn_asset("res://assets/security_terminal.glb",Vector3(-6.2,0,-19),0.3)
	extraction_gate = _spawn_asset("res://assets/extraction_gate.glb",Vector3(0,0,-103),0.0)

	for z in [3,-22,-46,-72,-95]:
		var light := OmniLight3D.new()
		light.position = Vector3(0,3.4,float(z))
		light.omni_range = 11.0
		light.light_energy = 0.65
		light.light_color = Color(0.55,0.72,0.78)
		add_child(light)

func _build_audio() -> void:
	ambience_player = AudioStreamPlayer.new()
	ambience_player.stream = load("res://audio/blackwood_ambience.wav")
	ambience_player.volume_db = -9.0
	ambience_player.finished.connect(func():
		if game_started:
			ambience_player.play()
	)
	add_child(ambience_player)
	static_player = AudioStreamPlayer.new()
	static_player.stream = load("res://audio/signal_static.wav")
	static_player.volume_db = -5.0
	add_child(static_player)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	fade = ColorRect.new()
	fade.color = Color(0.05,0.0,0.0,0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)

	hud = Label.new()
	hud.position = Vector2(24,18)
	hud.size = Vector2(1200,42)
	hud.add_theme_font_size_override("font_size",21)
	layer.add_child(hud)

	objective_label = Label.new()
	objective_label.position = Vector2(24,54)
	objective_label.size = Vector2(1180,60)
	objective_label.add_theme_font_size_override("font_size",17)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.modulate = Color(0.68,0.82,0.86)
	layer.add_child(objective_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(470,690)
	prompt_label.size = Vector2(660,50)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size",20)
	prompt_label.modulate = Color(0.86,0.92,0.94)
	layer.add_child(prompt_label)

	notice = Label.new()
	notice.position = Vector2(350,120)
	notice.size = Vector2(900,68)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size",32)
	layer.add_child(notice)

	joystick = Control.new()
	joystick.set_script(JoystickScript)
	joystick.position = Vector2(38,650)
	joystick.size = Vector2(190,190)
	layer.add_child(joystick)

	var interact := _action_button("INTERACT",Vector2(1330,690),Vector2(190,70))
	interact.pressed.connect(_interact)
	layer.add_child(interact)

	var flashlight_btn := _action_button("LIGHT",Vector2(1370,610),Vector2(150,62))
	flashlight_btn.pressed.connect(func():
		if player: player.toggle_flashlight()
	)
	layer.add_child(flashlight_btn)

	var crouch_btn := _action_button("CROUCH",Vector2(1195,755),Vector2(160,62))
	crouch_btn.pressed.connect(func():
		if player: player.toggle_crouch()
	)
	layer.add_child(crouch_btn)

	var run_btn := _action_button("RUN",Vector2(1195,675),Vector2(120,62))
	run_btn.button_down.connect(func():
		if player: player.set_running(true)
	)
	run_btn.button_up.connect(func():
		if player: player.set_running(false)
	)
	layer.add_child(run_btn)

	main_menu = _build_main_menu()
	layer.add_child(main_menu)
	mode_panel = _build_mode_panel()
	layer.add_child(mode_panel)
	mode_panel.visible = false
	settings_panel = _build_settings_panel()
	layer.add_child(settings_panel)
	settings_panel.visible = false
	archive_panel = _build_archive_panel()
	layer.add_child(archive_panel)
	archive_panel.visible = false

func _build_main_menu() -> Control:
	var root := ColorRect.new()
	root.position = Vector2(180,110)
	root.size = Vector2(1240,690)
	root.color = Color(0.005,0.01,0.015,0.96)

	var title := Label.new()
	title.text = "FACELESS 2"
	title.position = Vector2(80,44)
	title.size = Vector2(500,74)
	title.add_theme_font_size_override("font_size",58)
	title.modulate = Color(0.82,0.07,0.08)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "THE CAMERAS REMEMBER WHAT YOU FORGOT"
	subtitle.position = Vector2(85,114)
	subtitle.size = Vector2(680,34)
	subtitle.add_theme_font_size_override("font_size",18)
	subtitle.modulate = Color(0.34,0.68,0.72)
	root.add_child(subtitle)

	var by := Label.new()
	by.text = "made by zorix"
	by.position = Vector2(85,154)
	by.size = Vector2(460,30)
	by.modulate = Color(0.64,0.64,0.68)
	root.add_child(by)

	var continue_btn := _menu_button("CONTINUE",Vector2(90,240),Vector2(390,54))
	continue_btn.pressed.connect(_continue_game)
	root.add_child(continue_btn)
	var new_btn := _menu_button("NEW GAME",Vector2(90,306),Vector2(390,54))
	new_btn.pressed.connect(func():
		root.visible = false
		mode_panel.visible = true
	)
	root.add_child(new_btn)
	var mode_btn := _menu_button("GAME MODES",Vector2(90,372),Vector2(390,54))
	mode_btn.pressed.connect(func():
		root.visible = false
		mode_panel.visible = true
	)
	root.add_child(mode_btn)
	var settings_btn := _menu_button("SETTINGS",Vector2(90,438),Vector2(390,54))
	settings_btn.pressed.connect(func():
		root.visible = false
		settings_panel.visible = true
	)
	root.add_child(settings_btn)
	var archive_btn := _menu_button("ARCHIVE",Vector2(90,504),Vector2(390,54))
	archive_btn.pressed.connect(func():
		root.visible = false
		archive_panel.visible = true
	)
	root.add_child(archive_btn)

	var side := ColorRect.new()
	side.position = Vector2(610,170)
	side.size = Vector2(540,400)
	side.color = Color(0.02,0.06,0.07,0.72)
	root.add_child(side)
	var side_text := Label.new()
	side_text.position = Vector2(28,26)
	side_text.size = Vector2(485,340)
	side_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_text.add_theme_font_size_override("font_size",20)
	side_text.text = "CASE ZRX-BW/0217\n\nBLACKWOOD REOPENED\n\nThree power relays have come back online by themselves. Every camera shows the same figure — always one frame behind you.\n\nRecover the three relay logs, collect evidence, use the surveillance terminal, and reach the dead-zone gate before the feed learns your route."
	side.add_child(side_text)
	return root

func _build_mode_panel() -> Control:
	var p := _panel(Vector2(430,150),Vector2(740,590),Color(0.005,0.01,0.015,0.97))
	var title := Label.new()
	title.text = "CHOOSE YOUR NIGHT"
	title.position = Vector2(50,34)
	title.size = Vector2(640,50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",34)
	p.add_child(title)
	var modes := [
		["STORY","Five-zone narrative campaign."],
		["RUSH","Short route, faster enemy."],
		["NIGHTMARE","Extreme aggression and scarce battery."],
		["ENDLESS","Increasing relay cycles."],
		["EXPLORATION","No active hunter."],
		["BLACKOUT","Low battery and unstable lighting."]
	]
	for i in range(modes.size()):
		var b := _menu_button(modes[i][0]+" — "+modes[i][1],Vector2(95,110+i*62),Vector2(550,50))
		var mode_name: String = modes[i][0]
		b.pressed.connect(func():
			selected_mode = mode_name
			_start_new_game()
		)
		p.add_child(b)
	var back := _menu_button("BACK",Vector2(220,500),Vector2(300,48))
	back.pressed.connect(func():
		p.visible = false
		main_menu.visible = true
	)
	p.add_child(back)
	return p

func _build_settings_panel() -> Control:
	var p := _panel(Vector2(455,145),Vector2(690,600),Color(0.005,0.01,0.015,0.97))
	var title := Label.new()
	title.text = "SETTINGS"
	title.position = Vector2(42,30)
	title.add_theme_font_size_override("font_size",36)
	p.add_child(title)

	var quality := OptionButton.new()
	quality.position = Vector2(320,100)
	quality.size = Vector2(290,48)
	for t in ["PERFORMANCE","BALANCED","HIGH","ULTRA"]: quality.add_item(t)
	quality.select(settings["quality"])
	quality.item_selected.connect(func(i):
		settings["quality"] = i
		_apply_settings()
	)
	p.add_child(_setting_label("QUALITY",Vector2(52,112)))
	p.add_child(quality)

	var fps := OptionButton.new()
	fps.position = Vector2(320,165)
	fps.size = Vector2(290,48)
	for t in ["30 FPS","60 FPS","120 FPS"]: fps.add_item(t)
	fps.select(1)
	fps.item_selected.connect(func(i):
		settings["fps"] = [30,60,120][i]
		_apply_settings()
	)
	p.add_child(_setting_label("FPS LIMIT",Vector2(52,177)))
	p.add_child(fps)

	var fov := HSlider.new()
	fov.position = Vector2(320,230)
	fov.size = Vector2(290,42)
	fov.min_value = 60
	fov.max_value = 95
	fov.value = settings["fov"]
	fov.value_changed.connect(func(v):
		settings["fov"] = v
		if player and player.camera: player.camera.fov = v
	)
	p.add_child(_setting_label("FIELD OF VIEW",Vector2(52,242)))
	p.add_child(fov)

	var sens := HSlider.new()
	sens.position = Vector2(320,295)
	sens.size = Vector2(290,42)
	sens.min_value = 0.5
	sens.max_value = 2.0
	sens.step = 0.05
	sens.value = settings["sensitivity"]
	sens.value_changed.connect(func(v): settings["sensitivity"] = v)
	p.add_child(_setting_label("LOOK SENSITIVITY",Vector2(52,307)))
	p.add_child(sens)

	var volume := HSlider.new()
	volume.position = Vector2(320,360)
	volume.size = Vector2(290,42)
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = settings["volume"]
	volume.value_changed.connect(func(v):
		settings["volume"] = v
		AudioServer.set_bus_volume_db(0,linear_to_db(max(v,0.001)))
	)
	p.add_child(_setting_label("MASTER VOLUME",Vector2(52,372)))
	p.add_child(volume)

	var back := _menu_button("BACK",Vector2(195,490),Vector2(300,54))
	back.pressed.connect(func():
		p.visible = false
		main_menu.visible = true
	)
	p.add_child(back)
	return p

func _build_archive_panel() -> Control:
	var p := _panel(Vector2(340,140),Vector2(920,610),Color(0.005,0.01,0.015,0.98))
	var title := Label.new()
	title.text = "BLACKWOOD INCIDENT // ARCHIVE 0217"
	title.position = Vector2(45,38)
	title.size = Vector2(830,52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",31)
	p.add_child(title)
	var body := Label.new()
	body.position = Vector2(70,115)
	body.size = Vector2(780,350)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size",19)
	body.text = "1998 — A road patrol vanished after reporting a faceless pedestrian walking at an impossible constant distance.\n\n2026 — Blackwood's abandoned surveillance network powered itself back on. Five camera stations are transmitting again. The entity appears in every feed, but never at the same time.\n\nYour assignment: reactivate three relays, recover evidence and reach the dead-zone gate. If the terminal begins showing your current location before you arrive there, leave immediately."
	p.add_child(body)
	var back := _menu_button("BACK",Vector2(310,500),Vector2(300,52))
	back.pressed.connect(func():
		p.visible = false
		main_menu.visible = true
	)
	p.add_child(back)
	return p

func _setting_label(t: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size",18)
	return l

func _panel(pos: Vector2, size2: Vector2, color: Color) -> ColorRect:
	var p := ColorRect.new()
	p.position = pos
	p.size = size2
	p.color = color
	return p

func _menu_button(text_value: String, pos: Vector2, size2: Vector2) -> Button:
	var b := Button.new()
	b.text = text_value
	b.position = pos
	b.size = size2
	b.add_theme_font_size_override("font_size",19)
	return b

func _action_button(text_value: String, pos: Vector2, size2: Vector2) -> Button:
	var b := Button.new()
	b.text = text_value
	b.position = pos
	b.size = size2
	b.add_theme_font_size_override("font_size",18)
	return b

func _apply_settings() -> void:
	Engine.max_fps = int(settings["fps"])
	var q := int(settings["quality"])
	get_viewport().scaling_3d_scale = [0.66,0.82,1.0,1.12][q]
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_4X][q]

func _start_new_game() -> void:
	mode_panel.visible = false
	main_menu.visible = false
	get_tree().paused = false
	game_started = true
	for i in range(relay_active.size()): relay_active[i] = false
	evidence_collected = 0
	_spawn_player_and_enemy(false)
	_update_objective()
	_show_notice("NIGHT 1 // BLACKWOOD REOPENED")
	if ambience_player: ambience_player.play()

func _continue_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://faceless2_save.cfg") != OK:
		_show_notice("NO CHECKPOINT DATA")
		return
	selected_mode = str(cfg.get_value("save","mode","STORY"))
	main_menu.visible = false
	get_tree().paused = false
	game_started = true
	for i in range(relay_active.size()):
		relay_active[i] = bool(cfg.get_value("save","relay_"+str(i),false))
	evidence_collected = int(cfg.get_value("save","evidence",0))
	_spawn_player_and_enemy(true)
	_update_objective()
	_show_notice("CHECKPOINT RESTORED")
	if ambience_player: ambience_player.play()

func _spawn_player_and_enemy(from_save: bool) -> void:
	if player == null:
		player = CharacterBody3D.new()
		player.set_script(PlayerScript)
		player.game = self
		add_child(player)
		player.joystick = joystick
	player.restore_full()
	var pos := Vector3(0,0.9,5)
	if from_save:
		var cfg := ConfigFile.new()
		if cfg.load("user://faceless2_save.cfg") == OK:
			pos = Vector3(0,0.9,float(cfg.get_value("save","z",5.0)))
	player.global_position = pos
	player.camera.fov = float(settings["fov"])
	if selected_mode == "BLACKOUT": player.battery = 28.0
	elif selected_mode == "NIGHTMARE": player.battery = 45.0
	else: player.battery = 100.0

	if enemy != null and is_instance_valid(enemy): enemy.queue_free()
	if selected_mode != "EXPLORATION":
		enemy = CharacterBody3D.new()
		enemy.set_script(EnemyScript)
		enemy.game = self
		enemy.player = player
		enemy.position = Vector3(0,0.9,-28)
		enemy.patrol_points = [Vector3(0,0.9,-20),Vector3(-5,0.9,-42),Vector3(5,0.9,-62),Vector3(0,0.9,-86)]
		var diff := 1.0
		if selected_mode == "RUSH": diff = 1.15
		if selected_mode == "NIGHTMARE": diff = 1.42
		if selected_mode == "BLACKOUT": diff = 1.20
		enemy.difficulty = diff
		add_child(enemy)

func _interact() -> void:
	if not game_started or player == null:
		return
	for i in range(relays.size()):
		if not relay_active[i] and player.global_position.distance_to(relays[i].global_position) < 2.4:
			relay_active[i] = true
			_show_notice("RELAY %d ONLINE" % (i+1))
			_save_checkpoint()
			_update_objective()
			return
	for e in evidence_nodes:
		if is_instance_valid(e) and e.visible and player.global_position.distance_to(e.global_position) < 2.1:
			e.visible = false
			evidence_collected += 1
			_show_notice("EVIDENCE RECOVERED %d/3" % evidence_collected)
			_save_checkpoint()
			_update_objective()
			return
	if terminal and player.global_position.distance_to(terminal.global_position) < 2.5:
		camera_terminal_open = not camera_terminal_open
		_show_notice("CAMERA GRID: "+("ONLINE" if camera_terminal_open else "CLOSED"))
		return
	if extraction_gate and player.global_position.distance_to(extraction_gate.global_position) < 3.2:
		if _relay_count() >= 3:
			_finish_game()
		else:
			_show_notice("GATE LOCKED // POWER  "+str(_relay_count())+"/3")

func _update_nearby_prompt() -> void:
	prompt_label.text = ""
	for i in range(relays.size()):
		if not relay_active[i] and player.global_position.distance_to(relays[i].global_position) < 2.4:
			prompt_label.text = "INTERACT — REACTIVATE RELAY "+str(i+1)
			return
	for e in evidence_nodes:
		if is_instance_valid(e) and e.visible and player.global_position.distance_to(e.global_position) < 2.1:
			prompt_label.text = "INTERACT — RECOVER EVIDENCE"
			return
	if terminal and player.global_position.distance_to(terminal.global_position) < 2.5:
		prompt_label.text = "INTERACT — SECURITY CAMERA TERMINAL"
		return
	if extraction_gate and player.global_position.distance_to(extraction_gate.global_position) < 3.2:
		prompt_label.text = "INTERACT — DEAD-ZONE GATE"

func _relay_count() -> int:
	var n := 0
	for v in relay_active:
		if v: n += 1
	return n

func _update_zone() -> void:
	var z := player.global_position.z
	if z > -16: current_zone = "BLACKWOOD CHECKPOINT"
	elif z > -36: current_zone = "SURVEILLANCE TOWER"
	elif z > -58: current_zone = "ABANDONED STOP"
	elif z > -80: current_zone = "RANGER WOODS"
	else: current_zone = "DEAD ZONE"

func update_hud(h: float, s: float, b: float) -> void:
	if hud:
		hud.text = "HP %03d   STAMINA %03d   BATTERY %03d   %s   %s" % [int(h),int(s),int(b),selected_mode,current_zone]

func _update_objective() -> void:
	if objective_label:
		objective_label.text = "OBJECTIVE // Restore relays %d/3 · Evidence %d/3 · Reach the dead-zone gate" % [_relay_count(),evidence_collected]

func _save_checkpoint() -> void:
	if player == null: return
	var cfg := ConfigFile.new()
	cfg.set_value("save","mode",selected_mode)
	cfg.set_value("save","evidence",evidence_collected)
	cfg.set_value("save","z",player.global_position.z)
	for i in range(relay_active.size()):
		cfg.set_value("save","relay_"+str(i),relay_active[i])
	cfg.save("user://faceless2_save.cfg")

func player_hurt() -> void:
	fade.color = Color(0.42,0.0,0.0,0.32)
	create_tween().tween_property(fade,"color",Color(0.05,0.0,0.0,0.0),0.28)

func on_enemy_attack() -> void:
	_show_notice("SIGNAL LOST // MOVE")
	if static_player: static_player.play()

func player_dead() -> void:
	_show_notice("YOU WERE RECORDED")
	var tw := create_tween()
	tw.tween_property(fade,"color",Color(0,0,0,1),0.9)
	tw.tween_interval(1.0)
	tw.tween_callback(_restart_from_checkpoint)

func _restart_from_checkpoint() -> void:
	fade.color = Color(0,0,0,0)
	_continue_game()

func _finish_game() -> void:
	game_started = false
	get_tree().paused = true
	prompt_label.text = ""
	objective_label.text = "ARCHIVE COMPLETE // CASE ZRX-BW/0217"
	_show_notice("THE FEED WENT DARK — BUT IT SAVED YOUR FACELESS FRAME")
	main_menu.visible = true

func _show_notice(t: String) -> void:
	if notice == null: return
	notice.text = t
	var tw := create_tween()
	tw.tween_interval(1.35)
	tw.tween_callback(func():
		if notice.text == t: notice.text = ""
	)
