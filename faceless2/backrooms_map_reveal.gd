extends Control
# Presentation follows the chosen training map or the received authority map.
# It never chooses a different map, changes ENet state, or starts a second room.
const Catalog = preload("backrooms_map_catalog.gd")
var ui: Control
var state := "idle"
var current := 0
var target := -1
var last_committed := -1
var clock := 0.0
var tick := 0.0
var next_tick := 0.0
var step := 0
var total_steps := 0
var local_training := false
var center_image: TextureRect
var left_image: TextureRect
var right_image: TextureRect
var heading: Label
var title_label: Label
var status_label: Label
var action: Button
var visited: Array[int] = []
func configure(owner_ui: Control) -> void:
	for id in range(4):Catalog.texture(id)
	ui = owner_ui;name = "MapRoulette";size = Vector2(1600,900);z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new();backdrop.color = Color(.015,.015,.015,1);backdrop.size = size;backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE;add_child(backdrop)
	ui._label(self,"NULRYTH / MATCH",Vector2(72,47),260,22)
	preload("backrooms_developer_brand.gd").badge(self,Vector2(380,43),34)
	heading = ui._label(self,ui.localized("DECODING DESTINATION","解析目的地"),Vector2(100,123),1400,36)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label = ui._label(self,"",Vector2(120,182),1360,20,ui.MUTED);status_label.size.y = 36;status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_image = Catalog.image(self,3,Rect2(96,331,236,150));left_image.modulate = Color(.4,.4,.4)
	right_image = Catalog.image(self,1,Rect2(1268,331,236,150));right_image.modulate = Color(.4,.4,.4)
	ui._card(self,Rect2(364,234,872,430),Color(.1,.1,.1))
	center_image = Catalog.image(self,0,Rect2(370,240,860,418))
	title_label = ui._label(self,"",Vector2(270,684),1060,37);title_label.size.y = 58;title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui._label(self,"01  /  02  /  03  /  04",Vector2(650,745),320,18,ui.MUTED).size.y = 28
	action = ui._button(self,"",Rect2(650,799,300,58),_action)
	visible = false
func begin(training: bool = false) -> void:
	ui.release_mobile_inputs()
	heading.text = ui.localized("DECODING DESTINATION","解析目的地")
	local_training = training;state = "searching";target = -1;last_committed = -1;current = 0;clock = 0;tick = 0;visited.clear()
	visible = true;ui.modal = true;Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	action.text = ui.localized("CANCEL","取消")
	_select(0)
	status_label.text = ui.localized("SEARCHING / WAITING FOR ROOM MAP","正在搜索 / 等待房间地图")
func resolve(id: int) -> void:
	if not visible or id not in [0,1,2,3]:return
	if target == id and state in ["settling","locked"]:return
	target = id;clock = 0;step = 0
	total_steps = 14+posmod(target-(current+14),4)
	next_tick = .08;state = "settling"
	status_label.text = ui.localized("DESTINATION RECEIVED / LOCKING","已收到实际地图 / 正在锁定")
	action.text = ui.localized("SKIP ANIMATION","跳过动画")
	if not ui.game.interface_motion:_lock()
func _select(id: int) -> void:
	current = posmod(id,4)
	if not visited.has(current):visited.append(current)
	center_image.texture = Catalog.texture(current)
	left_image.texture = Catalog.texture(posmod(current-1,4));right_image.texture = Catalog.texture(posmod(current+1,4))
	title_label.text = Catalog.title(current,ui.game.language == "zh")
func _lock() -> void:
	_select(target);state = "locked";clock = 0
	status_label.text = ui.localized("MAP CONFIRMED / ","地图已确认 / ")+ui.localized("TRAINING" if local_training else "HOST / SERVER","训练" if local_training else "房主 / 服务器")
	action.text = ui.localized("ENTER MAP","进入地图")
func _process(delta: float) -> void:
	advance(delta)
func advance(delta: float) -> void:
	if not visible:return
	clock += delta
	if state == "searching":
		if not local_training and clock > .5 and not ui.game.rooms.matching and ui.game.rooms.operation.is_empty() and ui.game.net.mode == "solo":
			fail(ui.game.rooms.match_message if not ui.game.rooms.match_message.is_empty() else ui.localized("No room connected. Try again.","尚未连接房间，请重试。"));return
		if clock >= 45:fail(ui.localized("Connection timed out. Try again.","连接超时，请重试。"));return
		if ui.game.interface_motion:
			tick += delta
			if tick >= .1:
				var turns := floori(tick/.1);tick = fposmod(tick,.1);_select(current+turns)
	elif state == "settling":
		while state == "settling" and clock >= next_tick:
			step += 1;_select(current+1)
			if step >= total_steps:_lock();break
			next_tick += lerpf(.08,.33,pow(float(step)/total_steps,2))
	elif state == "locked" and clock >= (.75 if ui.game.interface_motion else .2):
		_complete()
func _complete() -> void:
	if target not in [0,1,2,3]:return
	last_committed = target
	var training := local_training
	visible = false;state = "idle"
	if training:ui.game.net.leave();ui.game.start_fps_arena(target)
	if ui.game.fps.active:
		ui.modal = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ui.touch_controls_enabled() else Input.MOUSE_MODE_CAPTURED
func fail(message: String) -> void:
	state = "error";target = -1;status_label.text = message;action.text = ui.localized("BACK","返回")
	ui.game.rooms.cancel_match()
func cancel() -> void:
	var training := local_training
	visible = false;state = "idle";target = -1
	ui.game.rooms.cancel_match()
	if not training and ui.game.net.mode != "solo":ui.game.net.leave()
	if not training:ui.game.running = false;ui.open_lobby()
func _action() -> void:
	if state in ["searching","error"]:cancel()
	elif target >= 0:_lock();_complete()
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_action();get_viewport().set_input_as_handled()
