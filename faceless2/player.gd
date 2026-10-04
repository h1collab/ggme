extends CharacterBody3D

var game: Node
var camera: Camera3D
var joystick: Control
var flashlight: SpotLight3D
var muzzle_light: OmniLight3D
var pistol_model: Node3D
var rifle_model: Node3D

var health := 100.0
var stamina := 100.0
var battery := 100.0
var yaw := 0.0
var pitch := 0.0
var look_touch := -1
var sprint_touch := false
var crouched := false
var alive := true

var current_weapon := "PISTOL"
var rifle_unlocked := false
var ammo_in_mag := 12
var reserve_ammo := 48
var weapon_cooldown := 0.0
var reload_cooldown := 0.0

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
	camera.fov = 76.0
	add_child(camera)

	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.10,-0.08,-0.04)
	flashlight.rotation_degrees.x = -1.0
	flashlight.spot_range = 30.0
	flashlight.spot_angle = 42.0
	flashlight.light_energy = 6.2
	flashlight.light_color = Color(0.91,0.96,1.0)
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)

	muzzle_light = OmniLight3D.new()
	muzzle_light.position = Vector3(0.18,-0.18,-0.7)
	muzzle_light.omni_range = 4.5
	muzzle_light.light_color = Color(1.0,0.60,0.24)
	muzzle_light.light_energy = 0.0
	camera.add_child(muzzle_light)

	_build_weapon_models()

	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_weapon_models() -> void:
	var pistol_scene: PackedScene = load("res://assets/pistol.glb")
	if pistol_scene:
		pistol_model = pistol_scene.instantiate() as Node3D
		pistol_model.position = Vector3(0.34,-0.31,-0.62)
		pistol_model.rotation_degrees = Vector3(-7,177,0)
		pistol_model.scale = Vector3(0.72,0.72,0.72)
		camera.add_child(pistol_model)
	var rifle_scene: PackedScene = load("res://assets/rifle.glb")
	if rifle_scene:
		rifle_model = rifle_scene.instantiate() as Node3D
		rifle_model.position = Vector3(0.34,-0.34,-0.78)
		rifle_model.rotation_degrees = Vector3(-8,177,0)
		rifle_model.scale = Vector3(0.76,0.76,0.76)
		rifle_model.visible = false
		camera.add_child(rifle_model)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	weapon_cooldown = max(0.0,weapon_cooldown-delta)
	reload_cooldown = max(0.0,reload_cooldown-delta)

	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): mv.x -= 1.0
	if Input.is_key_pressed(KEY_D): mv.x += 1.0
	if Input.is_key_pressed(KEY_W): mv.y -= 1.0
	if Input.is_key_pressed(KEY_S): mv.y += 1.0
	if joystick and joystick.value.length() > 0.04:
		mv = joystick.value

	var wants_run := sprint_touch or Input.is_key_pressed(KEY_SHIFT)
	var running := wants_run and stamina > 1.0 and mv.length() > 0.12 and not crouched
	var speed := 5.9 if running else (2.0 if crouched else 3.9)
	if running:
		stamina = max(0.0,stamina-delta*21.0)
	else:
		stamina = min(100.0,stamina+delta*14.0)

	var dir := global_transform.basis * Vector3(mv.x,0,mv.y)
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
	velocity.x = dir.x*speed
	velocity.z = dir.z*speed
	velocity.y = -0.2 if is_on_floor() else velocity.y - 18.0*delta
	move_and_slide()
	camera.position.y = lerpf(camera.position.y,1.10 if crouched else 1.58,delta*9.0)

	if flashlight.visible:
		battery = max(0.0,battery-delta*0.72)
		if battery <= 0.0:
			flashlight.visible = false

	if Input.is_key_pressed(KEY_SPACE):
		fire_weapon()
	if Input.is_key_pressed(KEY_R):
		reload_weapon()

	if game:
		game.update_hud(health,stamina,battery,current_weapon,ammo_in_mag,reserve_ammo)

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
	if game:
		sens = game.get_look_sensitivity()
	yaw -= v.x*sens
	pitch = clampf(pitch-v.y*sens,-1.25,1.25)
	rotation.y = yaw
	camera.rotation.x = pitch

func fire_weapon() -> void:
	if not alive or weapon_cooldown > 0.0 or reload_cooldown > 0.0:
		return
	if ammo_in_mag <= 0:
		if game:
			game.weapon_event("EMPTY")
		weapon_cooldown = 0.25
		return

	ammo_in_mag -= 1
	var damage := 34.0
	var fire_delay := 0.30
	if current_weapon == "RIFLE":
		damage = 23.0
		fire_delay = 0.105
	weapon_cooldown = fire_delay

	muzzle_light.light_energy = 4.8
	create_tween().tween_property(muzzle_light,"light_energy",0.0,0.055)
	pitch = clampf(pitch - (0.016 if current_weapon == "PISTOL" else 0.008),-1.25,1.25)
	camera.rotation.x = pitch

	var from := camera.global_position
	var direction := -camera.global_transform.basis.z
	var to := from + direction*90.0
	var query := PhysicsRayQueryParameters3D.create(from,to)
	query.exclude = [self]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var collider = result.get("collider")
		if collider != null and collider.has_method("take_bullet"):
			collider.take_bullet(damage,result.get("position",to))
			if game:
				game.weapon_event("HIT")
		else:
			pass
	if game:
		game.on_player_shot(current_weapon)

func reload_weapon() -> void:
	if reload_cooldown > 0.0 or weapon_cooldown > 0.0:
		return
	var mag_size := 12 if current_weapon == "PISTOL" else 30
	if ammo_in_mag >= mag_size or reserve_ammo <= 0:
		return
	var needed := mag_size-ammo_in_mag
	var loaded := mini(needed,reserve_ammo)
	ammo_in_mag += loaded
	reserve_ammo -= loaded
	reload_cooldown = 1.05 if current_weapon == "PISTOL" else 1.35
	if game:
		game.weapon_event("RELOADING")

func unlock_rifle() -> void:
	rifle_unlocked = true
	current_weapon = "RIFLE"
	ammo_in_mag = 30
	reserve_ammo += 90
	if pistol_model:
		pistol_model.visible = false
	if rifle_model:
		rifle_model.visible = true
	if game:
		game.weapon_event("RIFLE ACQUIRED")

func add_ammo(amount: int) -> void:
	reserve_ammo = mini(reserve_ammo+amount,240)
	if game:
		game.weapon_event("AMMO +%d" % amount)

func add_health(amount: float) -> void:
	health = min(100.0,health+amount)
	if game:
		game.weapon_event("MEDKIT +%d" % int(amount))

func toggle_flashlight() -> void:
	if battery > 0.0:
		flashlight.visible = not flashlight.visible

func set_running(on: bool) -> void:
	sprint_touch = on

func toggle_crouch() -> void:
	crouched = not crouched

func take_damage(amount: float) -> void:
	if not alive:
		return
	health = max(0.0,health-amount)
	if game:
		game.player_hurt()
	if health <= 0.0:
		alive = false
		if game:
			game.player_dead()

func add_battery(amount: float) -> void:
	battery = min(100.0,battery+amount)

func restore_full() -> void:
	health = 100.0
	stamina = 100.0
	battery = 100.0
	alive = true
	velocity = Vector3.ZERO
