extends CharacterBody3D

var game: Node
var player: CharacterBody3D
var hp: float = 80.0
var attack_cd: float = 0.0
var stun: float = 0.0
var dead: bool = false
var move_speed: float = 2.8
var visual_root: Node3D
var bob_time: float = 0.0

func _ready() -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.40
	cap.height = 1.82
	cs.shape = cap
	cs.position.y = 0.92
	add_child(cs)
	_build_visual()

func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.position = Vector3(0, 0.02, 0)
	add_child(visual_root)
	var packed: PackedScene = load("res://assets/teacher_sketchfab_rebuild.glb")
	if packed != null:
		var inst: Node = packed.instantiate()
		visual_root.add_child(inst)
		if inst is Node3D:
			(inst as Node3D).scale = Vector3(1.0, 1.0, 1.0)
			(inst as Node3D).rotation.y = PI
	else:
		var fallback: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.7, 1.8, 0.45)
		fallback.mesh = box
		visual_root.add_child(fallback)

func _physics_process(delta: float) -> void:
	if dead or player == null:
		return
	attack_cd = max(0.0, attack_cd - delta)
	stun = max(0.0, stun - delta)
	bob_time += delta * (3.2 if stun <= 0.0 else 6.0)
	visual_root.position.y = 0.02 + sin(bob_time) * 0.03
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	if stun <= 0.0 and to_player.length() > 1.35:
		velocity = to_player.normalized() * move_speed
		look_at(global_position + Vector3(to_player.x, 0.0, to_player.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
	velocity.y = -1.0
	move_and_slide()
	if to_player.length() < 1.45 and attack_cd <= 0.0 and stun <= 0.0:
		attack_cd = 1.0
		if player != null:
			player.take_damage(8.0)

func take_hit(damage: float, impulse: Vector3) -> void:
	if dead:
		return
	hp -= damage
	stun = 0.24
	velocity = impulse
	visual_root.scale = Vector3(1.06, 0.95, 1.06)
	var tw: Tween = create_tween()
	tw.tween_property(visual_root, "scale", Vector3.ONE, 0.14)
	if hp <= 0.0:
		dead = true
		if game != null:
			game.teacher_ko(self)
