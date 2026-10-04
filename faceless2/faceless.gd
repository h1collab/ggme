extends CharacterBody3D

var game: Node
var player: CharacterBody3D
var visual: Node3D
var patrol_points: Array[Vector3] = []
var patrol_index := 0
var state := "patrol"
var speed_patrol := 2.0
var speed_chase := 4.6
var attack_cd := 0.0
var memory := 0.0
var difficulty := 1.0

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
		visual = packed.instantiate() as Node3D
		add_child(visual)

func _physics_process(delta: float) -> void:
	if not player or not player.alive:
		velocity = Vector3.ZERO
		return
	attack_cd = max(0.0,attack_cd-delta)
	var to_player := player.global_position-global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var light_bonus := 7.5 if player.flashlight and player.flashlight.visible else 0.0
	var detect := 8.0*difficulty + light_bonus
	if dist < detect:
		state = "chase"
		memory = 4.0
	elif state == "chase":
		memory -= delta
		if memory <= 0.0:
			state = "patrol"

	if state == "chase":
		if dist > 0.1:
			velocity.x = to_player.normalized().x*speed_chase*difficulty
			velocity.z = to_player.normalized().z*speed_chase*difficulty
			look_at(global_position+Vector3(to_player.x,0,to_player.z),Vector3.UP)
		if dist < 1.45 and attack_cd <= 0.0:
			attack_cd = 1.15/max(difficulty,0.6)
			player.take_damage(22.0*difficulty)
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
	velocity.y = -1.0
	move_and_slide()
