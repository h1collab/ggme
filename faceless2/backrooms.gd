extends Node3D

const LevelScript = preload("backrooms_level.gd")
const PlayerScript = preload("backrooms_player.gd")
const UiScript = preload("backrooms_ui.gd")
const NetworkScript = preload("backrooms_network.gd")
const StoryScript = preload("backrooms_story.gd")
const RoomsScript = preload("backrooms_rooms.gd")
const Assets = preload("backrooms_assets.gd")
const SHIFT_SECONDS := 0.0  # Exploration has no forced survival clock
var level: Node3D
var player: CharacterBody3D
var ui: Control
var net: Node
var rooms: Node
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
var ending_variant := 0  # 0 send evidence; 1 seal the liminal signal
var failed := false
var notice := "寻找林岚留下的三段录音，跟随电梯信号离开。"
var crew: Dictionary = {}
var remote_water_steps: Dictionary = {}
var ambience: AudioStreamPlayer
var footsteps: AudioStreamPlayer
var hum: AudioStreamPlayer
var state_timer := 0.0
var quality := 1
var sensitivity := 1.0
var auto_turn := false
var audio_volume := 0.8
var voice_enabled := true
var shock_glance_enabled := true
var inventory := {"almond_water":0,"lift_keys":0}
var water_picked := false
var key_picked := false
var assembled := false
var splash_audio: AudioStreamPlayer3D
var lift_door_audio: AudioStreamPlayer3D
var lift_motor_audio: AudioStreamPlayer3D
var flooded_ambience: AudioStreamPlayer3D
const LIFT_RIDE_DURATION := 6.2
var lift_active := false
var lift_elapsed := 0.0
var lift_epoch := 0
var lift_motor_started := false
var lift_close_started := false
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
	rooms = RoomsScript.new()
	rooms.game = self
	add_child(rooms)
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
		voice_enabled = bool(config.get_value("audio", "generated_voice", true))
		shock_glance_enabled = bool(config.get_value("controls", "scripted_glance", true))
		rooms.configure(String(config.get_value("network", "directory_url", "")))
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
	splash_audio = _spatial_foley("splash.wav", -13)
	lift_door_audio = _spatial_foley("elevator_door.wav", -9)
	lift_motor_audio = _spatial_foley("elevator_move.wav", -15)
	lift_door_audio.position = Vector3(0, 1.2, -28.5)
	lift_motor_audio.position = Vector3(0, 1.3, -28.5)
	flooded_ambience = _spatial_foley("water.mp3", -22.0)
	if flooded_ambience.stream == null and ResourceLoader.exists(Assets.path("vendor/water.mp3")):
		flooded_ambience.stream = load(Assets.path("vendor/water.mp3"))
	flooded_ambience.position = Vector3(0, 0.1, -13)
	flooded_ambience.max_distance = 33.0

func _spatial_foley(filename: String, volume: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	var audio_path := "res://audio/" + filename
	if not ResourceLoader.exists(audio_path): audio_path = "res://faceless2/audio/" + filename
	if ResourceLoader.exists(audio_path): sound.stream = load(audio_path)
	sound.volume_db = volume
	sound.unit_size = 2.0
	sound.max_distance = 18
	add_child(sound)
	return sound

func water_footstep() -> void:
	if is_instance_valid(splash_audio) and splash_audio.stream != null:
		splash_audio.position = player.position + Vector3(0, 0.08, 0)
		splash_audio.pitch_scale = randf_range(0.88, 1.13)
		splash_audio.play()

func footstep() -> void:
	footsteps.pitch_scale = randf_range(0.94, 1.06) * (1.0 if stage != 2 else 0.8)
	if footsteps.stream != null: footsteps.play()

func _load_level(index: int) -> void:
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	stage = clampi(index, 0, 3)
	lift_active = false
	lift_elapsed = 0.0
	lift_close_started = false
	lift_motor_started = false
	if is_instance_valid(player): player.end_lift_ride()
	level = LevelScript.new()
	add_child(level)
	level.build(stage)
	remote_water_steps.clear()
	water_picked = false
	key_picked = false
	assembled = false
	if is_instance_valid(player): player.reset_to(level.spawn)
	if is_instance_valid(story): story.reset_layer(stage)
	if is_instance_valid(ambience):
		ambience.stop()
		var ambient_file := Assets.path("vendor/water.mp3" if stage == 2 else "vendor/hum.mp3")
		if ResourceLoader.exists(ambient_file): ambience.stream = load(ambient_file)
		if ambience.stream != null: ambience.play()
	if is_instance_valid(flooded_ambience):
		flooded_ambience.stop()
		if flooded_ambience.stream != null: flooded_ambience.play()
	clear_crew()

func start_solo() -> void:
	net.leave()
	inventory = {"almond_water":0,"lift_keys":0}
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
	ending_variant = 0
	failed = false
	running = true
	notice = "从现场调查开始 / 每一项证据都会改变真相。按 JOURNAL 回看线索。"
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
			var target: float = [0.58, 0.74, 0.91][quality]
			var lower: float = [0.52, 0.62, 0.73][quality]
			if frame_ema > 0.023 and get_viewport().scaling_3d_scale > lower:
				get_viewport().scaling_3d_scale = maxf(lower, get_viewport().scaling_3d_scale - 0.045)
			elif frame_ema < 0.017 and get_viewport().scaling_3d_scale < target:
				get_viewport().scaling_3d_scale = minf(target, get_viewport().scaling_3d_scale + 0.025)
	if running:
		level.update_state(doors, true, anomaly, repaired, elapsed, player.position, [0, 1, 2][quality])
		if ambience.stream != null and not ambience.playing: ambience.play()
		if is_instance_valid(flooded_ambience) and flooded_ambience.stream != null and not flooded_ambience.playing:
			flooded_ambience.play()
		story.update(delta)
		level.update_water(delta)
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
	if lift_active:
		lift_elapsed = minf(lift_elapsed + delta, LIFT_RIDE_DURATION)
		level.animate_lift(lift_elapsed)
		if not lift_close_started and lift_elapsed >= 2.15:
			lift_close_started = true
			if lift_door_audio.stream != null: lift_door_audio.play()
		if not lift_motor_started and lift_elapsed >= 3.3:
			lift_motor_started = true
			if lift_motor_audio.stream != null: lift_motor_audio.play()
		if lift_elapsed >= LIFT_RIDE_DURATION:
			lift_active = false
			if is_instance_valid(player): player.end_lift_ride()
			if stage < 3:
				start_shift(stage + 1)
				if net.mode == "solo": ui.open_briefing()
			else:
				completed = true
				notice = story.ENDINGS[ending_variant]
				story.say("[终章] " + notice, 15.0, "ending_seal" if ending_variant == 1 else "ending")
				revision += 1
		return
	if elapsed >= next_anomaly:
		# Sparse fluorescent flickers, not a camera-report mini-game.
		anomaly = randi_range(0, 2)
		anomaly_until = elapsed + randf_range(0.42, 0.9)
		next_anomaly = elapsed + randf_range(17.0, 29.0)
	if anomaly >= 0 and elapsed > anomaly_until:
		anomaly = -1

func transfer_ready() -> bool:
	return assembled and not repaired.has(false) and key_picked and not failed

func prompt() -> String:
	if not water_picked and player.position.distance_to(level.water_position) < 2.0: return "E / 拾取杏仁水"
	if not key_picked and player.position.distance_to(level.key_position) < 2.0: return "E / 拾取电梯钥匙组件"
	if not assembled and not repaired.has(false) and key_picked and player.position.distance_to(level.console_position) < 2.9: return "E / 拼接钥匙与信号图"
	for i in range(3):
		if player.position.distance_to(level.relays[i]) < 2.5:
			return "证据已记录 / 查看日志" if repaired[i] else "E / 调查 " + story.EVIDENCE_TITLES[stage][i]
	if player.position.distance_to(level.console_position) < 2.9: return "E / 打开调查日志"
	if player.position.distance_to(level.exit_position) < 2.8:
		return "电梯正在下降" if lift_active else ("E / 决定真相的去向" if stage == 3 and transfer_ready() else ("E / 进入电梯" if transfer_ready() else "电梯封锁 / 尚有证据未查清"))
	return ""

func interact() -> void:
	if not running or failed or completed or lift_active: return
	if not water_picked and player.position.distance_to(level.water_position) < 2.0:
		net.request("pickup", 0)
		return
	if not key_picked and player.position.distance_to(level.key_position) < 2.0:
		net.request("pickup", 1)
		return
	for i in range(3):
		if player.position.distance_to(level.relays[i]) < 2.5:
			if repaired[i]: ui.open_journal()
			else: net.request("collect", i)
			return
	if player.position.distance_to(level.console_position) < 2.9:
		if not assembled and not repaired.has(false) and key_picked:
			net.request("assemble", 0)
		else: ui.open_journal()
		return
	if player.position.distance_to(level.exit_position) < 2.8:
		if stage == 3 and transfer_ready(): ui.open_final_choice()
		else: net.request("transfer", 0)

func apply_action(action: String, index: int, pos: Vector3, monitoring: bool) -> void:
	if not net.authoritative() or not running or failed or completed: return
	match action:
		"pickup":
			if index == 0 and not water_picked and pos.distance_to(level.water_position) < 2.0:
				water_picked = true
				inventory["almond_water"] = int(inventory.get("almond_water",0)) + 1
				level.hide_pickup(0)
				notice = "发现杏仁水 / 救生物资已加入全队背包"
				story.say("[未知低语] 别喝空瓶子。它会先学你的口渴。", 6.0, "warning")
			elif index == 1 and not key_picked and pos.distance_to(level.key_position) < 2.0:
				key_picked = true
				inventory["lift_keys"] = int(inventory.get("lift_keys",0)) + 1
				level.hide_pickup(1)
				notice = "找到钥匙组件 / 去调查其余证据，回到调查台拼接"
				story.say("[门禁音] 一块在地板下找到的电梯钥匙。", 6.0)
			else: return
		"assemble":
			if assembled or repaired.has(false) or not key_picked or pos.distance_to(level.console_position) >= 2.9: return
			assembled = true
			notice = "钥匙与线索已拼合 / 黑暗深处的电梯已通电"
			anomaly = 1
			anomaly_until = elapsed + 2.5
			story.say("[电梯] 未登记的钥匙已接受。有人已经在轿厢里。", 8.0, "elevator")
		"drink":
			if int(inventory.get("almond_water",0)) <= 0: return
			inventory["almond_water"] = int(inventory.get("almond_water",0)) - 1
			signal_pressure = maxf(0.0, signal_pressure - 35.0)
			notice = "喝下杏仁水 / 心跳逐渐平静，周围的水仍在倒流"
		"collect":
			if index < 0 or index >= 3 or pos.distance_to(level.relays[index]) >= 2.5 or repaired[index]: return
			repaired[index] = true
			notice = "新证据 / " + story.EVIDENCE_TITLES[stage][index] + "，调查进度 %d/3。" % repaired.count(true)
			story.on_discovery(stage, index, repaired.count(true))
			anomaly = (index + stage) % 3
			anomaly_until = elapsed + 1.3
		"transfer":
			if not transfer_ready() or lift_active or pos.distance_to(level.exit_position) >= 2.8: return
			if stage == 3 and index not in [0, 1]: return
			ending_variant = index if stage == 3 else 0
			lift_active = true
			lift_elapsed = 0.0
			lift_epoch += 1
			lift_close_started = false
			lift_motor_started = false
			notice = "电梯已启动 / 开门，进舱，关门，然后下降。"
			level.animate_lift(0)
			if player.position.distance_to(level.exit_position) < 3.0 and not ui.modal: player.begin_lift_ride()
			if lift_door_audio.stream != null: lift_door_audio.play()
			story.say("[电梯广播] 信号已经恢复。请进入轿厢。", 5.0, "elevator")
		_:
			return
	revision += 1
	if hum.stream != null: hum.play()

func snapshot() -> Dictionary:
	return {"stage":stage,"elapsed":elapsed,"power":power,"pressure":signal_pressure,"heat":heat,"repaired":repaired.duplicate(),"doors":doors.duplicate(),"lights":lights_on,"fan":fan_on,"anomaly":anomaly,"reports":reports,"generator":generator_ready,"failed":failed,"completed":completed,"notice":notice,"revision":revision,"running":running,"lift_active":lift_active,"lift_elapsed":lift_elapsed,"lift_epoch":lift_epoch,"ending_variant":ending_variant,"inventory":inventory.duplicate(),"water_picked":water_picked,"key_picked":key_picked,"assembled":assembled}

func receive_state(state: Dictionary) -> void:
	if net.authoritative(): return
	if int(state.get("revision", -1)) < revision: return
	var next_stage := int(state.get("stage", 0))
	var previous_repaired: Array = repaired.duplicate()
	var previous_water := water_picked
	var previous_key := key_picked
	var was_running := running
	var old_lift_epoch := lift_epoch
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
	ending_variant = int(state.get("ending_variant", 0))
	inventory = state.get("inventory", {"almond_water":0,"lift_keys":0}).duplicate()
	water_picked = bool(state.get("water_picked", false))
	key_picked = bool(state.get("key_picked", false))
	assembled = bool(state.get("assembled", false))
	if water_picked: level.hide_pickup(0)
	else: level.show_pickup(0)
	if key_picked: level.hide_pickup(1)
	else: level.show_pickup(1)
	lift_epoch = int(state.get("lift_epoch", 0))
	lift_active = bool(state.get("lift_active", false))
	lift_elapsed = float(state.get("lift_elapsed", 0.0))
	level.animate_lift(lift_elapsed if lift_active else 0.0)
	if lift_active:
		if lift_epoch != old_lift_epoch:
			lift_close_started = false
			lift_motor_started = false
			if is_instance_valid(lift_door_audio) and lift_door_audio.stream != null: lift_door_audio.play()
			story.play_voice("elevator")
			if player.position.distance_to(level.exit_position) < 3.1 and not ui.modal:
				player.begin_lift_ride()
		if not lift_close_started and lift_elapsed >= 2.15:
			lift_close_started = true
			if is_instance_valid(lift_door_audio) and lift_door_audio.stream != null: lift_door_audio.play()
		if not lift_motor_started and lift_elapsed >= 3.3:
			lift_motor_started = true
			if is_instance_valid(lift_motor_audio) and lift_motor_audio.stream != null: lift_motor_audio.play()
	elif player.lift_riding:
		player.end_lift_ride()
	if water_picked and not previous_water: story.say("[无线电] 全队找到一瓶杏仁水。不要喝到瓶底。", 6.0, "warning")
	if key_picked and not previous_key: story.say("[门禁] 取得一段电梯钥匙组件。回到调查台拼合。", 6.0)
	if running and not was_running: story.say("[耳机里传来自己呼吸声] ……先看看黑暗中是谁站着。", 6.5)
	for i in range(3):
		if repaired[i] and not previous_repaired[i]: story.on_discovery(stage, i, repaired.count(true))

func update_crew(poses: Dictionary) -> void:
	var local_id := multiplayer.get_unique_id()
	for id in crew.keys():
		if not poses.has(id) or id == local_id: remove_crew(id)
	for id in poses:
		if id == local_id: continue
		# Reconstruct remote footsteps from validated ENet position updates;
		# never mirror their camera or call another peer's controls.
		var step_position: Vector3 = poses[id].p
		if remote_water_steps.has(id):
			if step_position.distance_to(remote_water_steps[id]) > 0.95:
				level.add_water_step(step_position)
				remote_water_steps[id] = step_position
		else:
			remote_water_steps[id] = step_position
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
	remote_water_steps.erase(id)

func clear_crew() -> void:
	for id in crew.keys(): remove_crew(id)

func _exit_tree() -> void:
	for audio in [ambience, footsteps, hum, splash_audio, lift_door_audio, lift_motor_audio, flooded_ambience]:
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
	config.set_value("audio", "generated_voice", voice_enabled)
	config.set_value("controls", "scripted_glance", shock_glance_enabled)
	config.set_value("network", "directory_url", rooms.directory_url if is_instance_valid(rooms) else "")
	config.save("user://faceless2.cfg")

func set_audio_volume(value: float) -> void:
	audio_volume = clampf(value, 0, 1)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(audio_volume, 0.001)))
	AudioServer.set_bus_mute(0, audio_volume == 0)
	save_settings()

func next_objective() -> Dictionary:
	if not water_picked: return {"text":"拾起杏仁水 / 先准备在异常空间中生存", "position":level.water_position}
	if not key_picked: return {"text":"寻找电梯钥匙 / 金属碰撞声在附近", "position":level.key_position}
	for i in range(3):
		if not repaired[i]: return {"text":story.EVIDENCE_TITLES[stage][i] + " / " + story.EVIDENCE_WHY[stage][i], "position":level.relays[i]}
	if not assembled: return {"text":"返回调查台 / 把钥匙与三份现场证据拼合", "position":level.console_position}
	return {"text":"进入电梯 / 选择真相的去向" if stage == 3 else "电梯已解锁 / 前往下一层", "position":level.exit_position}
