extends Control
var kind := "tokens"
var paid := false
var available := false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var ink := Color(.96,.96,.96) if available else Color(.62,.62,.62)
	var center := size*.5
	draw_circle(center,35,Color(.13,.13,.13))
	if kind == "tokens":
		var points := PackedVector2Array()
		for i in range(7):points.append(center+Vector2.from_angle(i*TAU/6.0)*28)
		draw_polyline(points,ink,2,true)
		draw_line(center+Vector2(-12,9),center+Vector2(12,-9),ink,4,true)
		draw_line(center+Vector2(-12,-3),center+Vector2(12,-3),ink,2,true)
	elif kind == "badge":
		var diamond := PackedVector2Array([center+Vector2(0,-31),center+Vector2(28,0),center+Vector2(0,31),center+Vector2(-28,0),center+Vector2(0,-31)])
		draw_polyline(diamond,ink,2,true)
		draw_circle(center,10,ink,false,2,true)
		draw_line(center+Vector2(-18,24),center+Vector2(-18,40),ink,2,true)
		draw_line(center+Vector2(18,24),center+Vector2(18,40),ink,2,true)
	else:
		var crown := PackedVector2Array([center+Vector2(-29,17),center+Vector2(-33,-15),center+Vector2(-14,-3),center+Vector2(0,-31),center+Vector2(14,-3),center+Vector2(33,-15),center+Vector2(29,17),center+Vector2(-29,17)])
		draw_polyline(crown,ink,2,true)
		draw_line(center+Vector2(-25,26),center+Vector2(25,26),ink,3,true)
	if paid:
		draw_line(Vector2(12,12),Vector2(28,12),ink,1,true)
		draw_line(size-Vector2(28,12),size-Vector2(12,12),ink,1,true)
