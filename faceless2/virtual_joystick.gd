extends Control

var value := Vector2.ZERO
var pointer_id := -1
var drag_center := Vector2.ZERO
var radius := 78.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(190,190)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and pointer_id == -1:
			pointer_id = t.index
			drag_center = t.position
			_update_value(t.position)
		elif not t.pressed and t.index == pointer_id:
			pointer_id = -1
			value = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == pointer_id:
			_update_value(d.position)

func _update_value(pos: Vector2) -> void:
	var offset := pos - drag_center
	if offset.length() > radius:
		offset = offset.normalized() * radius
	value = offset / radius
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	draw_circle(c,76.0,Color(0.02,0.04,0.05,0.62))
	draw_circle(c,70.0,Color(0.12,0.52,0.57,0.20),false,3.0)
	var knob := c + value * 48.0
	draw_circle(knob,28.0,Color(0.70,0.86,0.88,0.72))
	draw_circle(knob,22.0,Color(0.10,0.44,0.50,0.52))
