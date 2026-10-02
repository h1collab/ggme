extends Control

var value := Vector2.ZERO
var pointer := -1
var center := Vector2.ZERO
var radius := 78.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(190,190)
	queue_redraw()

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed and pointer == -1:
			pointer = event.index
			center = event.position
			_update_value(event.position)
		elif not event.pressed and event.index == pointer:
			pointer = -1
			value = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == pointer:
		_update_value(event.position)

func _update_value(pos: Vector2):
	var d := pos - center
	if d.length() > radius:
		d = d.normalized() * radius
	value = d / radius
	queue_redraw()

func _draw():
	var c := size * 0.5
	draw_circle(c, 76.0, Color(0.08,0.10,0.14,0.48))
	draw_circle(c, 70.0, Color(0.2,0.28,0.38,0.22), false, 4.0)
	var knob := c + value * 48.0
	draw_circle(knob, 28.0, Color(0.78,0.84,0.92,0.78))
	draw_circle(knob, 24.0, Color(0.34,0.45,0.60,0.55))
