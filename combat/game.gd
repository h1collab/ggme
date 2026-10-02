extends Node3D

const PlayerScript=preload("res://scripts/player.gd")
const TeacherScript=preload("res://scripts/stalker.gd")
const JoystickScript=preload("res://scripts/virtual_joystick.gd")

var player:CharacterBody3D
var teachers:Array[CharacterBody3D]=[]
var wave:=1
var score:=0
var combo:=0
var combo_timer:=0.0
var spawn_points=[
	Vector3(-12,0.9,-8),Vector3(12,0.9,-8),Vector3(-12,0.9,8),
	Vector3(12,0.9,8),Vector3(0,0.9,-10),Vector3(0,0.9,10)
]
var hud:Label
var notice:Label
var main_menu:Control
var settings_panel:Control
var overlay:ColorRect
var joystick:Control
var game_started:=false
var settings={"quality":2,"fps":60,"sensitivity":1.0,"volume":0.85}

func _ready():
	_build_world()
	_build_ui()
	_apply_settings()
	get_tree().paused=true

func _process(delta):
	if not game_started:return
	combo_timer-=delta
	if combo_timer<=0.0: combo=0
	if teachers.is_empty():
		wave+=1
		_show_notice("WAVE %d" % wave)
		_spawn_wave()

func _mat(c:Color,rough:=0.85,metal:=0.0)->StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=rough
	m.metallic=metal
	return m

func _mesh_box(parent:Node,pos:Vector3,size:Vector3,mat:Material):
	var mi:=MeshInstance3D.new()
	var b:=BoxMesh.new()
	b.size=size
	mi.mesh=b
	mi.material_override=mat
	mi.position=pos
	parent.add_child(mi)
	return mi

func _static_box(pos:Vector3,size:Vector3,mat:Material):
	var body:=StaticBody3D.new()
	body.position=pos
	add_child(body)
	_mesh_box(body,Vector3.ZERO,size,mat)
	var cs:=CollisionShape3D.new()
	var sh:=BoxShape3D.new()
	sh.size=size
	cs.shape=sh
	body.add_child(cs)

func _build_world():
	var world:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0.055,0.075,0.10)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(0.48,0.56,0.66)
	env.ambient_light_energy=0.55
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	world.environment=env
	add_child(world)
	var floor_mat=_mat(Color(0.47,0.45,0.40),0.95)
	var wall_mat=_mat(Color(0.76,0.78,0.72),0.93)
	var blue=_mat(Color(0.10,0.22,0.34),0.78)
	var wood=_mat(Color(0.37,0.20,0.10),0.82)
	_static_box(Vector3(0,-0.25,0),Vector3(32,0.5,24),floor_mat)
	_static_box(Vector3(-16,1.6,0),Vector3(0.4,3.2,24),wall_mat)
	_static_box(Vector3(16,1.6,0),Vector3(0.4,3.2,24),wall_mat)
	_static_box(Vector3(0,1.6,-12),Vector3(32,3.2,0.4),wall_mat)
	_static_box(Vector3(0,1.6,12),Vector3(32,3.2,0.4),wall_mat)
	for z in [-4.2,4.2]:
		for x in [-10.5,-3.5,3.5,10.5]:
			_mesh_box(self,Vector3(x,0.55,z),Vector3(2.5,0.12,1.0),wood)
			for sx in [-1.0,1.0]:
				_mesh_box(self,Vector3(x+sx,0.27,z),Vector3(0.12,0.54,0.12),blue)
	for x in range(-12,13,4):
		_mesh_box(self,Vector3(x,3.0,0),Vector3(1.2,0.08,0.3),_mat(Color(0.9,0.95,1.0),0.4))
		var l:=OmniLight3D.new()
		l.position=Vector3(x,2.65,0)
		l.omni_range=7.0
		l.light_energy=1.6
		add_child(l)
	for z in [-9.4,9.4]:
		for x in [-13.8,13.8]:
			_mesh_box(self,Vector3(x,1.1,z),Vector3(1.0,2.2,0.55),blue)

func _build_ui():
	var layer:=CanvasLayer.new()
	layer.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	overlay=ColorRect.new()
	overlay.color=Color(0.05,0.07,0.10,0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	hud=Label.new()
	hud.position=Vector2(28,22)
	hud.size=Vector2(900,48)
	hud.add_theme_font_size_override("font_size",24)
	hud.text="HEALTH 100   STAMINA 100   SCORE 0"
	layer.add_child(hud)
	notice=Label.new()
	notice.position=Vector2(420,80)
	notice.size=Vector2(760,70)
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size",34)
	layer.add_child(notice)
	joystick=Control.new()
	joystick.set_script(JoystickScript)
	joystick.position=Vector2(40,650)
	joystick.size=Vector2(190,190)
	layer.add_child(joystick)
	var hit:=Button.new()
	hit.text="HIT"
	hit.position=Vector2(1390,700)
	hit.size=Vector2(150,74)
	hit.add_theme_font_size_override("font_size",26)
	hit.pressed.connect(func(): if player: player.attack(1.0))
	layer.add_child(hit)
	var kick:=Button.new()
	kick.text="KICK"
	kick.position=Vector2(1218,748)
	kick.size=Vector2(150,74)
	kick.add_theme_font_size_override("font_size",24)
	kick.pressed.connect(func(): if player: player.attack(1.7))
	layer.add_child(kick)
	main_menu=_panel(Vector2(430,145),Vector2(740,560),Color(0.025,0.035,0.055,0.94))
	var title:=Label.new()
	title.text="SCHOOL BRAWL"
	title.position=Vector2(48,42)
	title.size=Vector2(640,70)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",52)
	main_menu.add_child(title)
	var sub:=Label.new()
	sub.text="ARCADE CAMPUS MAYHEM"
	sub.position=Vector2(48,112)
	sub.size=Vector2(640,36)
	sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size",20)
	sub.modulate=Color(0.65,0.74,0.86)
	main_menu.add_child(sub)
	var by:=Label.new()
	by.text="made by zorix"
	by.position=Vector2(48,152)
	by.size=Vector2(640,34)
	by.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	by.modulate=Color(0.82,0.58,0.94)
	main_menu.add_child(by)
	var play:=_menu_button("PLAY",Vector2(170,230),Vector2(400,64))
	play.pressed.connect(_start_game)
	main_menu.add_child(play)
	var settings:=_menu_button("SETTINGS",Vector2(170,310),Vector2(400,64))
	settings.pressed.connect(_show_settings)
	main_menu.add_child(settings)
	var info:=Label.new()
	info.text="Fight fictional staff NPCs, build combos, clear waves.\nNo gore — fast arcade knockouts."
	info.position=Vector2(90,410)
	info.size=Vector2(560,80)
	info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size",18)
	info.modulate=Color(0.72,0.77,0.84)
	main_menu.add_child(info)
	layer.add_child(main_menu)
	settings_panel=_build_settings_panel()
	layer.add_child(settings_panel)
	settings_panel.visible=false

func _panel(pos:Vector2,sz:Vector2,c:Color)->ColorRect:
	var p:=ColorRect.new()
	p.position=pos
	p.size=sz
	p.color=c
	return p

func _menu_button(text:String,pos:Vector2,sz:Vector2)->Button:
	var b:=Button.new()
	b.text=text
	b.position=pos
	b.size=sz
	b.add_theme_font_size_override("font_size",24)
	return b

func _build_settings_panel()->Control:
	var p:=_panel(Vector2(470,150),Vector2(660,560),Color(0.025,0.035,0.055,0.97))
	var title:=Label.new()
	title.text="SETTINGS"
	title.position=Vector2(35,28)
	title.add_theme_font_size_override("font_size",36)
	p.add_child(title)
	var ql:=Label.new(); ql.text="QUALITY"; ql.position=Vector2(45,105); p.add_child(ql)
	var q:=OptionButton.new(); q.position=Vector2(300,95); q.size=Vector2(300,50)
	for t in ["PERFORMANCE","BALANCED","HIGH QUALITY","ULTRA"]: q.add_item(t)
	q.select(settings.quality)
	q.item_selected.connect(func(i): settings.quality=i; _apply_settings())
	p.add_child(q)
	var fl:=Label.new(); fl.text="FPS LIMIT"; fl.position=Vector2(45,175); p.add_child(fl)
	var fps:=OptionButton.new(); fps.position=Vector2(300,165); fps.size=Vector2(300,50)
	for t in ["30","60","120"]: fps.add_item(t)
	fps.select(1)
	fps.item_selected.connect(func(i): settings.fps=[30,60,120][i]; _apply_settings())
	p.add_child(fps)
	var sl:=Label.new(); sl.text="LOOK SENSITIVITY"; sl.position=Vector2(45,245); p.add_child(sl)
	var s:=HSlider.new(); s.position=Vector2(300,235); s.size=Vector2(300,40); s.min_value=0.5;s.max_value=2.0;s.step=0.05;s.value=settings.sensitivity
	s.value_changed.connect(func(v): settings.sensitivity=v)
	p.add_child(s)
	var vl:=Label.new(); vl.text="MASTER VOLUME"; vl.position=Vector2(45,315); p.add_child(vl)
	var v:=HSlider.new(); v.position=Vector2(300,305); v.size=Vector2(300,40); v.min_value=0.0;v.max_value=1.0;v.step=0.05;v.value=settings.volume
	v.value_changed.connect(func(x): settings.volume=x; AudioServer.set_bus_volume_db(0,linear_to_db(max(x,0.001))))
	p.add_child(v)
	var back:=_menu_button("BACK",Vector2(180,440),Vector2(300,60))
	back.pressed.connect(func(): settings_panel.visible=false; main_menu.visible=true)
	p.add_child(back)
	return p

func _apply_settings():
	Engine.max_fps=int(settings.fps)
	var q=int(settings.quality)
	get_viewport().scaling_3d_scale=[0.65,0.82,1.0,1.15][q]
	get_viewport().msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_4X][q]

func _show_settings():
	main_menu.visible=false
	settings_panel.visible=true

func _start_game():
	main_menu.visible=false
	settings_panel.visible=false
	get_tree().paused=false
	game_started=true
	_spawn_player()
	_spawn_wave()
	_show_notice("WAVE 1")

func _spawn_player():
	if player:return
	player=CharacterBody3D.new()
	player.name="Player"
	player.position=Vector3(0,0.9,0)
	player.set_script(PlayerScript)
	player.game=self
	add_child(player)
	player.joystick=joystick

func _spawn_wave():
	var count=min(2+wave,8)
	for i in count:
		var t:=CharacterBody3D.new()
		t.position=spawn_points[i%spawn_points.size()]
		t.set_script(TeacherScript)
		t.game=self
		t.player=player
		t.hp=60.0+wave*8.0
		t.move_speed=min(2.5+wave*0.12,4.2)
		add_child(t)
		teachers.append(t)

func player_melee_attack(power:float):
	if not player:return
	var best:CharacterBody3D
	var best_d:=2.25
	for t in teachers:
		if not is_instance_valid(t):continue
		var to_t:=t.global_position-player.global_position
		var d:=to_t.length()
		if d<best_d:
			var facing:Vector3=-player.global_transform.basis.z
			if facing.dot(to_t.normalized())>0.30:
				best=t;best_d=d
	if best:
		var dir:=(best.global_position-player.global_position).normalized()
		best.take_hit(24.0*power,dir*(5.0+power*2.0))
		combo+=1
		combo_timer=2.4
		score+=int(100*power*max(1,combo))
		_show_notice("COMBO x%d" % combo)
	else:
		_show_notice("MISS")

func teacher_ko(t:CharacterBody3D):
	teachers.erase(t)
	score+=500
	var tw:=create_tween()
	tw.tween_property(t,"rotation:z",1.45,0.28)
	tw.parallel().tween_property(t,"position:y",0.25,0.28)
	tw.tween_interval(0.35)
	tw.tween_callback(t.queue_free)
	_show_notice("K.O.  +500")

func player_hurt():
	overlay.color=Color(0.55,0.03,0.03,0.28)
	var tw:=create_tween()
	tw.tween_property(overlay,"color",Color(0.05,0.07,0.10,0.0),0.25)

func player_knocked_out():
	game_started=false
	_show_notice("KNOCKED OUT")
	for t in teachers:
		if is_instance_valid(t): t.queue_free()
	teachers.clear()
	var tw:=create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(_restart_round)

func _restart_round():
	player.global_position=Vector3(0,0.9,0)
	player.restore()
	wave=1
	score=0
	combo=0
	game_started=true
	_spawn_wave()
	_show_notice("ROUND RESTART")

func update_player_hud(h:float,s:float):
	if hud:
		hud.text="HEALTH %03d   STAMINA %03d   SCORE %06d   WAVE %02d" % [int(h),int(s),score,wave]

func _show_notice(t:String):
	if not notice:return
	notice.text=t
	var tw:=create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func(): if notice.text==t: notice.text="")
