extends Node3D

# Local-only sightings. This director never RPCs, moves a remote camera,
# blocks an exit, or changes the host's authoritative clue state.
# Investigation chapters, not a repair loop or a collection of identical tapes.
# Each piece changes the meaning of the next floor, and is shared by ENet.
const BRIEFINGS := [
 ["序章 / 不要回头", "你在拆除工地接到一通求救。电话里是林岚，可她就在你身后说：‘我没打电话。’下一秒，电梯门将你们分开。你跌进一层没有出口的黄色长廊。灯会在你移动时熄灭。", "先拾起地上的杏仁水，找电梯钥匙。检查三处现场，将钥匙与线索在调查台拼合。不要回答自己的声音。"],
 ["第一章 / 门后的第三个人", "电梯下降了，却停在一条重复的宿舍走廊。每次关门，房间数就多一个。队伍里有人听见自己从隔壁喊救命。电梯需要一枚新的钥匙碎片。", "找到有绿光的补给，拾取钥匙组件，调查墙后的三处异常。将线索拼合后乘电梯离开。"],
 ["第二章 / 水面先动了", "泳池没有排水口。水里映出的是两秒之后的你。当所有人都停步时，水底却还有一串脚印。林岚说，怪物在等你模仿它。", "收集杏仁水与钥匙；追踪水中异样的三个位置。不要只相信眼前的反射。"],
 ["终章 / 零号井", "这不是失联者发来的求救，是建筑在练习人的声音。你曾经来到这里多次，并带出过它的碎片。现在它希望你亲手打开地面那扇门。", "拿到最后的钥匙，组合四层证据。不要相信房门外与你一模一样的声音。最终决定：带走它，还是永远封闭零号井。"]]
const EVIDENCE_TITLES := [
 ["01 / 无人来电", "02 / 从墙里伸出的脚印", "03 / 昨天的自己"],
 ["01 / 房间里有人", "02 / 会呼吸的机房", "03 / 多出来的工牌"],
 ["01 / 两秒后的倒影", "02 / 水下的求救", "03 / 不存在的第四人"],
 ["01 / 失败的撤离", "02 / 林岚的真正警告", "03 / 你的最后一份名单"]]
const EVIDENCE_WHY := [
 ["房间的电话已经拔线，却在跟着你呼吸。", "脚印到墙前戛然而止，但墙后还在响。", "监控不是过去：画面里的人刚刚转过头。"],
 ["门后的脚步会重复你的移动。", "停机以后，管道里有人敲出你的名字。", "所有记录都坚持有一个不存在的同伴。"],
 ["倒影比你先动，你可以试着停下。", "呼救声来自水下，但泳池没有深水区。", "第四个人没有脸，却用你的声音点名。"],
 ["钥匙上刻着你的上一次离开日期。", "林岚从没有要求你救她，她在阻止开门。", "名单上最后一个人将决定怪物能否出去。"]]
const MEMORY_TEXT := [
 ["断线电话连续响了七次。最后一次从听筒里传来自己的喘息。", "湿脚印沿墙往上爬，墙体背面响起敲门声。", "小票写着：撤离失败，重试。签名是你，日期是明天。"],
 ["门缝下面伸出一只与你同尺寸的鞋。灯一亮，它不见了。", "你屏住呼吸时，管道另一端仍有一个声音在替你呼吸。", "这枚工牌的照片空白，姓名栏却和你一模一样。"],
 ["水面中的你比真正的你早两秒低头。它在提前看你后面的东西。", "水下传来熟悉的声音：‘我没有失踪，是你把门打开了。’", "第四双湿脚印走入电梯。监控里只有三个人。"],
 ["上一轮调查留下的钥匙上刻着：不要带着它回家。", "林岚留下的原始记录：‘不是我在呼救。千万不要把你的声音借给它。’", "名单最后是‘返程者’，照片是你，下面却写着‘仍在地下’。"]]
const INTERLUDES := [
 "[电话在空房间里响了] 你刚才走过的门，此刻从里面锁上了。",
 "[房内传来你的声音] 救我……别开门。",
 "[广播] 下一班乘客请不要观察水中第二个人。",
 "[林岚] 现在你知道了：真正想离开的不是我们。"]
const ENDINGS := [
 "电梯抵达地面。灯光和雨水都恢复正常。你的手机收到新消息：‘我已经在你家门口了。’门铃响起，铃声与你的心跳完全同步。",
 "你按下封存键。电梯停止，黑暗中的脸第一次失去了笑容。广播播放林岚最后的录音：‘谢谢。别再找到我。’地面的夜终于安静。"]

var game: Node
var actor: Node3D
var animation: AnimationPlayer
var face_glimmer: OmniLight3D
var voice_audio: AudioStreamPlayer
var last_voice_key := ""
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
var intro_clock := 0.0
var intro_done := false

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
	voice_audio = AudioStreamPlayer.new()
	voice_audio.name = "KokoroGeneratedNarration"
	voice_audio.volume_db = -8.5
	add_child(voice_audio)
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
	var z := -18.1 if index == 1 else (-22.0 if index == 3 else -7.3)
	var side := 1.0 if index == 1 else -1.0
	trigger = Vector3(0, 0, z)
	reveal_point = Vector3(side * 5.2, 0, z - 0.2)
	hidden_point = Vector3(side * 5.2, 0, z + 3.0)
	peek_fraction = [0.83, 1.0, 0.88, 0.75][index]
	duration = [1.5, 2.0, 1.2, 1.0][index]
	subtitle = ""
	subtitle_seconds = 0
	intro_clock = 0
	intro_done = false
	if is_instance_valid(actor):
		actor.visible = false
		actor.position = hidden_point
	if is_instance_valid(animation): animation.speed_scale = 0
	step_audio.stop()
	breath_audio.stop()

func say(text: String, seconds: float = 7.0, voice_key: String = "") -> void:
	subtitle = text
	subtitle_seconds = seconds
	if not voice_key.is_empty(): play_voice(voice_key)

func on_discovery(chapter: int, index: int, total: int) -> void:
	# Local narration only; the host already validated the interact distance.
	say(MEMORY_TEXT[chapter][index], 12.5, "tape_%d_%d" % [chapter, index])
	# Something concrete reacts to a discovery: spatial footsteps behind the
	# player and sudden dimming, not just a wall of narrative subtitles.
	if is_instance_valid(step_audio) and step_audio.stream != null:
		step_audio.position = game.player.position + Vector3(0, 0, 2.5)
		step_audio.play()
	game.anomaly = index % 3
	game.anomaly_until = game.elapsed + 1.3
	if total == 2:
		# The chapter reveal is always reachable in the evidence journal even
		# if a concurrent recording temporarily replaces the subtitle.
		game.notice = "两项证据已确认 / 新线索已写入调查日志。"
		call_deferred("_chapter_turn", chapter)

func _chapter_turn(chapter: int) -> void:
	if not is_instance_valid(game) or game.stage != chapter: return
	say(INTERLUDES[chapter], 10.0, "turn_%d" % chapter)

func play_voice(key: String) -> bool:
	# Only pre-generated OGGs; no Android/system TTS, HTTP or runtime ML.
	last_voice_key = key
	if not game.voice_enabled or not is_instance_valid(voice_audio): return false
	var res := "res://audio/voice/" + key + ".ogg"
	if not ResourceLoader.exists(res):
		res = "res://faceless2/audio/voice/" + key + ".ogg"
	if not ResourceLoader.exists(res): return false
	voice_audio.stop()
	voice_audio.stream = load(res)
	voice_audio.play()
	return true

func _start_sighting(again: bool = false) -> void:
	phase = "approach"
	clock = 0
	step_clock = 0
	revealed = false
	if not again:
		seen = true
		say("[无线电] 别看脚步的方向……先听。", 5.0, "warning")
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
	# The opening is a PRESENT event, not a paragraph: the lights fail, a face
	# stands ahead in the hall, a breath comes from beside the player, and a
	# 0.65s local-only shock glance can be interrupted by any manual look.
	if game.stage == 0 and not intro_done and phase == "idle" and not seen:
		intro_clock += delta
		if intro_clock > 2.35 and is_instance_valid(actor):
			intro_done = true
			phase = "flash"
			clock = 0.0
			actor.position = Vector3(-1.1, 0, 4.25)
			actor.visible = true
			_set_walk_speed(0.0)
			game.anomaly = 0
			game.anomaly_until = game.elapsed + 1.1
			if game.shock_glance_enabled:
				game.player.begin_focus(actor.global_position + Vector3(0, 1.6, 0), 0.65)
			if breath_audio.stream != null:
				breath_audio.position = actor.position + Vector3(0, 1.5, 0)
				breath_audio.play()
			say("[身后有人贴耳低语] 别……回……头。", 3.5, "opening")
	if subtitle_seconds <= 0: subtitle = ""
	cooldown += delta
	if not seen and game.player.position.distance_to(trigger) < 2.15:
		_start_sighting()
	elif seen and not secondary_seen and phase == "done" and cooldown > 48.0 and game.player.position.distance_to(trigger + Vector3(0, 0, -11)) < 2.0:
		_start_sighting(true)
	if phase == "idle" or phase == "done": return
	clock += delta
	if phase == "flash":
		if clock >= 0.85:
			phase = "idle"
			if is_instance_valid(actor): actor.visible = false
			breath_audio.stop()
		return
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
	if is_instance_valid(voice_audio):
		voice_audio.stop()
		voice_audio.stream = null
	for sound in [step_audio, breath_audio]:
		if is_instance_valid(sound):
			sound.stop()
			sound.stream = null
