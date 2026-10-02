extends CharacterBody3D

var game: Node
var player: CharacterBody3D
var hp := 65.0
var attack_cd := 0.0
var stun := 0.0
var dead := false
var move_speed := 2.7
var body_parts: Array[MeshInstance3D] = []

func _ready():
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_build_teacher()

func _build_teacher():
	var cloth := _mat(Color(0.12,0.16,0.22),0.72)
	var shirt := _mat(Color(0.78,0.80,0.77),0.88)
	var skin := _mat(Color(0.52,0.34,0.24),0.8)
	var tie := _mat(Color(0.35,0.03,0.05),0.6)
	_part(Vector3(0,1.15,0),Vector3(0.72,0.92,0.38),cloth)
	_part(Vector3(0,1.73,0),Vector3(0.38,0.38,0.38),skin)
	_part(Vector3(0,1.35,-0.205),Vector3(0.34,0.42,0.05),shirt)
	_part(Vector3(0,1.36,-0.235),Vector3(0.07,0.32,0.035),tie)
	for sx in [-0.48,0.48]:
		_part(Vector3(sx,1.18,0),Vector3(0.18,0.78,0.20),cloth)
	for sx in [-0.22,0.22]:
		_part(Vector3(sx,0.55,0),Vector3(0.22,0.85,0.24),cloth)

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=rough
	return m

func _part(pos:Vector3,size:Vector3,mat:Material):
	var mi:=MeshInstance3D.new()
	var b:=BoxMesh.new()
	b.size=size
	mi.mesh=b
	mi.material_override=mat
	mi.position=pos
	add_child(mi)
	body_parts.append(mi)

func _physics_process(delta):
	if dead or not player:
		return
	attack_cd=max(0.0,attack_cd-delta)
	stun=max(0.0,stun-delta)
	var to_p:=player.global_position-global_position
	to_p.y=0
	if stun<=0.0 and to_p.length()>1.25:
		velocity=to_p.normalized()*move_speed
		look_at(global_position+Vector3(to_p.x,0,to_p.z),Vector3.UP)
	else:
		velocity.x=move_toward(velocity.x,0.0,delta*10.0)
		velocity.z=move_toward(velocity.z,0.0,delta*10.0)
	velocity.y=-1.0
	move_and_slide()
	if to_p.length()<1.45 and attack_cd<=0.0 and stun<=0.0:
		attack_cd=1.0
		player.take_damage(8.0)

func take_hit(damage:float, impulse:Vector3):
	if dead:return
	hp-=damage
	stun=0.25
	velocity=impulse
	for p in body_parts:
		p.scale=Vector3(1.05,0.94,1.05)
	var tw:=create_tween()
	tw.tween_method(_reset_scale,0.0,1.0,0.12)
	if hp<=0.0:
		dead=true
		if game: game.teacher_ko(self)

func _reset_scale(t:float):
	for p in body_parts:
		p.scale=Vector3.ONE
