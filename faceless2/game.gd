extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/faceless.gd")
const SoldierScript = preload("res://scripts/soldier.gd")
const JoystickScript = preload("res://scripts/virtual_joystick.gd")

var player: CharacterBody3D
var enemy: CharacterBody3D
var soldiers: Array[CharacterBody3D] = []
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
var cinematic_camera: Camera3D
var cinematic_overlay: ColorRect
var subtitle_box: ColorRect
var subtitle_label: Label
var subtitle_speaker: Label
var cinematic_running := false
var crosshair: Label
var environment: Environment
var game_started := false
var selected_mode := "STORY"
var relays: Array[Node3D] = []
var relay_active: Array[bool] = []
var evidence_nodes: Array[Node3D] = []
var evidence_collected := 0
var pickups: Array[Node3D] = []
var terminal: Node3D
var extraction_gate: Node3D
var rifle_pickup: Node3D
var camera_terminal_open := false
var ambience_player: AudioStreamPlayer
var static_player: AudioStreamPlayer
var current_zone := "BLACKWOOD CHECKPOINT"
var chapter := 1
var story_flags := {}
var settings := {
	"quality":2,
	"fps":60,
	"fov":76.0,
	"sensitivity":1.0,
	"brightness":1.35,
	"night_visibility":1.0,
	"volume":0.85
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
	_update_story()

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
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07,0.10,0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42,0.50,0.62)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.35
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.18,0.23,0.28)
	environment.fog_density = 0.008
	environment.fog_height = 0.0
	environment.fog_height_density = 0.08
	world.environment = environment
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-46,-22,0)
	moon.light_color = Color(0.52,0.63,0.82)
	moon.light_energy = 1.15
	moon.shadow_enabled = true
	add_child(moon)

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
		if r:
			r.set_meta("relay_index",i)
			relays.append(r)

	var evidence_positions := [Vector3(-4.8,0.65,-28),Vector3(5.7,0.65,-63),Vector3(-5.8,0.65,-88)]
	for i in range(3):
		var e := _spawn_asset("res://assets/evidence_case.glb",evidence_positions[i],0.2*float(i))
		if e:
			e.set_meta("evidence_index",i)
			evidence_nodes.append(e)

	terminal = _spawn_asset("res://assets/security_terminal.glb",Vector3(-6.2,0,-19),0.3)
	extraction_gate = _spawn_asset("res://assets/extraction_gate.glb",Vector3(0,0,-103),0.0)
	rifle_pickup = _spawn_asset("res://assets/rifle.glb",Vector3(-6.4,1.0,-67.8),0.4,Vector3(1.3,1.3,1.3))

	for p in [Vector3(5.3,0,-24),Vector3(-5.5,0,-58),Vector3(4.5,0,-86)]:
		var a := _spawn_asset("res://assets/ammo_box.glb",p)
		if a: a.set_meta("pickup","ammo"); pickups.append(a)
	for p in [Vector3(-4.0,0,-34),Vector3(5.2,0,-76)]:
		var m := _spawn_asset("res://assets/medkit.glb",p)
		if m: m.set_meta("pickup","medkit"); pickups.append(m)

	for z in [3,-14,-28,-44,-60,-76,-92]:
		_spawn_asset("res://assets/street_lamp.glb",Vector3(3.6,0,float(z)))
		var light := OmniLight3D.new()
		light.position = Vector3(4.1,3.45,float(z))
		light.omni_range = 16.0
		light.light_energy = 2.2
		light.light_color = Color(0.72,0.84,0.95)
		add_child(light)

func _build_audio() -> void:
	ambience_player = AudioStreamPlayer.new()
	ambience_player.stream = load("res://audio/blackwood_ambience.wav")
	ambience_player.volume_db = -7.0
	ambience_player.finished.connect(func():
		if game_started: ambience_player.play()
	)
	add_child(ambience_player)
	static_player = AudioStreamPlayer.new()
	static_player.stream = load("res://audio/signal_static.wav")
	static_player.volume_db = -4.0
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
	hud.size = Vector2(1380,42)
	hud.add_theme_font_size_override("font_size",20)
	layer.add_child(hud)

	objective_label = Label.new()
	objective_label.position = Vector2(24,54)
	objective_label.size = Vector2(1250,66)
	objective_label.add_theme_font_size_override("font_size",17)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.modulate = Color(0.75,0.88,0.92)
	layer.add_child(objective_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(420,690)
	prompt_label.size = Vector2(760,50)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size",20)
	layer.add_child(prompt_label)

	notice = Label.new()
	notice.position = Vector2(300,115)
	notice.size = Vector2(1000,75)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size",32)
	layer.add_child(notice)

	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.position = Vector2(790,430)
	crosshair.size = Vector2(30,30)
	crosshair.add_theme_font_size_override("font_size",28)
	crosshair.modulate = Color(0.9,0.94,0.95,0.86)
	layer.add_child(crosshair)

	joystick = Control.new()
	joystick.set_script(JoystickScript)
	joystick.position = Vector2(38,650)
	joystick.size = Vector2(190,190)
	layer.add_child(joystick)

	var interact := _action_button("INTERACT",Vector2(1360,690),Vector2(180,66))
	interact.pressed.connect(_interact)
	layer.add_child(interact)
	var fire := _action_button("FIRE",Vector2(1380,610),Vector2(160,66))
	fire.pressed.connect(func(): if player: player.fire_weapon())
	layer.add_child(fire)
	var reload := _action_button("RELOAD",Vector2(1210,610),Vector2(150,58))
	reload.pressed.connect(func(): if player: player.reload_weapon())
	layer.add_child(reload)
	var flashlight_btn := _action_button("LIGHT",Vector2(1220,680),Vector2(125,58))
	flashlight_btn.pressed.connect(func(): if player: player.toggle_flashlight())
	layer.add_child(flashlight_btn)
	var crouch_btn := _action_button("CROUCH",Vector2(1210,750),Vector2(140,58))
	crouch_btn.pressed.connect(func(): if player: player.toggle_crouch())
	layer.add_child(crouch_btn)
	var run_btn := _action_button("RUN",Vector2(1055,730),Vector2(120,58))
	run_btn.button_down.connect(func(): if player: player.set_running(true))
	run_btn.button_up.connect(func(): if player: player.set_running(false))
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
	_build_cinematic_ui(layer)

func _build_cinematic_ui(layer: CanvasLayer) -> void:
	cinematic_overlay = ColorRect.new()
	cinematic_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cinematic_overlay.color = Color(0,0,0,0.0)
	cinematic_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	cinematic_overlay.visible = false
	layer.add_child(cinematic_overlay)

	subtitle_box = ColorRect.new()
	subtitle_box.position = Vector2(180,690)
	subtitle_box.size = Vector2(1240,150)
	subtitle_box.color = Color(0.01,0.015,0.02,0.78)
	cinematic_overlay.add_child(subtitle_box)

	subtitle_speaker = Label.new()
	subtitle_speaker.position = Vector2(30,16)
	subtitle_speaker.size = Vector2(1180,28)
	subtitle_speaker.add_theme_font_size_override("font_size",16)
	subtitle_speaker.modulate = Color(0.38,0.75,0.80)
	subtitle_box.add_child(subtitle_speaker)

	subtitle_label = Label.new()
	subtitle_label.position = Vector2(30,47)
	subtitle_label.size = Vector2(1180,88)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size",23)
	subtitle_label.modulate = Color(0.92,0.94,0.95)
	subtitle_box.add_child(subtitle_label)

	cinematic_camera = Camera3D.new()
	cinematic_camera.fov = 66.0
	add_child(cinematic_camera)
	cinematic_camera.current = false

func _type_subtitle(speaker: String, text_value: String, cps: float = 38.0) -> void:
	subtitle_speaker.text = speaker
	subtitle_label.text = text_value
	subtitle_label.visible_characters = 0
	for i in range(text_value.length()+1):
		if not cinematic_running:
			return
		subtitle_label.visible_characters = i
		await get_tree().create_timer(1.0/cps).timeout

func _shot(from_pos: Vector3, to_pos: Vector3, look_target: Vector3, duration: float) -> void:
	var start_basis := Basis.looking_at((look_target-from_pos).normalized(),Vector3.UP)
	var end_basis := Basis.looking_at((look_target-to_pos).normalized(),Vector3.UP)
	cinematic_camera.global_transform = Transform3D(start_basis,from_pos)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cinematic_camera,"global_transform",Transform3D(end_basis,to_pos),duration)
	await tw.finished

func _start_cinematic_intro() -> void:
	if cinematic_running:
		return
	cinematic_running = true
	cinematic_overlay.visible = true
	cinematic_camera.current = true
	if player:
		player.set_controls_enabled(false)
		player.camera.current = false
	hud.visible = false
	objective_label.visible = false
	prompt_label.visible = false
	crosshair.visible = false
	_run_cinematic_intro()

func _run_cinematic_intro() -> void:
	await _shot(Vector3(-2.8,2.2,18),Vector3(0.0,1.8,8.5),Vector3(0,1.4,5),4.2)
	await _type_subtitle("BLACKWOOD ARCHIVE // 48 HOURS EARLIER","At 02:13, the abandoned checkpoint powered itself back on. No utility crew was scheduled. No vehicle entered the road.")
	await get_tree().create_timer(0.8).timeout

	await _shot(Vector3(6.8,4.0,-5),Vector3(-5.0,5.8,-18),Vector3(-7,4.8,-18),4.5)
	await _type_subtitle("DISPATCH RECORDING","Patrol Twelve was sent to verify the relay. Their body cameras captured movement around the surveillance tower before the first shot.")
	await get_tree().create_timer(0.7).timeout

	if soldiers.size() > 0 and is_instance_valid(soldiers[0]):
		await _shot(Vector3(7.5,2.1,-21),Vector3(3.5,1.7,-25),soldiers[0].global_position+Vector3(0,1.3,0),3.4)
	else:
		await _shot(Vector3(7.5,2.1,-21),Vector3(3.5,1.7,-25),Vector3(4.5,1.5,-25),3.4)
	await _type_subtitle("UNKNOWN RADIO","Blackwood Security now controls the route. Anyone approaching the relays is treated as hostile.")
	await get_tree().create_timer(0.7).timeout

	await _shot(Vector3(-2.5,1.2,-27),Vector3(-4.2,1.0,-28.5),Vector3(-4.8,0.7,-28),3.0)
	await _type_subtitle("RECOVERY NOTE","Three evidence cases were left behind. Their recordings are the only proof of what happened to the first patrol.")
	await get_tree().create_timer(0.7).timeout

	if enemy and is_instance_valid(enemy):
		enemy.global_position = Vector3(3.2,0.9,-46)
		await _shot(Vector3(-7.5,1.8,-39),Vector3(-3.0,1.7,-43),enemy.global_position+Vector3(0,1.4,0),4.2)
	else:
		await _shot(Vector3(-7.5,1.8,-39),Vector3(-3.0,1.7,-43),Vector3(3.2,2.0,-46),4.2)
	await _type_subtitle("FRAME 0913","One figure appears in every recovered feed. No face. No confirmed identity. Gunfire delays it, but the archive has no record of a permanent kill.",34.0)
	await get_tree().create_timer(1.0).timeout

	await _shot(Vector3(1.8,1.8,3.0),Vector3(0.2,1.65,5.2),Vector3(0,1.2,-8),2.8)
	await _type_subtitle("CONTROL","Restore the three relays. Recover the evidence. Reach the ranger cabin for heavier weapons. Then get to the dead-zone gate.")
	await get_tree().create_timer(0.7).timeout
	_finish_cinematic_intro()

func _finish_cinematic_intro() -> void:
	cinematic_running = false
	cinematic_overlay.visible = false
	cinematic_camera.current = false
	if player:
		player.camera.current = true
		player.set_controls_enabled(true)
	hud.visible = true
	objective_label.visible = true
	prompt_label.visible = true
	crosshair.visible = true
	_show_notice("CHAPTER I // ENTER BLACKWOOD")

func _build_main_menu() -> Control:
	var root := _panel(Vector2(170,90),Vector2(1260,720),Color(0.005,0.01,0.015,0.96))
	var title := Label.new()
	title.text = "FACELESS 2"
	title.position = Vector2(80,40)
	title.size = Vector2(520,74)
	title.add_theme_font_size_override("font_size",58)
	title.modulate = Color(0.86,0.07,0.08)
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "BLACKWOOD // ARMED RESPONSE"
	subtitle.position = Vector2(85,110)
	subtitle.add_theme_font_size_override("font_size",20)
	subtitle.modulate = Color(0.38,0.72,0.76)
	root.add_child(subtitle)
	var by := Label.new()
	by.text = "made by zorix"
	by.position = Vector2(85,150)
	by.modulate = Color(0.65,0.65,0.70)
	root.add_child(by)

	var labels := ["CONTINUE","NEW GAME","GAME MODES","SETTINGS","ARCHIVE"]
	for i in range(labels.size()):
		var b := _menu_button(labels[i],Vector2(90,230+i*66),Vector2(390,54))
		if i == 0: b.pressed.connect(_continue_game)
		elif i == 1:
			b.pressed.connect(func(): root.visible=false; mode_panel.visible=true)
		elif i == 2:
			b.pressed.connect(func(): root.visible=false; mode_panel.visible=true)
		elif i == 3:
			b.pressed.connect(func(): root.visible=false; settings_panel.visible=true)
		else:
			b.pressed.connect(func(): root.visible=false; archive_panel.visible=true)
		root.add_child(b)

	var panel := ColorRect.new()
	panel.position = Vector2(610,160)
	panel.size = Vector2(560,430)
	panel.color = Color(0.02,0.06,0.07,0.74)
	root.add_child(panel)
	var lore := Label.new()
	lore.position = Vector2(28,24)
	lore.size = Vector2(510,380)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.add_theme_font_size_override("font_size",19)
	lore.text = "CASE ZRX-BW/0217 // RESPONSE PHASE\n\nBlackwood's cameras are no longer the only threat. An unauthorized security unit has sealed the road and is shooting anyone approaching the relays.\n\nYou begin with a pistol. Reach the ranger cabin to recover a rifle. Restore three relays, survive the armed patrols, collect evidence, and reach the dead-zone gate. The Faceless entity cannot be trusted to stay dead."
	panel.add_child(lore)
	return root

func _build_mode_panel() -> Control:
	var p := _panel(Vector2(430,150),Vector2(740,590),Color(0.005,0.01,0.015,0.98))
	var title := Label.new()
	title.text = "CHOOSE YOUR NIGHT"
	title.position = Vector2(50,32)
	title.size = Vector2(640,50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",34)
	p.add_child(title)
	var modes := [["STORY","Campaign with gunfights and story beats."],["RUSH","Faster route and tougher patrols."],["NIGHTMARE","Stronger enemies, lower battery."],["ENDLESS","Relays reset after extraction."],["EXPLORATION","No Faceless hunter."],["BLACKOUT","Lower visibility and scarce power."]]
	for i in range(modes.size()):
		var b := _menu_button(modes[i][0]+" — "+modes[i][1],Vector2(80,105+i*62),Vector2(580,50))
		var mode_name: String = modes[i][0]
		b.pressed.connect(func(): selected_mode=mode_name; _start_new_game())
		p.add_child(b)
	var back := _menu_button("BACK",Vector2(220,500),Vector2(300,48))
	back.pressed.connect(func(): p.visible=false; main_menu.visible=true)
	p.add_child(back)
	return p

func _build_settings_panel() -> Control:
	var p := _panel(Vector2(455,120),Vector2(700,650),Color(0.005,0.01,0.015,0.98))
	var title := Label.new()
	title.text = "SETTINGS"
	title.position = Vector2(42,28)
	title.add_theme_font_size_override("font_size",36)
	p.add_child(title)

	var quality := OptionButton.new()
	quality.position = Vector2(330,95)
	quality.size = Vector2(290,46)
	for t in ["PERFORMANCE","BALANCED","HIGH","ULTRA"]: quality.add_item(t)
	quality.select(settings["quality"])
	quality.item_selected.connect(func(i): settings["quality"]=i; _apply_settings())
	p.add_child(_setting_label("QUALITY",Vector2(52,107))); p.add_child(quality)

	var fps := OptionButton.new()
	fps.position = Vector2(330,155); fps.size=Vector2(290,46)
	for t in ["30 FPS","60 FPS","120 FPS"]: fps.add_item(t)
	fps.select(1)
	fps.item_selected.connect(func(i): settings["fps"]=[30,60,120][i]; _apply_settings())
	p.add_child(_setting_label("FPS LIMIT",Vector2(52,167))); p.add_child(fps)

	var bright := HSlider.new()
	bright.position=Vector2(330,220); bright.size=Vector2(290,40)
	bright.min_value=0.8; bright.max_value=2.2; bright.step=0.05; bright.value=settings["brightness"]
	bright.value_changed.connect(func(v): settings["brightness"]=v; _apply_settings())
	p.add_child(_setting_label("BRIGHTNESS",Vector2(52,232))); p.add_child(bright)

	var night := HSlider.new()
	night.position=Vector2(330,280); night.size=Vector2(290,40)
	night.min_value=0.5; night.max_value=1.8; night.step=0.05; night.value=settings["night_visibility"]
	night.value_changed.connect(func(v): settings["night_visibility"]=v; _apply_settings())
	p.add_child(_setting_label("NIGHT VISIBILITY",Vector2(52,292))); p.add_child(night)

	var fov := HSlider.new()
	fov.position=Vector2(330,340); fov.size=Vector2(290,40)
	fov.min_value=60; fov.max_value=95; fov.value=settings["fov"]
	fov.value_changed.connect(func(v): settings["fov"]=v; if player and player.camera: player.camera.fov=v)
	p.add_child(_setting_label("FIELD OF VIEW",Vector2(52,352))); p.add_child(fov)

	var sens := HSlider.new()
	sens.position=Vector2(330,400); sens.size=Vector2(290,40)
	sens.min_value=.5; sens.max_value=2.0; sens.step=.05; sens.value=settings["sensitivity"]
	sens.value_changed.connect(func(v): settings["sensitivity"]=v)
	p.add_child(_setting_label("LOOK SENSITIVITY",Vector2(52,412))); p.add_child(sens)

	var back := _menu_button("BACK",Vector2(200,535),Vector2(300,52))
	back.pressed.connect(func(): p.visible=false; main_menu.visible=true)
	p.add_child(back)
	return p

func _build_archive_panel() -> Control:
	var p := _panel(Vector2(340,140),Vector2(920,610),Color(0.005,0.01,0.015,0.98))
	var title := Label.new()
	title.text = "BLACKWOOD INCIDENT // PHASE TWO"
	title.position=Vector2(45,36); title.size=Vector2(830,52); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",31)
	p.add_child(title)
	var body := Label.new()
	body.position=Vector2(70,110); body.size=Vector2(780,360); body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_theme_font_size_override("font_size",19)
	body.text="CHAPTER I — REOPENING\nRestore the checkpoint relay.\n\nCHAPTER II — ARMED RESPONSE\nBlackwood Security has orders to stop you. Recover ammunition and clear the tower route.\n\nCHAPTER III — THE CABIN\nFind the rifle inside the ranger sector.\n\nCHAPTER IV — DEAD SIGNAL\nRestore the final relay while the Faceless entity closes in.\n\nCHAPTER V — EXTRACTION\nReach the dead-zone gate with the archive evidence."
	p.add_child(body)
	var back := _menu_button("BACK",Vector2(310,500),Vector2(300,52))
	back.pressed.connect(func(): p.visible=false; main_menu.visible=true)
	p.add_child(back)
	return p

func _setting_label(t:String,pos:Vector2)->Label:
	var l:=Label.new(); l.text=t; l.position=pos; l.add_theme_font_size_override("font_size",18); return l
func _panel(pos:Vector2,size2:Vector2,color:Color)->ColorRect:
	var p:=ColorRect.new(); p.position=pos; p.size=size2; p.color=color; return p
func _menu_button(t:String,pos:Vector2,size2:Vector2)->Button:
	var b:=Button.new(); b.text=t; b.position=pos; b.size=size2; b.add_theme_font_size_override("font_size",19); return b
func _action_button(t:String,pos:Vector2,size2:Vector2)->Button:
	var b:=Button.new(); b.text=t; b.position=pos; b.size=size2; b.add_theme_font_size_override("font_size",18); return b

func _apply_settings() -> void:
	Engine.max_fps=int(settings["fps"])
	var q:=int(settings["quality"])
	get_viewport().scaling_3d_scale=[0.66,0.82,1.0,1.12][q]
	get_viewport().msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_4X][q]
	if environment:
		environment.adjustment_brightness=float(settings["brightness"])
		environment.ambient_light_energy=0.72*float(settings["night_visibility"])
		environment.fog_density=0.008/max(float(settings["night_visibility"]),0.5)

func _start_new_game() -> void:
	mode_panel.visible=false; main_menu.visible=false; get_tree().paused=false; game_started=true
	chapter=1; story_flags={}
	for i in range(relay_active.size()): relay_active[i]=false
	evidence_collected=0
	_spawn_player_and_enemies(false)
	_update_objective()
	_start_cinematic_intro()
	if ambience_player: ambience_player.play()

func _continue_game() -> void:
	var cfg:=ConfigFile.new()
	if cfg.load("user://faceless2_save.cfg")!=OK:
		_show_notice("NO CHECKPOINT DATA"); return
	selected_mode=str(cfg.get_value("save","mode","STORY"))
	chapter=int(cfg.get_value("save","chapter",1))
	main_menu.visible=false; get_tree().paused=false; game_started=true
	for i in range(relay_active.size()): relay_active[i]=bool(cfg.get_value("save","relay_"+str(i),false))
	evidence_collected=int(cfg.get_value("save","evidence",0))
	_spawn_player_and_enemies(true)
	if player: player.set_controls_enabled(true)
	_update_objective()
	_show_notice("CHECKPOINT RESTORED")
	if ambience_player: ambience_player.play()

func _spawn_player_and_enemies(from_save:bool)->void:
	if player==null:
		player=CharacterBody3D.new(); player.set_script(PlayerScript); player.game=self; add_child(player); player.joystick=joystick
	player.restore_full()
	var pos:=Vector3(0,0.9,5)
	if from_save:
		var cfg:=ConfigFile.new()
		if cfg.load("user://faceless2_save.cfg")==OK: pos=Vector3(0,0.9,float(cfg.get_value("save","z",5.0)))
	player.global_position=pos
	player.camera.fov=float(settings["fov"])
	if selected_mode=="BLACKOUT": player.battery=35.0
	elif selected_mode=="NIGHTMARE": player.battery=55.0

	if enemy and is_instance_valid(enemy): enemy.queue_free()
	for s in soldiers:
		if is_instance_valid(s): s.queue_free()
	soldiers.clear()

	if selected_mode!="EXPLORATION":
		enemy=CharacterBody3D.new(); enemy.set_script(EnemyScript); enemy.game=self; enemy.player=player; enemy.position=Vector3(0,0.9,-34)
		enemy.patrol_points=[Vector3(0,0.9,-24),Vector3(-5,0.9,-50),Vector3(5,0.9,-76),Vector3(0,0.9,-96)]
		enemy.difficulty=1.35 if selected_mode=="NIGHTMARE" else 1.0
		add_child(enemy)

	var positions=[Vector3(4.5,0.9,-25),Vector3(-5.0,0.9,-55),Vector3(4.2,0.9,-79)]
	for i in range(positions.size()):
		var s:=CharacterBody3D.new()
		s.set_script(SoldierScript); s.game=self; s.player=player; s.position=positions[i]
		s.patrol_points=[positions[i]+Vector3(-3,0,0),positions[i]+Vector3(3,0,-4)]
		s.difficulty=1.25 if selected_mode=="NIGHTMARE" else 1.0
		add_child(s); soldiers.append(s)

func _interact()->void:
	if not game_started or player==null: return
	if rifle_pickup and rifle_pickup.visible and player.global_position.distance_to(rifle_pickup.global_position)<2.2:
		rifle_pickup.visible=false; player.unlock_rifle(); chapter=maxi(chapter,3); _show_notice("RIFLE ACQUIRED // CHAPTER III"); _save_checkpoint(); _update_objective(); return
	for p in pickups:
		if is_instance_valid(p) and p.visible and player.global_position.distance_to(p.global_position)<2.0:
			var kind:=str(p.get_meta("pickup",""))
			p.visible=false
			if kind=="ammo": player.add_ammo(36)
			elif kind=="medkit": player.add_health(45)
			return
	for i in range(relays.size()):
		if not relay_active[i] and player.global_position.distance_to(relays[i].global_position)<2.4:
			relay_active[i]=true
			chapter=maxi(chapter,i+1)
			_show_notice("RELAY %d ONLINE"%(i+1)); _save_checkpoint(); _update_objective(); return
	for e in evidence_nodes:
		if is_instance_valid(e) and e.visible and player.global_position.distance_to(e.global_position)<2.1:
			e.visible=false; evidence_collected+=1; _show_notice("EVIDENCE %d/3"%evidence_collected); _save_checkpoint(); _update_objective(); return
	if terminal and player.global_position.distance_to(terminal.global_position)<2.5:
		camera_terminal_open=not camera_terminal_open; _show_notice("CAMERA GRID "+("ONLINE" if camera_terminal_open else "CLOSED")); return
	if extraction_gate and player.global_position.distance_to(extraction_gate.global_position)<3.2:
		if _relay_count()>=3 and evidence_collected>=2: _finish_game()
		else: _show_notice("GATE LOCKED // NEED POWER 3/3 AND EVIDENCE 2/3")

func _update_nearby_prompt()->void:
	prompt_label.text=""
	if rifle_pickup and rifle_pickup.visible and player.global_position.distance_to(rifle_pickup.global_position)<2.2: prompt_label.text="INTERACT — TAKE RIFLE"; return
	for p in pickups:
		if is_instance_valid(p) and p.visible and player.global_position.distance_to(p.global_position)<2.0: prompt_label.text="INTERACT — PICKUP"; return
	for i in range(relays.size()):
		if not relay_active[i] and player.global_position.distance_to(relays[i].global_position)<2.4: prompt_label.text="INTERACT — REACTIVATE RELAY "+str(i+1); return
	for e in evidence_nodes:
		if is_instance_valid(e) and e.visible and player.global_position.distance_to(e.global_position)<2.1: prompt_label.text="INTERACT — RECOVER EVIDENCE"; return
	if terminal and player.global_position.distance_to(terminal.global_position)<2.5: prompt_label.text="INTERACT — SECURITY TERMINAL"; return
	if extraction_gate and player.global_position.distance_to(extraction_gate.global_position)<3.2: prompt_label.text="INTERACT — DEAD-ZONE GATE"

func _update_story()->void:
	var z:=player.global_position.z
	if z<-20 and not story_flags.has("armed"):
		story_flags["armed"]=true; chapter=2; _show_notice("CHAPTER II // ARMED RESPONSE DETECTED")
	if z<-64 and not story_flags.has("cabin"):
		story_flags["cabin"]=true; chapter=maxi(chapter,3); _show_notice("CHAPTER III // SEARCH THE RANGER CABIN")
	if _relay_count()>=3 and not story_flags.has("dead_signal"):
		story_flags["dead_signal"]=true; chapter=4; _show_notice("CHAPTER IV // DEAD SIGNAL")
	if z<-96 and not story_flags.has("extract"):
		story_flags["extract"]=true; chapter=5; _show_notice("CHAPTER V // EXTRACTION")

func _relay_count()->int:
	var n:=0
	for v in relay_active:
		if v:n+=1
	return n

func _update_zone()->void:
	var z:=player.global_position.z
	if z>-16: current_zone="BLACKWOOD CHECKPOINT"
	elif z>-36: current_zone="SURVEILLANCE TOWER"
	elif z>-58: current_zone="ABANDONED STOP"
	elif z>-80: current_zone="RANGER WOODS"
	else: current_zone="DEAD ZONE"

func update_hud(h:float,s:float,b:float,weapon:String,mag:int,reserve:int)->void:
	if hud: hud.text="HP %03d  STA %03d  BAT %03d  %s %02d/%03d  CH.%d  %s"%[int(h),int(s),int(b),weapon,mag,reserve,chapter,current_zone]

func _update_objective()->void:
	if objective_label:
		objective_label.text="OBJECTIVE // Relays %d/3 · Evidence %d/3 · Rifle %s · Reach Dead Zone"%[_relay_count(),evidence_collected,("YES" if player and player.rifle_unlocked else "NO")]

func _save_checkpoint()->void:
	if player==null:return
	var cfg:=ConfigFile.new()
	cfg.set_value("save","mode",selected_mode); cfg.set_value("save","evidence",evidence_collected); cfg.set_value("save","z",player.global_position.z); cfg.set_value("save","chapter",chapter)
	for i in range(relay_active.size()): cfg.set_value("save","relay_"+str(i),relay_active[i])
	cfg.save("user://faceless2_save.cfg")

func on_player_shot(_weapon:String)->void:
	crosshair.modulate=Color(1.0,0.65,0.3,1.0)
	create_tween().tween_property(crosshair,"modulate",Color(0.9,0.94,0.95,0.86),0.10)

func weapon_event(t:String)->void:
	_show_notice(t)

func soldier_fired(_s:Node)->void:
	fade.color=Color(0.5,0.06,0.02,0.18)
	create_tween().tween_property(fade,"color",Color(0,0,0,0),0.16)

func soldier_down(s:CharacterBody3D)->void:
	soldiers.erase(s)
	var tw:=create_tween(); tw.tween_property(s,"rotation:z",1.35,0.24); tw.tween_interval(.2); tw.tween_callback(s.queue_free)
	_show_notice("HOSTILE DOWN")

func faceless_down(e:CharacterBody3D)->void:
	_show_notice("FACELESS DISRUPTED // IT WILL RETURN")
	var tw:=create_tween(); tw.tween_property(e,"position:y",-2.0,0.55); tw.tween_interval(4.0); tw.tween_callback(func(): if is_instance_valid(e): e.position=Vector3(0,0.9,-96); e.health=160.0; e.dead=false)

func player_hurt()->void:
	fade.color=Color(0.50,0.0,0.0,0.30); create_tween().tween_property(fade,"color",Color(0,0,0,0),0.24)
func on_enemy_attack()->void:
	_show_notice("SIGNAL LOST // MOVE"); if static_player: static_player.play()
func player_dead()->void:
	_show_notice("YOU WERE RECORDED")
	var tw:=create_tween(); tw.tween_property(fade,"color",Color(0,0,0,1),0.8); tw.tween_interval(.8); tw.tween_callback(_restart_from_checkpoint)
func _restart_from_checkpoint()->void:
	fade.color=Color(0,0,0,0); _continue_game()
func _finish_game()->void:
	game_started=false; get_tree().paused=true; objective_label.text="ARCHIVE COMPLETE // BLACKWOOD RESPONSE ENDED"; _show_notice("EXTRACTION COMPLETE // FACELESS 2"); main_menu.visible=true
func _show_notice(t:String)->void:
	if notice==null:return
	notice.text=t
	var tw:=create_tween(); tw.tween_interval(1.25); tw.tween_callback(func(): if notice.text==t: notice.text="")
