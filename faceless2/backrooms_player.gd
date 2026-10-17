extends CharacterBody3D

const FPS_WALK_SPEED := 3.8
const FPS_SPRINT_SPEED := 6.2
const Assets = preload("backrooms_assets.gd")
var third_person := false
var camera_clearance := 3.0
var game: Node
var viewmodel_root: Node3D
var walk_animation: AnimationPlayer
var leg_root: Node3D
var leg_animation: AnimationPlayer
var stride_spring := Vector2.ZERO
var viewmodel_motion := Vector3.ZERO
var lift_riding := false
var lift_clock := 0.0
var last_grounded := false
var landing_dip := 0.0
var camera: Camera3D
var torch: SpotLight3D
var flashlight_owned := false
var flashlight_model: Node3D
var flashlight_rig: Node3D
var leg_gait_was_moving := false
var flashlight_click: AudioStreamPlayer3D
var flashlight_pickup_tween: Tween
var yaw := 0.0
var pitch := 0.0
var aim_pointer := -1
var stamina := 100.0
var sprinting := false
var sprint_exhausted := false
var step_clock := 0.0
var motion_clock := 0.0
var focus_seconds := 0.0
var focus_target := Vector3.ZERO
var attention_hold := 0.0
var focus_allowed := false
var trigger_buffer := 0.0
var jump_requested := false
var jump_count := 0
var last_near_door: Node3D
var frowner_camera_active := false
var frowner_camera_seconds := 0.0
const COLLISION_RADIUS := .32
const COLLISION_HEIGHT := 1.72
const COLLISION_CENTER_Y := .88
var player_look_override := false
var flash_smiler_exposure := 0.0

func _ready() -> void:
	name = "LocalCrew"
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = COLLISION_RADIUS
	capsule.height = COLLISION_HEIGHT
	collision.shape = capsule
	collision.position.y = COLLISION_CENTER_Y
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.near = 0.06
	camera.fov = 76
	camera.current = true
	add_child(camera)
	torch = SpotLight3D.new()
	torch.position = Vector3(0.56, -0.50, -0.91)
	torch.light_color = Color(0.93, 0.96, 1.0)
	torch.light_energy = 1.9
	torch.spot_range = 11.5
	torch.spot_angle = 33
	torch.spot_attenuation = 1.65
	torch.shadow_enabled = false
	torch.visible = false
	camera.add_child(torch)
	# First-person arm meshes use the separately licensed and imported Sketchfab GLB.
	# Keep its authored skin and armature; Cesium is retained only for leg/foot movement.
	var asset_path := Assets.path("vendor/sketchfab_fps_arms.glb")
	if ResourceLoader.exists(asset_path):
		viewmodel_root = Node3D.new()
		viewmodel_root.name = "SketchfabFirstPersonHands"
		viewmodel_root.position = Vector3(0.0, -0.82, -0.59)
		viewmodel_root.rotation.y = PI
		camera.add_child(viewmodel_root)
		var arms: Node3D = Assets.fitted("vendor/sketchfab_fps_arms.glb",0.88)
		arms.name = "ScaledLicensedOriginal_RealGLBSkinnedHands"
		viewmodel_root.add_child(arms)
		for arm_mesh in arms.find_children("*", "MeshInstance3D", true, false):
			arm_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for anim in arms.find_children("*", "AnimationPlayer", true, false):
			for clip in anim.get_animation_list():
				if clip == "RESET": continue
				walk_animation = anim
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				anim.play(clip)
				anim.speed_scale = 0
				break
			if is_instance_valid(walk_animation): break
	# Camera-attached arms are for a natural near-field view; independently
	# rigged, licensed Cesium legs sit at the true foot position. Both preserve
	# the original animation skin, UV and source triangles (no capsule avatar).
	var feet_path := Assets.path("vendor/first_person_legs.glb")
	if ResourceLoader.exists(feet_path):
		leg_root = Node3D.new()
		leg_root.name = "CesiumFirstPersonFeet"
		# The skinned Cesium GLB is placed at the actual feet, not almost
		# a metre ahead of the collision capsule (which looked like floating poles).
		leg_root.position = Vector3(0.0, 0.018, -0.34)
		leg_root.scale = Vector3(0.96, 0.96, 0.96)
		leg_root.rotation.y = PI
		add_child(leg_root)
		var feet: Node3D = load(feet_path).instantiate()
		leg_root.add_child(feet)
		# Matte dark workwear over the original Cesium skinned leg/boot triangles.
		# Avoid the bright blue Cesium demo checker pattern in close-up.
		var boot_finish := StandardMaterial3D.new()
		boot_finish.albedo_color = Color(0.125,0.126,0.128)
		boot_finish.roughness = 0.83
		boot_finish.metallic = 0.03
		for limb in feet.find_children("*", "MeshInstance3D", true, false):
			limb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			limb.material_override = boot_finish
		for animator in feet.find_children("*", "AnimationPlayer", true, false):
			for clip in animator.get_animation_list():
				if clip == "RESET": continue
				leg_animation = animator
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animator.play(clip)
				animator.speed_scale = 0.0
				break
			if is_instance_valid(leg_animation): break

	# The real Poly Haven GLB uses its OWN camera-attached walking pivot.
	# Do not parent it under the hands: hiding the oversized Sketchfab hands
	# when collected must never make the physical flashlight disappear.
	var flashlight_path := Assets.path("vendor/flashlight_cc0.glb")
	if ResourceLoader.exists(flashlight_path):
		flashlight_rig = Node3D.new()
		flashlight_rig.name = "PolyHavenFlashlight_IndependentWalkingPivot"
		flashlight_rig.position = Vector3(0.57, -0.57, -0.84)
		flashlight_rig.rotation.y = PI - 0.08
		camera.add_child(flashlight_rig)
		flashlight_model = Assets.fitted("vendor/flashlight_cc0.glb",1.0)
		flashlight_model.name = "Held_PolyHaven_SmallPlasticTorch_GLB"
		var bbox: Vector3 = flashlight_model.get_meta("dimensions",Vector3.ONE)
		flashlight_model.scale *= 0.31 / maxf(bbox.x,maxf(bbox.y,bbox.z))
		flashlight_model.position = Vector3.ZERO
		flashlight_model.rotation = Vector3(-0.05,0.04,-PI*0.43)
		flashlight_rig.add_child(flashlight_model)
		for mesh in flashlight_model.find_children("*","MeshInstance3D",true,false):
			(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flashlight_model.visible = false
	flashlight_click = AudioStreamPlayer3D.new()
	flashlight_click.name = "HeldTorchSwitch3D"
	flashlight_click.max_distance = 5.0
	flashlight_click.unit_size = 0.6
	if ResourceLoader.exists("res://audio/flashlight_click.wav"):
		flashlight_click.stream = load("res://audio/flashlight_click.wav")
	camera.add_child(flashlight_click)

func take_flashlight() -> void:
	if flashlight_owned or not is_instance_valid(flashlight_model): return
	flashlight_owned = true
	# Holding a torch means no visible first-person arms: the original
	# Sketchfab skeleton is retained in the scene but completely hidden.
	if is_instance_valid(viewmodel_root): viewmodel_root.visible = false
	if game.prologue.phase == "ended" and game.wakeup_room.visible: game.wakeup_room.reveal_torch_smiler()
	flashlight_model.visible = true
	# A body-side carry: the real GLB is visible only at the bottom-right
	# edge. No unsupported floating hands, no torch in screen centre.
	torch.position = flashlight_rig.position + Vector3(-0.02,0.09,-0.13)
	flashlight_model.position.y = 0.10
	flashlight_pickup_tween = create_tween()
	flashlight_pickup_tween.tween_property(flashlight_model,"position:y",0.0,0.33).set_trans(Tween.TRANS_SINE)
	# Pickup and turning the light on are separate intentional actions.
	torch.visible = false

func toggle_torch() -> void:
	if not game.running or not flashlight_owned or not is_instance_valid(flashlight_model):
		if game.running and not game.ui.modal: game.ui.show_timed_hint(game.ui.localized("FIND THE FLASHLIGHT FIRST", "先拾起脚边的手电"),1.4)
		return
	torch.visible = not torch.visible
	if is_instance_valid(flashlight_click) and flashlight_click.stream != null: flashlight_click.play()

func reset_flashlight() -> void:
	flashlight_owned = false
	torch.visible = false
	if flashlight_pickup_tween != null and flashlight_pickup_tween.is_running(): flashlight_pickup_tween.kill()
	if is_instance_valid(flashlight_model):
		flashlight_model.visible = false
		flashlight_model.position.y = 0.0
	if is_instance_valid(viewmodel_root): viewmodel_root.visible = true
	if is_instance_valid(flashlight_rig):
		flashlight_rig.position = Vector3(0.57,-0.57,-0.84)
		flashlight_rig.rotation = Vector3(0,PI-0.08,0)

func _unhandled_input(event: InputEvent) -> void:
	if not game.running or game.ui.modal: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	if event is InputEventMouseButton and not game.ui.touch_controls_enabled() and is_instance_valid(game.fps) and game.fps.active:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed: request_fire()
		elif event.button_index == MOUSE_BUTTON_RIGHT: game.fps.set_aim(event.pressed)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER: if is_instance_valid(game.fps) and game.fps.round_over: game.net.request_fps_ready()
			KEY_E: interact_or_locked_door()
			KEY_SPACE: request_jump()
			KEY_J: game.ui.open_journal()
			KEY_F:
				if is_instance_valid(game.fps) and game.fps.active:
					game.fps.select_flashlight()
					if not game.fps.is_equipped(): toggle_torch()
				else: toggle_torch()
			KEY_R: if is_instance_valid(game.fps): game.fps.reload()
			KEY_T: if is_instance_valid(game.fps): game.fps.toggle_training()
			KEY_V: set_third_person(not third_person)
			KEY_1:
				if is_instance_valid(game.fps):
					if game.fps.level_id == -2: game.fps.select_weapon(0)
					else: game.fps.select_blaster()
			KEY_2:
				if is_instance_valid(game.fps):
					if game.fps.level_id == -2: game.fps.select_weapon(1)
					else: game.fps.select_flashlight()
			KEY_3: if is_instance_valid(game.fps): game.fps.select_weapon(2)
			KEY_4: if is_instance_valid(game.fps): game.fps.select_weapon(3)
			KEY_ESCAPE: game.ui.open_pause()
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.38 and aim_pointer == -1:
			aim_pointer = event.index
		elif not event.pressed and event.index == aim_pointer: aim_pointer = -1
	elif event is InputEventScreenDrag and event.index == aim_pointer:
		look(event.relative * 1.15)

func eye_position() -> Vector3:
	return global_position+Vector3(0,1.58,0)

func set_third_person(value: bool) -> void:
	third_person = value and is_instance_valid(game.fps) and game.fps.active
	aim_pointer = -1
	camera.position = Vector3(0,1.58,0)
	camera_clearance = 3.0
	if is_instance_valid(game.fps.weapon_pivot): game.fps.weapon_pivot.visible = game.fps.equipped and not third_person
	if is_instance_valid(game.fps_arena): game.fps_arena.update_local_actor(0.0)

func update_combat_camera(delta: float) -> void:
	if not third_person: return
	var pivot := eye_position()
	var orientation := global_basis*Basis(Vector3.RIGHT,pitch)
	var offset := orientation*Vector3(1.2,.18,2.8)
	var desired := pivot+offset
	var fraction := 1.0
	# A five-ray swept near-plane approximation prevents a shoulder camera
	# from looking through a corner even when its centre ray is clear.
	for local in [Vector3.ZERO,Vector3(.14,0,0),Vector3(-.14,0,0),Vector3(0,.14,0),Vector3(0,-.14,0)]:
		var shift: Vector3 = orientation*local
		var query := PhysicsRayQueryParameters3D.create(pivot+shift,desired+shift,1)
		query.exclude = [get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): fraction = minf(fraction,maxf(.0,pivot.distance_to(hit.position-shift)-.20)/offset.length())
	var length := offset.length()*fraction
	camera_clearance = length if length < camera_clearance else lerpf(camera_clearance,length,minf(1,delta*8))
	camera.global_position = pivot+offset.normalized()*camera_clearance
	camera.rotation = Vector3(pitch,0,0)
	# At extreme proximity hide the body rather than putting a camera in it.
	game.fps_arena.local_shadow.visible = camera_clearance > .65

func request_fire() -> void:
	# A press just before cooldown ends is retained, never resets host timing.
	if game.ui.modal or not game.fps.match_can_fire(): return
	var result: String = game.fps.fire()
	trigger_buffer = .16 if result == "COOLDOWN" and game.fps.magazine > 0 else 0.0

func look(delta: Vector2) -> void:
	if delta.length() > 0.7:
		player_look_override = true
		frowner_camera_active = false
	if delta.length() > 1: cancel_focus()
	yaw -= clampf(delta.x,-90.0,90.0) * 0.0019 * game.sensitivity
	pitch = clampf(pitch - clampf(delta.y,-90.0,90.0) * 0.0019 * game.sensitivity, -1.36, 1.30)
	rotation.y = yaw
	camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if not game.running or game.ui.modal:
		velocity = Vector3.ZERO
		aim_pointer = -1
		return
	if is_instance_valid(game.extra_levels) and game.extra_levels.visible:
		var episode: String = game.extra_levels.update_player(global_position,delta)
		if episode == "WITNESS": game.ui.show_timed_hint(game.ui.localized("SOMEONE TURNED AROUND BEHIND YOU", "身后有人转过身来"),2.8)
		elif episode == "VANISH": game.ui.show_timed_hint(game.ui.localized("THERE WAS SOMEONE HERE", "刚才这里还有一个人"),2.2)
	elif game.prologue.phase == "ended" and game.wakeup_room.visible:
		game.wakeup_room.update_frowner(delta)
		# Light only banishes a visible face actually inside its forward cone.
		var sprite := game.wakeup_room.smiler as Sprite3D
		if is_instance_valid(sprite) and sprite.visible:
			# Let the source-baked face remain depth-tested in real world space,
			# but keep its screen footprint bounded at very short distances.
			var range_to_face := camera.global_position.distance_to(sprite.global_position)
			sprite.pixel_size = 0.0017 * clampf(range_to_face / 3.1, 0.32, 1.0)
		if torch.visible and is_instance_valid(sprite) and sprite.visible:
			var target := sprite.global_position - camera.global_position
			if target.length() < torch.spot_range and -camera.global_transform.basis.z.dot(target.normalized()) > 0.86 and game.wakeup_room.smiler_clear_ray(camera.global_position,get_rid()):
				flash_smiler_exposure += delta
				if flash_smiler_exposure > 0.14: game.wakeup_room.smiler_flashlight_hit()
			else: flash_smiler_exposure = 0.0
		else: flash_smiler_exposure = 0.0
		if not game.wakeup_room.frowner_started and flashlight_owned and game.wakeup_room.smiler_flashlight_faded and global_position.z < -2.4 and not game.wakeup_room.frowner_finished:
			game.wakeup_room.begin_frowner()
			frowner_camera_active = game.shock_glance_enabled
			player_look_override = false
			frowner_camera_seconds = 0.0
		if frowner_camera_active and not player_look_override and not game.ui.modal:
			frowner_camera_seconds += delta
			var to_entity: Vector3 = game.wakeup_room.frowner_position - camera.global_position
			var desired := atan2(-to_entity.x, -to_entity.z)
			yaw = lerp_angle(yaw, desired, minf(delta * 0.62,0.06))
			rotation.y = yaw
			if frowner_camera_seconds > 3.4: frowner_camera_active = false
		if game.wakeup_room.update_visitor(global_position):
			game.ui.show_timed_hint(game.ui.localized("THE DOOR SLAMMED — ISOLATE THE BREAKER", "门突然关闭——先断开隔离开关"),2.6)
		if game.wakeup_room.update_observation(global_position):
			game.ui.show_timed_hint(game.ui.localized("SOMETHING MOVED BEHIND YOU", "背后有什么东西移动了"),2.5)
		# Show short physical interaction prompts only near a real imported switch
		# or console, and do not allocate new UI widgets during movement.
		if game.wakeup_room.door_slammed and not game.wakeup_room.lab_power_restored and not game.ui.transient_hint.visible:
			if not game.wakeup_room.breaker_isolated and global_position.distance_to(game.wakeup_room.breaker_position) < 1.65:
				game.ui.show_timed_hint(game.ui.localized("E / ISOLATE RED BREAKER", "E / 关闭红色隔离开关"),1.0)
			elif game.wakeup_room.breaker_isolated and global_position.distance_to(game.wakeup_room.backup_panel_position) < 1.65:
				game.ui.show_timed_hint(game.ui.localized("E / RESTORE BACKUP CIRCUIT", "E / 接通备用电路"),1.0)
		if game.wakeup_room.lab_power_restored and not game.wakeup_room.signal_traced and global_position.distance_to(game.wakeup_room.observation_console_position) < 1.75 and not game.ui.transient_hint.visible:
			game.ui.show_timed_hint(game.ui.localized("E / TRACE THE ECHO", "E / 追踪异常回声"),1.0)
		if not game.wakeup_room.flashlight_collected and global_position.distance_to(game.wakeup_room.flashlight_pickup_position) < 1.55:
			if not game.ui.transient_hint.visible:
				game.ui.show_timed_hint(game.ui.localized("E / PICK UP FLASHLIGHT", "E / 拾起手电筒"),1.0)
		var near: Node3D = game.wakeup_room.player_near_door(global_position)
		if near != last_near_door:
			last_near_door = near
			if near != null:
				game.wakeup_room.play_door_proximity(near)
				game.ui.show_timed_hint(game.ui.localized("E / TRY DOOR", "E / 尝试开门"), 1.5)
	else:
		last_near_door = null
	if focus_seconds > 0 and not lift_riding:
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
	if attention_hold > 0 or lift_riding: input = Vector2.ZERO
	var fps_mode: bool = is_instance_valid(game.fps) and game.fps.active
	if fps_mode:
		if stamina <= 5.0: sprint_exhausted = true
		elif stamina >= 25.0: sprint_exhausted = false
	sprinting = (Input.is_physical_key_pressed(KEY_SHIFT) or game.ui.run_held) and stamina > 5 and input.length() > 0.1 and (not fps_mode or not sprint_exhausted)
	stamina = clampf(stamina + (-18.0 if sprinting else 12.0) * delta, 0, 100)
	var direction := transform.basis * Vector3(input.x, 0, input.y)
	var speed := (FPS_SPRINT_SPEED if sprinting else FPS_WALK_SPEED) if fps_mode else (4.3 if sprinting else 2.6)
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 14)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 14)
	if not is_on_floor(): velocity.y -= 18.0 * delta
	else:
		velocity.y = 5.1 if jump_requested and not lift_riding else -0.1
		if jump_requested and not lift_riding: jump_count += 1
	jump_requested = false
	move_and_slide()
	if fps_mode:
		trigger_buffer = maxf(0.0,trigger_buffer-delta)
		var desktop_trigger: bool = not game.ui.touch_controls_enabled() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if game.ui.fire_held or desktop_trigger or trigger_buffer > 0.0:
			if game.fps.fire() == "REQUESTED": trigger_buffer = 0.0
	if is_on_floor() and not last_grounded: landing_dip = 0.045
	last_grounded = is_on_floor()
	landing_dip = move_toward(landing_dip, 0.0, delta * 0.18)
	if position.y < -2:
		position = game.fps_arena.spawn_for(1) if game.fps_arena.visible else (Vector3(0,0.1,3.1) if game.prologue.phase == "ended" and game.wakeup_room.visible else (game.extra_levels.exits[0]+Vector3(0,0.05,0.3) if is_instance_valid(game.extra_levels) and game.extra_levels.visible else game.level.spawn))
		velocity = Vector3.ZERO
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	motion_clock += delta * (10 if sprinting else 7) if moving else delta
	var bob := sin(motion_clock) * (0.022 if moving else 0.001)
	var cabin_vibration := sin(lift_clock * 19.0) * 0.009 if lift_riding and lift_clock >= 3.15 else 0.0
	if lift_riding: lift_clock += delta
	if third_person: update_combat_camera(delta)
	else: camera.position.y = lerpf(camera.position.y, 1.58 + bob - landing_dip + cabin_vibration, minf(delta * 10,1.0))
	if is_instance_valid(viewmodel_root):
		# Inertial arm sway + gait cycle; zero per-frame GLB allocations.
		var moving_strength := clampf(Vector2(velocity.x,velocity.z).length()/4.3, 0.0, 1.0)
		var target := Vector3(-input.x*0.033 + sin(motion_clock)*0.028*moving_strength,
			-0.82 - 0.018*absf(sin(motion_clock))*moving_strength + landing_dip*0.6,
			-0.59 - 0.026*moving_strength)
		viewmodel_root.position = viewmodel_root.position.lerp(target, minf(delta*8.0, 1.0))
		viewmodel_root.rotation.z = lerp_angle(viewmodel_root.rotation.z, input.x*0.018, minf(delta*5.0,1.0))
		# Do not let the hands reappear during movement or camera pans.
		viewmodel_root.visible = not flashlight_owned and (not lift_riding or lift_clock < 3.0) and (not is_instance_valid(game.fps) or not game.fps.active)
		if is_instance_valid(walk_animation):
			walk_animation.speed_scale = 0.0 if flashlight_owned or not moving else (1.35 if sprinting else 0.78)
	if is_instance_valid(flashlight_rig):
		# Physical GLB torch motion driven by actual player velocity, never
		# by static PNG/AI frames. Damped lateral stride and landing feedback.
		var sway_weight := clampf(Vector2(velocity.x,velocity.z).length()/4.3,0.0,1.0) if is_on_floor() else 0.0
		var stride := sin(motion_clock)
		var torch_target := Vector3(0.57 + stride*0.018*sway_weight - input.x*0.010,
			-0.57 - absf(stride)*0.014*sway_weight - landing_dip*0.42,
			-0.84 + 0.012*sway_weight)
		flashlight_rig.position = flashlight_rig.position.lerp(torch_target,minf(delta*9.0,1.0))
		flashlight_rig.rotation.x = lerp_angle(flashlight_rig.rotation.x,0.018*cos(motion_clock)*sway_weight,minf(delta*8.0,1.0))
		flashlight_rig.rotation.z = lerp_angle(flashlight_rig.rotation.z,0.026*stride*sway_weight,minf(delta*8.0,1.0))
		# Lighting starts at the same moving camera-space point as the
		# original handheld Poly Haven GLB, instead of the old centre-light.
		torch.position = flashlight_rig.position + Vector3(-0.02,0.09,-0.13)
		flashlight_rig.visible = (not lift_riding or lift_clock < 3.0) and (not is_instance_valid(game.fps) or not game.fps.active or not game.fps.is_equipped())
	if is_instance_valid(leg_root):
		# Imported skinned GLB boots belong near the collision capsule on the
		# real floor. Only show them on an intentional deep downward look.
		leg_root.visible = not lift_riding and pitch < -0.72 and (not is_instance_valid(game.fps) or not game.fps.active)
		leg_root.position.y = lerpf(leg_root.position.y,0.018,minf(delta*8.0,1.0))
		if is_instance_valid(leg_animation):
			var stepping := moving and is_on_floor()
			leg_animation.speed_scale = (1.40 if sprinting else 0.92) if stepping else 0.0
			if leg_gait_was_moving and not stepping: leg_animation.seek(0.0,true)
			leg_gait_was_moving = stepping
	step_clock -= delta
	if moving and is_on_floor() and step_clock <= 0:
		step_clock = 0.34 if sprinting else 0.52
		if game.fps_arena.visible or (game.prologue.phase == "ended" and game.wakeup_room.visible) or (is_instance_valid(game.extra_levels) and game.extra_levels.visible):
			game.footstep()
		elif not game.level.add_water_step(position):
			game.footstep()
		else:
			game.water_footstep()

func request_jump() -> void:
	if game.running and not game.ui.modal and not lift_riding:
		jump_requested = true

func interact_or_locked_door() -> void:
	if is_instance_valid(game.fps_arena) and game.fps_arena.visible: return
	if is_instance_valid(game.extra_levels) and game.extra_levels.visible:
		var transition: String = game.extra_levels.interact(global_position)
		match transition:
			"LIFT": game.ui.show_timed_hint(game.ui.localized("DOORS CLOSING — DESCENDING", "轿厢门关闭——正在下降"),4.0)
			"STAIRS": game.ui.show_timed_hint(game.ui.localized("SERVICE STAIR DOOR OPENING", "消防楼梯门开启"),2.0)
			"LOCKED": game.ui.show_timed_hint(game.ui.localized("WRONG FLOOR — SELECT THE LIT BUTTON", "楼层错误——请按亮起的按钮"),1.7)
			"CLIMB_STAIRS": game.ui.show_timed_hint(game.ui.localized("CLIMB THE STAIRS TO REACH THE SWITCH", "请先爬到楼梯顶端按下按钮"),2.0)
			"SECURITY_LOCKED": game.ui.show_timed_hint(game.ui.localized("SECURITY ACTIVE — DISABLE THE LEVEL 2 TARGETS", "警戒系统运行中——先清除层级 2 的警戒靶"),2.0)
			"BUSY": pass
			_: game.ui.show_timed_hint(game.ui.localized("FACE THE FLOOR SELECTOR AND PRESS E", "面向楼层按钮按 E"),1.6)
	elif game.prologue.phase == "ended" and game.wakeup_room.visible:
		if game.wakeup_room.signal_traced and global_position.distance_to(Vector3(11.0,0.1,-11.75)) < 2.15:
			game.open_backrooms_level(1)
			game.ui.show_timed_hint(game.ui.localized("LEVEL 1 — THE HABITABLE ZONE", "层级 1 —— 宜居地带"),3.0)
			return
		var result: String = game.wakeup_room.door_result(global_position)
		match result:
			"THRESHOLD":
				game.open_backrooms_level(0)
				game.ui.show_timed_hint(game.ui.localized("LEVEL 0 — THE LOBBY", "层级 0 —— 大堂"),2.8)
			"OPEN":
				game.ui.show_timed_hint(game.ui.localized("DOOR OPEN — ENTER THE LABORATORY", "门已打开——进入实验室"), 2.2)
			"FLASHLIGHT":
				take_flashlight()
				game.ui.show_timed_hint(game.ui.localized("FLASHLIGHT ACQUIRED — PRESS F / LIGHT", "获得手电——按 F / LIGHT 开关"), 2.4)
			"BREAKER":
				game.ui.show_timed_hint(game.ui.localized("CIRCUIT ISOLATED — RECONNECT THE BACKUP SWITCH", "回路已隔离——去接通备用电路"),2.6)
			"ISOLATED":
				game.ui.show_timed_hint(game.ui.localized("ISOLATION ACTIVE — FIND THE BACKUP SWITCH", "隔离开关已关闭——去找备用开关"),1.7)
			"SHORT":
				game.ui.show_timed_hint(game.ui.localized("SHORT CIRCUIT — ISOLATE RED BREAKER FIRST", "回路短路——先关闭红色隔离开关"),2.1)
			"POWER":
				game.ui.show_timed_hint(game.ui.localized("POWER RESTORED — THE OBSERVATION AIRLOCK IS OPEN", "电力恢复——观察室隔离门开启"),3.0)
			"TRACE":
				game.ui.show_timed_hint(game.ui.localized("THE RECORDED FOOTSTEPS ARE YOUR OWN — TWO SECONDS EARLY", "录下的脚步声是你自己的——却提前了两秒"),4.5)
			"OPENED":
				game.ui.show_timed_hint(game.ui.localized("THE LABORATORY IS OPEN", "实验室入口已打开"), 1.1)
			"LOCK":
				game.ui.show_timed_hint(game.ui.localized("LOCK", "已锁"), 2.0)
			_:
				game.ui.show_timed_hint(game.ui.localized("NOTHING TO USE", "附近没有可使用的物品"), 1.1)
	else:
		game.interact()

func reset_to(pos: Vector3) -> void:
	cancel_focus()
	position = pos
	velocity = Vector3.ZERO
	yaw = 0
	pitch = 0
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	stamina = 100
	sprint_exhausted = false
	lift_riding = false
	lift_clock = 0.0
	landing_dip = 0.0
	last_grounded = false
	last_near_door = null
	frowner_camera_active = false
	frowner_camera_seconds = 0.0
	player_look_override = false
	flash_smiler_exposure = 0.0
	leg_gait_was_moving = false

func begin_focus(target: Vector3, duration: float = 1.2) -> void:
	focus_target = target
	focus_seconds = clampf(duration, 0.0, 1.2)

func cancel_focus() -> void:
	focus_seconds = 0
	attention_hold = 0
	focus_allowed = false

func begin_attention() -> void:
	focus_allowed = true
	# Always bounded, and cancelled immediately when a menu opens or the
	# player moves the camera. Never lock movement when focus is disabled.
	attention_hold = 0.0

func begin_lift_ride() -> void:
	if lift_riding: return
	# Local near-elevator participant only. Other P2P cameras never change.
	lift_riding = true
	lift_clock = 0.0
	cancel_focus()
	# Set into the visible cabin when boarding starts; controls remain usable
	# after a finite host-controlled sequence, or if a menu is opened.
	position = Vector3(0, 0.05, -28.86)
	# One-time voluntary boarding view faces the inner doors; all look input
	# works immediately afterward. Never rotate a remote player's camera.
	yaw = PI
	rotation.y = yaw
	pitch = 0.0
	camera.rotation.x = 0.0
	velocity = Vector3.ZERO

func end_lift_ride() -> void:
	lift_riding = false
	lift_clock = 0.0
	if is_instance_valid(viewmodel_root): viewmodel_root.visible = true
