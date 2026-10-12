extends CharacterBody3D

const Assets = preload("backrooms_assets.gd")
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
var flashlight_click: AudioStreamPlayer3D
var flashlight_pickup_tween: Tween
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
var jump_requested := false
var jump_count := 0
var last_near_door: Node3D
var frowner_camera_active := false
var frowner_camera_seconds := 0.0
var player_look_override := false
var flash_smiler_exposure := 0.0

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
	torch.position = Vector3(0.27, -0.48, -0.82)
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
		viewmodel_root.position = Vector3(0.0, -1.49, -0.59)
		viewmodel_root.rotation.y = PI
		camera.add_child(viewmodel_root)
		var arms: Node3D = load(asset_path).instantiate()
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
		leg_root.position = Vector3(0.0, 0.025, -0.58)
		leg_root.scale = Vector3.ONE * 1.06
		leg_root.rotation.y = PI
		add_child(leg_root)
		var feet: Node3D = load(feet_path).instantiate()
		leg_root.add_child(feet)
		for limb in feet.find_children("*", "MeshInstance3D", true, false):
			limb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for animator in feet.find_children("*", "AnimationPlayer", true, false):
			for clip in animator.get_animation_list():
				if clip == "RESET": continue
				leg_animation = animator
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animator.play(clip)
				animator.speed_scale = 0.0
				break
			if is_instance_valid(leg_animation): break

	# The authored GLB is attached to the original skinned arms, not a primitive.
	var flashlight_path := Assets.path("vendor/flashlight_cc0.glb")
	if ResourceLoader.exists(flashlight_path):
		flashlight_model = Assets.fitted("vendor/flashlight_cc0.glb",1.0)
		flashlight_model.name = "Held_PolyHaven_SmallPlasticTorch_GLBSkinnedHands"
		var bbox: Vector3 = flashlight_model.get_meta("dimensions",Vector3.ONE)
		flashlight_model.scale *= 0.43 / maxf(bbox.x,maxf(bbox.y,bbox.z))
		flashlight_model.position = Vector3(-0.27,1.22,0.26)
		# Viewmodel parent faces 180 degrees: positive local Z is in front of POV.
		flashlight_model.rotation = Vector3(0.15,-0.18,-PI*0.46)
		if is_instance_valid(viewmodel_root): viewmodel_root.add_child(flashlight_model)
		else: camera.add_child(flashlight_model)
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
	if game.prologue.phase == "ended" and game.wakeup_room.visible: game.wakeup_room.reveal_torch_smiler()
	flashlight_model.visible = true
	flashlight_model.position.y += 0.19
	flashlight_pickup_tween = create_tween()
	flashlight_pickup_tween.tween_property(flashlight_model,"position:y",1.22,0.33).set_trans(Tween.TRANS_SINE)
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
		flashlight_model.position.y = 1.22

func _unhandled_input(event: InputEvent) -> void:
	if not game.running or game.ui.modal: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E: interact_or_locked_door()
			KEY_SPACE: request_jump()
			KEY_J: game.ui.open_journal()
			KEY_F: toggle_torch()
			KEY_ESCAPE: game.ui.open_pause()
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.38 and aim_pointer == -1:
			aim_pointer = event.index
		elif not event.pressed and event.index == aim_pointer: aim_pointer = -1
	elif event is InputEventScreenDrag and event.index == aim_pointer:
		look(event.relative * 1.15)

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
	if game.prologue.phase == "ended" and game.wakeup_room.visible:
		game.wakeup_room.update_frowner(delta)
		# Light only banishes a visible face actually inside its forward cone.
		var sprite := game.wakeup_room.smiler as Sprite3D
		if torch.visible and is_instance_valid(sprite) and sprite.visible:
			var target := sprite.global_position - camera.global_position
			if target.length() < torch.spot_range and -camera.global_transform.basis.z.dot(target.normalized()) > 0.86:
				flash_smiler_exposure += delta
				if flash_smiler_exposure > 0.14: game.wakeup_room.smiler_flashlight_hit()
			else: flash_smiler_exposure = 0.0
		else: flash_smiler_exposure = 0.0
		if not game.wakeup_room.frowner_started and flashlight_owned and global_position.z < -2.4 and not game.wakeup_room.frowner_finished:
			game.wakeup_room.begin_frowner()
			frowner_camera_active = true
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
			game.ui.show_timed_hint(game.ui.localized("POWER LOST — FIND THE BACKUP CONTROL", "电源中断——寻找备用控制台"),2.6)
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
	sprinting = (Input.is_physical_key_pressed(KEY_SHIFT) or game.ui.run_held) and stamina > 5 and input.length() > 0.1
	stamina = clampf(stamina + (-18.0 if sprinting else 12.0) * delta, 0, 100)
	var direction := transform.basis * Vector3(input.x, 0, input.y)
	var speed := 4.3 if sprinting else 2.6
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 14)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 14)
	if not is_on_floor(): velocity.y -= 18.0 * delta
	else:
		velocity.y = 5.1 if jump_requested and not lift_riding else -0.1
		if jump_requested and not lift_riding: jump_count += 1
	jump_requested = false
	move_and_slide()
	if is_on_floor() and not last_grounded: landing_dip = 0.045
	last_grounded = is_on_floor()
	landing_dip = move_toward(landing_dip, 0.0, delta * 0.18)
	if position.y < -2:
		position = Vector3(0,0.1,3.1) if game.prologue.phase == "ended" and game.wakeup_room.visible else game.level.spawn
		velocity = Vector3.ZERO
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	motion_clock += delta * (10 if sprinting else 7) if moving else delta
	var bob := sin(motion_clock) * (0.022 if moving else 0.001)
	var cabin_vibration := sin(lift_clock * 19.0) * 0.009 if lift_riding and lift_clock >= 3.15 else 0.0
	if lift_riding: lift_clock += delta
	camera.position.y = lerpf(camera.position.y, 1.58 + bob - landing_dip + cabin_vibration, minf(delta * 10,1.0))
	if is_instance_valid(viewmodel_root):
		# Inertial arm sway + gait cycle; zero per-frame GLB allocations.
		var moving_strength := clampf(Vector2(velocity.x,velocity.z).length()/4.3, 0.0, 1.0)
		var target := Vector3(-input.x*0.033 + sin(motion_clock)*0.028*moving_strength,
			-1.49 - 0.027*absf(sin(motion_clock))*moving_strength + landing_dip*0.6,
			-0.59 - 0.035*moving_strength)
		viewmodel_root.position = viewmodel_root.position.lerp(target, minf(delta*8.0, 1.0))
		viewmodel_root.rotation.z = lerp_angle(viewmodel_root.rotation.z, input.x*0.028, minf(delta*5.0,1.0))
		viewmodel_root.visible = not lift_riding or lift_clock < 3.0
		if is_instance_valid(walk_animation): walk_animation.speed_scale = 0.0 if not moving else (1.35 if sprinting else 0.78)
	if is_instance_valid(leg_root):
		# Low-angle downward looks show actual skinned knees, boots and steps;
		# arms remain in the lower field of view. Keep the body unobtrusive when
		# the player looks forward to avoid visual clipping.
		leg_root.visible = not lift_riding and pitch < -0.10
		leg_root.position.y = lerpf(leg_root.position.y, 0.045 + bob*0.18, minf(delta*6.0, 1.0))
		if is_instance_valid(leg_animation):
			leg_animation.speed_scale = 0.0 if not moving else (1.35 if sprinting else 0.78)
	step_clock -= delta
	if moving and is_on_floor() and step_clock <= 0:
		step_clock = 0.34 if sprinting else 0.52
		if game.prologue.phase == "ended" and game.wakeup_room.visible:
			game.footstep()
		elif not game.level.add_water_step(position):
			game.footstep()
		else:
			game.water_footstep()

func request_jump() -> void:
	if game.running and not game.ui.modal and not lift_riding:
		jump_requested = true

func interact_or_locked_door() -> void:
	if game.prologue.phase == "ended" and game.wakeup_room.visible:
		var result: String = game.wakeup_room.door_result(global_position)
		match result:
			"OPEN":
				game.ui.show_timed_hint(game.ui.localized("DOOR OPEN — ENTER THE LABORATORY", "门已打开——进入实验室"), 2.2)
			"FLASHLIGHT":
				take_flashlight()
				game.ui.show_timed_hint(game.ui.localized("FLASHLIGHT ACQUIRED — PRESS F / LIGHT", "获得手电——按 F / LIGHT 开关"), 2.4)
			"POWER":
				game.ui.show_timed_hint(game.ui.localized("BACKUP POWER RESTORED — THE DOOR UNLOCKED", "备用电源恢复——门已解锁"), 2.4)
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
	lift_riding = false
	lift_clock = 0.0
	landing_dip = 0.0
	last_grounded = false
	last_near_door = null
	frowner_camera_active = false
	frowner_camera_seconds = 0.0
	player_look_override = false
	flash_smiler_exposure = 0.0

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
