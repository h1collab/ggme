extends Control
# Glitch is confined to tiny decorative rules; text and hit areas stay still.
const SignalPalette = preload("backrooms_interface_theme.gd")
var hero := false
var searching := false
var motion_enabled := true
var phase := 0.0
var redraw_clock := 0.0
func _process(delta: float) -> void:
	if not is_visible_in_tree() or not (searching or motion_enabled): return
	phase = fposmod(phase+delta,6.0)
	redraw_clock += delta
	if redraw_clock >= .05:
		redraw_clock = 0.0
		queue_redraw()
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),SignalPalette.INK)
	for y in [108.0,867.0]:draw_line(Vector2(44,y),Vector2(1556,y),Color(.22,.22,.22),1)
	# Two restrained breaks per six-second cycle, never a screen flash.
	if motion_enabled and (phase < .10 or (phase > .22 and phase < .27)):
		var shift := 16.0 if phase < .10 else -8.0
		draw_rect(Rect2(1200+shift,106,88,2),Color(.65,.65,.65,.5))
		draw_rect(Rect2(260-shift,866,28,2),Color(.45,.45,.45,.5))
	if searching:draw_arc(Vector2(1512,154),18,phase,phase+PI*1.4,32,Color(.8,.8,.8),2,true)
