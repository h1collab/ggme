extends CharacterBody3D

var game: Node
var camera: Camera3D
var joystick: Control
var health := 100.0
var stamina := 100.0
var yaw := 0.0
var pitch := 0.0
var look_touch := -1
var attack_cooldown := 0.0
var hurt_lock := 0.0

func _ready():
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	camera = Camera3D.new()
	camera.position = Vector3(0,1.58,0)
	camera.fov = 76.0
	add_child(camera)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	attack_cooldown = max(0.0, attack_cooldown - delta)
	hurt_lock = max(0.0, hurt_lock - delta)
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): mv.x -= 1.0
	if Input.is_key_pressed(KEY_D): mv.x += 1.0
	if Input.is_key_pressed(KEY_W): mv.y -= 1.0
	if Input.is_key_pressed(KEY_S): mv.y += 1.0
	if joystick and joystick.value.length() > 0.04:
		mv = joystick.value
	var sprint := Input.is_key_pressed(KEY_SHIFT) and stamina > 1.0 and mv.length() > 0.15
	var speed := 6.2 if sprint else 4.0
	if sprint:
		stamina = max(0.0, stamina - delta * 20.0)
	else:
		stamina = min(100.0, stamina + delta * 14.0)
	var local := Vector3(mv.x,0,mv.y)
	var dir := global_transform.basis * local
	dir.y = 0
	if dir.length() > 0.01:
		dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y += -18.0 * delta if not is_on_floor() else -0.2
	move_and_slide()
	if game:
		game.update_player_hud(health, stamina)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * 0.0024)
	elif event is InputEventScreenTouch:
		var w := get_viewport().get_visible_rect().size.x
		if event.position.x > w * 0.45:
			if event.pressed and look_touch == -1:
				look_touch = event.index
			elif not event.pressed and event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag and event.index == look_touch:
		_look(event.relative * 0.0040)

func _look(v: Vector2):
	yaw -= v.x
	pitch = clampf(pitch - v.y, -1.28, 1.28)
	rotation.y = yaw
	camera.rotation.x = pitch

func attack(power := 1.0):
	if attack_cooldown > 0.0 or stamina < 5.0:
		return
	attack_cooldown = 0.34 if power <= 1.0 else 0.7
	stamina = max(0.0, stamina - (9.0 if power <= 1.0 else 18.0))
	if game:
		game.player_melee_attack(power)

func take_damage(amount: float):
	if hurt_lock > 0.0:
		return
	hurt_lock = 0.28
	health = max(0.0, health - amount)
	if game:
		game.player_hurt()
	if health <= 0.0 and game:
		game.player_knocked_out()

func restore():
	health = 100.0
	stamina = 100.0
	velocity = Vector3.ZERO
