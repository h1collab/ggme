extends CanvasLayer
# The launch scene has no dependency on the heavy gameplay script graph.
# Critical asset bytes load on Godot's loader thread; world initialization reports
# completed stages, so the bar never claims readiness before the scene is ready.
var backdrop: ColorRect
var canvas: Control
var progress_bar: ProgressBar
var status_text: Label
var percent_text: Label
var mark: Control
var resources: Array[String] = []
var retained: Array[Resource] = []
var index := 0
var requested := false
var game_started := false
var finished := false
var failed := false
var progress_value := 0.0
var samples: Array[float] = []
var clock := 0.0
var redraw_clock := 0.0
var completed_stages := 0
const STAGES := 6
func _ready() -> void:
	layer = 100
	if OS.has_feature("android"): DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	_build()
	get_viewport().size_changed.connect(_fit)
	_fit()
	for file in ["story_font.otf","huuxloc_backroom.glb","crew.glb","first_person_arms.glb","first_person_legs.glb","iphone17_pro.glb","wakeup_wall.glb","wakeup_floor_panel.glb","wakeup_door_single_closed.glb","flashlight_cc0.glb"]:
		var path: String = "res://assets/vendor/"+file
		if ResourceLoader.exists(path): resources.append(path)
	_request_next()
func _fit() -> void:
	var extent := get_viewport().get_visible_rect().size
	var factor := minf(extent.x/1600.0,extent.y/900.0)
	canvas.scale = Vector2.ONE*factor
	canvas.position = (extent-Vector2(1600,900)*factor)*.5
func _label(value: String, at: Vector2, width: float, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new();label.text = value;label.position = at;label.size = Vector2(width,font_size*1.6)
	label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color);canvas.add_child(label)
	return label
func _build() -> void:
	backdrop = ColorRect.new();backdrop.color = Color("080808");backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(backdrop)
	canvas = Control.new();canvas.size = Vector2(1600,900);add_child(canvas)
	_label("ZORIX / SYSTEM START",Vector2(180,162),1240,18,Color(.55,.55,.55))
	_label("STRINOVA",Vector2(172,286),1250,94)
	_label("S1  /  FIRST SIGNAL",Vector2(180,420),1240,22,Color(.7,.7,.7))
	progress_bar = ProgressBar.new();progress_bar.position = Vector2(180,594);progress_bar.size = Vector2(1240,5);progress_bar.show_percentage = false
	var back := StyleBoxFlat.new();back.bg_color = Color(.18,.18,.18)
	var fill := StyleBoxFlat.new();fill.bg_color = Color.WHITE
	progress_bar.add_theme_stylebox_override("background",back);progress_bar.add_theme_stylebox_override("fill",fill);progress_bar.add_theme_font_size_override("font_size",1);canvas.add_child(progress_bar)
	progress_bar.set_deferred("size",Vector2(1240,5))
	status_text = _label("READING RESOURCES",Vector2(180,632),1000,19,Color(.65,.65,.65))
	percent_text = _label("00%",Vector2(1260,620),160,34);percent_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mark = ColorRect.new();mark.color = Color(.7,.7,.7);mark.size = Vector2(34,2);mark.position = Vector2(180,539);canvas.add_child(mark)
	_label("BLACK / WHITE / SIGNAL",Vector2(180,750),1240,15,Color(.4,.4,.4))
func _request_next() -> void:
	requested = ResourceLoader.load_threaded_request(resources[index]) == OK
	if not requested: _fail()
func _set_progress(value: float) -> void:
	progress_value = maxf(progress_value,clampf(value,0,100))
	progress_bar.value = progress_value
	percent_text.text = "%02d%%" % floori(progress_value)
	samples.append(progress_value)
func _process(delta: float) -> void:
	clock += delta;redraw_clock += delta
	if redraw_clock >= .05:
		redraw_clock = 0
		# A quiet moving cursor, never a full-screen or body-text flash.
		mark.position.x = 180+fposmod(clock*.22,1.0)*1206
	if failed or game_started or not requested: return
	var report: Array = []
	var state := ResourceLoader.load_threaded_get_status(resources[index],report)
	var ratio: float = float(report[0]) if not report.is_empty() else 0.0
	_set_progress((float(index)+ratio)/float(resources.size())*35.0)
	if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: _fail(); return
	if state != ResourceLoader.THREAD_LOAD_LOADED: return
	retained.append(ResourceLoader.load_threaded_get(resources[index]))
	index += 1
	if index < resources.size(): _request_next()
	else:
		game_started = true
		status_text.text = "BUILDING WORLD"
		_start_game.call_deferred()
func _start_game() -> void:
	# Ensure the initialization caption/bar has reached the viewport first.
	get_tree().process_frame.connect(_instantiate_game,CONNECT_ONE_SHOT)
func _instantiate_game() -> void:
	var packed := load("res://main.tscn") as PackedScene
	if packed == null: _fail(); return
	var game := packed.instantiate()
	get_tree().root.add_child(game)
func set_stage(stage: int, caption: String) -> void:
	completed_stages = maxi(completed_stages,clampi(stage,0,STAGES))
	status_text.text = caption
	_set_progress(35.0+60.0*completed_stages/STAGES)
func finish(game: Node) -> void:
	if finished: return
	finished = true
	_set_progress(100)
	status_text.text = "READY"
	game.set_meta("boot_progress",samples.duplicate())
	game.set_meta("boot_stages",completed_stages)
	get_tree().current_scene = game
	get_tree().create_timer(.12).timeout.connect(_fade_handoff)
func _fade_handoff() -> void:
	var fade := create_tween().set_parallel()
	fade.tween_property(canvas,"modulate:a",0.0,.18)
	fade.tween_property(backdrop,"modulate:a",0.0,.18)
	fade.finished.connect(_release)
func _release() -> void:
	retained.clear()
	queue_free()
func _fail() -> void:
	failed = true
	status_text.text = "LOADING FAILED / RESTART TO RETRY"
	set_process(false)
