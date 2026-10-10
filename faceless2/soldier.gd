extends CharacterBody3D

const AssetVisual = preload("res://scripts/asset_visual.gd")
var game: Node
var player: CharacterBody3D
var visual: Node3D
var visual_scale := Vector3.ONE
var hit_tween: Tween
var muzzle_signal: MeshInstance3D
var health := 80.0
var attack_cd := 0.0
var dead := false
var patrol_points: Array[Vector3] = []
var patrol_index := 0
var difficulty := 1.0
var state := "patrol"
var last_known := Vector3.ZERO
var memory := 0.0
var sense_cd := 0.0
var has_sight := false
var windup := 0.0
var aim_point := Vector3.ZERO
var stagger := 0.0
var strafe_side := 1.0
var skeleton: Skeleton3D
var rig_root: Node3D
var gait := 0.0
var leg_rotations := {}

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.86
	cs.shape = cap
	cs.position.y = 0.93
	add_child(cs)
	var packed := load("res://assets/blackwood_soldier.glb") as PackedScene
	if packed:
		visual = Node3D.new()
		add_child(visual)
		var content := packed.instantiate() as Node3D
		# This rig faces +Z; AI and muzzle rays face -Z.
		content.rotation.y = PI
		visual.add_child(content)
		AssetVisual.prepare_world(content, "res://assets/blackwood_soldier.glb")
		var box := AssetVisual.bounds(visual)
		content.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
		visual.scale = Vector3.ONE * (1.86 / maxf(box.size.y, 0.001))
		visual_scale = visual.scale
		var rigs := content.find_children("*", "Skeleton3D", true, false)
		if not rigs.is_empty():
			skeleton = rigs[0] as Skeleton3D
			rig_root = content
			_pose_guard()
		var weapon := Node3D.new()
		weapon.position = Vector3(0.08, 1.30, -0.20)
		add_child(weapon)
		var rifle := load("res://assets/rifle.glb").instantiate() as Node3D
		weapon.add_child(rifle)
		var gun_box := AssetVisual.bounds(weapon)
		rifle.position -= gun_box.get_center()
		weapon.scale = Vector3.ONE * (0.70 / gun_box.size.z)
		AssetVisual.prepare_viewmodel(weapon)
	strafe_side = -1.0 if global_position.x < 0 else 1.0
	sense_cd = fposmod(global_position.z, 0.16)
	muzzle_signal = MeshInstance3D.new()
	var lamp := SphereMesh.new()
	lamp.radius = 0.025
	lamp.height = 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.48, 0.16)
	lamp.material = material
	muzzle_signal.mesh = lamp
	muzzle_signal.position = Vector3(0.08, 1.30, -0.55)
	muzzle_signal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_signal.hide()
	add_child(muzzle_signal)

func _point_bone(fragment: String, direction: Vector3) -> void:
	for bone in range(skeleton.get_bone_count()):
		if fragment not in String(skeleton.get_bone_name(bone)): continue
		var pose := skeleton.get_bone_global_pose(bone)
		var target := (skeleton.global_basis.inverse() * global_basis * direction).normalized()
		var desired := Basis(Quaternion(pose.basis.x.normalized(), target)) * pose.basis
		var parent := skeleton.get_bone_parent(bone)
		if parent >= 0: desired = skeleton.get_bone_global_pose(parent).basis.inverse() * desired
		skeleton.set_bone_pose_rotation(bone, desired.orthonormalized().get_rotation_quaternion())
		skeleton.force_update_all_bone_transforms()
		return

func _pose_guard() -> void:
	# Point each arm's +X bone axis toward a two-hand ready stance; preserve the
	# imported rest axes instead of assuming Blender and Valve rigs agree.
	_point_bone("R_UpperArm", Vector3(0.04, -0.28, -0.08))
	_point_bone("R_Forearm", Vector3(-0.17, 0.10, -0.22))
	_point_bone("L_UpperArm", Vector3(-0.02, -0.22, -0.20))
	_point_bone("L_Forearm", Vector3(0.20, 0.06, -0.21))
	for bone in range(skeleton.get_bone_count()):
		var name := String(skeleton.get_bone_name(bone))
		if "Thigh" in name or "Calf" in name:
			leg_rotations[bone] = skeleton.get_bone_pose_rotation(bone)

func _animate_gait(delta: float) -> void:
	if skeleton == null: return
	var movement := clampf(Vector2(velocity.x, velocity.z).length() / 2.3, 0, 1)
	gait += delta * 8.5 * movement
	for bone in leg_rotations:
		var name := String(skeleton.get_bone_name(bone))
		var step := sin(gait + (PI if "L_" in name else 0.0)) * movement
		var angle := step * 0.30 if "Thigh" in name else maxf(0, -step) * 0.42
		# The leg length axis is local X; local Z flexes the imported knee.
		skeleton.set_bone_pose_rotation(bone, leg_rotations[bone] * Quaternion(Vector3.BACK, angle))

func hear_shot(origin: Vector3) -> void:
	if dead or global_position.distance_to(origin) > 30.0: return
	last_known = origin
	memory = 5.0
	if not has_sight: state = "investigate"

func _physics_process(delta: float) -> void:
	if dead or player == null or not player.alive:
		velocity = Vector3.ZERO
		return
	attack_cd = maxf(0, attack_cd - delta)
	stagger = maxf(0, stagger - delta)
	memory = maxf(0, memory - delta)
	sense_cd -= delta
	var to_player := player.global_position - global_position
	to_player.y = 0
	var distance := to_player.length()
	if sense_cd <= 0:
		sense_cd = 0.16
		var range_limit := 24.0 if player.flashlight.visible else 18.0
		var facing := distance < 3.0 or memory > 0 or (-global_basis.z).dot(to_player.normalized()) > 0.42
		has_sight = distance < range_limit and facing and _can_see_player()
		if has_sight:
			last_known = player.global_position
			memory = 5.0
			state = "combat"
		elif memory <= 0:
			state = "patrol"
		else:
			state = "search"
	if windup > 0:
		windup = maxf(0, windup - delta)
		muzzle_signal.visible = windup > 0
		if windup == 0 and stagger <= 0: _fire_at_snapshot()
	var direction := Vector3.ZERO
	var speed := 1.7
	if memory > 0:
		direction = last_known - global_position
		direction.y = 0
		if direction.length() > 0.1: look_at(global_position + direction, Vector3.UP)
		speed = 2.3
		if has_sight:
			if distance < 5.0: direction = -to_player
			elif distance <= 10.0: direction = Vector3(to_player.z, 0, -to_player.x) * strafe_side * 0.4
			if distance < 15 and attack_cd <= 0 and windup <= 0 and stagger <= 0:
				windup = 0.48 / maxf(difficulty, 0.8)
				# A player who moves during the tell can dodge the ensuing shot.
				aim_point = player.global_position + Vector3(0, 1.05, 0)
				attack_cd = 1.3 / maxf(difficulty, 0.8)
				muzzle_signal.show()
		elif direction.length() < 1.2:
			direction = Vector3.ZERO
	elif not patrol_points.is_empty():
		direction = patrol_points[patrol_index % patrol_points.size()] - global_position
		direction.y = 0
		if direction.length() < 0.8:
			patrol_index = (patrol_index + 1) % patrol_points.size()
			direction = Vector3.ZERO
		else: look_at(global_position + direction, Vector3.UP)
	if stagger > 0 or windup > 0: speed *= 0.2
	var desired := direction.normalized() * speed if direction.length() > 0.1 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, desired.x, delta * 10)
	velocity.z = move_toward(velocity.z, desired.z, delta * 10)
	velocity.y = -0.2 if is_on_floor() else velocity.y - delta * 18
	move_and_slide()
	_animate_gait(delta)

func _can_see_player() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), player.global_position + Vector3(0, 1.05, 0))
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == player

func _fire_at_snapshot() -> void:
	var origin := global_position + global_basis * muzzle_signal.position
	var direction := (aim_point - origin).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 45)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.get("position", origin + direction * 45)
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if hit.get("collider") == player: player.take_damage(9.0 * difficulty, global_position)
	if game:
		game.soldier_fired(self)
		game.effects.shot(origin, end, normal, hit.get("collider") == player, true)

func take_bullet(damage: float, hit_pos: Vector3) -> void:
	if dead: return
	var headshot := hit_pos.y - global_position.y > 1.48
	if headshot and game: game.interface.critical_time = 0.28
	health -= damage * (1.8 if headshot else 1.0)
	last_known = player.global_position if player else global_position
	memory = 6.0
	state = "combat"
	stagger = 0.24
	windup = 0
	muzzle_signal.hide()
	if visual:
		if hit_tween and hit_tween.is_running(): hit_tween.kill()
		visual.rotation.x = -0.045
		hit_tween = create_tween()
		hit_tween.tween_property(visual, "rotation:x", 0.0, 0.16)
	if health <= 0:
		dead = true
		if game: game.soldier_down(self)
