extends Control

const Joystick = preload("virtual_joystick.gd")
const TouchAction = preload("touch_action.gd")
const PAPER := Color(0.88, 0.90, 0.84)
const MUTED := Color(0.56, 0.64, 0.61)
const ACCENT := Color(0.67, 0.88, 0.73)
var game: Node
var canvas: Control
var hud: Control
var panels: Control
var joystick: Control
var modal := true
var monitoring := false  # Kept for stable ENet wire arguments; no CCTV mode.
var result_shown := false
var run_held := false
var status_label: Label
var goal_label: Label
var prompt_label: Label
var objective_label: Label
var subtitle_label: Label
var notice_label: Label
var room_status: Label
var address_field: LineEdit
var port_field: SpinBox
var key_field: LineEdit
var upnp_box: CheckBox
var intro_timer: Timer
var panel_kind := ""

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
	else: canvas.position = (extent - Vector2(1600, 900) * factor) * 0.5
	canvas.scale = Vector2.ONE * factor

func _style(color: Color, border: Color = Color(0.26, 0.32, 0.30)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _card(parent: Node, rect: Rect2, color: Color = Color(0.025, 0.042, 0.04, 0.95)) -> Panel:
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
	label.size = Vector2(width, font_size * 3.0)
	parent.add_child(label)
	label.text = text
	return label

func _button(parent: Node, text: String, rect: Rect2, callback: Callable, touch: bool = false) -> Button:
	var button: Button = TouchAction.new() if touch else Button.new()
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_stylebox_override("normal", _style(Color(0.07, 0.095, 0.09, 0.97)))
	button.add_theme_stylebox_override("hover", _style(Color(0.14, 0.23, 0.19), ACCENT))
	button.add_theme_stylebox_override("pressed", _style(Color(0.19, 0.35, 0.27), ACCENT))
	button.pressed.connect(callback)
	parent.add_child(button)
	button.text = text
	return button

func _image(parent: Node, path: String, rect: Rect2, crop: bool = false) -> TextureRect:
	var img := TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.position = rect.position
	img.size = rect.size
	var texture: Texture2D = load(path)
	if crop:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(291, 297, 769, 767)
		texture = atlas
	img.texture = texture
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(img)
	return img

func _build_hud() -> void:
	hud = Control.new()
	hud.size = Vector2(1600, 900)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	_card(hud, Rect2(38, 28, 525, 105), Color(0.018, 0.035, 0.033, 0.82))
	status_label = _label(hud, "", Vector2(55, 43), 492, 22, ACCENT)
	goal_label = _label(hud, "", Vector2(55, 83), 492, 18)
	_card(hud, Rect2(1020, 28, 350, 90), Color(0.018, 0.035, 0.033, 0.82))
	notice_label = _label(hud, "", Vector2(1036, 45), 315, 18, MUTED)
	_button(hud, "II", Rect2(1410, 32, 135, 72), open_pause, true)
	_card(hud, Rect2(38, 148, 680, 91), Color(0.018, 0.035, 0.033, 0.82))
	objective_label = _label(hud, "", Vector2(55, 161), 650, 22, ACCENT)
	prompt_label = _label(hud, "", Vector2(470, 685), 660, 25, ACCENT)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label = _label(hud, "", Vector2(340, 585), 920, 23, PAPER)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cross := _label(hud, "·", Vector2(786, 429), 30, 27)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	joystick = Joystick.new()
	joystick.position = Vector2(68, 642)
	joystick.size = Vector2(195, 195)
	hud.add_child(joystick)
	_button(hud, "USE / E", Rect2(1340, 667, 205, 79), func(): game.interact(), true)
	_button(hud, "LIGHT / F", Rect2(1340, 770, 205, 74), func(): game.player.torch.visible = not game.player.torch.visible, true)
	var run := _button(hud, "RUN", Rect2(305, 755, 155, 75), func(): pass, true)
	run.button_down.connect(func(): run_held = true)
	run.button_up.connect(func(): run_held = false)
	_label(hud, "DRAG RIGHT TO LOOK", Vector2(1010, 846), 320, 17, MUTED)

func _clear(kind: String) -> void:
	if is_instance_valid(game) and is_instance_valid(game.player): game.player.cancel_focus()
	panel_kind = kind
	for child in panels.get_children():
		panels.remove_child(child)
		child.queue_free()
	modal = true
	monitoring = false
	run_held = false
	joystick.reset()
	hud.visible = false
	panels.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	room_status = null

func intro() -> void:
	_clear("intro")
	_card(panels, Rect2(0, 0, 1600, 900), Color(0.018, 0.032, 0.038))
	_image(panels, _brand_file("team_logo.jpg"), Rect2(655, 180, 290, 290), true)
	var title := _label(panels, "Made By Zorix GAme Team", Vector2(350, 525), 900, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var detail := _label(panels, "FACELESS 2 / AN ATMOSPHERIC HORROR STORY", Vector2(350, 615), 900, 21, MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(panels, "CONTINUE", Rect2(660, 748, 280, 67), menu)
	intro_timer = Timer.new()
	intro_timer.one_shot = true
	intro_timer.wait_time = 3.2
	intro_timer.timeout.connect(func(): if panel_kind == "intro": menu())
	add_child(intro_timer)
	intro_timer.start()

func menu() -> void:
	_clear("menu")
	_card(panels, Rect2(0, 0, 775, 900), Color(0.02, 0.035, 0.034, 0.97))
	_image(panels, _brand_file("game_icon.png"), Rect2(70, 50, 90, 90))
	_label(panels, "ZORIX / RECOVERED TRANSMISSION", Vector2(188, 76), 530, 20, ACCENT)
	_label(panels, "FACELESS 2", Vector2(70, 214), 680, 71)
	_label(panels, "THE SIGNAL BELOW", Vector2(73, 323), 640, 31, ACCENT)
	_label(panels, "搭档在一栋已拆除的楼里失联。\n出口消失了，黑暗里有东西正在模仿脚步。", Vector2(72, 411), 600, 26, MUTED)
	_button(panels, "开始探索     →", Rect2(72, 538, 600, 76), func(): game.start_solo())
	_button(panels, "DIRECT CO-OP / 1–4", Rect2(72, 631, 600, 74), open_lobby)
	_button(panels, "CONTROLS", Rect2(72, 734, 288, 67), open_guide)
	_button(panels, "ABOUT", Rect2(381, 734, 291, 67), open_about)
	_button(panels, "SETTINGS", Rect2(1195, 42, 338, 66), open_settings)
	_label(panels, "录音线索  /  环境恐怖  /  偶发黑暗目击", Vector2(73, 843), 640, 18, MUTED)
	_card(panels, Rect2(1050, 655, 460, 154), Color(0.02, 0.038, 0.036, 0.82))
	_label(panels, "00 / THE DISAPPEARED OFFICES", Vector2(1072, 681), 420, 21, ACCENT)
	_label(panels, "它早已被拆除。\n可灯仍然亮着。", Vector2(1072, 727), 420, 22)

func _page(title: String, kind: String) -> void:
	_clear(kind)
	_card(panels, Rect2(0, 0, 1600, 900), Color(0.02, 0.036, 0.034, 1.0))
	_label(panels, "FACELESS 2  /  ZORIX GAme TEAM", Vector2(72, 47), 1050, 19, ACCENT)
	_label(panels, title, Vector2(72, 108), 1240, 40)
	_button(panels, "BACK", Rect2(1320, 45, 204, 70), func(): close_panels() if game.running else menu())

func open_briefing() -> void:
	_page(game.story.BRIEFINGS[game.stage][0], "briefing")
	var message := _label(panels, game.story.BRIEFINGS[game.stage][1], Vector2(76, 226), 1430, 30)
	message.size.y = 235
	_card(panels, Rect2(76, 487, 1400, 134), Color(0.065, 0.089, 0.073))
	_label(panels, "下一步", Vector2(98, 502), 1200, 25, ACCENT)
	_label(panels, game.story.BRIEFINGS[game.stage][2], Vector2(98, 554), 1300, 23)
	_label(panels, "WASD / 左摇杆移动  ·  E / USE拾取录音  ·  F / LIGHT手电\n右侧拖动观察。镜头永远可以手动控制。", Vector2(76, 653), 1390, 22, MUTED)
	_button(panels, "进入黑暗 / CONTINUE", Rect2(76, 764, 1380, 80), close_panels)

func close_panels() -> void:
	panel_kind = "play"
	modal = false
	monitoring = false
	result_shown = false
	panels.visible = false
	hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("android") else Input.MOUSE_MODE_CAPTURED

func open_guide() -> void:
	_page("探索方式", "guide")
	var entries := [
		["真实空间", "三层办公室、地下机房和静水大厅。找到三份录音才能解锁电梯。"],
		["恐惧来自环境", "观察昏暗的墙角、听水声与远处的脚步。怪物不会追杀你。"],
		["自由视角", "剧情自动转头默认关闭；即使启用，手动滑动也能立刻打断。"],
		["直接联机", "最多四人 P2P。线索共享，但每个人的惊吓和镜头独立。"]]
	for i in range(entries.size()):
		var y := 225 + i * 132
		_label(panels, entries[i][0], Vector2(77, y), 450, 26, ACCENT)
		_label(panels, entries[i][1], Vector2(526, y), 945, 24)

func open_about() -> void:
	_page("ABOUT / FACELESS 2", "about")
	_image(panels, _brand_file("team_logo.jpg"), Rect2(105, 248, 357, 357), true)
	_label(panels, "Zorix GAme Team", Vector2(580, 244), 840, 45)
	_label(panels, "Made By Zorix GAme Team", Vector2(584, 335), 850, 27, ACCENT)
	_label(panels, "FACELESS 2 / THE SIGNAL BELOW\nExploration-driven atmospheric horror.\nLicensed real GLB architecture, local animated sightings and P2P co-op.", Vector2(584, 414), 875, 26)
	_button(panels, "OFFICIAL WEBSITE / zorix.it", Rect2(584, 592, 825, 70), func(): OS.shell_open("https://zorix.it"))
	_button(panels, "ASSET CREDITS / LICENSES", Rect2(584, 693, 825, 70), open_credits)
	_label(panels, "BUILD 0.13.0 / ANDROID", Vector2(584, 797), 820, 18, MUTED)

func open_credits() -> void:
	_page("授权素材 / CREDITS", "credits")
	var lines := [
		"Architecture: Huuxloc / BackRooms GLB — CC BY 4.0 (modified)",
		"Monster: City Building Game Art / HorrorGameMaker — CC0",
		"Furniture: Poly Haven — CC0",
		"Surfaces: ambientCG / Poly Haven — CC0",
		"Sound: Freesound / GboxMikeFozzy — CC0",
		"Crew: Cesium Man / Cesium — CC BY 4.0",
		"Chinese font: Noto Sans SC — OFL 1.1"]
	for i in range(lines.size()): _label(panels, lines[i], Vector2(80, 222 + i * 67), 1410, 24)
	_button(panels, "FULL CREDITS / AUTHORS & LINKS", Rect2(80, 763, 685, 68), func(): OS.shell_open("https://github.com/h1collab/ggme/blob/fix/faceless2-rendering-polish/faceless2/ASSET_CREDITS.md"))
	_button(panels, "CC BY 4.0", Rect2(802, 763, 605, 68), func(): OS.shell_open("https://creativecommons.org/licenses/by/4.0/"))

func open_pause() -> void:
	_page("暂停 / PAUSE", "pause")
	_label(panels, "单人探索时暂停；多人房间中其他玩家继续移动。", Vector2(76, 226), 1410, 26, MUTED)
	_button(panels, "CONTINUE", Rect2(75, 327, 620, 80), close_panels)
	_button(panels, "CONTROLS", Rect2(75, 445, 620, 78), open_guide)
	_button(panels, "SETTINGS", Rect2(825, 445, 620, 78), open_settings)
	_button(panels, "ASSET CREDITS", Rect2(825, 565, 620, 78), open_credits)
	_button(panels, "LEAVE", Rect2(75, 565, 620, 78), func(): game.net.leave(); game.running = false; menu())

func open_lobby() -> void:
	_page("DIRECT P2P / 1–4", "lobby")
	_card(panels, Rect2(72, 245, 690, 494))
	_card(panels, Rect2(800, 245, 730, 494))
	_label(panels, "HOST ADDRESS", Vector2(105, 275), 605, 20, MUTED)
	address_field = LineEdit.new()
	address_field.position = Vector2(105, 325)
	address_field.size = Vector2(610, 62)
	address_field.placeholder_text = "192.168.1.20 / public IP"
	address_field.add_theme_font_size_override("font_size", 24)
	panels.add_child(address_field)
	_label(panels, "UDP PORT", Vector2(105, 412), 210, 20, MUTED)
	port_field = SpinBox.new()
	port_field.position = Vector2(105, 455)
	port_field.size = Vector2(225, 58)
	port_field.min_value = 1024
	port_field.max_value = 65535
	port_field.value = 24711
	panels.add_child(port_field)
	_label(panels, "ROOM KEY", Vector2(368, 412), 350, 20, MUTED)
	key_field = LineEdit.new()
	key_field.position = Vector2(368, 455)
	key_field.size = Vector2(345, 58)
	key_field.max_length = 24
	key_field.secret = true
	panels.add_child(key_field)
	upnp_box = CheckBox.new()
	upnp_box.text = "尝试 UPnP 映射公网端口"
	upnp_box.position = Vector2(105, 538)
	upnp_box.size = Vector2(610, 53)
	panels.add_child(upnp_box)
	_button(panels, "HOST", Rect2(105, 638, 292, 68), _host)
	_button(panels, "JOIN", Rect2(425, 638, 290, 68), _join)
	_label(panels, "CONNECTING", Vector2(835, 280), 610, 27, ACCENT)
	_label(panels, "同一 Wi-Fi：输入房主局域网 IP 和 UDP 端口。\n\n公网：房主需要能被访问的公网地址、UPnP 或手动端口映射。\n\n无中继、无万能 NAT 穿透。房主离开则全员回到菜单。", Vector2(835, 355), 615, 25)
	room_status = _label(panels, game.net.status, Vector2(76, 777), 1420, 22, ACCENT)

func _host() -> void:
	var result: Error = game.net.host(int(port_field.value), key_field.text, upnp_box.button_pressed)
	if result == OK:
		game.start_shift(0)
		open_briefing()

func _join() -> void:
	game.running = false
	game.net.join(address_field.text, int(port_field.value), key_field.text)

func open_result() -> void:
	_page("录音已送出" if game.completed else "探索中断", "result")
	result_shown = true
	_label(panels, game.notice, Vector2(76, 260), 1410, 33, ACCENT)
	_label(panels, "已发现录音 / %d of 3\n抵达层级 / %d of 3" % [game.repaired.count(true), game.stage + 1], Vector2(76, 388), 1360, 29)
	if game.net.mode != "client": _button(panels, "RESTART THIS LAYER", Rect2(76, 666, 625, 82), func(): game.start_shift(game.stage); close_panels())
	_button(panels, "MAIN MENU", Rect2(790, 666, 620, 82), func(): game.net.leave(); game.running = false; menu())

func refresh() -> void:
	if not is_instance_valid(game.level): return
	status_label.text = game.level.title
	goal_label.text = "RECORDINGS %d/3  ·  %s" % [game.repaired.count(true), "SOLO" if game.net.mode == "solo" else "CREW %d/4" % max(1, game.net.poses.size())]
	notice_label.text = "STAMINA %d%%\n%d / 3 TAPES" % [int(game.player.stamina), game.repaired.count(true)]
	prompt_label.text = game.prompt()
	var objective: Dictionary = game.next_objective()
	var offset: Vector3 = objective.position - game.player.position
	var facing := Vector3(0, 0, -1).rotated(Vector3.UP, game.player.yaw)
	var angle := facing.signed_angle_to(Vector3(offset.x, 0, offset.z).normalized(), Vector3.UP)
	var direction := "前方" if absf(angle) < 0.65 else ("后方" if absf(angle) > 2.5 else ("左侧" if angle > 0 else "右侧"))
	objective_label.text = "下一步：%s\n%s / %dm" % [objective.text, direction, int(offset.length())]
	subtitle_label.text = game.story.subtitle
	if is_instance_valid(room_status): room_status.text = game.net.status

func open_settings() -> void:
	_page("图像、音量与操控", "settings")
	_label(panels, "3D QUALITY / 手机优先稳定流畅", Vector2(76, 222), 1250, 25, ACCENT)
	for i in range(3):
		var labels := ["PERFORMANCE / 58%", "BALANCED / 74%", "HIGH / 91%"]
		_button(panels, labels[i], Rect2(76 + i * 488, 306, 455, 76), func(): game.set_quality(i))
	var turn := CheckBox.new()
	turn.text = "允许剧情轻微自动转头（默认关闭；手动可打断）"
	turn.position = Vector2(75, 429)
	turn.size = Vector2(1390, 62)
	turn.button_pressed = game.auto_turn
	turn.toggled.connect(func(value: bool): game.auto_turn = value; game.player.cancel_focus(); game.save_settings())
	panels.add_child(turn)
	_label(panels, "视角灵敏度", Vector2(75, 521), 1100, 24, ACCENT)
	var sensitivity := HSlider.new()
	sensitivity.position = Vector2(75, 584)
	sensitivity.size = Vector2(1390, 51)
	sensitivity.min_value = 0.5
	sensitivity.max_value = 2.0
	sensitivity.step = 0.05
	sensitivity.value = game.sensitivity
	sensitivity.value_changed.connect(func(value: float): game.sensitivity = value; game.save_settings())
	panels.add_child(sensitivity)
	_label(panels, "主音量", Vector2(75, 678), 1100, 24, ACCENT)
	var volume := HSlider.new()
	volume.position = Vector2(75, 740)
	volume.size = Vector2(1390, 52)
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = game.audio_volume
	volume.value_changed.connect(game.set_audio_volume)
	panels.add_child(volume)

func _brand_file(filename: String) -> String:
	var packaged := "res://ui/" + filename
	return packaged if ResourceLoader.exists(packaged) else "res://faceless2/branding/" + filename
