extends CharacterBody3D

var game: Node
var player: CharacterBody3D
var visual: Node3D
var visual_scale := Vector3.ONE
var hit_tween: Tween

var health := 80.0
var attack_cd := 0.0
var dead := false
var patrol_points: Array[Vector3] = []
var patrol_index := 0
var difficulty := 1.0

func _fit_visual(root: Node3D, target_height: float) -> void:
	var first := true
	var box := AABB()
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var rel := root.global_transform.affine_inverse() * mi.global_transform
		var b: AABB = rel * mi.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	if not first and box.size.y > 0.001:
		root.scale = Vector3.ONE*(target_height/box.size.y)
		root.position.y = -box.position.y*(target_height/box.size.y)

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.86
	cs.shape = cap
	cs.position.y = 0.93
	add_child(cs)
	var packed: PackedScene = load("res://assets/blackwood_soldier.glb")
	if packed:
		visual = packed.instantiate() as Node3D
		add_child(visual)
		_fit_visual(visual,1.86)
		visual_scale = visual.scale

func _physics_process(delta: float) -> void:
	if dead or player == null or not player.alive:
		return
	attack_cd = max(0.0,attack_cd-delta)
	var to_player := player.global_position-global_position
	to_player.y = 0.0
	var d := to_player.length()
	if d < 18.0:
		look_at(global_position+Vector3(to_player.x,0,to_player.z),Vector3.UP)
		if d > 7.0:
			velocity.x = to_player.normalized().x*2.3
			velocity.z = to_player.normalized().z*2.3
		else:
			velocity.x = move_toward(velocity.x,0.0,delta*8.0)
			velocity.z = move_toward(velocity.z,0.0,delta*8.0)
		if d < 15.0 and attack_cd <= 0.0 and _can_see_player():
			attack_cd = 1.15/max(difficulty,0.8)
			player.take_damage(9.0*difficulty)
			if game:
				game.soldier_fired(self)
	else:
		if patrol_points.size() > 0:
			var target := patrol_points[patrol_index%patrol_points.size()]
			var dir := target-global_position
			dir.y = 0.0
			if dir.length() < 0.8:
				patrol_index = (patrol_index+1)%patrol_points.size()
			else:
				velocity.x = dir.normalized().x*1.7
				velocity.z = dir.normalized().z*1.7
				look_at(global_position+Vector3(dir.x,0,dir.z),Vector3.UP)
	velocity.y = -1.0
	move_and_slide()

func _can_see_player() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), player.global_position + Vector3(0, 1.2, 0))
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == player

func take_bullet(damage: float, _hit_pos: Vector3) -> void:
	if dead:
		return
	health -= damage
	if visual:
		if hit_tween and hit_tween.is_running():
			hit_tween.kill()
		visual.scale = visual_scale * Vector3(1.04,0.97,1.04)
		hit_tween = create_tween()
		hit_tween.tween_property(visual,"scale",visual_scale,0.10)
	if health <= 0.0:
		dead = true
		if game:
			game.soldier_down(self)
