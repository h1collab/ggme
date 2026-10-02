extends CharacterBody3D

var game: Node
var player: CharacterBody3D
var patrol: Array[Vector3] = []
var patrol_i := 0
var state := "PATROL"
var last_seen := Vector3.ZERO
var search_time := 0.0
var eye: Marker3D
var speed_patrol := 2.0
var speed_chase := 5.0

func _ready():
	eye = Marker3D.new()
	eye.position = Vector3(0, 1.65, 0)
	add_child(eye)

func _physics_process(delta):
	if not player:
		return
	var dist := global_position.distance_to(player.global_position)
	var can_see := dist < 16.0 and _line_of_sight()
	if can_see:
		state = "CHASE"
		last_seen = player.global_position
		search_time = 5.5
	elif state == "CHASE":
		state = "SEARCH"
	elif state == "SEARCH":
		search_time -= delta
		if search_time <= 0.0:
			state = "PATROL"
	var target := player.global_position if state == "CHASE" else last_seen if state == "SEARCH" else _patrol_target()
	var flat := target - global_position
	flat.y = 0
	if flat.length() > 0.5:
		var sp := speed_chase if state == "CHASE" else speed_patrol
		velocity = flat.normalized() * sp
		look_at(global_position + Vector3(flat.x, 0, flat.z), Vector3.UP)
	else:
		velocity = Vector3.ZERO
		if state == "PATROL":
			patrol_i = (patrol_i + 1) % max(1, patrol.size())
	velocity.y = -1.0
	move_and_slide()
	if game:
		game.set_chase_intensity(clampf(1.0 - dist / 13.0, 0.0, 1.0) if state == "CHASE" else 0.0)
	if dist < 1.35 and not player.caught_lock:
		game.player_caught()

func _patrol_target() -> Vector3:
	if patrol.is_empty():
		return global_position
	return patrol[patrol_i]

func _line_of_sight() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye.global_position, player.camera.global_position)
	q.exclude = [self.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == player
