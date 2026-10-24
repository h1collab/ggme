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
var clip_paths: Dictionary = {}
var was_airborne := false
var landing_time := 0.0
var run_cycle := false
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
	if not players.is_empty():
		animation = players[0] as AnimationPlayer
		for clip in animation.get_animation_list(): clip_paths[str(clip).get_file()] = str(clip)
	if is_instance_valid(skeleton):
		for i in range(skeleton.get_bone_count()):
			var key := skeleton.get_bone_name(i).to_lower()
			if ("hand" in key or "wrist" in key or "fist" in key) and ("right" in key or key.ends_with(".r") or key.ends_with("_r")):
				hand_bone = i
				attachment = BoneAttachment3D.new()
				attachment.bone_name = skeleton.get_bone_name(i)
				skeleton.add_child(attachment)
				break
	preload("backrooms_anime_finish.gd").character(model,seat)
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
	if not is_inside_tree() or not is_instance_valid(held) or not is_instance_valid(skeleton) or hand_bone < 0: return
	if not held.is_inside_tree() or not skeleton.is_inside_tree(): return
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
	var clip: String = clip_paths.get(key,"")
	if clip.is_empty() or current_clip == clip: return
	current_clip = clip
	animation.get_animation(clip).loop_mode = Animation.LOOP_NONE if key == "Jump" else Animation.LOOP_LINEAR
	animation.play(clip,.12)
func update_combat(speed: float, airborne: bool, weapon: int, serial: int, delta: float, pitch: float = 0.0, vertical_speed: float = 0.0) -> void:
	aim_pitch = clampf(pitch,-1.36,1.30)
	set_weapon(weapon)
	if serial > hit_serial: shot_seconds = .22
	hit_serial = serial
	shot_seconds = maxf(0,shot_seconds-delta)
	moving = speed > .15
	if was_airborne and not airborne: landing_time = .16
	landing_time = maxf(0.0,landing_time-delta)
	model.position.y = -.045*sin(PI*landing_time/.16)
	if airborne:
		play_clip("Jump")
		if is_instance_valid(animation):
			var duration := animation.get_animation(current_clip).length
			animation.seek(clampf((5.1-vertical_speed)/10.2,.10,.84)*duration,true)
			animation.advance(0.0)
			animation.speed_scale = 0.0
	else:
		if shot_seconds > 0: play_clip("SwordSlash" if weapon == 3 else "Shoot_OneHanded")
		elif moving:
			if speed > 4.6: run_cycle = true
			elif speed < 4.0: run_cycle = false
			play_clip("Run_Carry" if run_cycle else "Walk_Carry")
		else:
			play_clip("Shoot_OneHanded")
			if is_instance_valid(animation) and (animation.speed_scale != 0.0 or was_airborne):
				animation.play(current_clip,0.0)
				animation.seek(.15,true)
				animation.advance(0.0)
		if is_instance_valid(animation):
			animation.speed_scale = (clampf(speed/(6.2 if run_cycle else 3.8),.65,1.35) if moving else 1.0) if moving or shot_seconds > 0 else 0.0
	was_airborne = airborne
	_update_hand_weapon()
