extends Node3D

# Local-only sightings. This director never RPCs, moves a remote camera,
# blocks an exit, or changes the host's authoritative clue state.
const BRIEFINGS := [
	["00 / 不存在的入口", "你是 Zorix 异常建筑调查组的现场维修员。\n失联搭档林岚的录音从一栋早已拆除的办公楼传来。\n你跨过检修门后，出口从身后的墙面消失。电梯留下了她的最后坐标。", "在走廊和侧室找到三段失联录音；听完后到尽头的电梯。没有倒计时。"],
	["01 / 回声下沉", "维修层的管道传来与你脚步一致的回响。\n林岚的录音说：‘别相信每一次回头看到的东西。’\n三份维修记录指向下层被水淹没的空间。", "探索暗处，收集三份维修记录，再乘电梯前往最后的信号源。"],
	["02 / 水面之外", "水面没有映出你的影子。\n林岚最后的求救被分成三段，藏在房间深处。\n找齐录音才能确定回到现实的电梯位置。", "在浅水边找到三段录音；回到电梯将记录带出去。"]]
const MEMORY_TEXT := [
	["[录音 01] ‘我来到拆除后的工地，里面的灯还亮着。’", "[录音 02] ‘我听到有人在另一侧模仿我的呼吸。’", "[录音 03] ‘如果你来找我，不要跟随脚步声。’"],
	["[记录 01] 地下管线图显示，这里根本没有地下层。", "[记录 02] 回声总比真实脚步慢半拍；它在学习。", "[记录 03] 林岚将最后的频率写在潮湿的电梯门上。"],
	["[终末录音 01] ‘水面映出了另一个人，不是我。’", "[终末录音 02] ‘别停留在黑暗中；它在等你看清它。’", "[终末录音 03] ‘带走这些记录，然后离开。’"]]

var game: Node
var actor: Node3D
var animation: AnimationPlayer
var face_glimmer: OmniLight3D
var step_audio: AudioStreamPlayer3D
var breath_audio: AudioStreamPlayer3D
var phase := "idle"
var clock := 0.0
var seen := false
var revealed := false
var step_clock := 0.0
var trigger := Vector3.ZERO
var hidden_point := Vector3.ZERO
var reveal_point := Vector3.ZERO
var last_stage := -1
var subtitle := ""
var subtitle_seconds := 0.0
var duration := 1.6
var peek_fraction := 1.0
var sway := 0.0
var secondary_seen := false
var cooldown := 0.0

func _ready() -> void:
	name = "LocalSightingDirector"
	var path := asset("entity.glb")
	if ResourceLoader.exists(path):
		actor = load(path).instantiate()
		actor.name = "CornerWitness"
		add_child(actor)
		actor.scale = Vector3.ONE * 1.16
		actor.visible = false
		face_glimmer = OmniLight3D.new()
		face_glimmer.name = "FaceGlimmer"
		face_glimmer.position = Vector3(0, 1.58, 0)
		face_glimmer.light_color = Color(0.53, 0.71, 0.65)
		face_glimmer.light_energy = 0.22
		face_glimmer.omni_range = 1.5
		face_glimmer.shadow_enabled = false
		actor.add_child(face_glimmer)
		for node in actor.find_children("*", "AnimationPlayer", true, false):
			for clip in node.get_animation_list():
				if clip.to_lower().contains("walk"):
					animation = node
					animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
					animation.play(clip)
					animation.speed_scale = 0.85
					break
			if is_instance_valid(animation): break
	step_audio = _spatial_sound("vendor/monster_step.ogg", -14)
	breath_audio = _spatial_sound("vendor/breathing.mp3", -25)

func asset(relative: String) -> String:
	var packaged := "res://assets/" + relative
	return packaged if ResourceLoader.exists(packaged) else "res://faceless2/assets/" + relative

func _spatial_sound(file: String, volume: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	var path := asset(file)
	if ResourceLoader.exists(path): sound.stream = load(path)
	sound.volume_db = volume
	sound.max_distance = 25
	sound.unit_size = 2.6
	add_child(sound)
	return sound

func reset_layer(index: int) -> void:
	last_stage = index
	phase = "idle"
	clock = 0
	seen = false
	secondary_seen = false
	revealed = false
	step_clock = 0
	cooldown = 0
	# Physical wall segments make the retreat endpoint really occluded.
	var z := -18.1 if index == 1 else -7.3
	var side := 1.0 if index == 1 else -1.0
	trigger = Vector3(0, 0, z)
	reveal_point = Vector3(side * 5.2, 0, z - 0.2)
	hidden_point = Vector3(side * 5.2, 0, z + 3.0)
	peek_fraction = [0.83, 1.0, 0.88][index]
	duration = [1.5, 2.0, 1.2][index]
	subtitle = ""
	subtitle_seconds = 0
	if is_instance_valid(actor):
		actor.visible = false
		actor.position = hidden_point
	if is_instance_valid(animation): animation.speed_scale = 0
	step_audio.stop()
	breath_audio.stop()

func say(text: String, seconds: float = 7.0) -> void:
	subtitle = text
	subtitle_seconds = seconds

func _start_sighting(again: bool = false) -> void:
	phase = "approach"
	clock = 0
	step_clock = 0
	revealed = false
	if not again:
		seen = true
		say("[无线电] 别看脚步的方向……先听。", 5.0)
	else:
		secondary_seen = true
		# Secondary glimpses are brief, not another scripted stop.
		duration = 0.7
		peek_fraction = 0.79
	# Camera control is strictly opt-in, local and interruptible.
	if game.auto_turn and not again: game.player.begin_attention()

func _set_walk_speed(speed: float) -> void:
	if not is_instance_valid(animation): return
	if not animation.is_playing(): animation.play(animation.current_animation)
	animation.speed_scale = speed

func _look_toward(target: Vector3, delta: float, amount: float) -> void:
	if not is_instance_valid(actor): return
	var d := target - actor.position
	var target_yaw := atan2(-d.x, -d.z)
	actor.rotation.y = lerp_angle(actor.rotation.y, target_yaw, minf(delta * amount, 1.0))

func _sound_step() -> void:
	if step_audio.stream != null:
		step_audio.pitch_scale = randf_range(0.71, 0.85)
		step_audio.play()

func update(delta: float) -> void:
	if game.ui.modal or not game.running or game.failed or game.completed:
		step_audio.stream_paused = true
		breath_audio.stream_paused = true
		return
	step_audio.stream_paused = false
	breath_audio.stream_paused = false
	subtitle_seconds = maxf(0, subtitle_seconds - delta)
	if subtitle_seconds <= 0: subtitle = ""
	cooldown += delta
	if not seen and game.player.position.distance_to(trigger) < 2.15:
		_start_sighting()
	elif seen and not secondary_seen and phase == "done" and cooldown > 48.0 and game.player.position.distance_to(trigger + Vector3(0, 0, -11)) < 2.0:
		_start_sighting(true)
	if phase == "idle" or phase == "done": return
	clock += delta
	sway += delta
	step_audio.position = reveal_point
	breath_audio.position = reveal_point + Vector3(0, 1.58, 0)
	if phase in ["approach", "retreat"]:
		step_clock -= delta
		if step_clock <= 0:
			step_clock = randf_range(0.43, 0.62) if phase == "approach" else randf_range(0.32, 0.46)
			_sound_step()
	match phase:
		"approach":
			if clock >= 0.9 and is_instance_valid(actor):
				actor.visible = true
				var t := smoothstep(0.9, 2.0, clock) * peek_fraction
				actor.position = hidden_point.lerp(reveal_point, t)
				_look_toward(game.player.position + Vector3(0, 1.4, 0), delta, 2.7)
				# Actual imported skeleton/skin animation, timed to movement.
				_set_walk_speed(0.65 + 0.15 * sin(sway * 3.2))
				step_audio.position = actor.position
			if clock >= 2.0:
				phase = "reveal"
				clock = 0
				revealed = true
				if is_instance_valid(actor): actor.visible = true
				_set_walk_speed(0.0)
				if game.auto_turn and game.player.focus_allowed:
					game.player.begin_focus(actor.global_position + Vector3(0, 1.5, 0))
				if breath_audio.stream != null: breath_audio.play()
		"reveal":
			if is_instance_valid(actor):
				_look_toward(game.player.position + Vector3(0, 1.55, 0), delta, 0.72)
				actor.rotation.z = sin(sway * 1.6) * 0.022
				actor.position.y = sin(sway * 1.9) * 0.012
			if clock >= duration:
				phase = "retreat"
				clock = 0
				game.player.cancel_focus()
				if not secondary_seen: say("[林岚的录音] 黑暗里有一张脸。它刚才看见你了。", 7)
		"retreat":
			if is_instance_valid(actor):
				var t := smoothstep(0.0, 1.0, clock / 1.3)
				actor.position = reveal_point.lerp(hidden_point, t)
				actor.rotation.z = lerpf(actor.rotation.z, 0, minf(delta * 6, 1))
				_look_toward(hidden_point + Vector3(0, 0, -1), delta, 3.0)
				_set_walk_speed(0.8 + 0.2 * sin(sway * 3.6))
				step_audio.position = actor.position
			if clock >= 1.3:
				phase = "done"
				cooldown = 0
				if is_instance_valid(actor): actor.visible = false
				_set_walk_speed(0)
				breath_audio.stop()

func _exit_tree() -> void:
	for sound in [step_audio, breath_audio]:
		if is_instance_valid(sound):
			sound.stop()
			sound.stream = null
