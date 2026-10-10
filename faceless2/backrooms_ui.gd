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
var subtitle_backdrop: Panel
var subtitle_label: Label
var notice_label: Label
var room_status: Label
var address_field: LineEdit
var port_field: SpinBox
var key_field: LineEdit
var upnp_box: CheckBox
var room_code_field: LineEdit
var room_name_field: LineEdit
var room_visibility: OptionButton
var slot_limit: SpinBox
var directory_field: LineEdit
var available_rooms: VBoxContainer
var room_code_label: Label
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
	# A restrained exploration HUD: story and direction, not fake recording
	# indicators or FNAF-style camera-control overlays.
	hud = Control.new()
	hud.size = Vector2(1600, 900)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	_card(hud, Rect2(30, 24, 495, 105), Color(0.012, 0.025, 0.026, 0.72))
	status_label = _label(hud, "", Vector2(49, 38), 465, 22, ACCENT)
	goal_label = _label(hud, "", Vector2(49, 81), 462, 18)
	_card(hud, Rect2(30, 139, 536, 105), Color(0.013, 0.028, 0.025, 0.65))
	objective_label = _label(hud, "", Vector2(50, 151), 508, 21, PAPER)
	_card(hud, Rect2(1203, 25, 183, 78), Color(0.013, 0.025, 0.025, 0.72))
	notice_label = _label(hud, "", Vector2(1217, 43), 168, 18, MUTED)
	_button(hud, "日志 / J", Rect2(996, 30, 190, 69), open_journal, true)
	_button(hud, "Ⅱ", Rect2(1410, 30, 135, 69), open_pause, true)
	prompt_label = _label(hud, "", Vector2(468, 689), 665, 24, ACCENT)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_backdrop = _card(hud, Rect2(340, 764, 920, 80), Color(0.014, 0.028, 0.027, 0.72))
	subtitle_label = _label(hud, "", Vector2(358, 777), 882, 20)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cross := _label(hud, "+", Vector2(780, 425), 42, 21, Color(0.80,0.86,0.82,0.65))
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	joystick = Joystick.new()
	joystick.position = Vector2(66, 640)
	joystick.size = Vector2(186, 186)
	hud.add_child(joystick)
	_button(hud, "调查 / E", Rect2(1352, 637, 195, 77), func(): game.interact(), true)
	_button(hud, "手电 / F", Rect2(1352, 734, 195, 74), func(): game.player.torch.visible = not game.player.torch.visible, true)
	_button(hud, "杏仁水 / 喝", Rect2(1060, 784, 226, 52), func(): game.net.request("drink"), true)
	_button(hud, "重播语音", Rect2(1060, 840, 226, 50), _replay_generated_voice, true)
	var run := _button(hud, "RUN", Rect2(290, 784, 136, 67), func(): pass, true)
	run.button_down.connect(func(): run_held = true)
	run.button_up.connect(func(): run_held = false)

func _replay_generated_voice() -> void:
	if game.story.last_voice_key.is_empty():
		game.story.play_voice("brief_%d" % game.stage)
	else:
		game.story.play_voice(game.story.last_voice_key)

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
	var detail := _label(panels, "FACELESS 2 / THE OTHER SHIFT", Vector2(350, 615), 900, 21, MUTED)
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
	_label(panels, "THE OTHER SHIFT  /  错层", Vector2(73, 323), 640, 27, ACCENT)
	_label(panels, "一栋已经拆除的楼，记录着你从未经历过的出勤。\n找到林岚失踪的真相。水正在向每一层蔓延。", Vector2(72, 411), 600, 26, MUTED)
	_button(panels, "开始探索     →", Rect2(72, 538, 600, 76), func(): game.start_solo())
	_button(panels, "房间合作 / 2–4 人", Rect2(72, 631, 600, 74), open_lobby)
	_button(panels, "CONTROLS", Rect2(72, 734, 288, 67), open_guide)
	_button(panels, "ABOUT", Rect2(381, 734, 291, 67), open_about)
	_button(panels, "SETTINGS", Rect2(1195, 42, 338, 66), open_settings)
	_label(panels, "现场调查  /  动态积水  /  非线性真相  /  偶发黑暗目击", Vector2(73, 843), 640, 18, MUTED)
	_card(panels, Rect2(1050, 655, 460, 154), Color(0.02, 0.038, 0.036, 0.82))
	_label(panels, "00 / THE BUILDING THAT RETURNED", Vector2(1072, 681), 420, 19, ACCENT)
	_label(panels, "这不是录像修复任务。\n是一次不会被记住的调查。", Vector2(1072, 727), 420, 22)

func _page(title: String, kind: String) -> void:
	_clear(kind)
	_card(panels, Rect2(0, 0, 1600, 900), Color(0.02, 0.036, 0.034, 1.0))
	_label(panels, "FACELESS 2  /  ZORIX GAme TEAM", Vector2(72, 47), 1050, 19, ACCENT)
	_label(panels, title, Vector2(72, 108), 1240, 40)
	_button(panels, "BACK", Rect2(1320, 45, 204, 70), func(): close_panels() if game.running else menu())

func open_briefing() -> void:
	_page(game.story.BRIEFINGS[game.stage][0], "briefing")
	var message := _label(panels, game.story.BRIEFINGS[game.stage][1], Vector2(76, 215), 1430, 28)
	message.size.y = 256
	_card(panels, Rect2(76, 492, 1400, 145), Color(0.065, 0.089, 0.073))
	_label(panels, "调查目标 / 你的行动会留下证据", Vector2(98, 508), 1200, 23, ACCENT)
	_label(panels, game.story.BRIEFINGS[game.stage][2], Vector2(98, 555), 1310, 22)
	_label(panels, "WASD / 左摇杆移动  ·  E / 拾取或组合  ·  J / 日志  ·  F / 手电\n右侧拖动观察，低头能看到双脚。剧情镜头永远可打断。", Vector2(76, 653), 1390, 22, MUTED)
	_button(panels, "进入黑暗 / CONTINUE", Rect2(76, 764, 1380, 80), close_panels)
	game.story.play_voice("brief_%d" % game.stage)

func close_panels() -> void:
	panel_kind = "play"
	modal = false
	monitoring = false
	result_shown = false
	panels.visible = false
	hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("android") else Input.MOUSE_MODE_CAPTURED

func open_journal() -> void:
	_page("调查日志 / EVIDENCE JOURNAL", "journal")
	_label(panels, game.story.BRIEFINGS[game.stage][0] + "  /  " + game.level.subtitle, Vector2(78, 190), 1370, 26, ACCENT)
	for i in range(3):
		var found: bool = game.repaired[i]
		var y := 248 + i * 153
		_card(panels, Rect2(76, y, 1437, 139), Color(0.055, 0.082, 0.076, 0.93) if found else Color(0.022, 0.039, 0.038, 0.94))
		_label(panels, game.story.EVIDENCE_TITLES[game.stage][i] + ("  /  已发现" if found else "  /  未调查"), Vector2(102, y+17), 1370, 24, ACCENT if found else MUTED)
		var content: String = game.story.MEMORY_TEXT[game.stage][i] if found else "未知位置：请沿目标方向寻找现场物件。靠近后按 E / 调查。"
		var body := _label(panels, content, Vector2(102, y+65), 1350, 20, PAPER if found else MUTED)
		body.size.y = 67
	if game.repaired.count(true) >= 2:
		_label(panels, "新的发现 / " + game.story.INTERLUDES[game.stage], Vector2(78, 749), 1370, 18, ACCENT)
	else:
		_label(panels, "观察：地面上的积水也许比墙上标记更可靠。", Vector2(78, 749), 1370, 20, MUTED)
	_button(panels, "返回现场", Rect2(1215, 820, 295, 65), close_panels)

func open_final_choice() -> void:
	if game.stage != 3 or not game.transfer_ready() or game.lift_active: return
	_page("终章 / 信号的归属", "ending_choice")
	_label(panels, "你已找到三份原始证据。失联并非偶然。\n林岚没有请求救援：她试图阻止另一侧的东西通过这条线。", Vector2(85, 220), 1370, 30)
	_card(panels, Rect2(80, 415, 690, 264), Color(0.045,0.078,0.07,0.94))
	_card(panels, Rect2(805, 415, 690, 264), Color(0.072,0.054,0.046,0.94))
	_label(panels, "结局 A / 传回证据", Vector2(106, 446), 610, 30, ACCENT)
	_label(panels, "让外界知道真相，但那个信号也可能\n搭上你的电梯。", Vector2(106, 505), 622, 25)
	_label(panels, "结局 B / 封存信号", Vector2(834, 446), 608, 30, ACCENT)
	_label(panels, "放弃公开档案。切断通道，让楼层\n连同未知的人一起消失。", Vector2(834, 505), 618, 25)
	_button(panels, "带证据出去", Rect2(116, 699, 612, 84), func(): game.net.request("transfer", 0); close_panels())
	_button(panels, "关闭信号", Rect2(834, 699, 612, 84), func(): game.net.request("transfer", 1); close_panels())
	_label(panels, "共同游戏：由第一个成功进入电梯并提交选择的玩家决定房间结局。", Vector2(114, 817), 1400, 19, MUTED)

func open_guide() -> void:
	_page("探索方式", "guide")
	var entries := [
		["真实空间", "四个错位楼层，各有不同的证据与现场疑点。调查完成才能解锁电梯。"],
		["恐惧来自环境", "水会渗进每一层。听脚步和电机，注意偶尔出现在暗处的脸。"],
		["自由视角", "剧情自动转头默认关闭；即使启用，手动滑动也能立刻打断。"],
		["调查日志", "按 J 或触摸日志按钮查看证据原文。最后一层可决定送出或封存真相。"],
		["房间联机", "房间码与公开列表，2–4 人。证据共享，惊吓只控制自己视角。"]]
	for i in range(entries.size()):
		var y := 210 + i * 121
		_label(panels, entries[i][0], Vector2(77, y), 450, 26, ACCENT)
		_label(panels, entries[i][1], Vector2(526, y), 945, 24)

func open_about() -> void:
	_page("ABOUT / FACELESS 2", "about")
	_image(panels, _brand_file("team_logo.jpg"), Rect2(105, 248, 357, 357), true)
	_label(panels, "Zorix GAme Team", Vector2(580, 244), 840, 45)
	_label(panels, "Made By Zorix GAme Team", Vector2(584, 335), 850, 27, ACCENT)
	_label(panels, "FACELESS 2 / THE OTHER SHIFT\nExploration-driven horror with local scripted sightings.\nLicensed real GLB architecture, local animated sightings and P2P co-op.", Vector2(584, 414), 875, 26)
	_button(panels, "OFFICIAL WEBSITE / zorix.it", Rect2(584, 592, 825, 70), func(): OS.shell_open("https://zorix.it"))
	_button(panels, "ASSET CREDITS / LICENSES", Rect2(584, 693, 825, 70), open_credits)
	_label(panels, "BUILD 0.16.0 / ANDROID", Vector2(584, 797), 820, 18, MUTED)

func open_credits() -> void:
	_page("授权素材 / CREDITS", "credits")
	var lines := [
		"Architecture: Huuxloc / BackRooms GLB — CC BY 4.0 (modified)",
		"Monster: City Building Game Art / HorrorGameMaker — CC0",
		"Furniture: Poly Haven — CC0",
		"Surfaces: ambientCG / Poly Haven — CC0",
		"Sound: Freesound / GboxMikeFozzy — CC0",
		"Crew: Cesium Man / Cesium — CC BY 4.0",
		"Chinese font: Noto Sans SC — OFL 1.1",
		"Generated voice: Kokoro-82M-v1.1-zh — Apache 2.0"]
	for i in range(lines.size()): _label(panels, lines[i], Vector2(80, 222 + i * 67), 1410, 24)
	_button(panels, "FULL CREDITS / AUTHORS & LINKS", Rect2(80, 763, 685, 68), func(): OS.shell_open("https://github.com/h1collab/ggme/blob/fix/faceless2-rendering-polish/faceless2/ASSET_CREDITS.md"))
	_button(panels, "CC BY 4.0", Rect2(802, 763, 605, 68), func(): OS.shell_open("https://creativecommons.org/licenses/by/4.0/"))

func open_pause() -> void:
	_page("暂停 / PAUSE", "pause")
	_label(panels, "单人探索时暂停；多人房间中其他玩家继续移动。", Vector2(76, 226), 1410, 26, MUTED)
	if not game.rooms.room_code.is_empty():
		_label(panels, "你的房间号：" + game.rooms.room_code + "  ·  复制给朋友后可用房间号加入", Vector2(76, 260), 1420, 24, ACCENT)
	_button(panels, "CONTINUE", Rect2(75, 327, 620, 80), close_panels)
	_button(panels, "CONTROLS", Rect2(75, 445, 620, 78), open_guide)
	_button(panels, "SETTINGS", Rect2(825, 445, 620, 78), open_settings)
	_button(panels, "ASSET CREDITS", Rect2(825, 565, 620, 78), open_credits)
	_button(panels, "LEAVE", Rect2(75, 565, 620, 78), func(): game.net.leave(); game.running = false; menu())

func open_lobby() -> void:
	_page("联机房间 / 创建 · 公开列表 · 房间码", "lobby")
	if not game.rooms.rooms_changed.is_connected(_render_rooms): game.rooms.rooms_changed.connect(_render_rooms)
	if not game.rooms.room_created.is_connected(_room_created): game.rooms.room_created.connect(_room_created)
	if not game.rooms.room_error.is_connected(_room_error): game.rooms.room_error.connect(_room_error)
	_card(panels, Rect2(65, 218, 705, 560))
	_card(panels, Rect2(793, 218, 742, 560))
	_label(panels, "创建房间 / 你是房主", Vector2(92, 236), 650, 28, ACCENT)
	room_name_field = LineEdit.new()
	room_name_field.position = Vector2(94, 292)
	room_name_field.size = Vector2(630, 56)
	room_name_field.placeholder_text = "房间名字 / 例如 黑暗走廊"
	room_name_field.max_length = 40
	panels.add_child(room_name_field)
	_label(panels, "类型", Vector2(93, 373), 190, 19, MUTED)
	room_visibility = OptionButton.new()
	room_visibility.position = Vector2(96, 409)
	room_visibility.size = Vector2(323, 56)
	room_visibility.add_item("公开 / 显示在列表", 0)
	room_visibility.add_item("私人 / 只通过房间号", 1)
	panels.add_child(room_visibility)
	_label(panels, "人数上限", Vector2(455, 373), 240, 19, MUTED)
	slot_limit = SpinBox.new()
	slot_limit.position = Vector2(458, 409)
	slot_limit.size = Vector2(244, 56)
	slot_limit.min_value = 2
	slot_limit.max_value = 4
	slot_limit.step = 1
	slot_limit.value = 4
	panels.add_child(slot_limit)
	_button(panels, "创建房间", Rect2(95, 497, 609, 70), _create_room)
	room_code_label = _label(panels, "房间号在创建后显示，复制给朋友即可加入。", Vector2(99, 593), 630, 22, ACCENT)
	_label(panels, "同一 Wi-Fi 无须服务器。跨网络需要部署 JS 房间服务，且房主 UDP 端口可达。", Vector2(97, 680), 628, 19, MUTED)
	_label(panels, "加入房间 / 不输入 IP", Vector2(821, 236), 635, 28, ACCENT)
	room_code_field = LineEdit.new()
	room_code_field.position = Vector2(827, 290)
	room_code_field.size = Vector2(418, 57)
	room_code_field.placeholder_text = "输入八位房间号"
	room_code_field.max_length = 10
	panels.add_child(room_code_field)
	_button(panels, "加入", Rect2(1260, 288, 226, 60), _join_by_code)
	_label(panels, "附近 / 公开房间", Vector2(822, 371), 430, 22, MUTED)
	_button(panels, "刷新", Rect2(1315, 366, 176, 54), func(): game.rooms.discover())
	var viewport := ScrollContainer.new()
	viewport.position = Vector2(829, 439)
	viewport.size = Vector2(649, 263)
	panels.add_child(viewport)
	available_rooms = VBoxContainer.new()
	available_rooms.custom_minimum_size = Vector2(615, 0)
	available_rooms.add_theme_constant_override("separation", 9)
	viewport.add_child(available_rooms)
	_label(panels, "网络模式：本地发现 / JS 目录（可选）", Vector2(87, 790), 630, 19, MUTED)
	directory_field = LineEdit.new()
	directory_field.position = Vector2(88, 821)
	directory_field.size = Vector2(1025, 55)
	directory_field.placeholder_text = "公共服务 HTTPS 地址 / 不需要填写玩家 IP"
	directory_field.text = game.rooms.directory_url
	panels.add_child(directory_field)
	_button(panels, "保存服务", Rect2(1132, 815, 250, 60), _configure_directory)
	room_status = _label(panels, game.net.status, Vector2(822, 722), 683, 19, ACCENT)
	game.rooms.discover()

func _configure_directory() -> void:
	game.rooms.configure(directory_field.text)
	game.save_settings()
	game.rooms.discover()

func _create_room() -> void:
	game.rooms.create_room(room_visibility.selected == 0, int(slot_limit.value), room_name_field.text)
	if is_instance_valid(room_status): room_status.text = "正在创建房间……"

func _join_by_code() -> void:
	game.running = false
	game.rooms.join_code(room_code_field.text)

func _room_created(code: String) -> void:
	if panel_kind == "lobby":
		if is_instance_valid(room_code_label): room_code_label.text = "房间号：%s  /  请发给好友" % code
		open_briefing()

func _room_error(message: String) -> void:
	if panel_kind == "lobby" and is_instance_valid(room_status): room_status.text = message

func _render_rooms(list: Array) -> void:
	if panel_kind != "lobby" or not is_instance_valid(available_rooms): return
	for child in available_rooms.get_children():
		available_rooms.remove_child(child)
		child.queue_free()
	if list.is_empty():
		var help := Label.new()
		help.text = "暂无公开房间。私人房间请填写房间号。"
		help.add_theme_font_size_override("font_size", 22)
		available_rooms.add_child(help)
	for entry in list:
		var code: String = str(entry.get("code", ""))
		var players: int = int(entry.get("players", 1))
		var limit: int = int(entry.get("max_players", 4))
		var join := Button.new()
		join.custom_minimum_size = Vector2(600, 59)
		join.text = "%s   %d/%d   %s" % [str(entry.get("name", "Faceless 2")), players, limit, code]
		join.add_theme_font_size_override("font_size", 21)
		join.disabled = players >= limit
		join.pressed.connect(func(): game.rooms.join_code(code))
		available_rooms.add_child(join)

func open_result() -> void:
	_page("你决定了真相的去向" if game.completed else "探索中断", "result")
	result_shown = true
	_label(panels, game.notice, Vector2(76, 260), 1410, 33, ACCENT)
	_label(panels, "已确认现场证据 / %d of 3\n抵达层级 / %d of 4" % [game.repaired.count(true), game.stage + 1], Vector2(76, 388), 1360, 29)
	if game.net.mode != "client": _button(panels, "RESTART THIS LAYER", Rect2(76, 666, 625, 82), func(): game.start_shift(game.stage); close_panels())
	_button(panels, "MAIN MENU", Rect2(790, 666, 620, 82), func(): game.net.leave(); game.running = false; menu())

func refresh() -> void:
	if not is_instance_valid(game.level): return
	status_label.text = game.level.title
	goal_label.text = "线索 %d/3  ·  杏仁水 %d  ·  %s" % [game.repaired.count(true), int(game.inventory.get("almond_water",0)), "SOLO" if game.net.mode == "solo" else "ROOM %s  %d/%d" % [game.rooms.room_code, max(1,game.net.members.size()), game.net.max_crew]]
	notice_label.text = "耐力 %d%%\n钥匙 %s" % [int(game.player.stamina), "已找到" if game.key_picked else "未找到"]
	prompt_label.text = game.prompt()
	var objective: Dictionary = game.next_objective()
	var offset: Vector3 = objective.position - game.player.position
	var facing := Vector3(0, 0, -1).rotated(Vector3.UP, game.player.yaw)
	var angle := facing.signed_angle_to(Vector3(offset.x, 0, offset.z).normalized(), Vector3.UP)
	var direction := "前方" if absf(angle) < 0.65 else ("后方" if absf(angle) > 2.5 else ("左侧" if angle > 0 else "右侧"))
	var next_title: String = objective.text.split(" / ")[0]
	objective_label.text = "正在下降 / 不要回答声音" if game.lift_active else "调查目标：%s\n%s · 约 %d 米" % [next_title, direction, int(offset.length())]
	subtitle_label.text = game.story.subtitle
	subtitle_backdrop.visible = not game.story.subtitle.is_empty()
	if is_instance_valid(room_status): room_status.text = game.net.status

func open_settings() -> void:
	_page("画质、生成语音和操作", "settings")
	_label(panels, "动态 3D 分辨率 / 水面与阴影共用手机性能预算", Vector2(76, 197), 1310, 24, ACCENT)
	for i in range(3):
		var labels := ["流畅 / 58%", "均衡 / 74%", "精细 / 91%"]
		_button(panels, labels[i], Rect2(76 + i * 488, 273, 455, 73), func(): game.set_quality(i))
	var turn := CheckBox.new()
	turn.text = "剧情自动转头（默认关闭，手动触摸或鼠标立即取消）"
	turn.position = Vector2(75, 375)
	turn.size = Vector2(1390, 59)
	turn.button_pressed = game.auto_turn
	turn.toggled.connect(func(value: bool): game.auto_turn = value; game.player.cancel_focus(); game.save_settings())
	panels.add_child(turn)
	_label(panels, "视角灵敏度", Vector2(75, 467), 1100, 24, ACCENT)
	var sensitivity := HSlider.new()
	sensitivity.position = Vector2(75, 517)
	sensitivity.size = Vector2(1390, 51)
	sensitivity.min_value = 0.5
	sensitivity.max_value = 2.0
	sensitivity.step = 0.05
	sensitivity.value = game.sensitivity
	sensitivity.value_changed.connect(func(value: float): game.sensitivity = value; game.save_settings())
	panels.add_child(sensitivity)
	_label(panels, "主音量", Vector2(75, 582), 1100, 24, ACCENT)
	var volume := HSlider.new()
	volume.position = Vector2(75, 628)
	volume.size = Vector2(1390, 51)
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = game.audio_volume
	volume.value_changed.connect(game.set_audio_volume)
	panels.add_child(volume)
	var glance := CheckBox.new()
	glance.text = "开场惊吓瞬间转头（默认开；可关闭，手动视角立即打断）"
	glance.position = Vector2(75, 708)
	glance.size = Vector2(1400, 49)
	glance.button_pressed = game.shock_glance_enabled
	glance.toggled.connect(func(value: bool): game.shock_glance_enabled = value; game.player.cancel_focus(); game.save_settings())
	panels.add_child(glance)
	var speech := CheckBox.new()
	speech.text = "播放神经网络预生成的中文录音（非系统 TTS，可关闭）"
	speech.position = Vector2(75, 770)
	speech.size = Vector2(1400, 55)
	speech.button_pressed = game.voice_enabled
	speech.toggled.connect(func(value: bool):
		game.voice_enabled = value
		if not value and is_instance_valid(game.story.voice_audio): game.story.voice_audio.stop()
		game.save_settings())
	panels.add_child(speech)

func _brand_file(filename: String) -> String:
	var packaged := "res://ui/" + filename
	return packaged if ResourceLoader.exists(packaged) else "res://faceless2/branding/" + filename
