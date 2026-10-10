extends CharacterBody3D

const AssetVisual = preload("res://scripts/asset_visual.gd")

var game: Node
var player: CharacterBody3D
var visual: Node3D
var visual_scale := Vector3.ONE
var hit_tween: Tween
var animation: AnimationPlayer
var patrol_points: Array[Vector3] = []
var patrol_index := 0
var state := "patrol"
var speed_patrol := 2.0
var speed_chase := 4.6
var attack_cd := 0.0
var memory := 0.0
var last_known := Vector3.ZERO
var difficulty := 1.0
var health := 160.0
var dead := false

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 2.0
	cs.shape = cap
	cs.position.y = 1.0
	add_child(cs)
	var packed: PackedScene = load("res://assets/faceless_entity.glb")
	if packed:
		visual = Node3D.new()
		add_child(visual)
		var content := packed.instantiate() as Node3D
		visual.add_child(content)
		var box := AssetVisual.bounds(visual)
		content.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
		visual.scale = Vector3.ONE * (2.05 / maxf(box.size.y, 0.001))
		visual_scale = visual.scale
		var animations := content.find_children("*", "AnimationPlayer", true, false)
		if not animations.is_empty():
			animation = animations[0] as AnimationPlayer
			if animation.has_animation("Walk"):
				animation.get_animation("Walk").loop_mode = Animation.LOOP_LINEAR
				animation.play("Walk")

func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return
	if not player or not player.alive:
		velocity = Vector3.ZERO
		return
	attack_cd = max(0.0,attack_cd-delta)
	var to_player := player.global_position-global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var light_bonus := 7.5 if player.flashlight and player.flashlight.visible else 0.0
	var detect := 8.0*difficulty + light_bonus
	if dist < detect and _can_see_player():
		state = "chase"
		memory = 4.0
		last_known = player.global_position
	elif state == "chase":
		memory -= delta
		if memory <= 0.0:
			state = "patrol"

	if state == "chase":
		var pursuit := last_known - global_position
		pursuit.y = 0
		if pursuit.length() > 0.6:
			velocity.x = pursuit.normalized().x*speed_chase*difficulty
			velocity.z = pursuit.normalized().z*speed_chase*difficulty
			look_at(global_position+pursuit,Vector3.UP)
		else:
			velocity.x = move_toward(velocity.x, 0, delta * 12)
			velocity.z = move_toward(velocity.z, 0, delta * 12)
		if dist < 1.45 and attack_cd <= 0.0 and _can_see_player():
			attack_cd = 1.15/max(difficulty,0.6)
			player.take_damage(22.0*difficulty, global_position)
			if game: game.on_enemy_attack()
	else:
		if patrol_points.size() > 0:
			var target := patrol_points[patrol_index%patrol_points.size()]
			var d := target-global_position
			d.y = 0.0
			if d.length() < 0.9:
				patrol_index = (patrol_index+1)%patrol_points.size()
			else:
				velocity.x = d.normalized().x*speed_patrol
				velocity.z = d.normalized().z*speed_patrol
				look_at(global_position+Vector3(d.x,0,d.z),Vector3.UP)
	if animation: animation.speed_scale = 1.5 if state == "chase" else 0.85
	velocity.y = -0.2 if is_on_floor() else velocity.y - delta * 18
	move_and_slide()


func take_bullet(damage: float, _hit_pos: Vector3) -> void:
	if dead:
		return
	health -= damage
	if visual:
		if hit_tween and hit_tween.is_running(): hit_tween.kill()
		visual.scale = visual_scale * Vector3(1.04, 0.97, 1.04)
		hit_tween = create_tween()
		hit_tween.tween_property(visual, "scale", visual_scale, 0.13)
	if health <= 0.0:
		dead = true
		if game:
			game.faceless_down(self)

func _can_see_player() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.7, 0), player.global_position + Vector3(0, 1.1, 0))
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == player
