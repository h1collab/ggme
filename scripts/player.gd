extends CharacterBody3D

var game: Node
var camera: Camera3D
var flashlight: SpotLight3D
var ray: RayCast3D
var stamina := 100.0
var battery := 100.0
var yaw := 0.0
var pitch := 0.0
var move_touch := -1
var look_touch := -1
var move_origin := Vector2.ZERO
var move_vector := Vector2.ZERO
var right_tap_start := Vector2.ZERO
var right_tap_time := 0.0
var bob_t := 0.0
var base_cam_y := 1.58
var caught_lock := false

func _ready():
	camera = Camera3D.new()
	camera.position = Vector3(0, base_cam_y, 0)
	camera.fov = 74.0
	add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.08, -0.06, -0.18)
	flashlight.light_energy = 5.2
	flashlight.spot_range = 22.0
	flashlight.spot_angle = 28.0
	flashlight.shadow_enabled = true
	flashlight.light_color = Color(0.82, 0.9, 1.0)
	camera.add_child(flashlight)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -3.2)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	camera.add_child(ray)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	if caught_lock:
		velocity = Vector3.ZERO
		return
	var kb := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var mv := kb if kb.length() > 0.05 else move_vector
	var sprinting := Input.is_action_pressed("sprint") and mv.length() > 0.2 and stamina > 2.0
	var speed := 6.0 if sprinting else 3.6
	if sprinting:
		stamina = max(0.0, stamina - delta * 18.0)
	else:
		stamina = min(100.0, stamina + delta * 11.0)
	var local_dir := Vector3(mv.x, 0, mv.y)
	var dir := global_transform.basis * local_dir
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.2
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3 and is_on_floor()
	if moving:
		bob_t += delta * (12.0 if sprinting else 8.0)
		camera.position.y = base_cam_y + sin(bob_t) * (0.045 if sprinting else 0.025)
		camera.rotation.z = sin(bob_t * 0.5) * 0.006
	else:
		camera.position.y = lerpf(camera.position.y, base_cam_y, delta * 8.0)
		camera.rotation.z = lerpf(camera.rotation.z, 0.0, delta * 8.0)
	if flashlight.visible:
		battery = max(0.0, battery - delta * 0.9)
		if battery <= 0.0:
			flashlight.visible = false
		elif battery < 18.0:
			flashlight.light_energy = 3.0 + randf() * 2.4
		else:
			flashlight.light_energy = 5.2
	_update_interaction()
	if game:
		game.update_player_stats(stamina, battery, flashlight.visible)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * 0.0022)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventScreenTouch:
		var w := get_viewport().get_visible_rect().size.x
		if event.pressed:
			if event.position.x < w * 0.48 and move_touch == -1:
				move_touch = event.index
				move_origin = event.position
				move_vector = Vector2.ZERO
			elif look_touch == -1:
				look_touch = event.index
				right_tap_start = event.position
				right_tap_time = Time.get_ticks_msec() / 1000.0
		else:
			if event.index == move_touch:
				move_touch = -1
				move_vector = Vector2.ZERO
			elif event.index == look_touch:
				var elapsed := Time.get_ticks_msec() / 1000.0 - right_tap_time
				if elapsed < 0.25 and event.position.distance_to(right_tap_start) < 22.0:
					interact()
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			var d: Vector2 = (event.position - move_origin) / 90.0
			move_vector = Vector2(clampf(d.x, -1, 1), clampf(d.y, -1, 1))
		elif event.index == look_touch:
			_look(event.relative * 0.0042)

func _look(v: Vector2):
	yaw -= v.x
	pitch = clampf(pitch - v.y, -1.38, 1.38)
	rotation.y = yaw
	camera.rotation.x = pitch

func _update_interaction():
	ray.force_raycast_update()
	var prompt := ""
	if ray.is_colliding():
		var c = ray.get_collider()
		if c and c.has_meta("interact_kind"):
			prompt = game.describe_interaction(c) if game else "Interact"
	if game:
		game.set_prompt(prompt)

func interact():
	ray.force_raycast_update()
	if ray.is_colliding():
		var c = ray.get_collider()
		if c and c.has_meta("interact_kind") and game:
			game.interact(c)

func toggle_flashlight():
	if battery > 0.2:
		flashlight.visible = not flashlight.visible

func add_battery(v: float):
	battery = min(100.0, battery + v)

func freeze_for_catch():
	caught_lock = true
	flashlight.visible = false

func reset_after_catch(pos: Vector3):
	global_position = pos
	velocity = Vector3.ZERO
	caught_lock = false
	battery = max(battery, 35.0)
	flashlight.visible = true
