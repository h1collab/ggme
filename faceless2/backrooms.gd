extends Node3D

const LevelScript = preload("backrooms_level.gd")
const PlayerScript = preload("backrooms_player.gd")
const UiScript = preload("backrooms_ui.gd")
const NetworkScript = preload("backrooms_network.gd")
const StoryScript = preload("backrooms_story.gd")
const Assets = preload("backrooms_assets.gd")
const SHIFT_SECONDS := 0.0  # Exploration has no forced survival clock
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
var anomaly_until := 0.0
var anomaly_since := 0.0
var reports := 0
var mistakes := 0
var generator_ready := 0.0
var revision := 0
var completed := false
var failed := false
var notice := "寻找林岚留下的三段录音，跟随电梯信号离开。"
var crew: Dictionary = {}
var ambience: AudioStreamPlayer
var footsteps: AudioStreamPlayer
var hum: AudioStreamPlayer
var state_timer := 0.0
var quality := 1
var sensitivity := 1.0
var auto_turn := false
var audio_volume := 0.8
var frame_ema := 0.0167
var auto_scale_timer := 0.0
var story: Node3D

func _ready() -> void:
	name = "Faceless 2"
	if OS.has_feature("android"): DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.028, 0.035, 0.038)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.45, 0.43)
	env.ambient_light_energy = 0.17
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_density = 0.021
	env.fog_light_color = Color(0.13, 0.15, 0.15)
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
	if config.load("user://faceless2.cfg") == OK:
		quality = int(config.get_value("display", "quality", 1))
		sensitivity = clampf(float(config.get_value("controls", "sensitivity", 1.0)), 0.5, 2.0)
		auto_turn = bool(config.get_value("controls", "auto_turn", false))
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
		if ambience.stream != null: ambience.play()
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
	anomaly_until = 0
	reports = 0
	mistakes = 0
	generator_ready = 0
	completed = false
	failed = false
	running = true
	notice = "寻找三段录音。每次找到线索，电梯信号都会更清晰。"
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
		if not (net.mode == "solo" and ui.modal): _tick(delta)
	if OS.has_feature("android") and running:
		# Bound resolution changes and avoid rapid frame-to-frame quality pumping.
		frame_ema = lerpf(frame_ema, minf(delta, 0.1), 0.025)
		auto_scale_timer += delta
		if auto_scale_timer > 3.0:
			auto_scale_timer = 0
			var target := [0.58, 0.74, 0.91][quality]
			var lower := [0.52, 0.62, 0.73][quality]
			if frame_ema > 0.023 and get_viewport().scaling_3d_scale > lower:
				get_viewport().scaling_3d_scale = maxf(lower, get_viewport().scaling_3d_scale - 0.045)
			elif frame_ema < 0.017 and get_viewport().scaling_3d_scale < target:
				get_viewport().scaling_3d_scale = minf(target, get_viewport().scaling_3d_scale + 0.025)
	if running:
		level.update_state(doors, true, anomaly, repaired, elapsed, player.position, [0, 1, 2][quality])
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
	# Exploration is not a shift-management simulation. Time is ambient only.
	elapsed += delta
	if elapsed >= next_anomaly:
		# Sparse fluorescent flickers, not a camera-report mini-game.
		anomaly = randi_range(0, 2)
		anomaly_until = elapsed + randf_range(0.42, 0.9)
		next_anomaly = elapsed + randf_range(17.0, 29.0)
	if anomaly >= 0 and elapsed > anomaly_until:
		anomaly = -1

func transfer_ready() -> bool:
	return not repaired.has(false) and not failed

func prompt() -> String:
	for i in range(3):
		if player.position.distance_to(level.relays[i]) < 2.5:
			return "录音 %02d / 已记录" % (i + 1) if repaired[i] else "E / 拾取录音 %02d" % (i + 1)
	if player.position.distance_to(level.console_position) < 2.9: return "E / 收听调查终端"
	if player.position.distance_to(level.exit_position) < 2.8:
		return "E / 进入电梯" if transfer_ready() else "电梯无信号 / 仍有失联录音未找到"
	return ""

func interact() -> void:
	if not running or failed or completed: return
	for i in range(3):
		if player.position.distance_to(level.relays[i]) < 2.5:
			net.request("collect", i)
			return
	if player.position.distance_to(level.console_position) < 2.9:
		story.say("[调查终端] 这里没有摄像机控制功能。林岚的记录散落在走廊和侧室。", 8)
		return
	if player.position.distance_to(level.exit_position) < 2.8: net.request("transfer")

func apply_action(action: String, index: int, pos: Vector3, monitoring: bool) -> void:
	if not net.authoritative() or not running or failed or completed: return
	match action:
		"collect":
			if index < 0 or index >= 3 or pos.distance_to(level.relays[index]) >= 2.5 or repaired[index]: return
			repaired[index] = true
			notice = "录音 %02d 已保存 / %d of 3。" % [index + 1, repaired.count(true)]
			story.say(story.MEMORY_TEXT[stage][index], 9)
		"transfer":
			if not transfer_ready() or pos.distance_to(level.exit_position) >= 2.8: return
			if stage < 2:
				start_shift(stage + 1)
				if net.mode == "solo": ui.open_briefing()
			else:
				completed = true
				notice = "你带回了林岚的录音，电梯门打开。门外的走廊却没有脚步声。"
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
		ui.open_briefing()
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
	if running and not was_running: story.say("[无线电] 如果听见不属于你的脚步，别追。先找齐三段录音。", 10)
	for i in range(3):
		if repaired[i] and not previous_repaired[i]: story.say(story.MEMORY_TEXT[stage][i], 9)

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
	frame_ema = 0.0167
	auto_scale_timer = 0
	get_viewport().scaling_3d_scale = [0.58, 0.74, 0.91][quality] if OS.has_feature("android") else [0.68, 0.85, 1.0][quality]
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X][quality]
	player.torch.shadow_enabled = quality > 0 and not OS.has_feature("android")
	save_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "quality", quality)
	config.set_value("controls", "sensitivity", sensitivity)
	config.set_value("controls", "auto_turn", auto_turn)
	config.set_value("audio", "volume", audio_volume)
	config.save("user://faceless2.cfg")

func set_audio_volume(value: float) -> void:
	audio_volume = clampf(value, 0, 1)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(audio_volume, 0.001)))
	AudioServer.set_bus_mute(0, audio_volume == 0)
	save_settings()

func next_objective() -> Dictionary:
	for i in range(3):
		if not repaired[i]: return {"text":"寻找录音 %02d / %d of 3" % [i + 1, repaired.count(true)], "position":level.relays[i]}
	return {"text":"将林岚的录音带回电梯", "position":level.exit_position}
