extends Control
# Original SIGNAL atlas: capped 30Hz motion, active only on visible menu/search.
const SignalPalette = preload("backrooms_interface_theme.gd")
var hero := false
var searching := false
var phase := 0.0
var redraw_clock := 0.0
func _process(delta: float) -> void:
	if not is_visible_in_tree() or not (hero or searching): return
	phase = fposmod(phase+delta*.23,TAU)
	redraw_clock += delta
	if redraw_clock >= 1.0/30.0:
		redraw_clock = 0.0
		queue_redraw()
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
	if hero or searching:
		var center := Vector2(1185,476) if hero else Vector2(1512,154)
		var radius := 335.0 if hero else 24.0
		for ring in range(3):
			var at := radius+ring*12.0
			draw_arc(center,at,phase+ring*PI*.7,phase+ring*PI*.7+PI*1.35,64,Color(.16,.65,.95,.34),2,true)
		for index in range(12):
			var direction := Vector2.from_angle(phase+index*TAU/12.0)
			draw_line(center+direction*(radius-6),center+direction*(radius+5),SignalPalette.GOLD,2,true)
	if not hero: return
	# An abstract overhead plan for the two shipped sectors, not fake gameplay.
	for sector in range(4):
		var origin := Vector2(900,250+sector*130)
		draw_rect(Rect2(origin,Vector2(570,112)),SignalPalette.SURFACE)
		draw_rect(Rect2(origin,Vector2(570,112)),SignalPalette.BLUE,false,2)
		for j in range(5):
			var at := origin+Vector2(60+j*96,40+(j%2)*24)
			draw_rect(Rect2(at,Vector2(62,12)),SignalPalette.BLUE if sector == 0 else Color("198b9c"))
			draw_line(at,at+Vector2(0,28),SignalPalette.CYAN,2)
		var points := PackedVector2Array([origin+Vector2(22,96),origin+Vector2(110,96),origin+Vector2(110,78),origin+Vector2(300,78),origin+Vector2(300,48),origin+Vector2(540,48)])
		draw_polyline(points,SignalPalette.GOLD,3,true)
		for at in [origin+Vector2(22,96),origin+Vector2(540,48)]:
			draw_circle(at,7,SignalPalette.GOLD)
			draw_circle(at,13,SignalPalette.CYAN,false,1.5,true)
