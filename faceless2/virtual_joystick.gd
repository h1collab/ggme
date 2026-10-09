extends Control

var value := Vector2.ZERO
var pointer_id := -1
var radius := 78.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(func(): if not is_visible_in_tree(): reset())
	queue_redraw()

func reset() -> void:
	pointer_id = -1
	value = Vector2.ZERO
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and pointer_id == -1:
		pointer_id = event.index
		_update_value(event.position)
		accept_event()

func _input(event: InputEvent) -> void:
	# Release and drag may arrive outside the control's rectangle.
	if pointer_id == -1: return
	if event is InputEventScreenTouch and event.index == pointer_id and not event.pressed:
		reset()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == pointer_id:
		_update_value(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()

func _update_value(local_position: Vector2) -> void:
	var offset := (local_position - size * 0.5).limit_length(radius)
	value = offset / radius
	if value.length() < 0.08: value = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, 94, Color(0.015, 0.035, 0.042, 0.65))
	draw_circle(c, 86, Color(0.32, 0.73, 0.74, 0.42), false, 2, true)
	draw_circle(c, 58, Color(0.28, 0.59, 0.61, 0.16), false, 1, true)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + direction * 75, c + direction * 82, Color(0.60, 0.81, 0.82, 0.7), 2)
	var knob := c + value * 58
	draw_circle(knob, 29, Color(0.18, 0.41, 0.43, 0.9))
	draw_circle(knob, 29, Color(0.57, 0.85, 0.84, 0.85), false, 2, true)
