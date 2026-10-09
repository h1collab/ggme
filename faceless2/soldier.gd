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
		visual.add_child(content)
		var box := AssetVisual.bounds(visual)
		content.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
		visual.scale = Vector3.ONE * (1.86 / maxf(box.size.y, 0.001))
		visual_scale = visual.scale
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
	muzzle_signal.position = Vector3(0.14, 1.4, -0.30)
	muzzle_signal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_signal.hide()
	add_child(muzzle_signal)

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

func _can_see_player() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), player.global_position + Vector3(0, 1.05, 0))
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == player

func _fire_at_snapshot() -> void:
	var origin := global_position + global_basis * Vector3(0.14, 1.4, -0.30)
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
		visual.scale = visual_scale * Vector3(1.025, 0.98, 1.025)
		hit_tween = create_tween()
		hit_tween.tween_property(visual, "scale", visual_scale, 0.12)
	if health <= 0:
		dead = true
		if game: game.soldier_down(self)
