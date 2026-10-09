extends CharacterBody3D

const AssetVisual = preload("res://scripts/asset_visual.gd")
const FirstPersonAssets = preload("res://scripts/first_person_assets.gd")

var game: Node
var camera: Camera3D
var joystick: Control
var flashlight: SpotLight3D
var muzzle_light: OmniLight3D

var viewmodel_viewport: SubViewport
var viewmodel_layer: CanvasLayer
var viewmodel_camera: Camera3D
var reload_tween: Tween
var aim_touch := false
var fire_touch := false
var base_fov := 76.0
var recoil := 0.0
var sway := Vector2.ZERO

var viewmodel_root: Node3D
var weapon_holder: Node3D
var hands_holder: Node3D
var pistol_model: Node3D
var rifle_model: Node3D
var hands_model: Node3D

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
var aiming := false
var step_timer := 0.0
var pistol_mag := 12
var pistol_reserve := 48
var rifle_mag := 30
var rifle_reserve := 90

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
	camera.fov = base_fov
	camera.near = 0.06
	add_child(camera)

	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.10,-0.08,-0.04)
	flashlight.rotation_degrees.x = -1.0
	flashlight.spot_range = 30.0
	flashlight.spot_angle = 42.0
	flashlight.light_energy = 2.0
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

func _load_viewmodel(path: String, extent: float, orientation: Vector3) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var holder := Node3D.new()
	weapon_holder.add_child(holder)
	var pivot := Node3D.new()
	holder.add_child(pivot)
	pivot.rotation_degrees = orientation
	var content := packed.instantiate() as Node3D
	pivot.add_child(content)
	if path.ends_with("pistol.glb"):
		FirstPersonAssets.assemble_pistol(content)
	AssetVisual.fit_centered(holder, pivot, extent)
	AssetVisual.prepare_viewmodel(holder)
	return holder

func _build_viewmodel() -> void:
	# A transparent, independent world keeps walls and night fog from hiding hands.
	# Only three small models are rendered here; the environment is rendered once.
	viewmodel_layer = CanvasLayer.new()
	viewmodel_layer.layer = -1
	add_child(viewmodel_layer)
	viewmodel_viewport = SubViewport.new()
	viewmodel_viewport.own_world_3d = true
	viewmodel_viewport.transparent_bg = true
	viewmodel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewmodel_layer.add_child(viewmodel_viewport)
	var overlay := TextureRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.texture = viewmodel_viewport.get_texture()
	viewmodel_layer.add_child(overlay)
	get_viewport().size_changed.connect(_resize_viewmodel)
	_resize_viewmodel()

	viewmodel_camera = Camera3D.new()
	viewmodel_camera.fov = 70.0
	viewmodel_camera.near = 0.025
	viewmodel_camera.far = 4.0
	viewmodel_viewport.add_child(viewmodel_camera)
	viewmodel_camera.current = true
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.80, 0.92)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	viewmodel_viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_color = Color(0.94, 0.96, 1.0)
	key.light_energy = 1.2
	viewmodel_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(20, 145, 0)
	rim.light_color = Color(0.48, 0.68, 1.0)
	rim.light_energy = 0.55
	viewmodel_viewport.add_child(rim)

	viewmodel_root = Node3D.new()
	viewmodel_viewport.add_child(viewmodel_root)
	weapon_holder = Node3D.new()
	hands_holder = Node3D.new()
	viewmodel_root.add_child(weapon_holder)
	viewmodel_root.add_child(hands_holder)
	pistol_model = _load_viewmodel("res://assets/pistol.glb", 0.30, Vector3(0, 180, 0))
	# Measure the AR15 in its actual skeleton pose, not its vertical bind space.
	rifle_model = _load_viewmodel("res://assets/rifle.glb", 0.90, Vector3.ZERO)
	var packed := load("res://assets/fp_hands.glb") as PackedScene
	if packed:
		var source := packed.instantiate() as Node3D
		viewmodel_viewport.add_child(source)
		hands_model = FirstPersonAssets.make_hands(source)
		hands_holder.add_child(hands_model)
		source.free()
	_apply_weapon_pose()

func _resize_viewmodel() -> void:
	viewmodel_viewport.size = Vector2i(get_viewport().get_visible_rect().size)

func _process(delta: float) -> void:
	if viewmodel_root == null:
		return
	viewmodel_layer.visible = alive and camera.current and controls_enabled
	viewmodel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if viewmodel_layer.visible else SubViewport.UPDATE_DISABLED
	if reloading:
		return
	var blend := 1.0 - exp(-14.0 * delta)
	camera.fov = lerpf(camera.fov, base_fov * 0.78 if aiming else base_fov, blend)
	recoil = move_toward(recoil, 0.0, delta * 4.8)
	sway = sway.lerp(Vector2.ZERO, blend)
	var motion := 0.18 if aiming else 1.0
	var bob := Vector3(sin(bob_time) * 0.009, -absf(cos(bob_time)) * 0.01, 0) * last_move_strength * motion
	viewmodel_root.position = viewmodel_root.position.lerp(bob + Vector3(sway.x, sway.y, recoil * 0.055), blend)
	viewmodel_root.rotation_degrees = viewmodel_root.rotation_degrees.lerp(Vector3(-recoil * 5.0, 0, -bob.x * 75.0), blend)
	_apply_weapon_pose()

func _apply_weapon_pose() -> void:
	if current_weapon == "PISTOL":
		weapon_holder.position = Vector3(0, -0.08, -0.58) if aiming else Vector3(0.24, -0.20, -0.58)
		hands_holder.position = Vector3(0, -0.29, -0.49) if aiming else Vector3(0.10, -0.30, -0.49)
		if pistol_model: pistol_model.visible = true
		if rifle_model: rifle_model.visible = false
	else:
		weapon_holder.position = Vector3(0, -0.15, -0.49) if aiming else Vector3(0.23, -0.22, -0.70)
		hands_holder.position = Vector3(0, -0.27, -0.51) if aiming else Vector3(0.05, -0.29, -0.51)
		if pistol_model: pistol_model.visible = false
		if rifle_model: rifle_model.visible = true
	hands_holder.position = weapon_holder.position
	if hands_model:
		var right := hands_model.get_node("RightHand") as Node3D
		var left := hands_model.get_node("LeftHand") as Node3D
		right.position = Vector3(0.03, -0.10, 0.08) if current_weapon == "PISTOL" else Vector3(0.04, -0.12, 0.15)
		right.rotation_degrees = Vector3(20, 15, -15)
		left.position = Vector3(-0.03, -0.10, 0.01) if current_weapon == "PISTOL" else Vector3(-0.035, -0.11, -0.23)
		left.rotation_degrees = Vector3(15, -50, 20) if current_weapon == "PISTOL" else Vector3(15, -60, 20)
	weapon_holder.rotation_degrees = Vector3.ZERO
	hands_holder.rotation_degrees = Vector3.ZERO

func set_field_of_view(value: float) -> void:
	base_fov = clampf(value, 60.0, 95.0)

func set_touch_aiming(on: bool) -> void:
	aim_touch = on
	set_aiming(on)

func set_firing(on: bool) -> void:
	fire_touch = on

func set_controls_enabled(on: bool) -> void:
	controls_enabled = on
	if viewmodel_layer:
		viewmodel_layer.visible = on and alive
	if not on:
		look_touch = -1
		fire_touch = false
		aim_touch = false
		sprint_touch = false
		set_aiming(false)
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
		mv = mv.limit_length(1.0)

	var wants_run := controls_enabled and (sprint_touch or Input.is_key_pressed(KEY_SHIFT))
	var running := wants_run and stamina > 1.0 and mv.length() > 0.12 and not crouched
	var speed := 5.9 if running else (2.0 if crouched else 3.9)
	if running:
		stamina = max(0.0,stamina-delta*21.0)
	else:
		stamina = min(100.0,stamina+delta*14.0)

	var dir := global_transform.basis * Vector3(mv.x,0,mv.y)
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * speed, delta * 24.0)
	velocity.z = move_toward(velocity.z, dir.z * speed, delta * 24.0)
	velocity.y = -0.2 if is_on_floor() else velocity.y - 18.0*delta
	move_and_slide()
	camera.position.y = lerpf(camera.position.y,1.10 if crouched else 1.58,1.0 - exp(-9.0 * delta))

	last_move_strength = move_toward(last_move_strength,mv.length(),delta*4.0)
	if last_move_strength > 0.05 and is_on_floor():
		bob_time += delta*(11.5 if running else 8.0)
	else:
		bob_time += delta*2.0

	if controls_enabled and mv.length() > 0.15 and is_on_floor():
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.32 if running else 0.48
			if game:
				game.play_footstep(running)
	else:
		step_timer = 0.0

	if flashlight.visible:
		battery = max(0.0,battery-delta*0.72)
		if battery <= 0.0:
			flashlight.visible = false

	if controls_enabled:
		if fire_touch or Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			fire_weapon()
		set_aiming(aim_touch or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))

	if game:
		game.update_hud(health,stamina,battery,current_weapon,ammo_in_mag,reserve_ammo)

func _unhandled_input(event: InputEvent) -> void:
	if not alive or not controls_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q: switch_weapon()
			KEY_R: reload_weapon()
			KEY_F: toggle_flashlight()
			KEY_C: toggle_crouch()
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

func set_aiming(on: bool) -> void:
	if not controls_enabled or reloading:
		on = false
	if aiming == on:
		return
	aiming = on
	if game:
		game.set_crosshair_aiming(aiming)

func switch_weapon() -> void:
	if not rifle_unlocked or reloading or weapon_cooldown > 0.0:
		return
	if current_weapon == "PISTOL":
		pistol_mag = ammo_in_mag
		pistol_reserve = reserve_ammo
		current_weapon = "RIFLE"
		ammo_in_mag = rifle_mag
		reserve_ammo = rifle_reserve
	else:
		rifle_mag = ammo_in_mag
		rifle_reserve = reserve_ammo
		current_weapon = "PISTOL"
		ammo_in_mag = pistol_mag
		reserve_ammo = pistol_reserve
	set_aiming(false)
	_apply_weapon_pose()
	if game:
		game.weapon_event("SWITCHED TO "+current_weapon)

func _look(v: Vector2) -> void:
	var sens := 1.0
	if game:
		sens = game.get_look_sensitivity()
	sway += Vector2(-v.x, v.y) * 0.12
	sway = sway.limit_length(0.025)
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
	if aiming:
		damage *= 1.08
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
	if current_weapon == "PISTOL":
		pistol_mag = ammo_in_mag
		pistol_reserve = reserve_ammo
	else:
		rifle_mag = ammo_in_mag
		rifle_reserve = reserve_ammo
	if game:
		game.on_player_shot(current_weapon)

func _play_fire_animation() -> void:
	muzzle_light.light_energy = 5.4
	create_tween().tween_property(muzzle_light,"light_energy",0.0,0.055)
	recoil = minf(recoil + (1.0 if current_weapon == "PISTOL" else 0.55), 1.6)
	pitch = clampf(pitch-(0.016 if current_weapon=="PISTOL" else 0.008),-1.25,1.25)
	camera.rotation.x = pitch

func reload_weapon() -> void:
	if not controls_enabled or reloading or reload_cooldown > 0.0 or weapon_cooldown > 0.0:
		return
	var mag_size := 12 if current_weapon == "PISTOL" else 30
	set_aiming(false)
	if ammo_in_mag >= mag_size or reserve_ammo <= 0:
		return
	reloading = true
	reload_cooldown = 1.35 if current_weapon == "PISTOL" else 1.75
	if game: game.weapon_event("RELOADING")
	_play_reload_animation(mag_size)

func _play_reload_animation(mag_size: int) -> void:
	var base_weapon_pos := weapon_holder.position
	var base_weapon_rot := weapon_holder.rotation_degrees
	var base_hands_pos := hands_holder.position
	var base_hands_rot := hands_holder.rotation_degrees

	if reload_tween and reload_tween.is_running():
		reload_tween.kill()
	reload_tween = create_tween()
	var tw := reload_tween
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(weapon_holder,"rotation_degrees",base_weapon_rot+Vector3(22,-10,28),0.20)
	tw.parallel().tween_property(weapon_holder,"position",base_weapon_pos+Vector3(-0.08,-0.12,0.15),0.20)
	tw.parallel().tween_property(hands_holder,"position",base_hands_pos+Vector3(0.10,-0.04,0.10),0.20)
	tw.parallel().tween_property(hands_holder,"rotation_degrees",base_hands_rot+Vector3(12,-8,16),0.20)
	tw.tween_interval(0.10)
	tw.tween_property(hands_holder,"position",base_hands_pos+Vector3(-0.18,-0.20,-0.10),0.22)
	tw.parallel().tween_property(hands_holder,"rotation_degrees",base_hands_rot+Vector3(-24,18,-22),0.22)
	tw.tween_interval(0.08)
	tw.tween_property(hands_holder,"position",base_hands_pos+Vector3(0.05,0.03,-0.18),0.24)
	tw.parallel().tween_property(hands_holder,"rotation_degrees",base_hands_rot+Vector3(8,-5,8),0.24)
	tw.tween_callback(func():
		var needed := mag_size-ammo_in_mag
		var loaded := mini(needed,reserve_ammo)
		ammo_in_mag += loaded
		reserve_ammo -= loaded
	)
	tw.tween_property(weapon_holder,"rotation_degrees",base_weapon_rot,0.24)
	tw.parallel().tween_property(weapon_holder,"position",base_weapon_pos,0.24)
	tw.parallel().tween_property(hands_holder,"position",base_hands_pos,0.24)
	tw.parallel().tween_property(hands_holder,"rotation_degrees",base_hands_rot,0.24)
	tw.tween_callback(func():
		reloading = false
		aiming = false
		if current_weapon == "PISTOL":
			pistol_mag = ammo_in_mag
			pistol_reserve = reserve_ammo
		else:
			rifle_mag = ammo_in_mag
			rifle_reserve = reserve_ammo
		_apply_weapon_pose()
	)

func unlock_rifle() -> void:
	pistol_mag = ammo_in_mag
	pistol_reserve = reserve_ammo
	rifle_unlocked = true
	current_weapon = "RIFLE"
	rifle_mag = 30
	rifle_reserve = max(rifle_reserve,90)
	ammo_in_mag = rifle_mag
	reserve_ammo = rifle_reserve
	reloading = false
	if reload_tween and reload_tween.is_running():
		reload_tween.kill()
	set_aiming(false)
	_apply_weapon_pose()
	if game: game.weapon_event("RIFLE ACQUIRED // Q OR SWAP TO SWITCH")

func add_ammo(amount: int) -> void:
	reserve_ammo = mini(reserve_ammo+amount,240)
	if current_weapon == "PISTOL":
		pistol_reserve = reserve_ammo
	else:
		rifle_reserve = reserve_ammo
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
	if reload_tween and reload_tween.is_running():
		reload_tween.kill()
	recoil = 0.0
	sway = Vector2.ZERO
	weapon_cooldown = 0.0
	reload_cooldown = 0.0
	aim_touch = false
	fire_touch = false
	sprint_touch = false
	look_touch = -1
	crouched = false
	aiming = false
	if game: game.set_crosshair_aiming(false)
	if weapon_holder: _apply_weapon_pose()
	if camera:
		camera.fov = base_fov
	if viewmodel_root:
		viewmodel_root.position = Vector3.ZERO
