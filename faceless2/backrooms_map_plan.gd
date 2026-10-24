extends Control
var arena: Node3D
var map_id := 0
func _ready() -> void:mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(.025,.025,.025))
	var scale_factor := minf((size.x-12)/72,(size.y-12)/96)
	var origin := (size-Vector2(72,96)*scale_factor)*.5
	for footprint: Rect2 in arena.ground_plan(map_id):
		draw_rect(Rect2(origin+(footprint.position+Vector2(36,48))*scale_factor,footprint.size*scale_factor),Color(.6,.6,.6))
	for seat in range(1,7):
		var spawn: Vector3 = arena.spawn_for(seat)
		draw_circle(origin+(Vector2(spawn.x,spawn.z)+Vector2(36,48))*scale_factor,2.0,Color.WHITE)
	draw_rect(Rect2(origin,Vector2(72,96)*scale_factor),Color(.35,.35,.35),false,1)
