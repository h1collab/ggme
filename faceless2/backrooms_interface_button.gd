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
	var ink := SignalTheme.GOLD if selected or primary else SignalTheme.CYAN
	if selected or primary:
		draw_rect(Rect2(0,0,4,size.y),ink)
		draw_line(Vector2(12,size.y-7),Vector2(size.x-16,size.y-7),ink,2,true)
	var corner := Vector2(size.x-7,7)
	draw_line(corner+Vector2(-12,0),corner+Vector2(0,12),ink,2,true)
	if glow > .005:
		draw_rect(Rect2(5,5,size.x-10,size.y-10),Color(ink,glow*.14))
