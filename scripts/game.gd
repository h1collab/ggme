extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const StalkerScript = preload("res://scripts/stalker.gd")

var player: CharacterBody3D
var stalker: CharacterBody3D
var objective_label: Label
var prompt_label: Label
var stats_label: Label
var vignette: ColorRect
var scare_flash: ColorRect
var power_on := false
var archive_key := false
var fuse_a := false
var fuse_b := false
var escaped := false
var spawn_pos := Vector3(-14, 1.05, 8)
var exit_blocker: StaticBody3D
var exit_visual: MeshInstance3D
var lights: Array[OmniLight3D] = []
var flicker_t := 0.0
var scare_clock := 8.0

func _ready():
	seed(20261002)
	_build_world_environment()
	_build_level()
	_build_player()
	_build_stalker()
	_build_ui()
	_update_objective()

func _process(delta):
	if escaped:
		return
	flicker_t += delta
	scare_clock -= delta
	if power_on and flicker_t > 0.08:
		flicker_t = 0.0
		for i in lights.size():
			var l := lights[i]
			l.light_energy = (2.1 + sin(Time.get_ticks_msec() * 0.001 * (2.0 + i * 0.13)) * 0.22) * (0.25 if randf() < 0.025 else 1.0)
	if scare_clock < 0.0:
		scare_clock = randf_range(13.0, 25.0)
		if randf() < 0.6 and player and stalker and player.global_position.distance_to(stalker.global_position) > 7.0:
			_trigger_visual_scare()

func _build_world_environment():
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.006, 0.009)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.075, 0.09)
	env.ambient_light_energy = 0.22
	env.fog_enabled = true
	env.fog_light_color = Color(0.055, 0.065, 0.075)
	env.fog_light_energy = 0.35
	env.fog_density = 0.026
	env.fog_height = 1.0
	env.fog_height_density = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

func _mat(c: Color, rough := 0.8, metallic := 0.0, emission := Color(0,0,0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metallic
	if emission != Color(0,0,0):
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 2.0
	return m

func _mesh_box(parent: Node, pos: Vector3, size: Vector3, mat: Material, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

func _static_box(pos: Vector3, size: Vector3, mat: Material, rot_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	add_child(body)
	_mesh_box(body, Vector3.ZERO, size, mat)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	return body

func _area(pos: Vector3, size: Vector3, kind: String, data := "") -> Area3D:
	var a := Area3D.new()
	a.position = pos
	a.set_meta("interact_kind", kind)
	a.set_meta("data", data)
	add_child(a)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	return a

func _build_level():
	var floor_m := _mat(Color(0.055,0.06,0.062), 0.92)
	var wall_m := _mat(Color(0.16,0.18,0.17), 0.95)
	var green_m := _mat(Color(0.075,0.12,0.105), 0.88)
	var wood_m := _mat(Color(0.16,0.09,0.055), 0.72)
	var metal_m := _mat(Color(0.10,0.11,0.12), 0.35, 0.55)
	var red_m := _mat(Color(0.15,0.012,0.014), 0.85)
	_static_box(Vector3(0,-0.25,0), Vector3(38,0.5,28), floor_m)
	_static_box(Vector3(0,3.35,0), Vector3(38,0.35,28), _mat(Color(0.035,0.04,0.043),1.0))
	_static_box(Vector3(-19,1.6,0), Vector3(0.45,3.2,28), wall_m)
	_static_box(Vector3(19,1.6,0), Vector3(0.45,3.2,28), wall_m)
	_static_box(Vector3(0,1.6,-14), Vector3(38,3.2,0.45), wall_m)
	_static_box(Vector3(0,1.6,14), Vector3(38,3.2,0.45), wall_m)
	for x in [-11.0,-3.5,4.5,12.0]:
		_static_box(Vector3(x,1.6,-5.2), Vector3(0.3,3.2,10.2), wall_m)
		_static_box(Vector3(x,1.6,6.0), Vector3(0.3,3.2,8.0), wall_m)
	for x in [-15.0,-7.2,0.5,8.3,15.3]:
		_static_box(Vector3(x,1.6,2.0), Vector3(4.0,3.2,0.28), green_m)
	for p in [Vector3(-11,1.25,2),Vector3(-3.5,1.25,2),Vector3(4.5,1.25,2),Vector3(12,1.25,2)]:
		_mesh_box(self,p+Vector3(0,0,0.12),Vector3(1.55,2.5,0.12),wood_m)
	for rx in [-15.0,-7.0,1.0,9.0,15.0]:
		for z in [-9.5,-7.0,7.0,10.0]:
			_mesh_box(self,Vector3(rx,0.45,z),Vector3(2.2,0.12,0.9),wood_m)
			for sx in [-0.85,0.85]:
				_mesh_box(self,Vector3(rx+sx,0.22,z),Vector3(0.11,0.45,0.11),metal_m)
	for z in [-11.2,-8.9,-6.6,7.6,9.9,12.2]:
		for x in [-17.2,17.2]:
			_mesh_box(self,Vector3(x,1.05,z),Vector3(1.0,2.1,0.55),metal_m)
	for x in range(-16,17,4):
		for z in [-2.0,4.0]:
			_mesh_box(self,Vector3(x,3.05,z),Vector3(1.3,0.07,0.32),_mat(Color(0.7,0.76,0.68),0.6,0.0,Color(0.18,0.22,0.16)))
			var l := OmniLight3D.new()
			l.position = Vector3(x,2.72,z)
			l.omni_range = 8.0
			l.light_energy = 0.22
			l.light_color = Color(0.73,0.86,0.72)
			l.shadow_enabled = true
			add_child(l)
			lights.append(l)
	for i in range(18):
		var s := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = randf_range(0.08,0.28)
		cyl.bottom_radius = cyl.top_radius
		cyl.height = 0.008
		s.mesh = cyl
		s.material_override = red_m
		s.position = Vector3(-8.0+i*0.85,0.015,randf_range(-0.7,0.7))
		add_child(s)
	_make_pickup(Vector3(-15.5,0.9,-10.5),"fuse_a",Color(0.9,0.45,0.08),"保险丝 A")
	_make_pickup(Vector3(14.6,0.9,10.6),"fuse_b",Color(0.9,0.45,0.08),"保险丝 B")
	_make_pickup(Vector3(8.5,0.75,-10.0),"archive_key",Color(0.75,0.65,0.2),"档案室钥匙")
	_mesh_box(self,Vector3(-17.8,1.25,-1.6),Vector3(0.18,1.0,0.72),metal_m)
	_area(Vector3(-17.5,1.25,-1.6),Vector3(0.9,1.4,1.2),"power_panel")
	exit_blocker = _static_box(Vector3(0,1.4,13.55),Vector3(3.2,2.8,0.35),metal_m)
	exit_visual = exit_blocker.get_child(0)
	_area(Vector3(0,1.25,12.8),Vector3(3.8,2.6,1.1),"exit")
	for p in [Vector3(-17.4,2.35,0),Vector3(17.4,2.35,0),Vector3(0,2.35,12.9)]:
		_mesh_box(self,p,Vector3(0.4,0.18,0.08),_mat(Color(0.15,0.02,0.02),0.6,0.0,Color(0.7,0.015,0.01)))

func _make_pickup(pos: Vector3, kind: String, col: Color, label: String):
	var a := _area(pos,Vector3(0.9,1.0,0.9),kind,label)
	var mi := _mesh_box(a,Vector3.ZERO,Vector3(0.28,0.36,0.12),_mat(col,0.32,0.45,col*0.08))
	mi.rotation = Vector3(0.2,0.4,0.1)

func _build_player():
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = spawn_pos
	player.set_script(PlayerScript)
	player.game = self
	add_child(player)
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.38
	sh.height = 1.75
	cs.shape = sh
	cs.position.y = 0.88
	player.add_child(cs)

func _build_stalker():
	stalker = CharacterBody3D.new()
	stalker.name = "NightWarden"
	stalker.position = Vector3(12,0.9,-7)
	stalker.set_script(StalkerScript)
	stalker.game = self
	stalker.player = player
	add_child(stalker)
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.43
	sh.height = 1.9
	cs.shape = sh
	cs.position.y = 0.95
	stalker.add_child(cs)
	var body_m := _mat(Color(0.018,0.02,0.024),0.9)
	var skin_m := _mat(Color(0.18,0.19,0.16),0.82)
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.48
	cap.height = 1.75
	torso.mesh = cap
	torso.material_override = body_m
	torso.position.y = 1.0
	stalker.add_child(torso)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.31
	sph.height = 0.62
	head.mesh = sph
	head.material_override = skin_m
	head.position = Vector3(0,1.92,0)
	stalker.add_child(head)
	for sx in [-0.11,0.11]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.035
		em.height = 0.07
		eye.mesh = em
		eye.material_override = _mat(Color(0.65,0.02,0.01),0.2,0.0,Color(1.0,0.01,0.0))
		eye.position = Vector3(sx,2.0,-0.285)
		stalker.add_child(eye)
	stalker.patrol=[Vector3(12,0.9,-7),Vector3(12,0.9,8),Vector3(3,0.9,8),Vector3(3,0.9,-8),Vector3(-8,0.9,-8),Vector3(-8,0.9,9),Vector3(-15,0.9,9),Vector3(-15,0.9,-8)]

func _build_ui():
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := ColorRect.new()
	top.color = Color(0,0,0,0.42)
	top.position = Vector2(24,22)
	top.size = Vector2(610,92)
	layer.add_child(top)
	objective_label = Label.new()
	objective_label.position = Vector2(18,12)
	objective_label.size = Vector2(570,34)
	objective_label.add_theme_font_size_override("font_size",24)
	top.add_child(objective_label)
	stats_label = Label.new()
	stats_label.position = Vector2(18,50)
	stats_label.size = Vector2(570,28)
	stats_label.add_theme_font_size_override("font_size",17)
	top.add_child(stats_label)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(430,720)
	prompt_label.size = Vector2(740,56)
	prompt_label.add_theme_font_size_override("font_size",25)
	layer.add_child(prompt_label)
	var cross := Label.new()
	cross.text = "+"
	cross.position = Vector2(790,435)
	cross.add_theme_font_size_override("font_size",24)
	layer.add_child(cross)
	var hint := Label.new()
	hint.text = "左侧拖动移动 ｜ 右侧拖动观察 ｜ 轻点右侧交互 ｜ F 手电筒"
	hint.position = Vector2(420,842)
	hint.size = Vector2(760,34)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1,1,1,0.5)
	layer.add_child(hint)
	var fb := Button.new()
	fb.text = "手电"
	fb.position = Vector2(1450,770)
	fb.size = Vector2(118,66)
	fb.pressed.connect(player.toggle_flashlight)
	layer.add_child(fb)
	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0.03,0,0,0)
	layer.add_child(vignette)
	scare_flash = ColorRect.new()
	scare_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scare_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scare_flash.color = Color(0.7,0.82,0.85,0)
	layer.add_child(scare_flash)

func describe_interaction(c: Object) -> String:
	var k := str(c.get_meta("interact_kind"))
	match k:
		"fuse_a","fuse_b","archive_key":
			return "轻点：拾取 %s" % str(c.get_meta("data"))
		"power_panel":
			return "轻点：检修配电箱" if not power_on else "配电箱已恢复供电"
		"exit":
			return "轻点：尝试打开正门"
	return ""

func interact(c: Object):
	var k := str(c.get_meta("interact_kind"))
	match k:
		"fuse_a":
			fuse_a = true
			_consume(c)
			_notify("获得保险丝 A")
		"fuse_b":
			fuse_b = true
			_consume(c)
			_notify("获得保险丝 B")
		"archive_key":
			archive_key = true
			_consume(c)
			_notify("拿到档案室钥匙……远处有脚步声")
		"power_panel":
			if fuse_a and fuse_b:
				power_on = true
				_notify("电力恢复。正门磁锁仍需档案室钥匙。")
				_power_flash()
			else:
				_notify("缺少保险丝。配电箱无法启动。")
		"exit":
			if power_on and archive_key:
				_escape()
			elif not power_on:
				_notify("磁锁没有供电。")
			else:
				_notify("需要档案室钥匙解除机械锁。")
	_update_objective()

func _consume(a: Area3D):
	a.set_meta("interact_kind","")
	a.visible = false
	for child in a.get_children():
		if child is CollisionShape3D:
			child.disabled = true

func _update_objective():
	if not objective_label:
		return
	if escaped:
		objective_label.text = "你逃出了黑松疗养院"
		return
	if not fuse_a or not fuse_b:
		objective_label.text = "目标：找到两枚保险丝并恢复电力 (%d/2)" % [int(fuse_a)+int(fuse_b)]
	elif not power_on:
		objective_label.text = "目标：回到西侧配电箱恢复供电"
	elif not archive_key:
		objective_label.text = "目标：找到档案室钥匙"
	else:
		objective_label.text = "目标：前往南侧正门逃离"

func update_player_stats(stamina: float, battery: float, lamp_on: bool):
	if stats_label:
		stats_label.text = "体力 %03d%%    手电 %03d%% %s" % [int(stamina),int(battery),"●" if lamp_on else "○"]

func set_prompt(t: String):
	if prompt_label:
		prompt_label.text = t

func set_chase_intensity(v: float):
	if vignette:
		vignette.color = Color(0.18,0,0,0.08+v*0.24)

func _notify(t: String):
	prompt_label.text = t
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(_clear_prompt.bind(t))

func _power_flash():
	for l in lights:
		l.light_energy = 3.5
	var tw := create_tween()
	tw.tween_method(_set_cold_flash_alpha,0.45,0.0,0.35)

func _trigger_visual_scare():
	var tw := create_tween()
	tw.tween_method(_set_scare_flash_alpha,0.0,0.16,0.05)
	tw.tween_method(_set_scare_flash_alpha,0.16,0.0,0.14)

func player_caught():
	player.freeze_for_catch()
	_notify("你被值夜人抓住了……")
	var tw := create_tween()
	tw.tween_method(_set_red_flash_alpha,0.0,0.82,0.35)
	tw.tween_interval(0.55)
	tw.tween_callback(_reset_after_catch)
	tw.tween_method(_set_red_flash_alpha,0.82,0.0,0.45)

func _reset_after_catch():
	player.reset_after_catch(spawn_pos)
	stalker.global_position = Vector3(12,0.9,-7)
	stalker.state = "PATROL"
	stalker.patrol_i = 0

func _escape():
	escaped = true
	if exit_blocker:
		for child in exit_blocker.get_children():
			if child is CollisionShape3D:
				child.disabled = true
	var tw := create_tween()
	tw.tween_property(exit_visual,"position:y",3.4,1.4).set_trans(Tween.TRANS_QUAD)
	_update_objective()
	_notify("大门开启。你终于离开了这里。")

func _clear_prompt(expected: String):
	if prompt_label and prompt_label.text == expected:
		prompt_label.text = ""

func _set_cold_flash_alpha(a: float):
	if scare_flash:
		scare_flash.color = Color(0.7,0.86,0.8,a)

func _set_scare_flash_alpha(a: float):
	if scare_flash:
		scare_flash.color = Color(0.75,0.8,0.82,a)

func _set_red_flash_alpha(a: float):
	if scare_flash:
		scare_flash.color = Color(0.45,0.0,0.0,a)
