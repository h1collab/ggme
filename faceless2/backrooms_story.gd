extends Node3D

# Each crew member experiences a local, non-combat sighting. Never drives a
# remote player's camera or changes authoritative power/progression.
const BRIEFINGS := [
	["00 / 失联的夜班", "你是 Zorix 异常建筑调查组的维修员。\n02:00，搭档林岚的求救信号从一栋已经拆除的办公楼传来。\n你跨过检修门，身后的出口消失了。电梯仍能收到她的信号。", "恢复三个节点 → 在监控站报告三个闪烁故障 → 坚持到 06:00 → 到走廊尽头乘电梯。"],
	["01 / 楼下的脚步", "你修复的不是建筑电源，而是连接三层空间的信号中继。\n林岚留下的记录说：脚步声会模仿人，但它不喜欢被看见。\n下一层的供电稳定后，电梯才能继续追踪她。", "继续修复节点与监控故障。别追进阴影；回到有灯的地方。"],
	["02 / 水面没有倒影", "林岚的最后一段记录来自泳池：‘它学会了我的脚步。’\n这层中继可以把记录传回地面，也能为返回电梯打开出口。\n找到她留下的证据，完成最后一次校准，然后离开。", "修复三处节点、报告三次故障、等到 06:00；把记录带回电梯。"]]
var game: Node
var actor: Node3D
var animation: AnimationPlayer
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

func _ready() -> void:
	name = "StoryDirector"
	var path := asset("entity.glb")
	if ResourceLoader.exists(path):
		actor = load(path).instantiate()
		actor.name = "CornerWitness"
		add_child(actor)
		actor.scale = Vector3.ONE * 1.16
		actor.visible = false
		for node in actor.find_children("*", "AnimationPlayer", true, false):
			animation = node
			for animation_name in animation.get_animation_list():
				if animation_name.to_lower().contains("walk"):
					animation.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
					animation.play(animation_name)
					break
	step_audio = _spatial_sound("vendor/monster_step.ogg", -10)
	breath_audio = _spatial_sound("vendor/breathing.mp3", -21)

func asset(relative: String) -> String:
	var packaged := "res://assets/" + relative
	return packaged if ResourceLoader.exists(packaged) else "res://faceless2/assets/" + relative

func _spatial_sound(file: String, volume: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	var path := asset(file)
	if ResourceLoader.exists(path): sound.stream = load(path)
	sound.volume_db = volume
	sound.max_distance = 24
	sound.unit_size = 3
	add_child(sound)
	return sound

func reset_layer(index: int) -> void:
	last_stage = index
	phase = "idle"
	clock = 0
	seen = false
	revealed = false
	step_clock = 0
	var z := -18.1 if index == 1 else -7.3
	var side := 1.0 if index == 1 else -1.0
	trigger = Vector3(0, 0, z)
	reveal_point = Vector3(side * 5.2, 0, z - 0.2)
	hidden_point = Vector3(side * 5.2, 0, z + 3.0)
	subtitle = ""
	subtitle_seconds = 0
	if is_instance_valid(actor):
		actor.visible = false
		actor.position = hidden_point
	step_audio.stop()
	breath_audio.stop()

func say(text: String, seconds: float = 7.0) -> void:
	subtitle = text
	subtitle_seconds = seconds

func update(delta: float) -> void:
	if game.ui.modal or not game.running or game.failed or game.completed:
		step_audio.stream_paused = true
		breath_audio.stream_paused = true
		return
	step_audio.stream_paused = false
	breath_audio.stream_paused = false
	subtitle_seconds = maxf(0, subtitle_seconds - delta)
	if subtitle_seconds <= 0: subtitle = ""
	if not seen and game.player.position.distance_to(trigger) < 2.1:
		seen = true
		phase = "approach"
		clock = 0
		if game.auto_turn: game.player.begin_attention()
		say("[录音 / 林岚] 先别动……那不是你的脚步。", 6)
	if phase == "idle" or phase == "done": return
	clock += delta
	step_audio.position = reveal_point
	breath_audio.position = reveal_point + Vector3(0, 1.5, 0)
	step_clock -= delta
	if phase in ["approach", "retreat"] and step_clock <= 0:
		step_clock = 0.58 if phase == "approach" else 0.38
		step_audio.pitch_scale = 0.70 if game.stage != 2 else 0.60
		if step_audio.stream != null: step_audio.play()
	match phase:
		"approach":
			if clock >= 0.9 and is_instance_valid(actor):
				actor.visible = true
				actor.position = hidden_point.lerp(reveal_point, smoothstep(0.9, 1.8, clock))
				actor.look_at(reveal_point + Vector3(0, 0, -1), Vector3.UP, true)
				step_audio.position = actor.position
			if clock >= 1.8:
				phase = "reveal"
				clock = 0
				revealed = true
				if is_instance_valid(actor): actor.visible = true; actor.position = reveal_point
				if game.auto_turn and game.player.focus_allowed: game.player.begin_focus(reveal_point + Vector3(0, 1.55, 0))
				if breath_audio.stream != null: breath_audio.play()
		"reveal":
			if is_instance_valid(actor): actor.look_at(Vector3(game.player.position.x, 0, game.player.position.z), Vector3.UP, true)
			if clock >= 1.7:
				phase = "retreat"
				clock = 0
				game.player.cancel_focus()
				say("[录音 / 林岚] 它在躲开光。别追，继续恢复中继。", 8)
		"retreat":
			if is_instance_valid(actor):
				actor.position = reveal_point.lerp(hidden_point, smoothstep(0.0, 1.0, clock / 1.4))
				actor.look_at(hidden_point + Vector3(0, 0, 1), Vector3.UP, true)
				step_audio.position = actor.position
			if clock >= 1.4:
				phase = "done"
				if is_instance_valid(actor): actor.visible = false
				breath_audio.stop()

func _exit_tree() -> void:
	for sound in [step_audio, breath_audio]:
		if is_instance_valid(sound): sound.stop(); sound.stream = null
