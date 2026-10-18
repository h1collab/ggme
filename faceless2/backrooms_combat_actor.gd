extends Node3D
# Four distinct original Quaternius CC0 skinned GLBs, selected by server seat.
const Assets = preload("backrooms_assets.gd")
const Arsenal = preload("backrooms_arsenal.gd")
var model: Node3D
var animation: AnimationPlayer
var skeleton: Skeleton3D
var held: Node3D
var attachment: BoneAttachment3D
var meshes: Array[Node] = []
var current_weapon := -1
var current_clip := ""
var seat := 0
var moving := false
var shot_seconds := 0.0
var hit_serial := 0
var last_position := Vector3.INF
var aim_pitch := 0.0
var hand_bone := -1
var held_meshes: Array[Node] = []
func configure(number: int) -> void:
	seat = clampi(number,1,6)
	var source := posmod(seat-1,4)+1
	model = Assets.fitted("vendor/fps_character_%d.glb" % source,1.75)
	# Source characters face +Z. Game forward is -Z.
	model.rotation.y = PI
	add_child(model)
	set_meta("character_source","fps_character_%d.glb" % source)
	var skels := model.find_children("*","Skeleton3D",true,false)
	if not skels.is_empty(): skeleton = skels[0] as Skeleton3D
	var players := model.find_children("*","AnimationPlayer",true,false)
	if not players.is_empty(): animation = players[0] as AnimationPlayer
	if is_instance_valid(skeleton):
		for i in range(skeleton.get_bone_count()):
			var key := skeleton.get_bone_name(i).to_lower()
			if ("hand" in key or "wrist" in key or "fist" in key) and ("right" in key or key.ends_with(".r") or key.ends_with("_r")):
				hand_bone = i
				attachment = BoneAttachment3D.new()
				attachment.bone_name = skeleton.get_bone_name(i)
				skeleton.add_child(attachment)
				break
	# Seats five and six reuse licensed source meshes with distinct authored cloth palettes.
	if seat > 4:
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var original: Material = mesh.get_active_material(surface)
				if original is StandardMaterial3D:
					var tint := original.duplicate() as StandardMaterial3D
					tint.albedo_color *= Color(.55,.85,1) if seat == 5 else Color(1,.68,.38)
					mesh.set_surface_override_material(surface,tint)
	meshes = model.find_children("*","MeshInstance3D",true,false)
	skeleton.skeleton_updated.connect(_update_hand_weapon)
	set_weapon(0)
	play_clip("Shoot_OneHanded")
func set_weapon(index: int) -> void:
	if index == current_weapon or not Arsenal.valid(index): return
	current_weapon = index
	if is_instance_valid(held): held.queue_free()
	held = Arsenal.model(index)
	add_child(held)
	held_meshes = held.find_children("*","MeshInstance3D",true,false)
	_update_hand_weapon()
	if not is_instance_valid(attachment): push_error("Combat actor lacks original right-hand bone")
func _update_hand_weapon() -> void:
	if not is_instance_valid(held) or not is_instance_valid(skeleton) or hand_bone < 0: return
	var socket: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(hand_bone)
	var orientation := global_basis.orthonormalized()*Basis(Vector3.RIGHT,aim_pitch)
	if current_weapon in [1,2]: orientation *= Basis(Vector3.UP,-PI*.5)
	if current_weapon == 3: orientation *= Basis(Vector3.RIGHT,-PI*.5)
	var grip: Vector3 = held.get_meta("grip_local",Vector3.ZERO)
	held.global_transform = Transform3D(orientation,socket.origin-orientation*grip)
func hand_contact_error() -> float:
	var socket: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(hand_bone)
	return socket.origin.distance_to(held.to_global(held.get_meta("grip_local",Vector3.ZERO)))

func play_clip(key: String) -> void:
	if not is_instance_valid(animation): return
	for clip in animation.get_animation_list():
		if str(clip).get_file() != key: continue
		if current_clip != str(clip):
			current_clip = str(clip)
			animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			animation.play(clip,.12)
		return
func update_combat(speed: float, airborne: bool, weapon: int, serial: int, delta: float, pitch: float = 0.0) -> void:
	aim_pitch = clampf(pitch,-1.36,1.30)
	set_weapon(weapon)
	if serial > hit_serial: shot_seconds = .22
	hit_serial = serial
	shot_seconds = maxf(0,shot_seconds-delta)
	moving = speed > .15
	if airborne: play_clip("Jump")
	elif shot_seconds > 0: play_clip("SwordSlash" if weapon == 3 else "Shoot_OneHanded")
	elif moving: play_clip("Run_Carry" if speed > 4.5 else "Walk_Carry")
	else:
		play_clip("Shoot_OneHanded")
		if is_instance_valid(animation) and animation.speed_scale != 0.0:
			# Clear the previous clip's blend before freezing a ready pose.
			# Freezing a .12s blend at speed zero left the fist behind the body.
			animation.play(current_clip,0.0)
			animation.seek(.15,true)
			animation.advance(0.0)
	if is_instance_valid(animation): animation.speed_scale = (clampf(speed/3.8,.5,1.8) if moving else 1.0) if (moving or airborne or shot_seconds > 0) else 0.0
	_update_hand_weapon()
