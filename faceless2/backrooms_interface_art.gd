extends Control
# Static monochrome menu backdrop; only an active search indicator animates.
const SignalPalette = preload("backrooms_interface_theme.gd")
var hero := false
var searching := false
var phase := 0.0
var redraw_clock := 0.0
func _process(delta: float) -> void:
	if not is_visible_in_tree() or not searching: return
	phase = fposmod(phase+delta,TAU)
	redraw_clock += delta
	if redraw_clock >= 1.0/20.0:
		redraw_clock = 0.0
		queue_redraw()
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),SignalPalette.INK)
	draw_line(Vector2(44,108),Vector2(1556,108),Color(.22,.22,.22),1)
	draw_line(Vector2(44,867),Vector2(1556,867),Color(.22,.22,.22),1)
	if searching:
		draw_arc(Vector2(1512,154),18,phase,phase+PI*1.4,32,Color.WHITE,2,true)
	if not hero: return
	# A sparse alley plan keeps the menu's right-hand column quiet.
	for sector in range(4):
		var origin := Vector2(940,300+sector*130)
		for side in [-1,1]:
			for block in range(4):
				var at := origin+Vector2(block*115,0 if side < 0 else 50)
				draw_rect(Rect2(at,Vector2(80,22)),Color(.16,.16,.16))
		draw_line(origin+Vector2(-18,36),origin+Vector2(450,36),Color(.65,.65,.65),1,true)
