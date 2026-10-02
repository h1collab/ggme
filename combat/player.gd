extends CharacterBody3D

var game: Node
var camera: Camera3D
var joystick: Control
var health: float = 100.0
var stamina: float = 100.0
var yaw: float = 0.0
var pitch: float = 0.0
var look_touch: int = -1
var attack_cooldown: float = 0.0
var hurt_lock: float = 0.0

func _ready() -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.72
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.58, 0)
	camera.fov = 76.0
	add_child(camera)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	attack_cooldown = max(0.0, attack_cooldown - delta)
	hurt_lock = max(0.0, hurt_lock - delta)
	var move_input: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_input.x += 1.0
	if Input.is_key_pressed(KEY_W):
		move_input.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_input.y += 1.0
	if joystick != null and joystick.value.length() > 0.04:
		move_input = joystick.value
	var sprinting: bool = Input.is_key_pressed(KEY_SHIFT) and stamina > 1.0 and move_input.length() > 0.15
	var speed: float = 6.0 if sprinting else 4.1
	if sprinting:
		stamina = max(0.0, stamina - delta * 20.0)
	else:
		stamina = min(100.0, stamina + delta * 14.0)
	var local_dir: Vector3 = Vector3(move_input.x, 0, move_input.y)
	var world_dir: Vector3 = global_transform.basis * local_dir
	world_dir.y = 0.0
	if world_dir.length() > 0.01:
		world_dir = world_dir.normalized()
	velocity.x = world_dir.x * speed
	velocity.z = world_dir.z * speed
	velocity.y = -0.2 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	if game != null:
		game.update_player_hud(health, stamina)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		_look(mm.relative * 0.0024)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		var screen_w: float = get_viewport().get_visible_rect().size.x
		if st.position.x > screen_w * 0.45:
			if st.pressed and look_touch == -1:
				look_touch = st.index
			elif not st.pressed and st.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		if sd.index == look_touch:
			_look(sd.relative * 0.0040)

func _look(v: Vector2) -> void:
	yaw -= v.x
	pitch = clampf(pitch - v.y, -1.25, 1.25)
	rotation.y = yaw
	camera.rotation.x = pitch

func attack(power: float = 1.0) -> void:
	if attack_cooldown > 0.0 or stamina < 5.0:
		return
	attack_cooldown = 0.34 if power <= 1.0 else 0.72
	stamina = max(0.0, stamina - (8.0 if power <= 1.0 else 18.0))
	if game != null:
		game.player_melee_attack(power)

func take_damage(amount: float) -> void:
	if hurt_lock > 0.0:
		return
	hurt_lock = 0.28
	health = max(0.0, health - amount)
	if game != null:
		game.player_hurt()
	if health <= 0.0 and game != null:
		game.player_knocked_out()

func restore() -> void:
	health = 100.0
	stamina = 100.0
	velocity = Vector3.ZERO
