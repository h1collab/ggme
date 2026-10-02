extends Control

var value: Vector2 = Vector2.ZERO
var pointer_id: int = -1
var drag_center: Vector2 = Vector2.ZERO
var radius: float = 78.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(190, 190)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and pointer_id == -1:
			pointer_id = touch.index
			drag_center = touch.position
			_update_value(touch.position)
		elif not touch.pressed and touch.index == pointer_id:
			pointer_id = -1
			value = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == pointer_id:
			_update_value(drag.position)

func _update_value(pos: Vector2) -> void:
	var offset: Vector2 = pos - drag_center
	if offset.length() > radius:
		offset = offset.normalized() * radius
	value = offset / radius
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, 76.0, Color(0.07, 0.10, 0.15, 0.46))
	draw_circle(center, 70.0, Color(0.26, 0.34, 0.44, 0.22), false, 4.0)
	var knob: Vector2 = center + value * 48.0
	draw_circle(knob, 29.0, Color(0.82, 0.87, 0.93, 0.78))
	draw_circle(knob, 23.0, Color(0.33, 0.46, 0.63, 0.54))
