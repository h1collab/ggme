extends CharacterBody3D

var game: Node
var camera: Camera3D
var torch: SpotLight3D
var yaw := 0.0
var pitch := 0.0
var aim_pointer := -1
var stamina := 100.0
var sprinting := false
var step_clock := 0.0
var motion_clock := 0.0
var focus_seconds := 0.0
var focus_target := Vector3.ZERO
var attention_hold := 0.0
var focus_allowed := false

func _ready() -> void:
	name = "LocalCrew"
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.72
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.near = 0.06
	camera.fov = 76
	camera.current = true
	add_child(camera)
	torch = SpotLight3D.new()
	torch.position = Vector3(0.1, -0.1, -0.08)
	torch.light_color = Color(0.93, 0.96, 1.0)
	torch.light_energy = 1.5
	torch.spot_range = 14
	torch.spot_angle = 36
	torch.shadow_enabled = true
	camera.add_child(torch)

func _unhandled_input(event: InputEvent) -> void:
	if not game.running or game.ui.modal: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E: game.interact()
			KEY_F: torch.visible = not torch.visible
			KEY_ESCAPE: game.ui.open_pause()
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.38 and aim_pointer == -1:
			aim_pointer = event.index
		elif not event.pressed and event.index == aim_pointer: aim_pointer = -1
	elif event is InputEventScreenDrag and event.index == aim_pointer:
		look(event.relative * 1.15)

func look(delta: Vector2) -> void:
	if delta.length() > 1: cancel_focus()
	yaw -= delta.x * 0.0021 * game.sensitivity
	pitch = clampf(pitch - delta.y * 0.0021 * game.sensitivity, -1.25, 1.25)
	rotation.y = yaw
	camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if not game.running or game.ui.modal:
		velocity = Vector3.ZERO
		aim_pointer = -1
		return
	if focus_seconds > 0:
		focus_seconds = maxf(0, focus_seconds - delta)
		var direction := focus_target - camera.global_position
		yaw = lerp_angle(yaw, atan2(-direction.x, -direction.z), minf(1, delta * 7))
		pitch = lerpf(pitch, clampf(atan2(direction.y, Vector2(direction.x, direction.z).length()), -1.0, 1.0), minf(1, delta * 7))
		rotation.y = yaw
		camera.rotation.x = pitch
	attention_hold = maxf(0, attention_hold - delta)
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.y -= 1
	if Input.is_physical_key_pressed(KEY_S): input.y += 1
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input.x += 1
	if is_instance_valid(game.ui.joystick): input += game.ui.joystick.value
	input = input.limit_length(1.0)
	if attention_hold > 0: input = Vector2.ZERO
	sprinting = (Input.is_physical_key_pressed(KEY_SHIFT) or game.ui.run_held) and stamina > 5 and input.length() > 0.1
	stamina = clampf(stamina + (-18.0 if sprinting else 12.0) * delta, 0, 100)
	var direction := transform.basis * Vector3(input.x, 0, input.y)
	var speed := 4.3 if sprinting else 2.6
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 14)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 14)
	if not is_on_floor(): velocity.y -= 18.0 * delta
	else: velocity.y = -0.1
	move_and_slide()
	if position.y < -2:
		position = game.level.spawn
		velocity = Vector3.ZERO
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	motion_clock += delta * (10 if sprinting else 7) if moving else delta
	var bob := sin(motion_clock) * (0.022 if moving else 0.001)
	camera.position.y = lerpf(camera.position.y, 1.58 + bob, delta * 10)
	step_clock -= delta
	if moving and is_on_floor() and step_clock <= 0:
		step_clock = 0.34 if sprinting else 0.52
		game.footstep()

func reset_to(pos: Vector3) -> void:
	cancel_focus()
	position = pos
	velocity = Vector3.ZERO
	yaw = 0
	pitch = 0
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	stamina = 100

func begin_focus(target: Vector3) -> void:
	focus_target = target
	focus_seconds = 1.2

func cancel_focus() -> void:
	focus_seconds = 0
	attention_hold = 0
	focus_allowed = false

func begin_attention() -> void:
	focus_allowed = true
	# Always bounded, and cancelled immediately when a menu opens or the
	# player moves the camera. Never lock movement when focus is disabled.
	attention_hold = 3.7
