extends CharacterBody3D

var game: Node
var camera: Camera3D
var joystick: Control
var flashlight: SpotLight3D
var health := 100.0
var stamina := 100.0
var battery := 100.0
var yaw := 0.0
var pitch := 0.0
var look_touch := -1
var sprint_touch := false
var crouched := false
var alive := true

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.72
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)
	camera = Camera3D.new()
	camera.position = Vector3(0,1.58,0)
	camera.fov = 74.0
	add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.10,-0.10,-0.05)
	flashlight.rotation_degrees.x = -1.0
	flashlight.spot_range = 19.0
	flashlight.spot_angle = 30.0
	flashlight.light_energy = 3.2
	flashlight.light_color = Color(0.86,0.93,1.0)
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): mv.x -= 1.0
	if Input.is_key_pressed(KEY_D): mv.x += 1.0
	if Input.is_key_pressed(KEY_W): mv.y -= 1.0
	if Input.is_key_pressed(KEY_S): mv.y += 1.0
	if joystick and joystick.value.length() > 0.04:
		mv = joystick.value
	var wants_run := sprint_touch or Input.is_key_pressed(KEY_SHIFT)
	var running := wants_run and stamina > 1.0 and mv.length() > 0.12 and not crouched
	var speed := 5.8 if running else (2.0 if crouched else 3.7)
	if running:
		stamina = max(0.0,stamina-delta*22.0)
	else:
		stamina = min(100.0,stamina+delta*13.0)
	var dir := global_transform.basis * Vector3(mv.x,0,mv.y)
	dir.y = 0.0
	if dir.length() > 0.01: dir = dir.normalized()
	velocity.x = dir.x*speed
	velocity.z = dir.z*speed
	velocity.y = -0.2 if is_on_floor() else velocity.y - 18.0*delta
	move_and_slide()
	camera.position.y = lerpf(camera.position.y,1.10 if crouched else 1.58,delta*9.0)
	if flashlight.visible:
		battery = max(0.0,battery-delta*1.35)
		if battery <= 0.0:
			flashlight.visible = false
	if game:
		game.update_hud(health,stamina,battery)

func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look((event as InputEventMouseMotion).relative*0.0023)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.position.x > get_viewport().get_visible_rect().size.x*0.43:
			if st.pressed and look_touch == -1:
				look_touch = st.index
			elif not st.pressed and st.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == look_touch:
			_look(sd.relative*0.0040)

func _look(v: Vector2) -> void:
	var sens := 1.0
	if game: sens = game.get_look_sensitivity()
	yaw -= v.x*sens
	pitch = clampf(pitch-v.y*sens,-1.25,1.25)
	rotation.y = yaw
	camera.rotation.x = pitch

func toggle_flashlight() -> void:
	if battery > 0.0:
		flashlight.visible = not flashlight.visible

func set_running(on: bool) -> void:
	sprint_touch = on

func toggle_crouch() -> void:
	crouched = not crouched

func take_damage(amount: float) -> void:
	if not alive: return
	health = max(0.0,health-amount)
	if game: game.player_hurt()
	if health <= 0.0:
		alive = false
		if game: game.player_dead()

func add_battery(amount: float) -> void:
	battery = min(100.0,battery+amount)

func restore_full() -> void:
	health = 100.0
	stamina = 100.0
	battery = 100.0
	alive = true
	velocity = Vector3.ZERO
