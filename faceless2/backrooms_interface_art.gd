extends Control
# Authored 2D sector diagrams. Static geometry: no perpetual process or shader.
const SignalPalette = preload("backrooms_interface_theme.gd")
var hero := false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),SignalPalette.INK)
	for x in range(0,1601,80): draw_line(Vector2(x,0),Vector2(x,900),Color("0d2540"),1)
	for y in range(0,901,80): draw_line(Vector2(0,y),Vector2(1600,y),Color("0d2540"),1)
	draw_colored_polygon(PackedVector2Array([Vector2(810,0),Vector2(1600,0),Vector2(1600,900),Vector2(1070,900),Vector2(690,520)]),Color("0a1f39"))
	draw_line(Vector2(805,0),Vector2(1230,900),Color("185190"),2,true)
	for i in range(9):
		var start := Vector2(1385+i*20,0)
		draw_line(start,start+Vector2(130,130),SignalPalette.BLUE,7,true)
	draw_rect(Rect2(44,44,4,42),SignalPalette.GOLD)
	draw_line(Vector2(44,867),Vector2(1556,867),SignalPalette.BLUE,2)
	if not hero: return
	# An abstract overhead plan for the two shipped sectors, not fake gameplay.
	for sector in range(2):
		var origin := Vector2(900,250+sector*260)
		draw_rect(Rect2(origin,Vector2(570,204)),SignalPalette.SURFACE)
		draw_rect(Rect2(origin,Vector2(570,204)),SignalPalette.BLUE,false,2)
		for j in range(5):
			var at := origin+Vector2(60+j*96,45+(j%2)*65)
			draw_rect(Rect2(at,Vector2(62,22)),SignalPalette.BLUE if sector == 0 else Color("198b9c"))
			draw_line(at,at+Vector2(0,55),SignalPalette.CYAN,2)
		var points := PackedVector2Array([origin+Vector2(22,170),origin+Vector2(110,170),origin+Vector2(110,135),origin+Vector2(300,135),origin+Vector2(300,65),origin+Vector2(540,65)])
		draw_polyline(points,SignalPalette.GOLD,3,true)
		for at in [origin+Vector2(22,170),origin+Vector2(540,65)]:
			draw_circle(at,7,SignalPalette.GOLD)
			draw_circle(at,13,SignalPalette.CYAN,false,1.5,true)
