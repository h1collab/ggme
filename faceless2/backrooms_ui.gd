extends Control

const Joystick = preload("virtual_joystick.gd")
const TouchAction = preload("touch_action.gd")
const PAPER := Color(0.87, 0.87, 0.79)
const MUTED := Color(0.51, 0.57, 0.53)
const ACCENT := Color(0.70, 0.78, 0.54)
var game: Node
var canvas: Control
var hud: Control
var panels: Control
var joystick: Control
var modal := true
var monitoring := false
var result_shown := false
var run_held := false
var selected_camera := 0
var monitor_view: SubViewport
var monitor_camera: Camera3D
var status_label: Label
var goal_label: Label
var prompt_label: Label
var meter_label: Label
var console_status: Label
var room_status: Label
var address_field: LineEdit
var port_field: SpinBox
var key_field: LineEdit
var upnp_box: CheckBox
var door_buttons: Array = []
var camera_buttons: Array = []
var light_button: Button
var fan_button: Button
var generator_button: Button
var intro_timer: Timer
var intro_elapsed := 0.0
var notice_label: Label
var monitor_notice: Label
var panel_kind := ""
var objective_label: Label
var subtitle_label: Label

func _ready() -> void:
	var font_path := "res://assets/vendor/story_font.otf" if ResourceLoader.exists("res://assets/vendor/story_font.otf") else "res://faceless2/assets/vendor/story_font.otf"
	if ResourceLoader.exists(font_path):
		theme = Theme.new()
		theme.default_font = load(font_path)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = Control.new()
	canvas.size = Vector2(1600, 900)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_build_hud()
	panels = Control.new()
	panels.size = Vector2(1600, 900)
	canvas.add_child(panels)
	monitor_view = SubViewport.new()
	monitor_view.size = Vector2i(960, 540)
	monitor_view.world_3d = game.get_viewport().world_3d
	monitor_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	monitor_view.msaa_3d = Viewport.MSAA_DISABLED
	add_child(monitor_view)
	monitor_camera = Camera3D.new()
	monitor_camera.fov = 72
	monitor_camera.current = true
	monitor_camera.near = 0.05
	monitor_camera.cull_mask = 1
	monitor_view.add_child(monitor_camera)
	retarget_camera()

func _fit() -> void:
	var extent := get_viewport().get_visible_rect().size
	var factor := minf(extent.x / 1600, extent.y / 900)
	var safe := DisplayServer.get_display_safe_area()
	if OS.has_feature("android") and safe.size.x > 0:
		var physical_to_canvas := extent / Vector2(get_window().size)
		var safe_size := Vector2(safe.size) * physical_to_canvas
		var safe_position := Vector2(safe.position) * physical_to_canvas
		factor = minf(safe_size.x / 1600, safe_size.y / 900)
		canvas.position = safe_position + (safe_size - Vector2(1600, 900) * factor) * 0.5
		print("ANDROID_LAYOUT / logical=", extent, " physical=", get_window().size, " safe=", safe)
	else: canvas.position = (extent - Vector2(1600, 900) * factor) * 0.5
	canvas.scale = Vector2.ONE * factor

func _style(color: Color, border: Color = Color(0.25, 0.30, 0.25)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func _card(parent: Node, rect: Rect2, color: Color = Color(0.045, 0.06, 0.05, 0.96)) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(color))
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, pos: Vector2, width: float, font_size: int = 22, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(width, font_size * 2.8)
	parent.add_child(label)
	label.text = text
	label.size = Vector2(width, font_size * 2.8)
	return label

func _button(parent: Node, text: String, rect: Rect2, callback: Callable, touch: bool = false) -> Button:
	var button: Button = TouchAction.new() if touch else Button.new()
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.10, 0.085, 0.96)))
	button.add_theme_stylebox_override("hover", _style(Color(0.17, 0.22, 0.15), ACCENT))
	button.add_theme_stylebox_override("pressed", _style(Color(0.25, 0.31, 0.19), ACCENT))
	button.pressed.connect(callback)
	parent.add_child(button)
	# Shape after the final font/theme and tree are available.
	button.text = text
	button.size = rect.size
	return button

func _image(parent: Node, path: String, rect: Rect2, crop: bool = false) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = rect.position
	image.size = rect.size
	var texture: Texture2D = load(path)
	if crop:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(291, 297, 769, 767)
		texture = atlas
	image.texture = texture
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _build_hud() -> void:
	hud = Control.new()
	hud.size = Vector2(1600, 900)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	_card(hud, Rect2(38, 30, 520, 94), Color(0.035, 0.05, 0.04, 0.86))
	status_label = _label(hud, "", Vector2(58, 43), 480, 20, ACCENT)
	goal_label = _label(hud, "", Vector2(58, 76), 480, 18)
	_card(hud, Rect2(1020, 30, 360, 94), Color(0.035, 0.05, 0.04, 0.86))
	meter_label = _label(hud, "", Vector2(1040, 43), 330, 21)
	_button(hud, "II", Rect2(1410, 30, 135, 76), open_pause, true)
	prompt_label = _label(hud, "", Vector2(460, 695), 680, 22, ACCENT)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label = _label(hud, "", Vector2(475, 754), 650, 19)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cross := _label(hud, "·", Vector2(787, 432), 26, 25)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	joystick = Joystick.new()
	joystick.position = Vector2(72, 645)
	joystick.size = Vector2(190, 190)
	hud.add_child(joystick)
	_button(hud, "USE / E", Rect2(1340, 670, 205, 82), func(): game.interact(), true)
	_button(hud, "TORCH / F", Rect2(1340, 780, 205, 68), func(): game.player.torch.visible = not game.player.torch.visible, true)
	var run := _button(hud, "RUN", Rect2(305, 750, 150, 78), func(): pass, true)
	run.button_down.connect(func(): run_held = true)
	run.button_up.connect(func(): run_held = false)
	_label(hud, "DRAG RIGHT TO LOOK", Vector2(1020, 846), 315, 16, MUTED)
	_card(hud, Rect2(38, 148, 660, 86), Color(0.025, 0.04, 0.035, 0.84))
	objective_label = _label(hud, "", Vector2(58, 163), 620, 21, ACCENT)
	subtitle_label = _label(hud, "", Vector2(460, 600), 760, 24, PAPER)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _clear(kind: String) -> void:
	# A panel must never leave the player locked in a scripted attention hold.
	if is_instance_valid(game) and is_instance_valid(game.player): game.player.cancel_focus()
	panel_kind = kind
	print("UI_SCREEN / " + kind)
	for child in panels.get_children():
		panels.remove_child(child)
		child.queue_free()
	modal = true
	monitoring = false
	run_held = false
	joystick.reset()
	hud.visible = false
	panels.visible = true
	monitor_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	console_status = null
	monitor_notice = null
	room_status = null

func intro() -> void:
	_clear("intro")
	_card(panels, Rect2(0, 0, 1600, 900), Color(0.025, 0.04, 0.055))
	_image(panels, _brand_file("team_logo.jpg"), Rect2(650, 190, 300, 300), true)
	var text := _label(panels, "Made By Zorix GAme Team", Vector2(350, 545), 900, 40)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var detail := _label(panels, "A SURVEY OF IMPOSSIBLE SPACES", Vector2(350, 625), 900, 18, MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(panels, "CONTINUE", Rect2(660, 740, 280, 62), menu)
	intro_timer = Timer.new()
	intro_timer.one_shot = true
	intro_timer.wait_time = 3.2
	intro_timer.timeout.connect(func(): if panel_kind == "intro": menu())
	add_child(intro_timer)
	intro_timer.start()

func menu() -> void:
	_clear("menu")
	if not game.running:
		game.player.reset_to(Vector3(0, 0.05, 0))
		game.player.yaw = -0.42
		game.player.rotation.y = -0.42
	_card(panels, Rect2(0, 0, 730, 900), Color(0.025, 0.04, 0.032, 0.97))
	_image(panels, _brand_file("game_icon.png"), Rect2(66, 58, 92, 92))
	_label(panels, "ZORIX / FIELD RECORDINGS", Vector2(185, 80), 480, 20, ACCENT)
	_label(panels, "BACKROOMS", Vector2(65, 218), 700, 68)
	_label(panels, "NIGHT RELAY", Vector2(70, 307), 620, 36, ACCENT)
	_label(panels, "找回失联搭档的记录。\n维持供电，走过三层没有出口的空间。", Vector2(72, 405), 590, 25, MUTED)
	_button(panels, "开始剧情调查     →", Rect2(72, 535, 570, 80), func(): game.start_solo())
	_button(panels, "COOPERATIVE / DIRECT P2P", Rect2(72, 635, 570, 72), open_lobby)
	_button(panels, "FIELD GUIDE", Rect2(72, 728, 275, 64), open_guide)
	_button(panels, "ABOUT US", Rect2(367, 728, 275, 64), open_about)
	_button(panels, "SETTINGS", Rect2(1220, 45, 305, 65), open_settings)
	_label(panels, "三层空间  /  1–4 人  /  环境与目击恐怖", Vector2(72, 835), 620, 16, MUTED)
	_card(panels, Rect2(1040, 640, 490, 154), Color(0.03, 0.05, 0.035, 0.86))
	_label(panels, "00 / THE OFFICES", Vector2(1066, 666), 440, 25, ACCENT)
	_label(panels, "林岚的求救来自这栋楼。\n但它在十年前就被拆除了。", Vector2(1066, 709), 430, 20)

func open_briefing() -> void:
	_page(game.story.BRIEFINGS[game.stage][0], "briefing")
	var briefing := _label(panels, game.story.BRIEFINGS[game.stage][1], Vector2(75, 235), 1410, 31)
	briefing.size.y = 220
	_card(panels, Rect2(75, 475, 1400, 150), Color(0.06, 0.08, 0.055))
	_label(panels, "本层目标", Vector2(100, 492), 1320, 26, ACCENT)
	_label(panels, game.story.BRIEFINGS[game.stage][2], Vector2(100, 540), 1310, 25)
	_label(panels, "移动：WASD / 左摇杆    交互：E / USE    手电：F / TORCH\n听到脚步时可以停下观察；手动移动视角可打断自动转头。", Vector2(75, 660), 1400, 22, MUTED)
	_button(panels, "我明白了 / 进入本层", Rect2(75, 775, 1380, 78), close_panels)

func close_panels() -> void:
	panel_kind = "play"
	print("UI_SCREEN / play")
	modal = false
	monitoring = false
	result_shown = false
	panels.visible = false
	hud.visible = true
	monitor_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("android") else Input.MOUSE_MODE_CAPTURED

func _page(title: String, kind: String) -> void:
	_clear(kind)
	_card(panels, Rect2(0, 0, 1600, 900), Color(0.025, 0.04, 0.035, 1.0))
	_label(panels, "ZORIX / NIGHT RELAY", Vector2(72, 45), 800, 18, ACCENT)
	_label(panels, title, Vector2(72, 105), 1250, 42)
	_button(panels, "BACK", Rect2(1320, 48, 205, 62), func(): close_panels() if game.running else menu())

func open_guide() -> void:
	_page("任务与操作说明", "guide")
	var entries := [
		["01 / 你为什么在这里", "你进入了失联搭档林岚最后发出求救的建筑。恢复中继，就能追踪她的记录并启动返回电梯。"],
		["02 / 先修复三个节点", "跟随左上角的方向与距离提示；走到节点附近按 E 或 USE。每个节点恢复 9% 电力。"],
		["03 / 再观察监控", "回调查站查看三个摄像头，报告出现闪烁的那一路。正确报告三次；误报会扣除 6% 电力。"],
		["04 / 管理电力并撤离", "闸门降低干扰但耗电；风扇降温；备用充电增加热量且需冷却。坚持三分钟至 06:00，再到走廊尽头乘电梯。"],
		["05 / 脚步声与同行者", "未知身影会在特定区域短暂露面，然后躲回暗处。别追逐它。多人可以分工维修和监控；联机菜单不会暂停公共计时。"]]
	for i in range(entries.size()):
		var y := 212 + i * 125
		_label(panels, entries[i][0], Vector2(76, y), 430, 25, ACCENT)
		_label(panels, entries[i][1], Vector2(530, y), 940, 23)

func open_about() -> void:
	_page("ABOUT US", "about")
	_image(panels, _brand_file("team_logo.jpg"), Rect2(105, 240, 370, 370), true)
	_label(panels, "Zorix GAme Team", Vector2(580, 254), 830, 45)
	_label(panels, "Made By Zorix GAme Team", Vector2(584, 336), 800, 26, ACCENT)
	_label(panels, "BACKROOMS / NIGHT RELAY\nAn atmospheric cooperative survey game.\nTension through space, observation and resource choices.", Vector2(584, 418), 865, 27)
	_button(panels, "OFFICIAL WEBSITE  /  zorix.it  ↗", Rect2(584, 600, 830, 72), func(): OS.shell_open("https://zorix.it"))
	_button(panels, "ASSET CREDITS / LICENSES", Rect2(584, 694, 830, 72), open_credits)
	_label(panels, "BUILD 0.12.0 / ANDROID", Vector2(584, 792), 830, 18, MUTED)

func open_credits() -> void:
	_page("ASSET CREDITS / LICENSES", "credits")
	_label(panels, "All third-party models, textures and sounds have identified redistributable licenses.", Vector2(76, 194), 1440, 21, ACCENT)
	var credits := [
		"Monster: HorrorGameMaker / City Building Game Art - CC0",
		"Furniture: Poly Haven - CC0",
		"Photographic surfaces: ambientCG / Poly Haven - CC0",
		"Creature footsteps: GboxMikeFozzy / OpenGameArt - CC0",
		"Breathing, machinery, water: Freesound recordings - CC0",
		"Crew avatar: Cesium Man (2017) / Cesium - CC BY 4.0",
		"Chinese font: Noto Sans SC / SIL Open Font License 1.1"]
	for i in range(credits.size()):
		_label(panels, credits[i], Vector2(94, 255 + i * 62), 1390, 23)
	_button(panels, "FULL ASSET CREDITS / SOURCES", Rect2(94, 755, 660, 65), func(): OS.shell_open("https://github.com/h1collab/ggme/blob/fix/faceless2-rendering-polish/faceless2/ASSET_CREDITS.md"))
	_button(panels, "CESIUM / CC BY 4.0", Rect2(795, 755, 620, 65), func(): OS.shell_open("https://creativecommons.org/licenses/by/4.0/"))

func open_pause() -> void:
	_page("SURVEY MENU", "pause")
	_label(panels, "Solo survey is paused." if game.net.mode == "solo" else "The shared shift continues while menus are open.", Vector2(75, 220), 1300, 25, MUTED)
	_button(panels, "RETURN TO SURVEY", Rect2(75, 315, 600, 82), close_panels)
	_button(panels, "FIELD GUIDE", Rect2(75, 425, 600, 82), open_guide)
	_button(panels, "SESSION DETAILS", Rect2(75, 535, 600, 82), open_lobby)
	_button(panels, "SETTINGS", Rect2(850, 535, 600, 82), open_settings)
	_button(panels, "ASSET CREDITS", Rect2(850, 645, 600, 82), open_credits)
	_button(panels, "LEAVE SURVEY", Rect2(75, 645, 600, 82), func(): game.net.leave(); game.running = false; menu())
	_label(panels, game.level.title, Vector2(850, 320), 640, 28, ACCENT)
	_label(panels, game.notice, Vector2(850, 410), 600, 25)

func open_lobby() -> void:
	_page("COOPERATIVE / DIRECT P2P", "lobby")
	_label(panels, "1–4 CREW / HOST A ROOM OR JOIN BY ADDRESS", Vector2(75, 205), 1420, 22, ACCENT)
	_card(panels, Rect2(72, 270, 690, 470))
	_card(panels, Rect2(800, 270, 730, 470))
	_label(panels, "HOST ADDRESS", Vector2(105, 297), 605, 18, MUTED)
	address_field = LineEdit.new()
	address_field.position = Vector2(105, 342)
	address_field.size = Vector2(610, 65)
	address_field.placeholder_text = "192.168.1.20 or public host address"
	address_field.add_theme_font_size_override("font_size", 25)
	panels.add_child(address_field)
	_label(panels, "UDP PORT", Vector2(105, 434), 215, 18, MUTED)
	port_field = SpinBox.new()
	port_field.position = Vector2(105, 475)
	port_field.size = Vector2(225, 60)
	port_field.min_value = 1024
	port_field.max_value = 65535
	port_field.value = 24711
	port_field.get_line_edit().add_theme_font_size_override("font_size", 25)
	panels.add_child(port_field)
	_label(panels, "ROOM KEY / OPTIONAL", Vector2(365, 434), 350, 18, MUTED)
	key_field = LineEdit.new()
	key_field.position = Vector2(365, 475)
	key_field.size = Vector2(350, 60)
	key_field.max_length = 24
	key_field.secret = true
	panels.add_child(key_field)
	upnp_box = CheckBox.new()
	upnp_box.text = "Try UPnP mapping for a public room"
	upnp_box.position = Vector2(105, 559)
	upnp_box.size = Vector2(600, 54)
	upnp_box.add_theme_font_size_override("font_size", 21)
	panels.add_child(upnp_box)
	_button(panels, "HOST NEW SURVEY", Rect2(105, 640, 290, 65), _host)
	_button(panels, "JOIN ROOM", Rect2(425, 640, 290, 65), _join)
	_label(panels, "HOW TO CONNECT", Vector2(835, 304), 620, 26, ACCENT)
	_label(panels, "Same Wi-Fi: enter the host's local IP and UDP port.\n\nInternet: share the public endpoint after UPnP mapping, or forward that UDP port manually. Carrier NAT may require a reachable host.\n\nThe host must stay online. No automatic matchmaking or relay is configured.", Vector2(835, 367), 620, 24)
	room_status = _label(panels, game.net.status if is_instance_valid(game.net) else "Offline", Vector2(76, 770), 1450, 24, ACCENT)

func _host() -> void:
	var result: Error = game.net.host(int(port_field.value), key_field.text, upnp_box.button_pressed)
	if result == OK:
		game.start_shift(0)
		open_briefing()

func _join() -> void:
	game.running = false
	game.net.join(address_field.text, int(port_field.value), key_field.text)

func open_monitor() -> void:
	_clear("monitor")
	monitoring = true
	_card(panels, Rect2(0, 0, 1600, 900), Color(0.025, 0.04, 0.033, 0.99))
	_label(panels, "SURVEY STATION / LIVE CIRCUIT MONITOR", Vector2(55, 35), 1220, 27, ACCENT)
	_button(panels, "LOWER MONITOR", Rect2(1260, 28, 290, 60), close_panels)
	_card(panels, Rect2(55, 125, 1000, 568))
	var feed := TextureRect.new()
	feed.position = Vector2(58, 128)
	feed.size = Vector2(994, 559)
	feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed.texture = monitor_view.get_texture()
	panels.add_child(feed)
	_card(panels, Rect2(58, 615, 994, 72), Color(0.02, 0.035, 0.025, 0.8))
	monitor_notice = _label(panels, "", Vector2(78, 621), 947, 21, ACCENT)
	_label(panels, "LIVE / 24 V   ·   OBSERVE FLUORESCENT FLICKER", Vector2(78, 142), 900, 20, ACCENT)
	camera_buttons.clear()
	for i in range(3):
		camera_buttons.append(_button(panels, "CAM / %02d" % (i + 1), Rect2(55 + i * 340, 716, 320, 72), func(): select_camera(i)))
	_button(panels, "REPORT FAULT ON SELECTED FEED", Rect2(55, 811, 1000, 60), func(): game.net.request("report", selected_camera))
	console_status = _label(panels, _monitor_status(), Vector2(1095, 116), 450, 24)
	door_buttons.clear()
	for i in range(2):
		door_buttons.append(_button(panels, "%s SHUTTER / %s" % ["LEFT" if i == 0 else "RIGHT", "CLOSED" if game.doors[i] else "OPEN"], Rect2(1090, 295 + i * 85, 455, 66), func(): game.net.request("door", i)))
	light_button = _button(panels, "HALL LIGHTS / " + ("ON" if game.lights_on else "OFF"), Rect2(1090, 470, 455, 66), func(): game.net.request("lights"))
	fan_button = _button(panels, "VENTILATION / " + ("ON" if game.fan_on else "OFF"), Rect2(1090, 555, 455, 66), func(): game.net.request("fan"))
	generator_button = _button(panels, "BACKUP CHARGE +12%", Rect2(1090, 640, 455, 66), func(): game.net.request("generator"))
	_label(panels, "Shutters slow interference.\nClosed shutters consume more power.\nFan cools; backup charge adds heat.", Vector2(1100, 745), 435, 21, MUTED)
	retarget_camera()
	monitor_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func select_camera(index: int) -> void:
	selected_camera = clampi(index, 0, 2)
	retarget_camera()

func retarget_camera() -> void:
	if not is_instance_valid(monitor_camera): return
	monitor_camera.transform = game.level.cameras[selected_camera]
	var targets := [Vector3(-8, 2.1, -5), Vector3(8, 2.1, -16), Vector3(-8, 2.1, -27)]
	monitor_camera.look_at(targets[selected_camera], Vector3.UP)

func open_result() -> void:
	_page("SURVEY COMPLETE" if game.completed else "SURVEY INTERRUPTED", "result")
	result_shown = true
	_label(panels, game.notice, Vector2(75, 265), 1390, 34, ACCENT)
	_label(panels, "Layers surveyed / %d of 3\nCircuit reports / %d\nReserve remaining / %d%%" % [3 if game.completed else game.stage, game.reports, int(game.power)], Vector2(75, 375), 1340, 29)
	if game.net.mode != "client":
		_button(panels, "RESTART THIS LAYER", Rect2(75, 650, 620, 86), func(): game.start_shift(game.stage); close_panels())
	_button(panels, "LEAVE TO MAIN MENU", Rect2(760, 650, 700, 86), func(): game.net.leave(); game.running = false; menu())

func refresh() -> void:
	if not is_instance_valid(game.level): return
	status_label.text = "%s   /   %02d:%02d" % [game.level.title, 2 + int(game.elapsed / 45), int(fmod(game.elapsed / 45, 1.0) * 60)]
	goal_label.text = "NODES %d/3   ·   REPORTS %d/3   ·   %s" % [game.repaired.count(true), game.reports, "SOLO" if game.net.mode == "solo" else "CREW %d/4" % max(1, game.net.poses.size())]
	meter_label.text = "POWER %d%%   /   SIGNAL %d%%\nSTAMINA %d%%" % [int(game.power), int(game.signal_pressure), int(game.player.stamina)]
	prompt_label.text = game.prompt()
	notice_label.text = game.notice
	var objective: Dictionary = game.next_objective()
	var offset: Vector3 = objective.position - game.player.position
	var facing := Vector3(0, 0, -1).rotated(Vector3.UP, game.player.yaw)
	var angle := facing.signed_angle_to(Vector3(offset.x, 0, offset.z).normalized(), Vector3.UP)
	var direction := "前方" if absf(angle) < 0.65 else ("后方" if absf(angle) > 2.5 else ("左侧" if angle > 0 else "右侧"))
	objective_label.text = "下一步：%s\n%s / 距离 %dm" % [objective.text, direction, int(offset.length())]
	subtitle_label.text = game.story.subtitle
	if is_instance_valid(monitor_notice): monitor_notice.text = game.notice
	if is_instance_valid(room_status): room_status.text = game.net.status
	if panel_kind == "monitor":
		for child in panels.get_children():
			if child is Label or child is Button: child.queue_redraw()
	if is_instance_valid(console_status):
		console_status.text = _monitor_status()
		for i in range(2): door_buttons[i].text = "%s SHUTTER / %s" % ["LEFT" if i == 0 else "RIGHT", "CLOSED" if game.doors[i] else "OPEN"]
		light_button.text = "HALL LIGHTS / " + ("ON" if game.lights_on else "OFF")
		fan_button.text = "VENTILATION / " + ("ON" if game.fan_on else "OFF")
		var cooldown := maxf(0, game.generator_ready - game.elapsed)
		generator_button.text = "BACKUP CHARGE +12%" if cooldown <= 0 else "BACKUP COOLING / %ds" % int(ceil(cooldown))
		generator_button.disabled = cooldown > 0
		for i in range(3): camera_buttons[i].modulate = ACCENT if i == selected_camera else Color.WHITE

func open_settings() -> void:
	_page("画面、音量与视角", "settings")
	_label(panels, "RENDER QUALITY", Vector2(75, 245), 700, 27, ACCENT)
	for i in range(3):
		var names := ["PERFORMANCE / 60%", "BALANCED / 80%", "HIGH / NATIVE"]
		_button(panels, names[i], Rect2(75 + i * 490, 320, 455, 78), func(): game.set_quality(i))
	var turn := CheckBox.new()
	turn.text = "剧情自动转头与短暂停步（手动看向别处可打断）"
	turn.position = Vector2(75, 435)
	turn.size = Vector2(1390, 64)
	turn.button_pressed = game.auto_turn
	turn.toggled.connect(func(value: bool): game.auto_turn = value; game.player.cancel_focus(); game.save_settings())
	panels.add_child(turn)
	_label(panels, "视角灵敏度", Vector2(75, 535), 700, 25, ACCENT)
	var sensitivity := HSlider.new()
	sensitivity.position = Vector2(75, 590)
	sensitivity.size = Vector2(1390, 64)
	sensitivity.min_value = 0.5
	sensitivity.max_value = 2.0
	sensitivity.step = 0.05
	sensitivity.value = game.sensitivity
	sensitivity.value_changed.connect(func(value: float): game.sensitivity = value; game.save_settings())
	panels.add_child(sensitivity)
	_label(panels, "主音量", Vector2(75, 695), 700, 25, ACCENT)
	var volume := HSlider.new()
	volume.position = Vector2(75, 760)
	volume.size = Vector2(1390, 64)
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = game.audio_volume
	volume.value_changed.connect(game.set_audio_volume)
	panels.add_child(volume)

func _monitor_status() -> String:
	return "%02d:%02d / SHIFT\nPOWER %d%%\nSIGNAL %d%% / HEAT %d%%\nREPORTS %d/3" % [2 + int(game.elapsed / 45), int(fmod(game.elapsed / 45, 1.0) * 60), int(game.power), int(game.signal_pressure), int(game.heat), game.reports]

func _brand_file(filename: String) -> String:
	var packaged := "res://ui/" + filename
	return packaged if ResourceLoader.exists(packaged) else "res://faceless2/branding/" + filename
