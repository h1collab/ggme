extends Node3D

# Local-only sightings. This director never RPCs, moves a remote camera,
# blocks an exit, or changes the host's authoritative clue state.
# Investigation chapters, not a repair loop or a collection of identical tapes.
# Each piece changes the meaning of the next floor, and is shared by ENet.
const BRIEFINGS := [
	["序章 / 被拆除的入口", "你是 Zorix 异常建筑调查组的现场调查员。\n五年前，银杏街 17 号办公楼被宣布拆除；今晚 02:13，失联搭档林岚的求救却从原地址发来。\n检修门在你身后封死。地上的水还带着室外的雨味，但这里已经四十天没有下雨。", "先查清这栋楼为何仍在运行。调查文件、异常足迹与调度记录；不要追逐黑暗中的人影。"],
	["第一章 / 第三个人的脚步", "第一层证据证明：你们并不是第一次进入这里。\n地下机房的仪表记录了一支不存在的第三人小队。无人的水坑里出现了与你同步却方向相反的脚印。\n林岚留下了一条消息：‘如果有人穿着我的外套，就当作没看见。’", "核对管线图、确认机房呼吸声源、找到井道终端上的队员档案。然后决定是否继续下降。"],
	["终章 / 水记得你的名字", "电梯门里有一道从内侧留下的抓痕。水面映出的是你刚才站过的位置，而不是现在的你。\n林岚还活着吗？最后一层保存着她的求救记录，也保存着你自己的上一轮出勤档案。\n取回真相后，可以把证据送到地面，或封存这里，结束信号。", "查验水下工牌、读取最后的巡检日志、找到终端中的原始记录。最后在电梯选择如何处理真相。"]]
const EVIDENCE_TITLES := [
	["01 / 拆除令的原件", "02 / 逆行的湿脚印", "03 / 凌晨调度单"],
	["01 / 不存在的管线", "02 / 机房呼吸测试", "03 / 第三名队员档案"],
	["01 / 浸水的工牌", "02 / 井道巡检日志", "03 / 最后一次呼叫"]]
const EVIDENCE_WHY := [
	["纸张日期比建筑消失晚五年：有人仍在维护它。", "脚印朝墙里走去，却没有返回；它正在模仿行动。", "调度单上有你上次来这里的签字，但你完全不记得。"],
	["下方根本不该有楼层；水从上层顺着不存在的管道渗入。", "机械噪声停下时仍有呼吸声，是有人在机房里等待。", "录像显示三个人走进电梯，你们的名单上只有两个人。"],
	["工牌上的照片是林岚，签发日期却写着明天。", "你在记录里听见自己的声音，提醒过去的自己别靠近电梯。", "最后一次呼叫不是求救。有人正利用信号引你把它带出去。"]]
const MEMORY_TEXT := [
	["[纸质档案] 建筑物于五年前拆除，但这份消防验收日期写着昨天。签名栏只有一个字：‘返’。", "[现场勘察] 雨水倒流进墙，第二串脚印竟与你的鞋底花纹相同；它的方向却朝向你。", "[调度单] 外勤姓名栏出现了两次你的名字。第一行旁写着：‘已返回’，第二行写着：‘再次进入’。"],
	["[管网记录] 供水阀编号指向一个在城市图纸上不存在的楼层。锈水里混着新鲜泥沙。", "[机房录音] 电机已经停机，但第三个麦克风里仍有呼吸声。它只在你停止呼吸时响起。", "[队员档案] 监控里走入电梯的第三个人穿着你的制服，但胸牌写着林岚的名字。"],
	["[工牌] 林岚的工牌仍然潮湿。签发日期是明天，背面写着：‘别相信你看到的我。’", "[巡检日志] 第七次出勤的声音属于你：‘如果你听到这个消息，就证明我又失败了。’", "[原始信号] 林岚没有发出求救。她一直在警告地面不要打开门，而你收到的声音来自门的另一侧。"]]
const INTERLUDES := [
	"[楼内广播] 应急出口的位置刚刚改变。它知道你正在寻找调度单。别相信第二次出现的指示牌。",
	"[林岚 / 断续的无线电] 我看到你了……可你明明还在上一层。千万别回答另一个你的呼叫。",
	"[楼层系统] 上传通道已经连接。警告：文件中包含尚未发生的事件。谁才是调查对象？"]
const ENDINGS := [
	"你将所有证据送到地面。凌晨的新闻确认失踪者获救，却没有人记得她的名字。手机响起，是你自己的声音：‘下一次别开门。’",
	"你关闭了信号中继。电梯最终抵达空荡的工地，雨水停了，走廊却不再存在。林岚的声音留在地下：‘谢谢你没让它出来。’"]

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

func say(text: String, seconds: float = 7.0, voice_key: String = "") -> void:
	subtitle = text
	subtitle_seconds = seconds
	if not voice_key.is_empty(): play_voice(voice_key)

func on_discovery(chapter: int, index: int, total: int) -> void:
	# Local narration only; the host already validated the interact distance.
	say(MEMORY_TEXT[chapter][index], 12.5, "tape_%d_%d" % [chapter, index])
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
	if is_instance_valid(voice_audio):
		voice_audio.stop()
		voice_audio.stream = null
	for sound in [step_audio, breath_audio]:
		if is_instance_valid(sound):
			sound.stop()
			sound.stream = null
