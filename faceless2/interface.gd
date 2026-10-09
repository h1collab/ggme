extends Control

# One fitted canvas keeps HUD, touch targets and subtitles inside the display
# safe area, including tablets and ultrawide phones. The 3D world stays full size.
const JoystickScript = preload("res://scripts/virtual_joystick.gd")
const TouchActionScript = preload("res://scripts/touch_action.gd")
const INK := Color(0.018, 0.033, 0.041, 0.88)
const WHITE := Color(0.89, 0.94, 0.94)
const MUTED := Color(0.48, 0.62, 0.66)
const TEAL := Color(0.36, 0.88, 0.83)
const RED := Color(0.96, 0.30, 0.24)
const DESIGN := Vector2(1600, 900)

var game: Node
var design: Control
var combat: Control
var touch_controls: Control
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var battery_bar: ProgressBar
var health_value: Label
var ammo_value: Label
var weapon_label: Label
var progress_label: Label
var compass_label: Label
var interaction_button: Button
var continue_button: Button
var pause_panel: Control
var pause_button: Button
var status_label: Label
var radio_panel: Control
var radio_text: Label
var radio_speaker: Label
var help_label: Label
var heading := 0.0
var health := 100.0
var hit_time := 0.0
var kill_time := 0.0
var damage_time := 0.0
var damage_bearing := 0.0
var damage_direction_time := 0.0
var critical_time := 0.0
var shot_time := 0.0
var radio_time := 0.0
var notice_time := 0.0
var reticle_aiming := false
var combat_visible := false
var force_touch := false
var marker_position := Vector2.ZERO
var marker_distance := 0.0
var marker_visible := false
var marker_offscreen := false
var settings_return: Control
var settings_snapshot := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	design = Control.new()
	design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.size = DESIGN
	add_child(design)
	_build_hud()
	_build_menus()
	_build_cinema()
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()
	refresh_state()

func _fit_layout() -> void:
	var available := get_viewport_rect().size
	var origin := Vector2.ZERO
	if OS.has_feature("mobile"):
		var screen := Vector2(DisplayServer.screen_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if screen.x > 0 and screen.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var ratio := available / screen
			origin = Vector2(safe.position) * ratio
			available = Vector2(safe.size) * ratio
	var factor := minf(available.x / DESIGN.x, available.y / DESIGN.y)
	design.scale = Vector2.ONE * factor
	design.position = origin + (available - DESIGN * factor) * 0.5
	queue_redraw()

func _label(parent: Control, text_value: String, pos: Vector2, extent: Vector2, font_size := 18, tint := WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _style(color: Color, border: Color, radius := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	return style

func _card(parent: Control, pos: Vector2, extent: Vector2, tint := INK) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = extent
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(tint, Color(0.22, 0.37, 0.40, 0.65)))
	parent.add_child(panel)
	return panel

func _button(parent: Control, caption: String, pos: Vector2, extent: Vector2, accent := false, roundness := 6) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = pos
	button.size = extent
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(Color(0.06, 0.20, 0.22, 0.87) if accent else INK, TEAL if accent else Color(0.24, 0.39, 0.42), roundness))
	button.add_theme_stylebox_override("hover", _style(Color(0.10, 0.28, 0.29, 0.94), TEAL, roundness))
	button.add_theme_stylebox_override("pressed", _style(Color(0.20, 0.43, 0.42, 0.98), WHITE, roundness))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), TEAL, roundness))
	button.add_theme_stylebox_override("disabled", _style(Color(0.02, 0.04, 0.05, 0.65), Color(0.14, 0.22, 0.24), roundness))
	if parent == touch_controls: button.set_script(TouchActionScript)
	parent.add_child(button)
	return button

func _bar(parent: Control, pos: Vector2, extent: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = extent
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size", 1)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color(0.10, 0.18, 0.20), Color.TRANSPARENT, 2))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT, 2))
	parent.add_child(bar)
	return bar

func _build_hud() -> void:
	combat = Control.new()
	combat.size = DESIGN
	combat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.add_child(combat)
	var mission := _card(combat, Vector2(38, 36), Vector2(480, 160))
	_label(mission, "FIELD OBJECTIVE", Vector2(22, 14), Vector2(430, 24), 14, TEAL)
	game.objective_label = _label(mission, "RESTORE THE CHECKPOINT", Vector2(22, 44), Vector2(435, 65), 21)
	game.objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label = _label(mission, "GRID 0/3    EVIDENCE 0/2", Vector2(22, 124), Vector2(430, 22), 15, MUTED)
	compass_label = _label(combat, "N    000°", Vector2(670, 32), Vector2(260, 36), 22)
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.hud = _label(combat, "BLACKWOOD CHECKPOINT", Vector2(38, 210), Vector2(490, 26), 14, MUTED)
	var vitals := _card(combat, Vector2(288, 782), Vector2(380, 80))
	health_value = _label(vitals, "100", Vector2(20, 8), Vector2(64, 34), 28)
	_label(vitals, "VITALS", Vector2(86, 18), Vector2(80, 22), 13, MUTED)
	health_bar = _bar(vitals, Vector2(20, 50), Vector2(166, 6), TEAL)
	_label(vitals, "STA", Vector2(207, 14), Vector2(40, 18), 12, MUTED)
	stamina_bar = _bar(vitals, Vector2(250, 22), Vector2(108, 4), WHITE)
	_label(vitals, "BAT", Vector2(207, 44), Vector2(40, 18), 12, MUTED)
	battery_bar = _bar(vitals, Vector2(250, 52), Vector2(108, 4), Color(0.88, 0.69, 0.36))
	var ammo := _card(combat, Vector2(1232, 782), Vector2(330, 80))
	weapon_label = _label(ammo, "G19 / PISTOL", Vector2(22, 12), Vector2(174, 20), 14, MUTED)
	ammo_value = _label(ammo, "12 / 048", Vector2(22, 32), Vector2(202, 38), 31)
	status_label = _label(ammo, "READY", Vector2(222, 24), Vector2(90, 36), 13, TEAL)
	game.prompt_label = _label(combat, "", Vector2(530, 714), Vector2(540, 48), 21, TEAL)
	game.prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label = _label(combat, "WASD  MOVE    LMB  FIRE    RMB  AIM    E  INTERACT    ESC  PAUSE", Vector2(460, 864), Vector2(920, 24), 12, MUTED)
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.notice = _label(design, "", Vector2(420, 258), Vector2(760, 46), 23, WHITE)
	game.notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Preserve the game's reticle reference; the actual reticle is drawn in _draw.
	game.crosshair = _label(combat, "", Vector2(780, 430), Vector2(40, 40))
	pause_button = _button(combat, "II", Vector2(1492, 36), Vector2(70, 56))
	pause_button.pressed.connect(game.toggle_pause)
	touch_controls = Control.new()
	touch_controls.size = DESIGN
	touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat.add_child(touch_controls)
	game.joystick = Control.new()
	game.joystick.set_script(JoystickScript)
	game.joystick.position = Vector2(38, 632)
	game.joystick.size = Vector2(208, 208)
	touch_controls.add_child(game.joystick)
	var run := _button(touch_controls, "RUN", Vector2(72, 552), Vector2(136, 60), false, 28)
	run.button_down.connect(func(): if game.player: game.player.set_running(true))
	run.button_up.connect(func(): if game.player: game.player.set_running(false))
	var fire := _button(touch_controls, "FIRE", Vector2(1460, 464), Vector2(102, 102), true, 50)
	fire.button_down.connect(func(): if game.player: game.player.set_firing(true))
	fire.button_up.connect(func(): if game.player: game.player.set_firing(false))
	var aim := _button(touch_controls, "AIM", Vector2(1474, 350), Vector2(88, 88), false, 44)
	aim.button_down.connect(func(): if game.player: game.player.set_touch_aiming(true))
	aim.button_up.connect(func(): if game.player: game.player.set_touch_aiming(false))
	var reload := _button(touch_controls, "LOAD", Vector2(1474, 592), Vector2(88, 70))
	reload.pressed.connect(func(): if game.player: game.player.reload_weapon())
	var light := _button(touch_controls, "LIGHT", Vector2(1240, 700), Vector2(96, 58))
	light.pressed.connect(func(): if game.player: game.player.toggle_flashlight())
	var swap := _button(touch_controls, "SWAP", Vector2(1352, 700), Vector2(96, 58))
	swap.pressed.connect(func(): if game.player: game.player.switch_weapon())
	var crouch := _button(touch_controls, "LOW", Vector2(1464, 700), Vector2(98, 58))
	crouch.pressed.connect(func(): if game.player: game.player.toggle_crouch())
	interaction_button = _button(touch_controls, "USE", Vector2(1058, 690), Vector2(128, 68), true)
	interaction_button.pressed.connect(game._interact)
	radio_panel = _card(combat, Vector2(572, 100), Vector2(456, 136))
	radio_speaker = _label(radio_panel, "RADIO / DISPATCH", Vector2(20, 12), Vector2(416, 20), 14, TEAL)
	radio_text = _label(radio_panel, "", Vector2(20, 42), Vector2(416, 82), 17)
	radio_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_panel.visible = false
	game.fade = ColorRect.new()
	game.fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.fade.color = Color.TRANSPARENT
	game.fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game.fade)

func _page() -> Control:
	var page := Control.new()
	page.size = DESIGN
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.visible = false
	design.add_child(page)
	return page

func _page_title(page: Control, eyebrow: String, title: String) -> void:
	_card(page, Vector2(42, 36), Vector2(1516, 826), Color(0.018, 0.033, 0.041, 0.98))
	_label(page, eyebrow, Vector2(96, 72), Vector2(1100, 28), 14, TEAL)
	_label(page, title, Vector2(96, 108), Vector2(1300, 70), 44)

func _build_menus() -> void:
	game.main_menu = _page()
	game.main_menu.visible = true
	_label(game.main_menu, "BLACKWOOD / SURVIVAL CAMPAIGN", Vector2(90, 66), Vector2(600, 28), 14, TEAL)
	_label(game.main_menu, "FACELESS", Vector2(84, 112), Vector2(510, 104), 76)
	_label(game.main_menu, "02", Vector2(505, 114), Vector2(150, 100), 76, RED)
	_label(game.main_menu, "EVERY SIGNAL LEAVES A TRACE.", Vector2(90, 225), Vector2(530, 30), 17, MUTED)
	continue_button = _button(game.main_menu, "CONTINUE OPERATION", Vector2(90, 314), Vector2(440, 64), true)
	continue_button.pressed.connect(game._continue_game)
	var start := _button(game.main_menu, "NEW OPERATION", Vector2(90, 396), Vector2(440, 64))
	start.pressed.connect(func(): game.main_menu.hide(); game.mode_panel.show(); queue_redraw())
	var options := _button(game.main_menu, "SETTINGS", Vector2(90, 478), Vector2(440, 64))
	options.pressed.connect(func(): open_settings(game.main_menu))
	var archive := _button(game.main_menu, "INCIDENT ARCHIVE", Vector2(90, 560), Vector2(440, 64))
	archive.pressed.connect(func(): game.main_menu.hide(); game.archive_panel.show(); queue_redraw())
	var briefing := _card(game.main_menu, Vector2(698, 142), Vector2(804, 544), Color(0.026, 0.06, 0.07, 0.74))
	_label(briefing, "MISSION FILE  /  0213-BW", Vector2(34, 26), Vector2(700, 24), 14, TEAL)
	_label(briefing, "THE LAST SIGNAL", Vector2(34, 70), Vector2(690, 56), 38)
	var desc := _label(briefing, "A silent checkpoint. An armed response.\nSomething that follows the signal.", Vector2(34, 144), Vector2(650, 90), 22)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stages := ["01   RESTORE THE GRID", "02   RECOVER THE ARCHIVE", "03   ARM UP AT THE CABIN", "04   SURVIVE THE RESPONSE", "05   REACH EXTRACTION"]
	for i in range(stages.size()):
		_label(briefing, stages[i], Vector2(34, 256 + i * 43), Vector2(660, 36), 18, WHITE if i == 0 else MUTED)
	_label(briefing, "6 MODES     /     OFFLINE CAMPAIGN", Vector2(34, 492), Vector2(700, 24), 13, TEAL)
	_label(game.main_menu, "RECOMMENDED: HEADPHONES  /  LANDSCAPE", Vector2(90, 736), Vector2(650, 28), 14, MUTED)
	_label(game.main_menu, "BLACKWOOD SECURITY   •   RESTRICTED ACCESS", Vector2(90, 824), Vector2(900, 24), 12, MUTED)
	_build_modes()
	_build_settings()
	game.archive_panel = _page()
	_page_title(game.archive_panel, "CLASSIFIED / FIELD RECORD", "BLACKWOOD INCIDENT")
	var chapters := ["I — REOPENING\nRestore the checkpoint relay.", "II — ARMED RESPONSE\nClear a route through Blackwood Security.", "III — THE CABIN\nRecover the rifle and replenish supplies.", "IV — DEAD SIGNAL\nSynchronize the grid as the entity closes in.", "V — EXTRACTION\nRecover evidence and reach the gate.", "VI — LAST SIGNAL\nSurvive the counterattack and leave alive."]
	for i in range(chapters.size()):
		var col := i % 2
		var row := i / 2
		var text := _label(game.archive_panel, chapters[i], Vector2(100 + col * 740, 224 + row * 154), Vector2(640, 114), 22)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := _button(game.archive_panel, "BACK", Vector2(100, 754), Vector2(280, 62))
	back.pressed.connect(func(): game.archive_panel.hide(); game.main_menu.show(); refresh_state())
	pause_panel = _page()
	_page_title(pause_panel, "FIELD OPERATION / SUSPENDED", "PAUSED")
	_label(pause_panel, "Your operation resumes from this exact moment.", Vector2(100, 204), Vector2(1180, 40), 22, MUTED)
	var resume := _button(pause_panel, "RESUME OPERATION", Vector2(100, 300), Vector2(520, 74), true)
	resume.pressed.connect(game.toggle_pause)
	var pause_settings := _button(pause_panel, "SETTINGS", Vector2(100, 398), Vector2(520, 74))
	pause_settings.pressed.connect(func(): open_settings(pause_panel))
	var exit := _button(pause_panel, "SAVE & MAIN MENU", Vector2(100, 496), Vector2(520, 74))
	exit.pressed.connect(game.return_to_menu)
	var controls := _label(pause_panel, "FIELD CONTROLS\n\nWASD / joystick   Move\nMouse / right-screen drag   Look\nLMB / FIRE   Shoot       RMB / AIM   Aim\nR   Reload       Q   Switch weapon\nF   Flashlight       C   Crouch\nShift / RUN   Sprint       E / USE   Interact", Vector2(766, 294), Vector2(670, 354), 21)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_modes() -> void:
	game.mode_panel = _page()
	_page_title(game.mode_panel, "DEPLOYMENT / RULES OF ENGAGEMENT", "CHOOSE YOUR OPERATION")
	var modes := ["STORY", "RUSH", "NIGHTMARE", "ENDLESS", "EXPLORATION", "BLACKOUT"]
	var descriptions := ["The complete Blackwood campaign.", "Faster pursuit. Keep moving.", "Stronger opposition. Limited power.", "Pressure without a safe ending.", "Explore without the Faceless pursuit.", "Minimal battery. Trust the road."]
	for i in range(modes.size()):
		var col := i % 2
		var row := i / 2
		var button := _button(game.mode_panel, "%02d   %s" % [i + 1, modes[i]], Vector2(100 + col * 740, 218 + row * 165), Vector2(660, 70), i == 0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var selected: String = modes[i]
		button.pressed.connect(func(): game.selected_mode = selected; game._start_new_game())
		_label(game.mode_panel, descriptions[i], Vector2(120 + col * 740, 298 + row * 165), Vector2(620, 48), 18, MUTED)
	var back := _button(game.mode_panel, "BACK", Vector2(100, 754), Vector2(280, 62))
	back.pressed.connect(func(): game.mode_panel.hide(); game.main_menu.show(); refresh_state())

func _build_settings() -> void:
	game.settings_panel = _page()
	_page_title(game.settings_panel, "CONFIGURATION / PERSISTENT PROFILE", "SETTINGS")
	var keys := ["quality", "fps"]
	var names := ["RENDER QUALITY", "FRAME LIMIT"]
	var choices := [["PERFORMANCE", "BALANCED", "HIGH", "ULTRA"], ["30 FPS", "60 FPS", "120 FPS"]]
	for i in range(2):
		_label(game.settings_panel, names[i], Vector2(100, 216 + i * 88), Vector2(300, 44), 19, MUTED)
		var option := OptionButton.new()
		option.position = Vector2(436, 210 + i * 88)
		option.size = Vector2(330, 58)
		option.add_theme_font_size_override("font_size", 20)
		option.add_theme_stylebox_override("normal", _style(INK, MUTED))
		for caption in choices[i]: option.add_item(caption)
		var key: String = keys[i]
		option.set_meta("setting_key", key)
		option.item_selected.connect(func(index): game.settings[key] = index if key == "quality" else [30, 60, 120][index]; game._apply_settings())
		game.settings_panel.add_child(option)
	var specs := [["brightness", "BRIGHTNESS", 0.8, 2.2, 0.05], ["night_visibility", "NIGHT VISIBILITY", 0.5, 1.8, 0.05], ["fov", "FIELD OF VIEW", 60.0, 95.0, 1.0], ["sensitivity", "LOOK SENSITIVITY", 0.5, 2.0, 0.05], ["volume", "MASTER VOLUME", 0.0, 1.0, 0.05], ["touch_opacity", "TOUCH OPACITY", 0.3, 1.0, 0.05]]
	for i in range(specs.size()):
		var col := 0 if i < 3 else 1
		var row := i % 3
		var x := 100 + col * 744
		var y := 408 + row * 100
		var spec: Array = specs[i]
		_label(game.settings_panel, spec[1], Vector2(x, y), Vector2(380, 26), 17, MUTED)
		var value_label := _label(game.settings_panel, "", Vector2(x + 488, y), Vector2(140, 28), 18, TEAL)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var slider := HSlider.new()
		slider.position = Vector2(x, y + 34)
		slider.size = Vector2(628, 36)
		slider.min_value = spec[2]
		slider.max_value = spec[3]
		slider.step = spec[4]
		var key: String = spec[0]
		slider.set_meta("setting_key", key)
		slider.value_changed.connect(func(value): game.settings[key] = value; value_label.text = "%d°" % int(value) if key == "fov" else "%d%%" % int(round(value * 100)); game._apply_settings())
		game.settings_panel.add_child(slider)
	var back := _button(game.settings_panel, "SAVE & BACK", Vector2(100, 754), Vector2(300, 62), true)
	back.pressed.connect(close_settings)
	_label(game.settings_panel, "Changes apply immediately. Saved when you leave this screen.", Vector2(430, 770), Vector2(1050, 32), 17, MUTED)

func open_settings(from: Control) -> void:
	settings_return = from
	settings_snapshot = game.settings.duplicate()
	from.hide()
	game.settings_panel.show()
	for child in game.settings_panel.get_children():
		if not child.has_meta("setting_key"): continue
		var key := str(child.get_meta("setting_key"))
		if child is OptionButton:
			child.select(int(game.settings[key]) if key == "quality" else [30, 60, 120].find(int(game.settings[key])))
		elif child is HSlider:
			child.value = float(game.settings[key])
			child.value_changed.emit(child.value)
	refresh_state()

func close_settings() -> void:
	game._save_settings()
	game.settings_panel.hide()
	if settings_return: settings_return.show()
	refresh_state()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if game.cinematic_running:
			game.skip_cinematic()
		elif game.settings_panel.visible:
			close_settings()
		elif game.mode_panel.visible or game.archive_panel.visible:
			game.mode_panel.hide()
			game.archive_panel.hide()
			game.main_menu.show()
			refresh_state()
		else:
			game.toggle_pause()
		get_viewport().set_input_as_handled()

func _build_cinema() -> void:
	game.cinematic_overlay = ColorRect.new()
	game.cinematic_overlay.color = Color.TRANSPARENT
	game.cinematic_overlay.size = DESIGN
	game.cinematic_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	game.cinematic_overlay.visible = false
	design.add_child(game.cinematic_overlay)
	var skip := _button(game.cinematic_overlay, "SKIP  >", Vector2(1392, 90), Vector2(170, 58))
	skip.pressed.connect(game.skip_cinematic)
	var top := ColorRect.new()
	top.size = Vector2(1600, 72)
	top.color = Color.BLACK
	game.cinematic_overlay.add_child(top)
	var bottom := ColorRect.new()
	bottom.position = Vector2(0, 828)
	bottom.size = Vector2(1600, 72)
	bottom.color = Color.BLACK
	game.cinematic_overlay.add_child(bottom)
	game.subtitle_box = ColorRect.new()
	game.subtitle_box.position = Vector2(240, 668)
	game.subtitle_box.size = Vector2(1120, 132)
	game.subtitle_box.color = Color(0.008, 0.016, 0.023, 0.90)
	game.cinematic_overlay.add_child(game.subtitle_box)
	game.subtitle_speaker = _label(game.subtitle_box, "", Vector2(24, 12), Vector2(1072, 24), 15, TEAL)
	game.subtitle_label = _label(game.subtitle_box, "", Vector2(24, 42), Vector2(1072, 80), 22)
	game.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game.cinematic_camera = Camera3D.new()
	game.cinematic_camera.fov = 62.0
	game.cinematic_camera.near = 0.08
	game.add_child(game.cinematic_camera)
	game.cinematic_camera.current = false

func refresh_state() -> void:
	combat_visible = game.game_started and not game.cinematic_running and not get_tree().paused and game.player != null and game.player.alive
	combat.visible = combat_visible
	game.notice.visible = combat_visible or game.main_menu.visible
	touch_controls.visible = combat_visible and (OS.has_feature("mobile") or force_touch)
	touch_controls.modulate.a = float(game.settings.get("touch_opacity", 0.65))
	help_label.visible = not (OS.has_feature("mobile") or force_touch)
	if not touch_controls.visible: game.joystick.reset()
	interaction_button.visible = not game.prompt_label.text.is_empty()
	var save := ConfigFile.new()
	continue_button.disabled = save.load("user://faceless2_save.cfg") != OK
	queue_redraw()

func update_vitals(h: float, s: float, b: float, weapon: String, mag: int, reserve: int) -> void:
	health = h
	health_value.text = "%03d" % int(h)
	health_bar.value = h
	stamina_bar.value = s
	battery_bar.value = b
	health_value.modulate = RED if h < 35 else WHITE
	weapon_label.text = "MK18 / RIFLE" if weapon == "RIFLE" else "G19 / PISTOL"
	ammo_value.text = "%02d / %03d" % [mag, reserve]
	ammo_value.modulate = RED if mag <= (6 if weapon == "RIFLE" else 3) else WHITE
	status_label.text = "RELOAD" if game.player.reloading else ("EMPTY" if mag == 0 else "READY")
	status_label.modulate = RED if mag == 0 else TEAL
	game.hud.text = "%s  /  CH.%02d" % [game.current_zone, game.chapter]
	progress_label.text = "GRID %d/3    EVIDENCE %d/2    KILLS %02d" % [game._relay_count(), game.evidence_collected, game.kills]

func show_notice(text_value: String) -> void:
	game.notice.text = text_value
	notice_time = 2.8

func show_radio(speaker: String, text_value: String) -> void:
	radio_speaker.text = "RADIO / " + speaker
	radio_text.text = text_value
	radio_time = clampf(float(text_value.length()) / 16.0, 4.0, 12.0)

func confirm_hit(killed := false) -> void:
	hit_time = 0.22
	if killed: kill_time = 0.42

func _process(delta: float) -> void:
	var active: bool = game.game_started and not get_tree().paused and not game.cinematic_running and game.player != null and game.player.alive
	if active != combat_visible: refresh_state()
	# UI timers continue for menu notifications; combat effects freeze on pause.
	notice_time = maxf(0, notice_time - delta)
	if notice_time == 0: game.notice.text = ""
	if active:
		hit_time = maxf(0, hit_time - delta)
		kill_time = maxf(0, kill_time - delta)
		damage_time = maxf(0, damage_time - delta)
		shot_time = maxf(0, shot_time - delta)
		damage_direction_time = maxf(0, damage_direction_time - delta)
		critical_time = maxf(0, critical_time - delta)
		radio_time = maxf(0, radio_time - delta)
		radio_panel.visible = radio_time > 0
		interaction_button.visible = not game.prompt_label.text.is_empty()
		heading = fposmod(rad_to_deg(game.player.rotation.y) * -1.0, 360.0)
		var directions := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
		compass_label.text = "%s   %03d°" % [directions[int(round(heading / 45.0)) % 8], int(heading)]
		_update_marker()
	queue_redraw()

func _update_marker() -> void:
	marker_visible = false
	var target: Node3D = game._current_objective().get("target") as Node3D
	if not is_instance_valid(target): return
	var camera: Camera3D = game.player.camera
	var world := target.global_position + Vector3.UP * 1.8
	marker_distance = camera.global_position.distance_to(world)
	var behind := camera.is_position_behind(world)
	var screen: Vector2
	if behind:
		var local := camera.global_transform.affine_inverse() * world
		screen = Vector2(1440 if local.x >= 0 else 160, 450)
	else:
		screen = design.get_global_transform_with_canvas().affine_inverse() * camera.unproject_position(world)
	marker_position = Vector2(clampf(screen.x, 560, 1380), clampf(screen.y, 278, 652))
	marker_offscreen = behind or not marker_position.is_equal_approx(screen)
	marker_visible = marker_distance > 2.5

func reticle_center() -> Vector2:
	# The camera aims at the full viewport centre, even on asymmetrical cutouts.
	return design.get_global_transform_with_canvas().affine_inverse() * (get_viewport_rect().size * 0.5)

func _draw() -> void:
	if not is_instance_valid(design): return
	var menu_visible: bool = game.main_menu.visible or game.mode_panel.visible or game.settings_panel.visible or game.archive_panel.visible or pause_panel.visible
	if menu_visible:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.009, 0.019, 0.027, 0.98))
	draw_set_transform(design.position, 0, design.scale)
	if game.main_menu.visible:
		# Deterministic forest silhouette; no texture downloads or per-frame noise.
		for i in range(18):
			var x := 580.0 + i * 61.0
			var h := 190.0 + fposmod(i * 79.0, 330.0)
			var c := Color(0.04, 0.11, 0.13, 0.70)
			draw_line(Vector2(x, 740), Vector2(x, 740 - h), c, 4)
			for branch in range(5):
				var y := 740.0 - h + branch * h * 0.15
				var spread := 20.0 + branch * 12.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x - spread, y + h * 0.22), Vector2(x + spread, y + h * 0.22)]), c)
		for i in range(12): draw_line(Vector2(650, 780 + i * 4), Vector2(1510, 780 + i * 4), Color(0.11, 0.29, 0.31, 0.12 - i * 0.008), 1)
		draw_line(Vector2(90, 282), Vector2(530, 282), RED, 3)
		draw_line(Vector2(90, 792), Vector2(1500, 792), Color(0.18, 0.30, 0.32), 1)
	if not combat_visible: return
	var center := reticle_center()
	var gap: float = (3.0 if reticle_aiming else 5.0 + game.player.current_spread * 280.0) + shot_time * 65.0
	var color := WHITE if shot_time <= 0 else Color(1, 0.73, 0.38)
	draw_circle(center, 1.6, color)
	if not reticle_aiming:
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + direction * gap, center + direction * (gap + 7), Color(0, 0, 0, 0.7), 4)
			draw_line(center + direction * gap, center + direction * (gap + 7), color, 2)
	if hit_time > 0 or kill_time > 0:
		var hit_color := RED if kill_time > 0 else (Color(1, 0.76, 0.34) if critical_time > 0 else TEAL)
		for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_line(center + direction * 11, center + direction * 18, hit_color, 2.5)
	if damage_direction_time > 0:
		var tint := Color(0.98, 0.30, 0.19, minf(1, damage_direction_time * 2))
		draw_arc(center, 80, damage_bearing - 0.22, damage_bearing + 0.22, 12, tint, 4, true)
		var direction := Vector2.from_angle(damage_bearing)
		draw_colored_polygon(PackedVector2Array([center + direction * 94, center + Vector2.from_angle(damage_bearing - 0.08) * 85, center + Vector2.from_angle(damage_bearing + 0.08) * 85]), tint)
	if damage_time > 0 or health < 35:
		var alpha := maxf(damage_time * 0.48, (35 - health) / 100.0 * (0.7 + sin(Time.get_ticks_msec() * 0.004) * 0.15))
		for i in range(10):
			var tint := Color(0.65, 0.04, 0.015, alpha * (1.0 - i / 10.0) * 0.36)
			draw_rect(Rect2(Vector2(i * 7, i * 7), DESIGN - Vector2.ONE * i * 14), tint, false, 8)
	if marker_visible:
		var c := marker_position
		if marker_offscreen:
			var sign_x := -1.0 if c.x < 800 else 1.0
			draw_polyline(PackedVector2Array([c + Vector2(-sign_x * 6, -8), c + Vector2(sign_x * 6, 0), c + Vector2(-sign_x * 6, 8)]), TEAL, 2)
		else:
			draw_polyline(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0), c + Vector2(0, -8)]), TEAL, 2)
		draw_string(ThemeDB.fallback_font, c + Vector2(-20, 30), "%.0f m" % marker_distance, HORIZONTAL_ALIGNMENT_CENTER, 48, 15, TEAL)
