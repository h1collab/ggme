extends Node3D

const LevelScript = preload("backrooms_level.gd")
const PlayerScript = preload("backrooms_player.gd")
const UiScript = preload("backrooms_ui.gd")
const NetworkScript = preload("backrooms_network.gd")
const StoryScript = preload("backrooms_story.gd")
const Assets = preload("backrooms_assets.gd")
const SHIFT_SECONDS := 180.0
var level: Node3D
var player: CharacterBody3D
var ui: Control
var net: Node
var environment: WorldEnvironment
var running := false
var stage := 0
var elapsed := 0.0
var power := 100.0
var signal_pressure := 0.0
var heat := 0.0
var repaired := [false, false, false]
var doors := [false, false]
var lights_on := true
var fan_on := false
var anomaly := -1
var next_anomaly := 18.0
var anomaly_since := 0.0
var reports := 0
var mistakes := 0
var generator_ready := 0.0
var revision := 0
var completed := false
var failed := false
var notice := "Restore three nodes. Observe cameras at the survey station."
var crew: Dictionary = {}
var ambience: AudioStreamPlayer
var footsteps: AudioStreamPlayer
var hum: AudioStreamPlayer
var state_timer := 0.0
var quality := 1
var sensitivity := 1.0
var auto_turn := true
var audio_volume := 0.8
var story: Node3D

func _ready() -> void:
	name = "Backrooms"
	if OS.has_feature("android"): DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.69, 0.66)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_density = 0.008
	env.fog_light_color = Color(0.38, 0.37, 0.30)
	environment.environment = env
	add_child(environment)
	_load_level(0)
	player = PlayerScript.new()
	player.game = self
	add_child(player)
	player.reset_to(level.spawn)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = UiScript.new()
	ui.game = self
	layer.add_child(ui)
	net = NetworkScript.new()
	net.game = self
	add_child(net)
	_audio()
	story = StoryScript.new()
	story.game = self
	add_child(story)
	story.reset_layer(stage)
	var config := ConfigFile.new()
	if config.load("user://night-relay.cfg") == OK:
		quality = int(config.get_value("display", "quality", 1))
		sensitivity = clampf(float(config.get_value("controls", "sensitivity", 1.0)), 0.5, 2.0)
		auto_turn = bool(config.get_value("controls", "auto_turn", true))
		audio_volume = clampf(float(config.get_value("audio", "volume", 0.8)), 0, 1)
	set_audio_volume(audio_volume)
	set_quality(quality)
	ui.intro()

func _audio() -> void:
	ambience = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/roomtone.wav"): ambience.stream = load("res://audio/roomtone.wav")
	if ResourceLoader.exists(Assets.path("vendor/hum.mp3")): ambience.stream = load(Assets.path("vendor/hum.mp3"))
	ambience.volume_db = -19
	add_child(ambience)
	if ambience.stream != null: ambience.play()
	footsteps = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/footstep.wav"): footsteps.stream = load("res://audio/footstep.wav")
	if ResourceLoader.exists(Assets.path("vendor/monster_step.ogg")): footsteps.stream = load(Assets.path("vendor/monster_step.ogg"))
	footsteps.volume_db = -17
	add_child(footsteps)
	hum = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/relay.wav"): hum.stream = load("res://audio/relay.wav")
	hum.volume_db = -17
	add_child(hum)

func footstep() -> void:
	footsteps.pitch_scale = randf_range(0.94, 1.06) * (1.0 if stage != 2 else 0.8)
	if footsteps.stream != null: footsteps.play()

func _load_level(index: int) -> void:
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	stage = clampi(index, 0, 2)
	level = LevelScript.new()
	add_child(level)
	level.build(stage)
	if is_instance_valid(player): player.reset_to(level.spawn)
	if is_instance_valid(ui): ui.retarget_camera()
	if is_instance_valid(story): story.reset_layer(stage)
	if is_instance_valid(ambience):
		ambience.stop()
		var ambient_file := Assets.path("vendor/water.mp3" if stage == 2 else "vendor/hum.mp3")
		if ResourceLoader.exists(ambient_file): ambience.stream = load(ambient_file)
	clear_crew()

func start_solo() -> void:
	net.leave()
	start_shift(0)
	ui.open_briefing()

func start_shift(index: int) -> void:
	_load_level(index)
	elapsed = 0
	power = 100
	signal_pressure = 0
	heat = 0
	repaired = [false, false, false]
	doors = [false, false]
	lights_on = true
	fan_on = false
	anomaly = -1
	next_anomaly = 18
	reports = 0
	mistakes = 0
	generator_ready = 0
	completed = false
	failed = false
	running = true
	notice = "先恢复节点，再回监控站排除故障；电梯会在 06:00 解锁。"
	revision += 1
	if is_instance_valid(net) and net.mode == "host":
		for id in net.members:
			net.poses[id] = {"p":level.spawn + Vector3(0.9 * (int(id) % 4), 0, 0), "y":0.0}
			net.pose_times[id] = Time.get_ticks_msec()
			if id != 1: net._welcome.rpc_id(id, snapshot(), net.poses[id].p)
		ui.close_panels()

func _process(delta: float) -> void:
	if not is_instance_valid(ui): return
	if running and net.authoritative() and not failed and not completed:
		if not (net.mode == "solo" and ui.modal and not ui.monitoring): _tick(delta)
	if running:
		level.update_state(doors, lights_on and power > 0, anomaly, repaired, elapsed, ui.monitor_camera.position if ui.monitoring else player.position, [0, 2, 3][quality])
		if ambience.stream != null and not ambience.playing: ambience.play()
		story.update(delta)
	for id in crew:
		var actor: Node3D = crew[id]
		var target: Vector3 = actor.get_meta("target", actor.position)
		var speed := actor.position.distance_to(target)
		actor.position = actor.position.lerp(target, minf(delta * 12, 1))
		actor.rotation.y = lerp_angle(actor.rotation.y, float(actor.get_meta("yaw", 0.0)), minf(delta * 10, 1))
		for animation_player in actor.find_children("*", "AnimationPlayer", true, false):
			animation_player.speed_scale = 1.0 if speed > 0.015 else 0.0
	ui.refresh()
	if running and (failed or completed):
		if not ui.result_shown: ui.open_result()

func _tick(delta: float) -> void:
	elapsed = minf(elapsed + delta, SHIFT_SECONDS)
	var monitors := 1 if ui.monitoring else 0
	for active in net.monitor_flags.values():
		if active: monitors += 1
	var draw: float = 0.13 + (0.045 if lights_on else 0) + monitors * 0.04 + (0.06 if fan_on else 0)
	for closed in doors:
		if closed: draw += 0.13
	power = clampf(power - draw * delta, 0, 100)
	heat = clampf(heat + ((monitors * 0.12 + (0.07 if lights_on else 0)) - (0.7 if fan_on else 0.08)) * delta, 0, 100)
	if elapsed >= next_anomaly and anomaly == -1 and reports < 3:
		anomaly = (reports + stage) % 3
		anomaly_since = elapsed
		notice = "监控出现闪烁故障：到调查站查看三个画面，报告闪烁的那一路。"
	if anomaly >= 0:
		var isolation := 0
		for closed in doors:
			if closed: isolation += 1
		signal_pressure = clampf(signal_pressure + (0.55 - 0.2 * isolation) * delta, 0, 100)
	else: signal_pressure = maxf(0, signal_pressure - 0.4 * delta)
	if heat > 70: power = maxf(0, power - 0.12 * delta)
	if power <= 0 or signal_pressure >= 100:
		failed = true
		notice = "备用电力耗尽。重启本层后，少关闸门，及时补充电力。" if power <= 0 else "信号过载。重启本层后，及时报告监控故障。"
	elif transfer_ready(): notice = "本层校准完成。前往中央走廊尽头的电梯。"

func transfer_ready() -> bool:
	return elapsed >= SHIFT_SECONDS and reports >= 3 and not repaired.has(false) and not failed

func prompt() -> String:
	if player.position.distance_to(level.console_position) < 2.9: return "E / 使用调查站"
	for i in range(3):
		if player.position.distance_to(level.relays[i]) < 2.4:
			return "节点 %02d / 已恢复" % (i + 1) if repaired[i] else "E / 恢复节点 %02d" % (i + 1)
	if player.position.distance_to(level.exit_position) < 2.8:
		return "E / 乘电梯" if transfer_ready() else "电梯锁定 / 完成校准并等到 06:00"
	return ""

func interact() -> void:
	if not running or failed or completed: return
	if player.position.distance_to(level.console_position) < 2.9:
		ui.open_monitor()
		return
	for i in range(3):
		if player.position.distance_to(level.relays[i]) < 2.4:
			net.request("repair", i)
			return
	if player.position.distance_to(level.exit_position) < 2.8: net.request("transfer")

func apply_action(action: String, index: int, pos: Vector3, monitoring: bool) -> void:
	if not net.authoritative() or not running or failed or completed: return
	var at_console := pos.distance_to(level.console_position) < 3.5
	match action:
		"repair":
			if index < 0 or index >= 3 or pos.distance_to(level.relays[index]) >= 2.5 or repaired[index]: return
			repaired[index] = true
			power = minf(100, power + 9)
			notice = "节点 %02d 已恢复，备用电力 +9%%。林岚的信号更清晰了。" % (index + 1)
			story.say(["[维修记录] 出口不是锁住了。它从墙上消失了。", "[林岚的便签] 一个人站在监控前，另一个人修理；不要同时离开调查站。", "[最后记录] 如果你听到我的声音，把这段记录带出去。别留在这里找我。"][index], 9)
		"door":
			if not at_console or not monitoring or index < 0 or index >= 2: return
			doors[index] = not doors[index]
		"lights":
			if not at_console or not monitoring: return
			lights_on = not lights_on
		"fan":
			if not at_console or not monitoring: return
			fan_on = not fan_on
		"report":
			if not at_console or not monitoring or index < 0 or index >= 3: return
			if anomaly == index:
				reports += 1
				anomaly = -1
				signal_pressure = maxf(0, signal_pressure - 18)
				next_anomaly = elapsed + 24
				notice = "故障排除，摄像头 %02d 恢复稳定。" % (index + 1)
			else:
				power = maxf(0, power - 6)
				mistakes += 1
				notice = "这一路没有故障。误报消耗了 6% 备用电力。"
		"generator":
			if not at_console or not monitoring or elapsed < generator_ready: return
			power = minf(100, power + 12)
			heat = minf(100, heat + 12)
			generator_ready = elapsed + 40
			notice = "备用电力 +12%，热量上升；发电机需冷却 40 秒。"
		"transfer":
			if not transfer_ready() or pos.distance_to(level.exit_position) >= 2.8: return
			if stage < 2:
				start_shift(stage + 1)
				if net.mode == "solo": ui.open_briefing()
			else:
				completed = true
				notice = "返回电梯启动。林岚的记录已传回地面。你离开了，但她的脚步仍在录音里。"
		_:
			return
	revision += 1
	if hum.stream != null: hum.play()

func snapshot() -> Dictionary:
	return {"stage":stage,"elapsed":elapsed,"power":power,"pressure":signal_pressure,"heat":heat,"repaired":repaired.duplicate(),"doors":doors.duplicate(),"lights":lights_on,"fan":fan_on,"anomaly":anomaly,"reports":reports,"generator":generator_ready,"failed":failed,"completed":completed,"notice":notice,"revision":revision,"running":running}

func receive_state(state: Dictionary) -> void:
	if net.authoritative(): return
	if int(state.get("revision", -1)) < revision: return
	var next_stage := int(state.get("stage", 0))
	var previous_repaired: Array = repaired.duplicate()
	var was_running := running
	if next_stage != stage:
		_load_level(next_stage)
		ui.close_panels()
	elapsed = float(state.elapsed)
	power = float(state.power)
	signal_pressure = float(state.pressure)
	heat = float(state.heat)
	repaired = state.repaired.duplicate()
	doors = state.doors.duplicate()
	lights_on = state.lights
	fan_on = state.fan
	anomaly = state.anomaly
	reports = state.reports
	generator_ready = state.generator
	failed = state.failed
	completed = state.completed
	notice = state.notice
	revision = state.revision
	running = state.running
	if running and not was_running: story.say("[无线电] 林岚失联了。先恢复节点，再回调查站；修好中继才能启动电梯。", 10)
	for i in range(3):
		if repaired[i] and not previous_repaired[i]: story.say("[维修记录] 林岚留下了记录：不要追逐那个躲在灯外的身影。", 8)

func update_crew(poses: Dictionary) -> void:
	var local_id := multiplayer.get_unique_id()
	for id in crew.keys():
		if not poses.has(id) or id == local_id: remove_crew(id)
	for id in poses:
		if id == local_id: continue
		if not crew.has(id):
			crew[id] = _crew_avatar(id)
			crew[id].position = poses[id].p
		crew[id].set_meta("target", poses[id].p)
		crew[id].set_meta("yaw", poses[id].y)

func _crew_avatar(id: int) -> Node3D:
	var avatar := Assets.fitted("vendor/crew.glb", 1.75)
	avatar.name = "Surveyor_%s" % id
	add_child(avatar)
	var label := Label3D.new()
	label.text = "CREW / %02d" % (crew.size() + 1)
	label.position.y = 1.95
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 0
	avatar.add_child(label)
	return avatar

func remove_crew(id: int) -> void:
	if crew.has(id):
		crew[id].queue_free()
		crew.erase(id)

func clear_crew() -> void:
	for id in crew.keys(): remove_crew(id)

func _exit_tree() -> void:
	for audio in [ambience, footsteps, hum]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null

func set_quality(value: int) -> void:
	quality = clampi(value, 0, 2)
	get_viewport().scaling_3d_scale = [0.6, 0.8, 1.0][quality]
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	player.torch.shadow_enabled = quality > 0
	save_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "quality", quality)
	config.set_value("controls", "sensitivity", sensitivity)
	config.set_value("controls", "auto_turn", auto_turn)
	config.set_value("audio", "volume", audio_volume)
	config.save("user://night-relay.cfg")

func set_audio_volume(value: float) -> void:
	audio_volume = clampf(value, 0, 1)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(audio_volume, 0.001)))
	AudioServer.set_bus_mute(0, audio_volume == 0)
	save_settings()

func next_objective() -> Dictionary:
	for i in range(3):
		if not repaired[i]: return {"text":"恢复节点 %02d" % (i + 1), "position":level.relays[i]}
	if reports < 3: return {"text":"回调查站报告故障 / %d/3" % reports, "position":level.console_position}
	if elapsed < SHIFT_SECONDS: return {"text":"维持供电至 06:00 / 剩余 %ds" % int(ceil(SHIFT_SECONDS - elapsed)), "position":level.console_position}
	return {"text":"到电梯带回林岚的记录", "position":level.exit_position}
