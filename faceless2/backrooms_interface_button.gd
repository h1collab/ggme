extends Button
const SignalTheme = preload("backrooms_interface_theme.gd")
var glow := 0.0:
	set(value):glow = value;queue_redraw()
var selected := false
var primary := false
var motion: Tween
func _ready() -> void:
	for event in [mouse_entered,mouse_exited,button_down,button_up,focus_entered,focus_exited]:event.connect(feedback)
func feedback() -> void:
	# Resolve the combined state once: focus loss must not cancel hover/press.
	var target := 1.0 if is_hovered() or has_focus() or button_pressed else 0.0
	if is_instance_valid(motion):motion.kill()
	motion = create_tween();motion.tween_property(self,"glow",target,.12)
func set_selection(value: bool) -> void:
	if selected == value:return
	selected = value;queue_redraw()
func _draw() -> void:
	if selected:draw_line(Vector2(8,size.y-3),Vector2(size.x-8,size.y-3),SignalTheme.WHITE,2,true)
	if primary:draw_line(Vector2(0,0),Vector2(size.x,0),Color(.7,.7,.7),2)
	if glow > .005:draw_rect(Rect2(1,1,size.x-2,size.y-2),Color(1,1,1,glow*.07))
