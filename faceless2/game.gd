extends Node3D

const GroundSurface = preload("res://scripts/ground_surface.gd")
const AssetVisual = preload("res://scripts/asset_visual.gd")

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/faceless.gd")
const SoldierScript = preload("res://scripts/soldier.gd")
const InterfaceScript = preload("res://scripts/interface.gd")
const WorldDetailScript = preload("res://scripts/world_detail.gd")
const CombatEffectsScript = preload("res://scripts/combat_effects.gd")
var interface: Control
var world_detail: Node3D
var effects: Node3D

var player: CharacterBody3D
var enemy: CharacterBody3D
var soldiers: Array[CharacterBody3D] = []
var joystick: Control
var hud: Label
var objective_label: Label
var prompt_label: Label
var notice: Label
var fade: ColorRect
var main_menu: Control
var mode_panel: Control
var settings_panel: Control
var archive_panel: Control
var cinematic_camera: Camera3D
var cinematic_overlay: ColorRect
var subtitle_box: ColorRect
var subtitle_label: Label
var subtitle_speaker: Label
var cinematic_running := false
var crosshair: Label
var environment: Environment
var moon_light: DirectionalLight3D
var street_lights: Array[SpotLight3D] = []
var prompt_timer := 0.0

var game_started := false
var selected_mode := "STORY"
var relays: Array[Node3D] = []
var relay_active: Array[bool] = []
var evidence_nodes: Array[Node3D] = []
var evidence_collected := 0
var pickups: Array[Node3D] = []
var terminal: Node3D
var extraction_gate: Node3D
var rifle_pickup: Node3D
var camera_terminal_open := false
var ambience_player: AudioStreamPlayer
var static_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var step_player: AudioStreamPlayer
var shot_players: Array[AudioStreamPlayer] = []
var shot_cursor := 0
var heartbeat_player: AudioStreamPlayer
var current_zone := "BLACKWOOD CHECKPOINT"
var chapter := 1
var story_flags := {}
var kills := 0
var final_wave_started := false
var final_wave_cleared := false
var settings := {
	"quality":2,
	"fps":60,
	"fov":76.0,
	"sensitivity":1.0,
	"brightness":1.35,
	"night_visibility":1.0,
	"volume":0.85,
	"touch_opacity":0.65
}

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	_load_settings()
	_build_world()
	world_detail = Node3D.new()
	world_detail.set_script(WorldDetailScript)
	world_detail.game = self
	add_child(world_detail)
	effects = Node3D.new()
	effects.set_script(CombatEffectsScript)
	effects.game = self
	add_child(effects)
	_build_ui()
	_build_audio()
	_apply_settings()
	get_tree().paused = true

func _process(delta: float) -> void:
	if not game_started or player == null or cinematic_running:
		return
	prompt_timer -= delta
	if prompt_timer <= 0.0:
		prompt_timer = 0.10
		_update_nearby_prompt()
		_update_zone()
		_update_story()
		_update_objective()

func get_look_sensitivity() -> float:
	return float(settings["sensitivity"])

func _mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _static_box(pos: Vector3, size3: Vector3, _material: Material) -> void:
	# Collision only. v4 intentionally renders no procedural box geometry.
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size3
	cs.shape = sh
	body.add_child(cs)

func _spawn_asset(path: String, pos: Vector3, rot_y := 0.0, target_extent := 0.0) -> Node3D:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst := packed.instantiate()
	if not (inst is Node3D):
		return null
	# Keep gameplay anchors at the visible object's base. Imported origins can be
	# hundreds of units away; using those for interaction made pickups unreachable.
	var n := Node3D.new()
	n.name = path.get_file().get_basename().to_pascal_case()
	n.position = pos
	n.rotation.y = rot_y
	add_child(n)
	var pivot := Node3D.new()
	n.add_child(pivot)
	var content := inst as Node3D
	pivot.add_child(content)
	AssetVisual.prepare_world(content, path)
	if target_extent > 0.0:
		var box := AssetVisual.bounds(n)
		var largest := maxf(box.size.x,maxf(box.size.y,box.size.z))
		if largest > 0.001:
			var factor := target_extent/largest
			content.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
			pivot.scale = Vector3.ONE * factor
	for mesh in n.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 95.0
		mesh.visibility_range_end_margin = 10.0
	return n

func _build_road() -> void:
	# This download is a complete, inverted forest diorama, not a road strip.
	# Use its original textured road surface, instead of scaling tree bounds to 145m.
	var packed := ResourceLoader.load("res://assets/blackwood_road.glb", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		push_error("Missing original road asset")
		return
	var source := packed.instantiate() as Node3D
	add_child(source)
	var surface: MeshInstance3D
	for node in source.find_children("*", "MeshInstance3D", true, false):
		if "Dirt_Road_Bare" in node.name:
			surface = node as MeshInstance3D
			break
	if surface == null:
		push_error("Sketchfab road surface Dirt_Road_Bare is missing")
		source.free()
		return
	# The source patch is an irregular showcase mesh with gaps at its edges.
	# Reuse its original PBR texture on continuous, upward-facing gameplay planes.
	var source_material := surface.get_active_material(0) as BaseMaterial3D
	var road_material := GroundSurface.make(source_material)
	# One draw surface keeps Mobile's per-object light selection continuous.
	var tile := Node3D.new()
	tile.name = "RoadTile0"
	tile.position = Vector3(0, 0, -47)
	add_child(tile)
	var visual := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.4, 150.0)
	plane.material = road_material
	visual.mesh = plane
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.add_child(visual)
	var forest_floor := MeshInstance3D.new()
	var shoulder := PlaneMesh.new()
	shoulder.size = Vector2(200.0, 420.0)
	var soil := GroundSurface.make(source_material, true)
	shoulder.material = soil
	forest_floor.position = Vector3(0, -0.035, -60)
	forest_floor.mesh = GroundSurface.terrain(shoulder, forest_floor.position)
	forest_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(forest_floor)
	# Release the unused diorama meshes and materials after extracting the road.
	source.free()

func _build_world() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.008,0.014,0.025)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.49,0.53,0.59)
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.30
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.035,0.055,0.075)
	environment.fog_density = 0.0022
	environment.fog_height_density = 0.006
	world.environment = environment
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48,-18,0)
	moon.light_color = Color(0.76,0.82,0.92)
	moon.light_energy = 0.42
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45.0
	moon_light = moon
	add_child(moon)

	# Collision-only road and invisible edge barriers.
	_static_box(Vector3(0,-0.35,-47),Vector3(18,0.7,150),_mat(Color.WHITE))
	_static_box(Vector3(-8.8,1.2,-47),Vector3(0.5,2.4,150),_mat(Color.WHITE))
	_static_box(Vector3(8.8,1.2,-47),Vector3(0.5,2.4,150),_mat(Color.WHITE))
	# Close both ends of the collision strip before the distant visual terrain.
	_static_box(Vector3(0,1.2,-122),Vector3(18,2.4,0.5),_mat(Color.WHITE))
	_static_box(Vector3(0,1.2,28),Vector3(18,2.4,0.5),_mat(Color.WHITE))

	# Every visible object below is an original Sketchfab GLB, normalized to a sane game scale.
	_build_road()
	var booth := _spawn_asset("res://assets/checkpoint_gate.glb",Vector3(-5.7,0,8),0.0,3.0)
	var tower := _spawn_asset("res://assets/surveillance_tower.glb",Vector3(-6.4,0,-20),0.2,8.2)
	var shelter := _spawn_asset("res://assets/abandoned_bus_stop.glb",Vector3(6.0,0,-43),PI,4.5)
	var cabin := _spawn_asset("res://assets/ranger_cabin.glb",Vector3(-6.0,0,-69),0.15,6.0)
	_spawn_asset("res://assets/dead_zone_fence.glb",Vector3(0,0,-94),0.0,12.0)

	# Static structures collide with their visible geometry, leaving doorways
	# and the space under the lookout open instead of filling them with boxes.
	AssetVisual.add_static_collision(booth)
	AssetVisual.add_static_collision(tower)
	AssetVisual.add_static_collision(shelter)
	AssetVisual.add_static_collision(cabin)

	# Tree roots follow rolling soil; positions remain outside the barriers.
	var forest_random := RandomNumberGenerator.new()
	forest_random.seed = 2139
	for z in range(4,-103,-12):
		for side in [-1.0, 1.0]:
			var x: float = side * forest_random.randf_range(11.5, 14.0)
			var depth := float(z) + forest_random.randf_range(-3, 3)
			_spawn_asset("res://assets/pine_cluster.glb", Vector3(x, GroundSurface.forest_height(x, depth)-0.035, depth), forest_random.randf_range(-PI, PI), forest_random.randf_range(5.8, 8.2))

	relay_active = [false,false,false]
	var relay_positions := [Vector3(5.5,0,-13),Vector3(-5.4,0,-53),Vector3(5.3,0,-84)]
	for i in range(3):
		var r := _spawn_asset("res://assets/power_relay.glb",relay_positions[i],0.0,1.9)
		if r:
			r.set_meta("relay_index",i)
			relays.append(r)
		_static_box(relay_positions[i]+Vector3(0,0.9,0),Vector3(1.4,1.8,0.9),_mat(Color.WHITE))

	var evidence_positions := [Vector3(-4.5,0,-29),Vector3(5.2,0,-64),Vector3(-4.8,0,-88)]
	for i in range(3):
		var e := _spawn_asset("res://assets/evidence_case.glb",evidence_positions[i],0.2*float(i),0.65)
		if e:
			e.set_meta("evidence_index",i)
			evidence_nodes.append(e)

	terminal = _spawn_asset("res://assets/security_terminal.glb",Vector3(-5.2,0,-22),0.25,1.6)
	extraction_gate = _spawn_asset("res://assets/extraction_gate.glb",Vector3(0,0,-106),0.0,11.0)
	rifle_pickup = _spawn_asset("res://assets/rifle.glb",Vector3(-4.9,0.95,-70.5),0.35,1.05)

	for p in [Vector3(5.0,0,-25),Vector3(-4.8,0,-59),Vector3(4.6,0,-87)]:
		var a := _spawn_asset("res://assets/ammo_box.glb",p,0.0,0.65)
		if a:
			a.set_meta("pickup","ammo")
			pickups.append(a)
	for p in [Vector3(-4.2,0,-36),Vector3(4.9,0,-78)]:
		var m := _spawn_asset("res://assets/medkit.glb",p,0.0,0.52)
		if m:
			m.set_meta("pickup","medkit")
			pickups.append(m)

	for z in [3,-14,-30,-46,-62,-78,-94]:
		_spawn_asset("res://assets/street_lamp.glb",Vector3(4.8,0,float(z)),0.0,4.2)
		var light := SpotLight3D.new()
		light.position = Vector3(4.5,3.4,float(z))
		light.rotation_degrees = Vector3(-67, 90, 0)
		light.spot_range = 13.0
		light.spot_angle = 70.0
		light.spot_angle_attenuation = 0.6
		light.light_energy = 2.3
		light.light_color = Color(1.0,0.83,0.64)
		light.shadow_bias = 0.08
		light.shadow_normal_bias = 0.6
		light.distance_fade_enabled = true
		light.distance_fade_begin = 28.0
		light.distance_fade_length = 12.0
		street_lights.append(light)
		add_child(light)

func _build_audio() -> void:
	ambience_player = AudioStreamPlayer.new()
	ambience_player.stream = load("res://audio/blackwood_ambience.wav")
	ambience_player.volume_db = -7.0
	ambience_player.finished.connect(func():
		if game_started: ambience_player.play()
	)
	add_child(ambience_player)
	static_player = AudioStreamPlayer.new()
	static_player.stream = load("res://audio/signal_static.wav")
	static_player.volume_db = -4.0
	add_child(static_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -1.0
	add_child(voice_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = -2.0
	add_child(sfx_player)
	step_player = AudioStreamPlayer.new()
	add_child(step_player)
	for i in range(4):
		var shot := AudioStreamPlayer.new()
		add_child(shot)
		shot_players.append(shot)
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.stream = load("res://audio/heartbeat.wav")
	heartbeat_player.volume_db = -9.0
	heartbeat_player.finished.connect(func():
		if game_started and player and player.health < 35.0:
			heartbeat_player.play()
	)
	add_child(heartbeat_player)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	interface = Control.new()
	interface.set_script(InterfaceScript)
	interface.game = self
	layer.add_child(interface)

func toggle_pause() -> void:
	if not game_started or cinematic_running or player == null or not player.alive:
		return
	var suspend := not get_tree().paused
	player.set_controls_enabled(not suspend)
	joystick.reset()
	get_tree().paused = suspend
	interface.pause_panel.visible = suspend
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if suspend or OS.has_feature("mobile") else Input.MOUSE_MODE_CAPTURED
	interface.refresh_state()

func return_to_menu() -> void:
	_save_checkpoint()
	game_started = false
	get_tree().paused = true
	player.set_controls_enabled(false)
	joystick.reset()
	interface.pause_panel.hide()
	main_menu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	interface.refresh_state()

func _set_cinematic_active(on: bool) -> void:
	cinematic_running = on
	cinematic_overlay.visible = on
	cinematic_camera.current = on
	if player:
		player.camera.current = not on
		player.set_controls_enabled(not on)
	for soldier in soldiers:
		if is_instance_valid(soldier): soldier.set_physics_process(not on)
	if is_instance_valid(enemy): enemy.set_physics_process(not on)
	joystick.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on or OS.has_feature("mobile") else Input.MOUSE_MODE_CAPTURED
	interface.refresh_state()

func _type_subtitle(speaker: String, text_value: String, voice_path := "", cps := 34.0) -> void:
	subtitle_speaker.text = speaker
	subtitle_label.text = text_value
	subtitle_label.visible_characters = 0
	if voice_path != "" and ResourceLoader.exists(voice_path):
		voice_player.stream = load(voice_path)
		voice_player.play()
	for i in range(text_value.length()+1):
		if not cinematic_running:
			return
		subtitle_label.visible_characters = i
		await get_tree().create_timer(1.0/cps).timeout
	if voice_player.playing:
		await voice_player.finished

func _shot(from_pos: Vector3, to_pos: Vector3, look_target: Vector3, duration: float) -> void:
	# All intro shots stay above the clear road centerline, avoiding structures and tree collision.
	var start_basis := Basis.looking_at((look_target-from_pos).normalized(),Vector3.UP)
	var end_basis := Basis.looking_at((look_target-to_pos).normalized(),Vector3.UP)
	cinematic_camera.global_transform = Transform3D(start_basis,from_pos)
	var elapsed := 0.0
	while elapsed < duration and cinematic_running:
		var fraction := 0.5 - cos(clampf(elapsed / duration, 0, 1) * PI) * 0.5
		cinematic_camera.global_transform = Transform3D(start_basis, from_pos).interpolate_with(Transform3D(end_basis, to_pos), fraction)
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func skip_cinematic() -> void:
	if not cinematic_running: return
	if voice_player: voice_player.stop()
	_set_cinematic_active(false)
	_update_objective()

func _start_cinematic_intro() -> void:
	if cinematic_running: return
	_set_cinematic_active(true)
	_run_cinematic_intro()

func _run_cinematic_intro() -> void:
	await _shot(Vector3(0,4.2,18),Vector3(0,3.1,9.5),Vector3(0,1.2,0),3.6)
	if not cinematic_running: return
	await _type_subtitle("BLACKWOOD CONTROL","The checkpoint powered itself back on at 02:13. No utility crew is present. Proceed to Relay One and restore the grid.","res://audio/voice_intro_01.wav",32.0)
	if not cinematic_running: return

	await _shot(Vector3(0,4.6,-7),Vector3(0,4.3,-17),Vector3(-6.4,4.5,-20),3.4)
	if not cinematic_running: return
	await _type_subtitle("DISPATCH","Patrol Twelve stopped responding forty-eight hours ago. Armed security now holds the road. They will fire on sight.","res://audio/voice_intro_02.wav",32.0)
	if not cinematic_running: return

	await _shot(Vector3(0,3.2,-31),Vector3(0,3.0,-42),Vector3(3.0,1.8,-46),3.4)
	if not cinematic_running: return
	if enemy and is_instance_valid(enemy):
		enemy.global_position = Vector3(4.3,0.9,-48)
	await _type_subtitle("ARCHIVE","One impossible frame survived. A man without a face appears behind every lost patrol. Gunfire only delays it.","res://audio/voice_intro_03.wav",30.0)
	if not cinematic_running: return

	await _shot(Vector3(0,3.0,-54),Vector3(0,2.7,-65),Vector3(-5.0,1.0,-69),3.3)
	if not cinematic_running: return
	await _type_subtitle("BLACKWOOD CONTROL","Restore all three relays. Recover the evidence. Find the rifle at the ranger cabin. Then reach the dead-zone gate alive.","res://audio/voice_intro_04.wav",31.0)
	if not cinematic_running: return

	await _shot(Vector3(0,2.5,6),Vector3(0,1.75,4.5),Vector3(5.5,1.0,-13),2.4)
	if not cinematic_running: return
	await _type_subtitle("OBJECTIVE","First objective: follow the road to Relay One. Interact with the electrical cabinet when you reach it.","res://audio/voice_objective_01.wav",32.0)
	if not cinematic_running: return
	_finish_cinematic_intro()


func _finish_cinematic_intro() -> void:
	_set_cinematic_active(false)
	_show_notice("CHAPTER I // ENTER BLACKWOOD")
	_update_objective()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://faceless2_settings.cfg") != OK: return
	var ranges := {"quality": Vector2(0, 3), "fps": Vector2(30, 120), "fov": Vector2(60, 95), "sensitivity": Vector2(0.5, 2), "brightness": Vector2(0.8, 2.2), "night_visibility": Vector2(0.5, 1.8), "volume": Vector2(0, 1), "touch_opacity": Vector2(0.3, 1)}
	for key in settings:
		var value = cfg.get_value("settings", key, settings[key])
		if value is float or value is int:
			settings[key] = clampf(float(value), ranges[key].x, ranges[key].y)
	settings["quality"] = int(settings["quality"])
	if not int(settings["fps"]) in [30, 60, 120]: settings["fps"] = 60

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings: cfg.set_value("settings", key, settings[key])
	if cfg.save("user://faceless2_settings.cfg") != OK: _show_notice("SETTINGS COULD NOT BE SAVED")

func _apply_settings() -> void:
	Engine.max_fps=int(settings["fps"])
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(settings["volume"]), 0.001)))
	AudioServer.set_bus_mute(0, float(settings["volume"]) == 0.0)
	if interface: interface.touch_controls.modulate.a = float(settings["touch_opacity"])
	var q:=int(settings["quality"])
	if world_detail: world_detail.apply_quality(q)
	if effects: effects.quality = q
	get_viewport().scaling_3d_scale=[0.66,0.82,1.0,1.0][q]
	get_viewport().msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_4X][q]
	if moon_light:
		moon_light.shadow_enabled = q >= 1
		moon_light.directional_shadow_max_distance = [20.0, 30.0, 45.0, 65.0][q]
	if player:
		player.set_field_of_view(float(settings["fov"]))
		player.flashlight.shadow_enabled = q >= 2
		player.viewmodel_viewport.msaa_3d = Viewport.MSAA_2X if q < 2 else Viewport.MSAA_4X
	if environment:
		environment.adjustment_brightness=float(settings["brightness"])
		environment.ambient_light_energy=0.38*float(settings["night_visibility"])
		environment.fog_density=0.0022/max(float(settings["night_visibility"]),0.5)

func _run_mid_cinematic(beat: String) -> void:
	if cinematic_running or player == null:
		return
	_set_cinematic_active(true)

	if beat=="tower":
		await _shot(Vector3(0,3.2,-15),Vector3(0,2.8,-22),Vector3(-6.4,3.8,-20),2.5)
		if not cinematic_running: return
		await _type_subtitle("DISPATCH","Movement confirmed around the surveillance tower. Armed personnel are searching the road ahead.","res://audio/voice_chapter_02.wav",32.0)
	elif beat=="cabin":
		await _shot(Vector3(0,3.0,-59),Vector3(-1.5,2.4,-66),Vector3(-6.0,1.6,-69),2.7)
		if not cinematic_running: return
		await _type_subtitle("BLACKWOOD CONTROL","The ranger cabin is close. Recover the rifle and resupply before continuing.","res://audio/voice_chapter_03.wav",32.0)
	elif beat=="dead_signal":
		await _shot(Vector3(0,3.0,-81),Vector3(0,2.6,-89),Vector3(5.3,1.2,-84),2.6)
		if not cinematic_running: return
		await _type_subtitle("ARCHIVE","All three relays are synchronized. The Faceless signal is now moving with you instead of behind you.","res://audio/voice_chapter_04.wav",30.0)

	_set_cinematic_active(false)
	_update_objective()


func _start_new_game() -> void:
	interface.finish_brand_intro()
	mode_panel.visible=false; main_menu.visible=false; get_tree().paused=false; game_started=true
	chapter=1; story_flags={}; kills=0; final_wave_started=false; final_wave_cleared=false
	for i in range(relay_active.size()): relay_active[i]=false
	evidence_collected=0
	for item in evidence_nodes + pickups: item.visible = true
	if rifle_pickup: rifle_pickup.visible = true
	if player: player.reset_loadout()
	world_detail.refresh_relays()
	effects.clear_effects()
	_spawn_player_and_enemies(false)
	_save_checkpoint()
	_update_objective()
	_start_cinematic_intro()
	interface.refresh_state()
	if ambience_player: ambience_player.play()

func _continue_game() -> void:
	interface.finish_brand_intro()
	var cfg:=ConfigFile.new()
	if cfg.load("user://faceless2_save.cfg")!=OK:
		_show_notice("NO CHECKPOINT DATA"); return
	selected_mode=str(cfg.get_value("save","mode","STORY"))
	chapter=int(cfg.get_value("save","chapter",1))
	main_menu.visible=false; get_tree().paused=false; game_started=true
	for i in range(relay_active.size()): relay_active[i]=bool(cfg.get_value("save","relay_"+str(i),false))
	evidence_collected=int(cfg.get_value("save","evidence",0))
	world_detail.refresh_relays()
	effects.clear_effects()
	kills = int(cfg.get_value("save", "kills", 0))
	story_flags = cfg.get_value("save", "story_flags", {})
	final_wave_started = bool(cfg.get_value("save", "final_wave_started", false))
	final_wave_cleared = bool(cfg.get_value("save", "final_wave_cleared", false))
	for i in range(evidence_nodes.size()):
		evidence_nodes[i].visible = not bool(cfg.get_value("save", "evidence_taken_" + str(i), i < evidence_collected))
	for i in range(pickups.size()):
		pickups[i].visible = not bool(cfg.get_value("save", "pickup_taken_" + str(i), false))
	_spawn_player_and_enemies(true)
	if player: player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("mobile") else Input.MOUSE_MODE_CAPTURED
	_update_objective()
	_show_notice("CHECKPOINT RESTORED")
	interface.refresh_state()
	if ambience_player: ambience_player.play()

func _spawn_player_and_enemies(from_save:bool)->void:
	if player==null:
		player=CharacterBody3D.new(); player.set_script(PlayerScript); player.game=self; add_child(player); player.joystick=joystick
	player.restore_full()
	var pos:=Vector3(0,0.9,5)
	if from_save:
		var cfg:=ConfigFile.new()
		if cfg.load("user://faceless2_save.cfg")==OK:
			pos=Vector3(float(cfg.get_value("save", "x", 0)), 0.9, float(cfg.get_value("save","z",5.0)))
			player.reset_loadout()
			if bool(cfg.get_value("save", "rifle_unlocked", false)):
				player.unlock_rifle()
				if rifle_pickup: rifle_pickup.visible = false
			for key in ["pistol_mag", "pistol_reserve", "rifle_mag", "rifle_reserve"]:
				player.set(key, int(cfg.get_value("save", key, player.get(key))))
			player.current_weapon = str(cfg.get_value("save", "weapon", "PISTOL")) if player.rifle_unlocked else "PISTOL"
			player.ammo_in_mag = player.rifle_mag if player.current_weapon == "RIFLE" else player.pistol_mag
			player.reserve_ammo = player.rifle_reserve if player.current_weapon == "RIFLE" else player.pistol_reserve
			player._apply_weapon_pose()
	player.global_position=pos
	player.set_field_of_view(float(settings["fov"]))
	_apply_settings()
	if selected_mode=="BLACKOUT": player.battery=35.0
	elif selected_mode=="NIGHTMARE": player.battery=55.0

	if enemy and is_instance_valid(enemy): enemy.queue_free()
	for s in soldiers:
		if is_instance_valid(s): s.queue_free()
	soldiers.clear()

	if selected_mode!="EXPLORATION":
		enemy=CharacterBody3D.new(); enemy.set_script(EnemyScript); enemy.game=self; enemy.player=player; enemy.position=Vector3(0,0.9,-34)
		enemy.patrol_points.assign([Vector3(0,0.9,-24),Vector3(-5,0.9,-50),Vector3(5,0.9,-76),Vector3(0,0.9,-96)])
		enemy.difficulty=1.35 if selected_mode=="NIGHTMARE" else 1.0
		add_child(enemy)

	var positions=[Vector3(4.5,0.9,-25),Vector3(-5.0,0.9,-55),Vector3(4.2,0.9,-79)]
	for p in positions:
		if not from_save or not final_wave_cleared: _spawn_soldier(p)
	if from_save and final_wave_started and not final_wave_cleared:
		for p in [Vector3(-5.2,0.9,-96),Vector3(5.2,0.9,-98),Vector3(-4,0.9,-102),Vector3(4,0.9,-104)]: _spawn_soldier(p, true)

func _spawn_soldier(pos: Vector3, hard := false) -> void:
	var s:=CharacterBody3D.new()
	s.set_script(SoldierScript)
	s.game=self
	s.player=player
	s.position=pos
	s.patrol_points.assign([pos+Vector3(-3,0,0),pos+Vector3(3,0,-4)])
	s.difficulty=1.35 if hard or selected_mode=="NIGHTMARE" else 1.0
	add_child(s)
	soldiers.append(s)

func _spawn_reinforcements(stage: int) -> void:
	if stage == 1:
		_spawn_soldier(Vector3(-4.8,0.9,-35))
		_spawn_soldier(Vector3(4.8,0.9,-39))
		_play_radio_line("BLACKWOOD CONTROL","Security reinforcements are moving toward the abandoned stop. Stay off the centerline.","res://audio/voice_relay_01.wav")
	elif stage == 2:
		_spawn_soldier(Vector3(-4.6,0.9,-72),true)
		_spawn_soldier(Vector3(4.5,0.9,-75),true)
		_play_radio_line("BLACKWOOD CONTROL","Relay Two exposed your position. Reach the ranger cabin and recover the rifle before the next team arrives.","res://audio/voice_relay_02.wav")

func _start_final_wave() -> void:
	if final_wave_started:
		return
	final_wave_started=true
	chapter=6
	_show_notice("CHAPTER VI // LAST SIGNAL")
	for p in [Vector3(-5.2,0.9,-96),Vector3(5.2,0.9,-98),Vector3(-4.0,0.9,-102),Vector3(4.0,0.9,-104)]:
		_spawn_soldier(p,true)
	if enemy and is_instance_valid(enemy):
		enemy.health=320.0
		enemy.dead=false
		enemy.global_position=Vector3(0,0.9,-101)
		enemy.difficulty=1.45
	_play_radio_line("DISPATCH","The gate is powered, but a security counterattack is inbound. Hold the dead zone until the road is clear.","res://audio/voice_final_wave.wav")

func _play_radio_line(speaker: String, text_value: String, voice_path: String) -> void:
	interface.show_radio(speaker, text_value)
	if voice_path != "" and ResourceLoader.exists(voice_path):
		voice_player.stream=load(voice_path)
		voice_player.play()

func _interact()->void:
	if not game_started or player==null or cinematic_running or get_tree().paused: return
	if rifle_pickup and rifle_pickup.visible and player.global_position.distance_to(rifle_pickup.global_position)<2.2:
		rifle_pickup.visible=false; player.unlock_rifle(); chapter=maxi(chapter,3); _show_notice("RIFLE ACQUIRED // CHAPTER III"); _save_checkpoint(); _update_objective(); return
	for p in pickups:
		if is_instance_valid(p) and p.visible and player.global_position.distance_to(p.global_position)<2.0:
			var kind:=str(p.get_meta("pickup",""))
			p.visible=false
			if kind=="ammo": player.add_ammo(36)
			elif kind=="medkit": player.add_health(45)
			return
	for i in range(relays.size()):
		if not relay_active[i] and player.global_position.distance_to(relays[i].global_position)<2.4:
			relay_active[i]=true
			world_detail.refresh_relays()
			chapter=maxi(chapter,i+1)
			_show_notice("RELAY %d ONLINE"%(i+1))
			if i == 0: _spawn_reinforcements(1)
			elif i == 1: _spawn_reinforcements(2)
			elif i == 2: _play_radio_line("BLACKWOOD CONTROL","All relays are online. Move to the dead-zone gate. Expect one final response.","res://audio/voice_relay_03.wav")
			_save_checkpoint()
			_update_objective()
			return
	for e in evidence_nodes:
		if is_instance_valid(e) and e.visible and player.global_position.distance_to(e.global_position)<2.1:
			e.visible=false; evidence_collected+=1; _show_notice("EVIDENCE %d/3"%evidence_collected); _save_checkpoint(); _update_objective(); return
	if terminal and player.global_position.distance_to(terminal.global_position)<2.5:
		camera_terminal_open=not camera_terminal_open; _show_notice("CAMERA GRID "+("ONLINE" if camera_terminal_open else "CLOSED")); return
	if extraction_gate and player.global_position.distance_to(extraction_gate.global_position)<3.2:
		if _relay_count()<3 or evidence_collected<2:
			_show_notice("GATE LOCKED // NEED POWER 3/3 AND EVIDENCE 2/3")
		elif not final_wave_started:
			_start_final_wave()
		elif final_wave_cleared:
			_finish_game()
		else:
			_show_notice("CLEAR THE COUNTERATTACK BEFORE EXTRACTION")

func _update_nearby_prompt()->void:
	prompt_label.text=""
	if rifle_pickup and rifle_pickup.visible and player.global_position.distance_to(rifle_pickup.global_position)<2.2: prompt_label.text="INTERACT — TAKE RIFLE"; return
	for p in pickups:
		if is_instance_valid(p) and p.visible and player.global_position.distance_to(p.global_position)<2.0: prompt_label.text="INTERACT — PICKUP"; return
	for i in range(relays.size()):
		if not relay_active[i] and player.global_position.distance_to(relays[i].global_position)<2.4: prompt_label.text="INTERACT — REACTIVATE RELAY "+str(i+1); return
	for e in evidence_nodes:
		if is_instance_valid(e) and e.visible and player.global_position.distance_to(e.global_position)<2.1: prompt_label.text="INTERACT — RECOVER EVIDENCE"; return
	if terminal and player.global_position.distance_to(terminal.global_position)<2.5: prompt_label.text="INTERACT — SECURITY TERMINAL"; return
	if extraction_gate and player.global_position.distance_to(extraction_gate.global_position)<3.2: prompt_label.text="INTERACT — DEAD-ZONE GATE"

func _update_story()->void:
	var z:=player.global_position.z
	if z<-20 and not story_flags.has("armed"):
		story_flags["armed"]=true
		chapter=2
		_show_notice("CHAPTER II // ARMED RESPONSE")
		_run_mid_cinematic("tower")
	if z<-43 and not story_flags.has("stop"):
		story_flags["stop"]=true
		_show_notice("CHECKPOINT // ABANDONED STOP")
		_save_checkpoint()
	if z<-64 and not story_flags.has("cabin"):
		story_flags["cabin"]=true
		chapter=maxi(chapter,3)
		_show_notice("CHAPTER III // RANGER WOODS")
		_run_mid_cinematic("cabin")
	if _relay_count()>=3 and not story_flags.has("dead_signal"):
		story_flags["dead_signal"]=true
		chapter=4
		_show_notice("CHAPTER IV // DEAD SIGNAL")
		_run_mid_cinematic("dead_signal")
	if z<-92 and not story_flags.has("extract"):
		story_flags["extract"]=true
		chapter=5
		_show_notice("CHAPTER V // DEAD ZONE")

func _relay_count()->int:
	var n:=0
	for v in relay_active:
		if v:n+=1
	return n

func _update_zone()->void:
	var z:=player.global_position.z
	if z>-16: current_zone="BLACKWOOD CHECKPOINT"
	elif z>-36: current_zone="SURVEILLANCE TOWER"
	elif z>-58: current_zone="ABANDONED STOP"
	elif z>-80: current_zone="RANGER WOODS"
	else: current_zone="DEAD ZONE"

func update_hud(h:float,s:float,b:float,weapon:String,mag:int,reserve:int)->void:
	if interface: interface.update_vitals(h, s, b, weapon, mag, reserve)

func _current_objective() -> Dictionary:
	if relay_active.size() >= 1 and not relay_active[0] and relays.size() > 0:
		return {"text":"GO TO RELAY 1 — restore checkpoint power","target":relays[0]}
	if evidence_nodes.size() > 0 and is_instance_valid(evidence_nodes[0]) and evidence_nodes[0].visible:
		return {"text":"RECOVER EVIDENCE 1 — case beside the road","target":evidence_nodes[0]}
	if relay_active.size() >= 2 and not relay_active[1] and relays.size() > 1:
		return {"text":"GO TO RELAY 2 — surveillance sector","target":relays[1]}
	if player and not player.rifle_unlocked and rifle_pickup and rifle_pickup.visible:
		return {"text":"GET THE RIFLE — ranger cabin","target":rifle_pickup}
	if evidence_nodes.size() > 1 and is_instance_valid(evidence_nodes[1]) and evidence_nodes[1].visible:
		return {"text":"RECOVER EVIDENCE 2","target":evidence_nodes[1]}
	if relay_active.size() >= 3 and not relay_active[2] and relays.size() > 2:
		return {"text":"GO TO RELAY 3 — dead-zone approach","target":relays[2]}
	if evidence_collected < 2:
		for e in evidence_nodes:
			if is_instance_valid(e) and e.visible:
				return {"text":"RECOVER ANOTHER EVIDENCE CASE","target":e}
	if final_wave_started and not final_wave_cleared:
		return {"text":"SURVIVE THE SECURITY COUNTERATTACK","target":extraction_gate}
	if final_wave_cleared:
		return {"text":"EXTRACT — interact with the dead-zone gate","target":extraction_gate}
	return {"text":"REACH THE DEAD-ZONE GATE — trigger final response","target":extraction_gate}

func _update_objective()->void:
	if objective_label == null or player == null:
		return
	var obj: Dictionary = _current_objective()
	objective_label.text = str(obj.get("text", ""))

func _save_checkpoint()->void:
	if player==null:return
	var cfg:=ConfigFile.new()
	cfg.set_value("save","mode",selected_mode); cfg.set_value("save","evidence",evidence_collected); cfg.set_value("save","z",player.global_position.z); cfg.set_value("save","chapter",chapter)
	for i in range(relay_active.size()): cfg.set_value("save","relay_"+str(i),relay_active[i])
	for i in range(evidence_nodes.size()): cfg.set_value("save", "evidence_taken_" + str(i), not evidence_nodes[i].visible)
	for i in range(pickups.size()): cfg.set_value("save", "pickup_taken_" + str(i), not pickups[i].visible)
	cfg.set_value("save", "x", player.global_position.x)
	cfg.set_value("save", "rifle_unlocked", player.rifle_unlocked)
	cfg.set_value("save", "weapon", player.current_weapon)
	player.pistol_mag = player.ammo_in_mag if player.current_weapon == "PISTOL" else player.pistol_mag
	player.pistol_reserve = player.reserve_ammo if player.current_weapon == "PISTOL" else player.pistol_reserve
	player.rifle_mag = player.ammo_in_mag if player.current_weapon == "RIFLE" else player.rifle_mag
	player.rifle_reserve = player.reserve_ammo if player.current_weapon == "RIFLE" else player.rifle_reserve
	for key in ["pistol_mag", "pistol_reserve", "rifle_mag", "rifle_reserve", "kills", "story_flags", "final_wave_started", "final_wave_cleared"]:
		cfg.set_value("save", key, player.get(key) if key.begins_with("pistol_") or key.begins_with("rifle_") else get(key))
	cfg.save("user://faceless2_save.cfg")

func set_crosshair_aiming(on: bool) -> void:
	if interface: interface.reticle_aiming = on

func _play_sfx(path: String, volume_db := -2.0) -> void:
	if not ResourceLoader.exists(path): return
	var channel := sfx_player
	if "footstep" in path:
		channel = step_player
	elif "_shot.wav" in path:
		channel = shot_players[shot_cursor]
		shot_cursor = (shot_cursor + 1) % shot_players.size()
	channel.stop()
	channel.stream = load(path)
	channel.volume_db = volume_db
	channel.play()

func play_footstep(running: bool) -> void:
	_play_sfx("res://audio/footstep_run.wav" if running else "res://audio/footstep.wav",-10.0)

func on_player_shot(weapon:String)->void:
	interface.shot_time = 0.09
	for soldier in soldiers:
		if is_instance_valid(soldier): soldier.hear_shot(player.global_position)
	_play_sfx("res://audio/rifle_shot.wav" if weapon=="RIFLE" else "res://audio/pistol_shot.wav",-1.0)

func weapon_event(t:String)->void:
	if t == "HIT":
		interface.confirm_hit()
	elif t not in ["RELOADING", "READY"]:
		_show_notice(t)
	if t=="RELOADING":
		_play_sfx("res://audio/reload_click.wav",-4.0)

func soldier_fired(_s:Node)->void:
	var sound := _s.get_node_or_null("Gunfire") as AudioStreamPlayer3D
	if sound == null:
		sound = AudioStreamPlayer3D.new()
		sound.name = "Gunfire"
		sound.stream = load("res://audio/rifle_shot.wav")
		sound.volume_db = -14
		sound.max_distance = 55
		_s.add_child(sound)
	sound.play()

func soldier_down(s:CharacterBody3D)->void:
	soldiers.erase(s)
	kills+=1
	var tw:=create_tween(); tw.tween_property(s,"rotation:z",1.35,0.24); tw.tween_interval(.2); tw.tween_callback(s.queue_free)
	interface.confirm_hit(true)
	if final_wave_started and soldiers.is_empty():
		final_wave_cleared=true
		_show_notice("ROAD CLEAR // EXTRACTION AVAILABLE")
		_play_radio_line("BLACKWOOD CONTROL","Counterattack neutralized. The dead-zone gate is clear. Extract now.","res://audio/voice_final_clear.wav")
		_save_checkpoint()

func faceless_down(e:CharacterBody3D)->void:
	_show_notice("FACELESS DISRUPTED // IT WILL RETURN")
	var tw:=create_tween(); tw.tween_property(e,"position:y",-2.0,0.55); tw.tween_interval(4.0); tw.tween_callback(func(): if is_instance_valid(e): e.position=Vector3(0,0.9,-96); e.health=160.0; e.dead=false)

func player_hurt(source_position := Vector3.INF)->void:
	interface.damage_time = 0.65
	if source_position.is_finite() and player:
		var local: Vector3 = player.camera.global_transform.affine_inverse() * source_position
		interface.damage_bearing = atan2(local.x, -local.z) - PI * 0.5
		interface.damage_direction_time = 0.9
	if player and player.health < 35.0 and heartbeat_player and not heartbeat_player.playing:
		heartbeat_player.play()
func on_enemy_attack()->void:
	_show_notice("SIGNAL LOST // MOVE"); if static_player: static_player.play()
func player_dead()->void:
	_show_notice("YOU WERE RECORDED")
	var tw:=create_tween(); tw.tween_property(fade,"color",Color(0,0,0,1),0.8); tw.tween_interval(.8); tw.tween_callback(_restart_from_checkpoint)
func _restart_from_checkpoint()->void:
	fade.color=Color(0,0,0,0); _continue_game()
func _finish_game()->void:
	game_started=false
	get_tree().paused=true
	player.set_controls_enabled(false)
	_show_notice("EXTRACTION COMPLETE // FACELESS 2")
	main_menu.visible=true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	interface.refresh_state()

func _show_notice(t:String)->void:
	if interface: interface.show_notice(t)
