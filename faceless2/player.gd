extends CharacterBody3D

var game: Node
var camera: Camera3D
var joystick: Control
var flashlight: SpotLight3D
var muzzle_light: OmniLight3D

var viewmodel_root: Node3D
var weapon_holder: Node3D
var right_hand_holder: Node3D
var left_hand_holder: Node3D
var pistol_model: Node3D
var rifle_model: Node3D
var pistol_mag: Node3D
var rifle_mag: Node3D
var right_hand: Node3D
var left_hand: Node3D

var health := 100.0
var stamina := 100.0
var battery := 100.0
var yaw := 0.0
var pitch := 0.0
var look_touch := -1
var sprint_touch := false
var crouched := false
var alive := true
var controls_enabled := true
var bob_time := 0.0
var last_move_strength := 0.0

var current_weapon := "PISTOL"
var rifle_unlocked := false
var ammo_in_mag := 12
var reserve_ammo := 48
var weapon_cooldown := 0.0
var reload_cooldown := 0.0
var reloading := false

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

	_build_viewmodel()

	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_viewmodel() -> void:
	viewmodel_root = Node3D.new()
	viewmodel_root.position = Vector3.ZERO
	camera.add_child(viewmodel_root)

	weapon_holder = Node3D.new()
	right_hand_holder = Node3D.new()
	left_hand_holder = Node3D.new()
	viewmodel_root.add_child(weapon_holder)
	viewmodel_root.add_child(right_hand_holder)
	viewmodel_root.add_child(left_hand_holder)

	var right_scene: PackedScene = load("res://assets/fp_right_hand.glb")
	if right_scene:
		right_hand = right_scene.instantiate() as Node3D
		right_hand_holder.add_child(right_hand)
	var left_scene: PackedScene = load("res://assets/fp_left_hand.glb")
	if left_scene:
		left_hand = left_scene.instantiate() as Node3D
		left_hand_holder.add_child(left_hand)

	var pistol_scene: PackedScene = load("res://assets/pistol.glb")
	if pistol_scene:
		pistol_model = pistol_scene.instantiate() as Node3D
		weapon_holder.add_child(pistol_model)
	var pistol_mag_scene: PackedScene = load("res://assets/pistol_mag.glb")
	if pistol_mag_scene:
		pistol_mag = pistol_mag_scene.instantiate() as Node3D
		weapon_holder.add_child(pistol_mag)

	var rifle_scene: PackedScene = load("res://assets/rifle.glb")
	if rifle_scene:
		rifle_model = rifle_scene.instantiate() as Node3D
		weapon_holder.add_child(rifle_model)
	var rifle_mag_scene: PackedScene = load("res://assets/rifle_mag.glb")
	if rifle_mag_scene:
		rifle_mag = rifle_mag_scene.instantiate() as Node3D
		weapon_holder.add_child(rifle_mag)

	_apply_weapon_pose()

func _apply_weapon_pose() -> void:
	if current_weapon == "PISTOL":
		weapon_holder.position = Vector3(0.31,-0.30,-0.64)
		weapon_holder.rotation_degrees = Vector3(-7,177,0)
		weapon_holder.scale = Vector3(0.72,0.72,0.72)
		right_hand_holder.position = Vector3(0.27,-0.34,-0.38)
		right_hand_holder.rotation_degrees = Vector3(-18,168,-5)
		right_hand_holder.scale = Vector3(0.76,0.76,0.76)
		left_hand_holder.position = Vector3(-0.23,-0.48,-0.24)
		left_hand_holder.rotation_degrees = Vector3(-35,195,18)
		left_hand_holder.scale = Vector3(0.74,0.74,0.74)
		if pistol_model: pistol_model.visible = true
		if pistol_mag:
			pistol_mag.visible = true
			pistol_mag.position = Vector3(0,-0.17,0.16)
		if rifle_model: rifle_model.visible = false
		if rifle_mag: rifle_mag.visible = false
	else:
		weapon_holder.position = Vector3(0.30,-0.32,-0.88)
		weapon_holder.rotation_degrees = Vector3(-8,177,0)
		weapon_holder.scale = Vector3(0.68,0.68,0.68)
		right_hand_holder.position = Vector3(0.30,-0.36,-0.38)
		right_hand_holder.rotation_degrees = Vector3(-17,168,-6)
		right_hand_holder.scale = Vector3(0.77,0.77,0.77)
		left_hand_holder.position = Vector3(-0.17,-0.31,-0.82)
		left_hand_holder.rotation_degrees = Vector3(-12,166,14)
		left_hand_holder.scale = Vector3(0.76,0.76,0.76)
		if pistol_model: pistol_model.visible = false
		if pistol_mag: pistol_mag.visible = false
		if rifle_model: rifle_model.visible = true
		if rifle_mag:
			rifle_mag.visible = true
			rifle_mag.position = Vector3(0,-0.19,-0.03)

func set_controls_enabled(on: bool) -> void:
	controls_enabled = on
	if not on:
		velocity.x = 0.0
		velocity.z = 0.0

func _physics_process(delta: float) -> void:
	if not alive:
		return
	weapon_cooldown = max(0.0,weapon_cooldown-delta)
	reload_cooldown = max(0.0,reload_cooldown-delta)

	var mv := Vector2.ZERO
	if controls_enabled:
		if Input.is_key_pressed(KEY_A): mv.x -= 1.0
		if Input.is_key_pressed(KEY_D): mv.x += 1.0
		if Input.is_key_pressed(KEY_W): mv.y -= 1.0
		if Input.is_key_pressed(KEY_S): mv.y += 1.0
		if joystick and joystick.value.length() > 0.04:
			mv = joystick.value

	var wants_run := controls_enabled and (sprint_touch or Input.is_key_pressed(KEY_SHIFT))
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

	last_move_strength = move_toward(last_move_strength,mv.length(),delta*4.0)
	if last_move_strength > 0.05 and is_on_floor():
		bob_time += delta*(11.5 if running else 8.0)
	else:
		bob_time += delta*2.0
	_update_viewmodel_motion(running)

	if flashlight.visible:
		battery = max(0.0,battery-delta*0.72)
		if battery <= 0.0:
			flashlight.visible = false

	if controls_enabled:
		if Input.is_key_pressed(KEY_SPACE):
			fire_weapon()
		if Input.is_key_pressed(KEY_R):
			reload_weapon()

	if game:
		game.update_hud(health,stamina,battery,current_weapon,ammo_in_mag,reserve_ammo)

func _update_viewmodel_motion(running: bool) -> void:
	if viewmodel_root == null or reloading:
		return
	var amount: float = 1.0 if running else 0.55
	var bob_x: float = sin(bob_time)*0.012*last_move_strength*amount
	var bob_y: float = absf(cos(bob_time))*0.014*last_move_strength*amount
	viewmodel_root.position = viewmodel_root.position.lerp(Vector3(bob_x,-bob_y,0),0.18)
	viewmodel_root.rotation_degrees = viewmodel_root.rotation_degrees.lerp(Vector3(bob_y*65.0,bob_x*45.0,-bob_x*80.0),0.18)

func _unhandled_input(event: InputEvent) -> void:
	if not alive or not controls_enabled:
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
	if not controls_enabled or not alive or weapon_cooldown > 0.0 or reload_cooldown > 0.0 or reloading:
		return
	if ammo_in_mag <= 0:
		if game: game.weapon_event("EMPTY")
		weapon_cooldown = 0.25
		return

	ammo_in_mag -= 1
	var damage := 34.0
	var fire_delay := 0.30
	if current_weapon == "RIFLE":
		damage = 23.0
		fire_delay = 0.105
	weapon_cooldown = fire_delay
	_play_fire_animation()

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
			if game: game.weapon_event("HIT")
	if game:
		game.on_player_shot(current_weapon)

func _play_fire_animation() -> void:
	muzzle_light.light_energy = 5.4
	create_tween().tween_property(muzzle_light,"light_energy",0.0,0.055)
	var kick := 0.085 if current_weapon == "PISTOL" else 0.045
	var lift := 7.0 if current_weapon == "PISTOL" else 3.5
	var base_pos := weapon_holder.position
	var base_rot := weapon_holder.rotation_degrees
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(weapon_holder,"position",base_pos+Vector3(0,0,kick),0.045)
	tw.parallel().tween_property(weapon_holder,"rotation_degrees",base_rot+Vector3(-lift,0,1.5),0.045)
	tw.tween_property(weapon_holder,"position",base_pos,0.11)
	tw.parallel().tween_property(weapon_holder,"rotation_degrees",base_rot,0.11)
	if right_hand_holder:
		var hand_base := right_hand_holder.rotation_degrees
		var ht := create_tween()
		ht.tween_property(right_hand_holder,"rotation_degrees",hand_base+Vector3(-4,0,2),0.045)
		ht.tween_property(right_hand_holder,"rotation_degrees",hand_base,0.11)
	pitch = clampf(pitch-(0.016 if current_weapon=="PISTOL" else 0.008),-1.25,1.25)
	camera.rotation.x = pitch

func reload_weapon() -> void:
	if not controls_enabled or reloading or reload_cooldown > 0.0 or weapon_cooldown > 0.0:
		return
	var mag_size := 12 if current_weapon == "PISTOL" else 30
	if ammo_in_mag >= mag_size or reserve_ammo <= 0:
		return
	reloading = true
	reload_cooldown = 1.35 if current_weapon == "PISTOL" else 1.75
	if game: game.weapon_event("RELOADING")
	_play_reload_animation(mag_size)

func _play_reload_animation(mag_size: int) -> void:
	var base_weapon_pos := weapon_holder.position
	var base_weapon_rot := weapon_holder.rotation_degrees
	var base_left_pos := left_hand_holder.position
	var base_left_rot := left_hand_holder.rotation_degrees
	var mag: Node3D = pistol_mag if current_weapon == "PISTOL" else rifle_mag
	var mag_base := mag.position if mag else Vector3.ZERO

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(weapon_holder,"rotation_degrees",base_weapon_rot+Vector3(18,0,22),0.18)
	tw.parallel().tween_property(weapon_holder,"position",base_weapon_pos+Vector3(-0.04,-0.05,0.10),0.18)
	tw.parallel().tween_property(left_hand_holder,"position",base_left_pos+Vector3(0.20,0.10,-0.16),0.18)
	tw.tween_interval(0.06)
	if mag:
		tw.tween_property(mag,"position",mag_base+Vector3(0,-0.58,0.12),0.22)
	tw.parallel().tween_property(left_hand_holder,"position",base_left_pos+Vector3(0.08,-0.18,0.08),0.22)
	tw.tween_interval(0.08)
	if mag:
		tw.tween_property(mag,"position",mag_base,0.26)
	tw.parallel().tween_property(left_hand_holder,"position",base_left_pos+Vector3(0.18,0.02,-0.16),0.26)
	tw.tween_callback(func():
		var needed := mag_size-ammo_in_mag
		var loaded := mini(needed,reserve_ammo)
		ammo_in_mag += loaded
		reserve_ammo -= loaded
	)
	tw.tween_property(weapon_holder,"rotation_degrees",base_weapon_rot,0.22)
	tw.parallel().tween_property(weapon_holder,"position",base_weapon_pos,0.22)
	tw.parallel().tween_property(left_hand_holder,"position",base_left_pos,0.22)
	tw.parallel().tween_property(left_hand_holder,"rotation_degrees",base_left_rot,0.22)
	tw.tween_callback(func():
		reloading = false
		_apply_weapon_pose()
	)

func unlock_rifle() -> void:
	rifle_unlocked = true
	current_weapon = "RIFLE"
	ammo_in_mag = 30
	reserve_ammo += 90
	reloading = false
	_apply_weapon_pose()
	if game: game.weapon_event("RIFLE ACQUIRED")

func add_ammo(amount: int) -> void:
	reserve_ammo = mini(reserve_ammo+amount,240)
	if game: game.weapon_event("AMMO +%d" % amount)

func add_health(amount: float) -> void:
	health = min(100.0,health+amount)
	if game: game.weapon_event("MEDKIT +%d" % int(amount))

func toggle_flashlight() -> void:
	if battery > 0.0:
		flashlight.visible = not flashlight.visible

func set_running(on: bool) -> void:
	sprint_touch = on

func toggle_crouch() -> void:
	if controls_enabled:
		crouched = not crouched

func take_damage(amount: float) -> void:
	if not alive:
		return
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
	reloading = false
