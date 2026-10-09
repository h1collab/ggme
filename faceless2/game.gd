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
var voice_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var heartbeat_player: AudioStreamPlayer
var current_zone := "BLACKWOOD CHECKPOINT"
var chapter := 1
var story_flags := {}
var kills := 0
var final_wave_started := false
var final_wave_cleared := false
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
	_update_objective()

func get_look_sensitivity() -> float:
	return float(settings["sensitivity"])

func _mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _static_box(pos: Vector3, size3: Vector3, _material: Material) -> void:
	# Collision only. v4 intentionally renders no procedural box geometry.
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size3
	cs.shape = sh
	body.add_child(cs)

func _visual_aabb(root: Node3D) -> AABB:
	var first := true
	var result := AABB()
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var rel := root.global_transform.affine_inverse() * mi.global_transform
		var box: AABB = rel * mi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

func _spawn_asset(path: String, pos: Vector3, rot_y := 0.0, target_extent := 0.0) -> Node3D:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst := packed.instantiate()
	if not (inst is Node3D):
		return null
	var n := inst as Node3D
	n.position = pos
	n.rotation.y = rot_y
	add_child(n)
	if target_extent > 0.0:
		var box := _visual_aabb(n)
		var largest := maxf(box.size.x,maxf(box.size.y,box.size.z))
		if largest > 0.001:
			var factor := target_extent/largest
			n.scale = Vector3.ONE*factor
			# Put the lowest visible point on the requested ground height.
			n.position.y = pos.y - box.position.y*factor
	return n

func _build_world() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055,0.075,0.105)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.38,0.46,0.58)
	environment.ambient_light_energy = 0.70
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.30
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.14,0.18,0.23)
	environment.fog_density = 0.006
	environment.fog_height_density = 0.055
	world.environment = environment
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48,-18,0)
	moon.light_color = Color(0.56,0.66,0.84)
	moon.light_energy = 1.15
	moon.shadow_enabled = true
	add_child(moon)

	# Collision-only road and invisible edge barriers.
	_static_box(Vector3(0,-0.35,-47),Vector3(18,0.7,150),_mat(Color.WHITE))
	_static_box(Vector3(-8.8,1.2,-47),Vector3(0.5,2.4,150),_mat(Color.WHITE))
	_static_box(Vector3(8.8,1.2,-47),Vector3(0.5,2.4,150),_mat(Color.WHITE))

	# Every visible object below is an original Sketchfab GLB, normalized to a sane game scale.
	_spawn_asset("res://assets/blackwood_road.glb",Vector3(0,0,-47),0.0,145.0)
	_spawn_asset("res://assets/checkpoint_gate.glb",Vector3(0,0,8),0.0,8.0)
	_spawn_asset("res://assets/surveillance_tower.glb",Vector3(-6.4,0,-20),0.2,8.2)
	_spawn_asset("res://assets/abandoned_bus_stop.glb",Vector3(6.0,0,-43),PI,4.5)
	_spawn_asset("res://assets/ranger_cabin.glb",Vector3(-6.0,0,-69),0.15,6.0)
	_spawn_asset("res://assets/dead_zone_fence.glb",Vector3(0,0,-94),0.0,12.0)

	# Structure collision volumes, placed away from the playable road center.
	_static_box(Vector3(-5.7,1.4,8),Vector3(3.0,2.8,3.0),_mat(Color.WHITE))
	_static_box(Vector3(-6.4,2.4,-20),Vector3(3.4,4.8,3.4),_mat(Color.WHITE))
	_static_box(Vector3(6.0,1.3,-43),Vector3(4.8,2.6,2.7),_mat(Color.WHITE))
	_static_box(Vector3(-6.0,1.7,-69),Vector3(6.2,3.4,5.0),_mat(Color.WHITE))

	# Cleaner forest spacing: fewer clusters, always outside the road barriers.
	for z in range(4,-103,-12):
		_spawn_asset("res://assets/pine_cluster.glb",Vector3(-12.2,0,float(z)),0.07*float(z),6.2)
		_spawn_asset("res://assets/pine_cluster.glb",Vector3(12.2,0,float(z)-2.0),-0.05*float(z),6.2)
		_static_box(Vector3(-12.2,2.4,float(z)),Vector3(3.6,4.8,3.6),_mat(Color.WHITE))
		_static_box(Vector3(12.2,2.4,float(z)-2.0),Vector3(3.6,4.8,3.6),_mat(Color.WHITE))

	relay_active = [false,false,false]
	var relay_positions := [Vector3(5.5,0,-13),Vector3(-5.4,0,-53),Vector3(5.3,0,-84)]
	for i in range(3):
		var r := _spawn_asset("res://assets/power_relay.glb",relay_positions[i],0.0,1.9)
		if r:
			r.set_meta("relay_index",i)
			relays.append(r)
		_static_box(relay_positions[i]+Vector3(0,0.9,0),Vector3(1.4,1.8,0.9),_mat(Color.WHITE))

	var evidence_positions := [Vector3(-4.5,0,-29),Vector3(5.2,0,-64),Vector3(-4.8,0,-88)]
	for i in range(3):
		var e := _spawn_asset("res://assets/evidence_case.glb",evidence_positions[i],0.2*float(i),0.65)
		if e:
			e.set_meta("evidence_index",i)
			evidence_nodes.append(e)

	terminal = _spawn_asset("res://assets/security_terminal.glb",Vector3(-5.2,0,-22),0.25,1.6)
	extraction_gate = _spawn_asset("res://assets/extraction_gate.glb",Vector3(0,0,-106),0.0,11.0)
	rifle_pickup = _spawn_asset("res://assets/rifle.glb",Vector3(-4.9,0.95,-70.5),0.35,1.05)

	for p in [Vector3(5.0,0,-25),Vector3(-4.8,0,-59),Vector3(4.6,0,-87)]:
		var a := _spawn_asset("res://assets/ammo_box.glb",p,0.0,0.65)
		if a:
			a.set_meta("pickup","ammo")
			pickups.append(a)
	for p in [Vector3(-4.2,0,-36),Vector3(4.9,0,-78)]:
		var m := _spawn_asset("res://assets/medkit.glb",p,0.0,0.52)
		if m:
			m.set_meta("pickup","medkit")
			pickups.append(m)

	for z in [3,-14,-30,-46,-62,-78,-94]:
		_spawn_asset("res://assets/street_lamp.glb",Vector3(4.8,0,float(z)),0.0,4.2)
		var light := OmniLight3D.new()
		light.position = Vector3(4.5,3.6,float(z))
		light.omni_range = 15.5
		light.light_energy = 1.9
		light.light_color = Color(0.70,0.82,0.94)
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
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -1.0
	add_child(voice_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = -2.0
	add_child(sfx_player)
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.stream = load("res://audio/heartbeat.wav")
	heartbeat_player.volume_db = -9.0
	heartbeat_player.finished.connect(func():
		if game_started and player and player.health < 35.0:
			heartbeat_player.play()
	)
	add_child(heartbeat_player)

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
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-20,-20)
	crosshair.size = Vector2(40,40)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size",24)
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
	var run_btn := _action_button("RUN",Vector2(1045,748),Vector2(115,56))
	run_btn.button_down.connect(func(): if player: player.set_running(true))
	run_btn.button_up.connect(func(): if player: player.set_running(false))
	layer.add_child(run_btn)

	var aim_btn := _action_button("AIM",Vector2(1050,675),Vector2(110,56))
	aim_btn.button_down.connect(func(): if player: player.set_aiming(true))
	aim_btn.button_up.connect(func(): if player: player.set_aiming(false))
	layer.add_child(aim_btn)

	var swap_btn := _action_button("SWAP",Vector2(920,748),Vector2(115,56))
	swap_btn.pressed.connect(func(): if player: player.switch_weapon())
	layer.add_child(swap_btn)

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
	subtitle_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_box.position = Vector2(150,-168)
	subtitle_box.size = Vector2(-300,138)
	subtitle_box.color = Color(0.008,0.012,0.018,0.84)
	cinematic_overlay.add_child(subtitle_box)

	subtitle_speaker = Label.new()
	subtitle_speaker.position = Vector2(28,14)
	subtitle_speaker.size = Vector2(1120,25)
	subtitle_speaker.add_theme_font_size_override("font_size",15)
	subtitle_speaker.modulate = Color(0.30,0.82,0.86)
	subtitle_box.add_child(subtitle_speaker)

	subtitle_label = Label.new()
	subtitle_label.position = Vector2(28,43)
	subtitle_label.size = Vector2(1120,80)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size",22)
	subtitle_label.modulate = Color(0.94,0.95,0.96)
	subtitle_box.add_child(subtitle_label)

	cinematic_camera = Camera3D.new()
	cinematic_camera.fov = 62.0
	cinematic_camera.near = 0.08
	add_child(cinematic_camera)
	cinematic_camera.current = false

func _type_subtitle(speaker: String, text_value: String, voice_path := "", cps := 34.0) -> void:
	subtitle_speaker.text = speaker
	subtitle_label.text = text_value
	subtitle_label.visible_characters = 0
	if voice_path != "" and ResourceLoader.exists(voice_path):
		voice_player.stream = load(voice_path)
		voice_player.play()
	for i in range(text_value.length()+1):
		if not cinematic_running:
			return
		subtitle_label.visible_characters = i
		await get_tree().create_timer(1.0/cps).timeout
	if voice_player.playing:
		await voice_player.finished

func _shot(from_pos: Vector3, to_pos: Vector3, look_target: Vector3, duration: float) -> void:
	# All intro shots stay above the clear road centerline, avoiding structures and tree collision.
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
	await _shot(Vector3(0,4.2,18),Vector3(0,3.1,9.5),Vector3(0,1.2,0),3.6)
	await _type_subtitle("BLACKWOOD CONTROL","The checkpoint powered itself back on at 02:13. No utility crew is present. Proceed to Relay One and restore the grid.","res://audio/voice_intro_01.wav",32.0)

	await _shot(Vector3(0,4.6,-7),Vector3(0,4.3,-17),Vector3(-6.4,4.5,-20),3.4)
	await _type_subtitle("DISPATCH","Patrol Twelve stopped responding forty-eight hours ago. Armed security now holds the road. They will fire on sight.","res://audio/voice_intro_02.wav",32.0)

	await _shot(Vector3(0,3.2,-31),Vector3(0,3.0,-42),Vector3(3.0,1.8,-46),3.4)
	if enemy and is_instance_valid(enemy):
		enemy.global_position = Vector3(4.3,0.9,-48)
	await _type_subtitle("ARCHIVE","One impossible frame survived. A man without a face appears behind every lost patrol. Gunfire only delays it.","res://audio/voice_intro_03.wav",30.0)

	await _shot(Vector3(0,3.0,-54),Vector3(0,2.7,-65),Vector3(-5.0,1.0,-69),3.3)
	await _type_subtitle("BLACKWOOD CONTROL","Restore all three relays. Recover the evidence. Find the rifle at the ranger cabin. Then reach the dead-zone gate alive.","res://audio/voice_intro_04.wav",31.0)

	await _shot(Vector3(0,2.5,6),Vector3(0,1.75,4.5),Vector3(5.5,1.0,-13),2.4)
	await _type_subtitle("OBJECTIVE","First objective: follow the road to Relay One. Interact with the electrical cabinet when you reach it.","res://audio/voice_objective_01.wav",32.0)
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
	_update_objective()

func _build_main_menu() -> Control:
	var root := ColorRect.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.color = Color(0.004,0.007,0.011,0.94)

	var rail := ColorRect.new()
	rail.position = Vector2(0,0)
	rail.size = Vector2(18,900)
	rail.color = Color(0.72,0.025,0.035,0.92)
	root.add_child(rail)

	var brand := Label.new()
	brand.text = "FACELESS"
	brand.position = Vector2(82,72)
	brand.size = Vector2(520,70)
	brand.add_theme_font_size_override("font_size",56)
	brand.modulate = Color(0.94,0.95,0.96)
	root.add_child(brand)

	var sequel := Label.new()
	sequel.text = "02"
	sequel.position = Vector2(460,58)
	sequel.size = Vector2(120,80)
	sequel.add_theme_font_size_override("font_size",64)
	sequel.modulate = Color(0.78,0.04,0.05)
	root.add_child(sequel)

	var tagline := Label.new()
	tagline.text = "BLACKWOOD INCIDENT // FIELD TERMINAL"
	tagline.position = Vector2(87,145)
	tagline.size = Vector2(570,34)
	tagline.add_theme_font_size_override("font_size",16)
	tagline.modulate = Color(0.28,0.72,0.76)
	root.add_child(tagline)

	var labels := ["CONTINUE","NEW GAME","GAME MODES","SETTINGS","ARCHIVE"]
	for i in range(labels.size()):
		var b := _menu_button(labels[i],Vector2(86,242+i*70),Vector2(390,54))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("outline_size",0)
		if i == 0:
			b.pressed.connect(_continue_game)
		elif i == 1:
			b.pressed.connect(func(): root.visible=false; mode_panel.visible=true)
		elif i == 2:
			b.pressed.connect(func(): root.visible=false; mode_panel.visible=true)
		elif i == 3:
			b.pressed.connect(func(): root.visible=false; settings_panel.visible=true)
		else:
			b.pressed.connect(func(): root.visible=false; archive_panel.visible=true)
		root.add_child(b)

	var card := ColorRect.new()
	card.position = Vector2(760,120)
	card.size = Vector2(720,600)
	card.color = Color(0.018,0.028,0.038,0.88)
	root.add_child(card)

	var status := Label.new()
	status.text = "CASE STATUS  //  ACTIVE"
	status.position = Vector2(38,34)
	status.size = Vector2(620,34)
	status.add_theme_font_size_override("font_size",16)
	status.modulate = Color(0.78,0.07,0.08)
	card.add_child(status)

	var mission := Label.new()
	mission.text = "BLACKWOOD RESPONSE"
	mission.position = Vector2(38,82)
	mission.size = Vector2(620,50)
	mission.add_theme_font_size_override("font_size",32)
	card.add_child(mission)

	var summary := Label.new()
	summary.position = Vector2(38,150)
	summary.size = Vector2(630,260)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size",19)
	summary.text = "Three relay stations are offline. Patrol Twelve is missing. Armed security controls the road.\n\nYour route is now guided step by step in the HUD. Follow the current objective marker, interact with highlighted equipment, and use checkpoints to continue."
	summary.modulate = Color(0.78,0.83,0.88)
	card.add_child(summary)

	var hint := Label.new()
	hint.text = "STORY MODE RECOMMENDED  •  HEADPHONES RECOMMENDED\nOriginal Sketchfab environment assets  •  made by zorix"
	hint.position = Vector2(38,500)
	hint.size = Vector2(630,70)
	hint.add_theme_font_size_override("font_size",15)
	hint.modulate = Color(0.40,0.58,0.64)
	card.add_child(hint)
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
	chapter=1; story_flags={}; kills=0; final_wave_started=false; final_wave_cleared=false
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
	for p in positions:
		_spawn_soldier(p)

func _spawn_soldier(pos: Vector3, hard := false) -> void:
	var s:=CharacterBody3D.new()
	s.set_script(SoldierScript)
	s.game=self
	s.player=player
	s.position=pos
	s.patrol_points=[pos+Vector3(-3,0,0),pos+Vector3(3,0,-4)]
	s.difficulty=1.35 if hard or selected_mode=="NIGHTMARE" else 1.0
	add_child(s)
	soldiers.append(s)

func _spawn_reinforcements(stage: int) -> void:
	if stage == 1:
		_spawn_soldier(Vector3(-4.8,0.9,-35))
		_spawn_soldier(Vector3(4.8,0.9,-39))
		_play_radio_line("BLACKWOOD CONTROL","Security reinforcements are moving toward the abandoned stop. Stay off the centerline.","res://audio/voice_relay_01.wav")
	elif stage == 2:
		_spawn_soldier(Vector3(-4.6,0.9,-72),true)
		_spawn_soldier(Vector3(4.5,0.9,-75),true)
		_play_radio_line("BLACKWOOD CONTROL","Relay Two exposed your position. Reach the ranger cabin and recover the rifle before the next team arrives.","res://audio/voice_relay_02.wav")

func _start_final_wave() -> void:
	if final_wave_started:
		return
	final_wave_started=true
	chapter=6
	_show_notice("CHAPTER VI // LAST SIGNAL")
	for p in [Vector3(-5.2,0.9,-96),Vector3(5.2,0.9,-98),Vector3(-4.0,0.9,-102),Vector3(4.0,0.9,-104)]:
		_spawn_soldier(p,true)
	if enemy and is_instance_valid(enemy):
		enemy.health=320.0
		enemy.dead=false
		enemy.global_position=Vector3(0,0.9,-101)
		enemy.difficulty=1.45
	_play_radio_line("DISPATCH","The gate is powered, but a security counterattack is inbound. Hold the dead zone until the road is clear.","res://audio/voice_final_wave.wav")

func _play_radio_line(speaker: String, text_value: String, voice_path: String) -> void:
	_show_notice(speaker+" // RADIO")
	if voice_path != "" and ResourceLoader.exists(voice_path):
		voice_player.stream=load(voice_path)
		voice_player.play()

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
			_show_notice("RELAY %d ONLINE"%(i+1))
			if i == 0: _spawn_reinforcements(1)
			elif i == 1: _spawn_reinforcements(2)
			elif i == 2: _play_radio_line("BLACKWOOD CONTROL","All relays are online. Move to the dead-zone gate. Expect one final response.","res://audio/voice_relay_03.wav")
			_save_checkpoint()
			_update_objective()
			return
	for e in evidence_nodes:
		if is_instance_valid(e) and e.visible and player.global_position.distance_to(e.global_position)<2.1:
			e.visible=false; evidence_collected+=1; _show_notice("EVIDENCE %d/3"%evidence_collected); _save_checkpoint(); _update_objective(); return
	if terminal and player.global_position.distance_to(terminal.global_position)<2.5:
		camera_terminal_open=not camera_terminal_open; _show_notice("CAMERA GRID "+("ONLINE" if camera_terminal_open else "CLOSED")); return
	if extraction_gate and player.global_position.distance_to(extraction_gate.global_position)<3.2:
		if _relay_count()<3 or evidence_collected<2:
			_show_notice("GATE LOCKED // NEED POWER 3/3 AND EVIDENCE 2/3")
		elif not final_wave_started:
			_start_final_wave()
		elif final_wave_cleared:
			_finish_game()
		else:
			_show_notice("CLEAR THE COUNTERATTACK BEFORE EXTRACTION")

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
		story_flags["armed"]=true
		chapter=2
		_show_notice("CHAPTER II // ARMED RESPONSE")
		_play_radio_line("DISPATCH","Movement confirmed around the surveillance tower. Armed personnel are searching the road ahead.","res://audio/voice_chapter_02.wav")
	if z<-43 and not story_flags.has("stop"):
		story_flags["stop"]=true
		_show_notice("CHECKPOINT // ABANDONED STOP")
		_save_checkpoint()
	if z<-64 and not story_flags.has("cabin"):
		story_flags["cabin"]=true
		chapter=maxi(chapter,3)
		_show_notice("CHAPTER III // RANGER WOODS")
		_play_radio_line("BLACKWOOD CONTROL","The ranger cabin is close. Recover the rifle and resupply before continuing.","res://audio/voice_chapter_03.wav")
	if _relay_count()>=3 and not story_flags.has("dead_signal"):
		story_flags["dead_signal"]=true
		chapter=4
		_show_notice("CHAPTER IV // DEAD SIGNAL")
		_play_radio_line("ARCHIVE","All three relays are synchronized. The Faceless signal is now moving with you instead of behind you.","res://audio/voice_chapter_04.wav")
	if z<-92 and not story_flags.has("extract"):
		story_flags["extract"]=true
		chapter=5
		_show_notice("CHAPTER V // DEAD ZONE")

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
	if hud:
		hud.text="HP %03d  STA %03d  BAT %03d  %s %02d/%03d  KILLS %02d  CH.%d  %s"%[int(h),int(s),int(b),weapon,mag,reserve,kills,chapter,current_zone]

func _current_objective() -> Dictionary:
	if relay_active.size() >= 1 and not relay_active[0] and relays.size() > 0:
		return {"text":"GO TO RELAY 1 — restore checkpoint power","target":relays[0]}
	if evidence_nodes.size() > 0 and is_instance_valid(evidence_nodes[0]) and evidence_nodes[0].visible:
		return {"text":"RECOVER EVIDENCE 1 — case beside the road","target":evidence_nodes[0]}
	if relay_active.size() >= 2 and not relay_active[1] and relays.size() > 1:
		return {"text":"GO TO RELAY 2 — surveillance sector","target":relays[1]}
	if player and not player.rifle_unlocked and rifle_pickup and rifle_pickup.visible:
		return {"text":"GET THE RIFLE — ranger cabin","target":rifle_pickup}
	if evidence_nodes.size() > 1 and is_instance_valid(evidence_nodes[1]) and evidence_nodes[1].visible:
		return {"text":"RECOVER EVIDENCE 2","target":evidence_nodes[1]}
	if relay_active.size() >= 3 and not relay_active[2] and relays.size() > 2:
		return {"text":"GO TO RELAY 3 — dead-zone approach","target":relays[2]}
	if evidence_collected < 2:
		for e in evidence_nodes:
			if is_instance_valid(e) and e.visible:
				return {"text":"RECOVER ANOTHER EVIDENCE CASE","target":e}
	if final_wave_started and not final_wave_cleared:
		return {"text":"SURVIVE THE SECURITY COUNTERATTACK","target":extraction_gate}
	if final_wave_cleared:
		return {"text":"EXTRACT — interact with the dead-zone gate","target":extraction_gate}
	return {"text":"REACH THE DEAD-ZONE GATE — trigger final response","target":extraction_gate}

func _update_objective()->void:
	if objective_label == null or player == null:
		return
	var obj: Dictionary = _current_objective()
	var target: Node3D = obj.get("target") as Node3D
	var distance: float = 0.0
	if target != null:
		distance = player.global_position.distance_to(target.global_position)
	objective_label.text = "NEXT // %s   •   %.0f m" % [str(obj.get("text","")),distance]

func _save_checkpoint()->void:
	if player==null:return
	var cfg:=ConfigFile.new()
	cfg.set_value("save","mode",selected_mode); cfg.set_value("save","evidence",evidence_collected); cfg.set_value("save","z",player.global_position.z); cfg.set_value("save","chapter",chapter)
	for i in range(relay_active.size()): cfg.set_value("save","relay_"+str(i),relay_active[i])
	cfg.save("user://faceless2_save.cfg")

func set_crosshair_aiming(on: bool) -> void:
	if crosshair:
		crosshair.text = "·" if on else "+"
		crosshair.add_theme_font_size_override("font_size",18 if on else 24)

func _play_sfx(path: String, volume_db := -2.0) -> void:
	if sfx_player and ResourceLoader.exists(path):
		sfx_player.stop()
		sfx_player.stream=load(path)
		sfx_player.volume_db=volume_db
		sfx_player.play()

func play_footstep(running: bool) -> void:
	_play_sfx("res://audio/footstep_run.wav" if running else "res://audio/footstep.wav",-10.0)

func on_player_shot(weapon:String)->void:
	crosshair.modulate=Color(1.0,0.65,0.3,1.0)
	create_tween().tween_property(crosshair,"modulate",Color(0.9,0.94,0.95,0.86),0.10)
	_play_sfx("res://audio/rifle_shot.wav" if weapon=="RIFLE" else "res://audio/pistol_shot.wav",-1.0)

func weapon_event(t:String)->void:
	_show_notice(t)
	if t=="RELOADING":
		_play_sfx("res://audio/reload_click.wav",-4.0)

func soldier_fired(_s:Node)->void:
	fade.color=Color(0.5,0.06,0.02,0.18)
	create_tween().tween_property(fade,"color",Color(0,0,0,0),0.16)

func soldier_down(s:CharacterBody3D)->void:
	soldiers.erase(s)
	kills+=1
	var tw:=create_tween(); tw.tween_property(s,"rotation:z",1.35,0.24); tw.tween_interval(.2); tw.tween_callback(s.queue_free)
	_show_notice("HOSTILE DOWN")
	if final_wave_started and soldiers.is_empty():
		final_wave_cleared=true
		_show_notice("ROAD CLEAR // EXTRACTION AVAILABLE")
		_play_radio_line("BLACKWOOD CONTROL","Counterattack neutralized. The dead-zone gate is clear. Extract now.","res://audio/voice_final_clear.wav")
		_save_checkpoint()

func faceless_down(e:CharacterBody3D)->void:
	_show_notice("FACELESS DISRUPTED // IT WILL RETURN")
	var tw:=create_tween(); tw.tween_property(e,"position:y",-2.0,0.55); tw.tween_interval(4.0); tw.tween_callback(func(): if is_instance_valid(e): e.position=Vector3(0,0.9,-96); e.health=160.0; e.dead=false)

func player_hurt()->void:
	fade.color=Color(0.50,0.0,0.0,0.30)
	create_tween().tween_property(fade,"color",Color(0,0,0,0),0.24)
	if player and player.health < 35.0 and heartbeat_player and not heartbeat_player.playing:
		heartbeat_player.play()
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
