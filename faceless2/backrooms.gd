extends Node3D

const LevelScript = preload("backrooms_level.gd")
const PlayerScript = preload("backrooms_player.gd")
const UiScript = preload("backrooms_ui.gd")
const NetworkScript = preload("backrooms_network.gd")
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

func _ready() -> void:
	name = "Backrooms"
	if OS.has_feature("android"): DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.69, 0.66)
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
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
	var config := ConfigFile.new()
	if config.load("user://night-relay.cfg") == OK:
		quality = int(config.get_value("display", "quality", 1))
		sensitivity = clampf(float(config.get_value("controls", "sensitivity", 1.0)), 0.5, 2.0)
	set_quality(quality)
	ui.intro()

func _audio() -> void:
	ambience = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/roomtone.wav"): ambience.stream = load("res://audio/roomtone.wav")
	ambience.volume_db = -19
	add_child(ambience)
	if ambience.stream != null: ambience.play()
	footsteps = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/footstep.wav"): footsteps.stream = load("res://audio/footstep.wav")
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
	clear_crew()

func start_solo() -> void:
	net.leave()
	start_shift(0)
	ui.close_panels()

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
	notice = "Repair NODE 01–03, report 3 camera faults, then reach 06:00."
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
	for id in crew:
		var actor: Node3D = crew[id]
		var target: Vector3 = actor.get_meta("target", actor.position)
		var speed := actor.position.distance_to(target)
		actor.position = actor.position.lerp(target, minf(delta * 12, 1))
		actor.rotation.y = lerp_angle(actor.rotation.y, float(actor.get_meta("yaw", 0.0)), minf(delta * 10, 1))
		actor.get_node("Body").position.y = 0.91 + sin(Time.get_ticks_msec() * 0.009) * minf(speed, 0.03)
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
		notice = "Fluorescent circuit fault. Observe the three feeds and report the flicker."
	if anomaly >= 0:
		var isolation := 0
		for closed in doors:
			if closed: isolation += 1
		signal_pressure = clampf(signal_pressure + (0.55 - 0.2 * isolation) * delta, 0, 100)
	else: signal_pressure = maxf(0, signal_pressure - 0.4 * delta)
	if heat > 70: power = maxf(0, power - 0.12 * delta)
	if power <= 0 or signal_pressure >= 100:
		failed = true
		notice = "Power exhausted." if power <= 0 else "Signal saturation. The survey must be restarted."
	elif transfer_ready(): notice = "Shift complete. Reach TRANSFER at the far end of the central hall."

func transfer_ready() -> bool:
	return elapsed >= SHIFT_SECONDS and reports >= 3 and not repaired.has(false) and not failed

func prompt() -> String:
	if player.position.distance_to(level.console_position) < 2.9: return "E / USE SURVEY STATION"
	for i in range(3):
		if player.position.distance_to(level.relays[i]) < 2.4:
			return "NODE %02d / ONLINE" % (i + 1) if repaired[i] else "E / CALIBRATE NODE %02d" % (i + 1)
	if player.position.distance_to(level.exit_position) < 2.8:
		return "E / TRANSFER" if transfer_ready() else "TRANSFER LOCKED / FINISH THE SHIFT"
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
			notice = "NODE %02d calibrated. Reserve charge recovered." % (index + 1)
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
				notice = "Fault isolated. Camera %02d circuit stable." % (index + 1)
			else:
				power = maxf(0, power - 6)
				mistakes += 1
				notice = "No fault on this circuit. False reports cost 6% reserve."
		"generator":
			if not at_console or not monitoring or elapsed < generator_ready: return
			power = minf(100, power + 12)
			heat = minf(100, heat + 12)
			generator_ready = elapsed + 40
			notice = "Backup charge +12%. Generator cooling for 40 seconds."
		"transfer":
			if not transfer_ready() or pos.distance_to(level.exit_position) >= 2.8: return
			if stage < 2:
				start_shift(stage + 1)
			else:
				completed = true
				notice = "All three layers surveyed. Your crew made it through."
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
	var avatar := Node3D.new()
	avatar.name = "Surveyor_%s" % id
	add_child(avatar)
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color(0.36, 0.40, 0.34)
	suit.roughness = 0.95
	for part in [{"name":"Body","p":Vector3(0,0.91,0),"r":0.24,"h":0.8},{"name":"Helmet","p":Vector3(0,1.52,0),"r":0.16,"h":0.3},{"name":"LeftLeg","p":Vector3(-0.13,0.37,0),"r":0.085,"h":0.65},{"name":"RightLeg","p":Vector3(0.13,0.37,0),"r":0.085,"h":0.65},{"name":"LeftArm","p":Vector3(-0.31,1.0,0),"r":0.07,"h":0.62},{"name":"RightArm","p":Vector3(0.31,1.0,0),"r":0.07,"h":0.62}]:
		var mesh := MeshInstance3D.new()
		var shape := CapsuleMesh.new()
		shape.radius = part.r
		shape.height = part.h
		shape.radial_segments = 12
		shape.rings = 4
		mesh.mesh = shape
		mesh.name = part.name
		mesh.position = part.p
		mesh.material_override = suit
		avatar.add_child(mesh)
	var visor := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.22, 0.10, 0.02)
	visor.mesh = shape
	visor.position = Vector3(0, 1.55, -0.15)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.07, 0.10, 0.09)
	glass.roughness = 0.28
	visor.material_override = glass
	avatar.add_child(visor)
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
	config.save("user://night-relay.cfg")
