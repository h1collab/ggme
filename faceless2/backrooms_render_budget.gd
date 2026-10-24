extends RefCounted
# Mobile pixel budget + hysteresis. Never scales the 2D canvas/touch coordinates.
var limits := Vector2.ONE
var scale := 1.0
var frame_ema := 1.0/60.0
var warmup := 8.0
var cooldown := 0.0
var slow_seconds := 0.0
var fast_seconds := 0.0
var changes := 0
func configure(preset: int, pixels: Vector2i, mobile: bool) -> float:
	preset = clampi(preset,0,2)
	var area := maxf(1,float(pixels.x)*float(pixels.y))
	var cap := sqrt(float([600000,900000,1400000][preset])/area)
	var high := minf(float([.60,.74,.90][preset]),cap) if mobile else float([.75,1.0,1.0][preset])
	limits = Vector2(high*.76,high) if mobile else Vector2(high,high)
	scale = high
	frame_ema = 1.0/60.0
	warmup = 8.0
	cooldown = 0.0
	slow_seconds = 0.0
	fast_seconds = 0.0
	changes = 0
	return scale
func sample(delta: float, paused: bool = false) -> float:
	if paused or delta <= 0.0: return scale
	var step := minf(delta,.10)
	frame_ema = lerpf(frame_ema,step,1.0-exp(-step*2.0))
	if warmup > 0:
		warmup -= step
		return scale
	cooldown = maxf(0,cooldown-step)
	slow_seconds = slow_seconds+step if frame_ema > .024 else 0.0
	fast_seconds = fast_seconds+step if frame_ema < .018 else 0.0
	if cooldown > 0: return scale
	var next := scale
	if slow_seconds >= 2.5: next = maxf(limits.x,scale-.05)
	elif fast_seconds >= 12.0: next = minf(limits.y,scale+.025)
	if not is_equal_approx(next,scale):
		scale = next
		changes += 1
		cooldown = 6.0
		slow_seconds = 0.0
		fast_seconds = 0.0
	return scale
