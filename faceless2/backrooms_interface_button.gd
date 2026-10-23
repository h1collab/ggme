extends Button
const SignalTheme = preload("backrooms_interface_theme.gd")
var glow := 0.0:
	set(value):
		glow = value
		queue_redraw()
var selected := false
var primary := false
var motion: Tween
func _ready() -> void:
	mouse_entered.connect(func(): feedback(1.0))
	mouse_exited.connect(func(): feedback(0.0))
	button_down.connect(func(): feedback(1.0))
	button_up.connect(func(): feedback(0.0))
	focus_entered.connect(func(): feedback(1.0))
	focus_exited.connect(func(): feedback(0.0))
func feedback(value: float) -> void:
	if is_instance_valid(motion): motion.kill()
	motion = create_tween()
	motion.tween_property(self,"glow",value,.12)
func set_selection(value: bool) -> void:
	if selected == value: return
	selected = value
	queue_redraw()
func _draw() -> void:
	# One selection rule, without decorative slashes or doubled edge marks.
	if selected:
		draw_line(Vector2(8,size.y-3),Vector2(size.x-8,size.y-3),SignalTheme.WHITE,2,true)
	if glow > .005:
		draw_rect(Rect2(1,1,size.x-2,size.y-2),Color(1,1,1,glow*.09))
