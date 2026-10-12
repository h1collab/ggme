extends Node3D
# Cinematic-only underground secret facility. Reused imported Kenney CC0 GLBs.
const Assets = preload("backrooms_assets.gd")
const CAMERA_GROUND := Vector3(0, 0.32, 3.1)
const CAMERA_UP := Vector3(0, 1.62, 3.1)
const LOOK_GROUND := Vector3(0, -0.4, 0.35)
const LOOK_DARKNESS := Vector3(0, 1.26, -18.0)
var authored_modules := 0
var facility_lights: Array[Light3D] = []
var low_rumble: AudioStreamPlayer3D
var far_clang: AudioStreamPlayer3D
var smiler: Node3D
var smiler_glow: OmniLight3D
var smiler_sound: AudioStreamPlayer3D
var door_audio: AudioStreamPlayer3D
var near_door_audio: AudioStreamPlayer3D
var door_notice_until := 0.0
var walkable_floor: StaticBody3D
var side_doors: Array[Node3D] = []
var openable_door: Node3D
var laboratory_entered := false
var laboratory_modules := 0
var laboratory_spawn := Vector3(11.0,0.12,-3.0)
var laboratory_root: Node3D
var lab_physics: StaticBody3D
var lab_central_light: OmniLight3D
var lab_emergency_light: SpotLight3D
var lab_power_failed := false
var lab_power_restored := false
var door_slammed := false
var flashlight_collected := false
var flashlight_world: Node3D
var flashlight_pickup_position := Vector3(0.64,0.14,2.25)
var backup_panel_position := Vector3(12.8,1.25,-4.8)
var slam_audio: AudioStreamPlayer3D
var pickup_audio: AudioStreamPlayer3D
var module_target: Node3D
var door_tween: Tween
var proximity_last_ms := -100000
var frowner: Sprite3D
var frowner_started := false
var frowner_finished := false
var frowner_timer := 0.0
var frowner_position := Vector3(-3.05,1.63,-4.4)
var smiler_flashlight_faded := false

func _ready() -> void:
	name = "WakeupFacility_Area51Inspired"
	# Facility is a plausible black-site research space, not an official Area 51 layout.
	var concrete := _finish(Color(0.51,0.58,0.61), "concrete.jpg")
	var industrial := _finish(Color(0.18,0.23,0.24))
	var floor_finish := _finish(Color(0.55,0.60,0.61), "concrete.jpg")
	var panel := _finish(Color(0.26,0.30,0.30))
	for x in [-3.0,-1.5,0.0,1.5,3.0]:
		for z in [3.0,1.5,0.0,-1.5,-3.0,-4.5,-6.0,-7.5,-9.0]:
			_module("floor_panel",Vector3(x,-0.06,z),floor_finish, Vector3(1.5,0.18,1.5))
	for z in [3.0,1.5,0.0,-1.5,-3.0,-4.5,-6.0,-7.5,-9.0]:
		_module("wall",Vector3(-3.8,1.55,z),concrete,Vector3(0.22,3.1,1.5))
		# A real opening in the wall, centered on the Smiler-marked doorway.
		if z != 0.0 and z != -1.5: _module("wall",Vector3(3.8,1.55,z),concrete,Vector3(0.22,3.1,1.5))
		_module("structure_panel",Vector3(0,3.15,z),panel,Vector3(7.5,0.18,1.5))
	for z in [3.0,-2.0,-7.0]:
		for x in [-3.6,3.6]:
			_module("wall_pillar",Vector3(x,1.5,z),industrial,Vector3(0.4,3.0,0.4))
	_module("door_single_closed",Vector3(-2.8,1.5,-6.5),industrial,Vector3(1.4,2.9,0.25))
	_module("computer_screen",Vector3(2.8,1.25,-2.25),panel,Vector3(0.8,1.05,0.3))
	_module("display_wall",Vector3(-3.6,1.8,-3.2),panel,Vector3(0.25,1.4,1.8))
	for i in range(5):
		_module("pipe",Vector3(-3.45,2.65,1.6-i*2.0),industrial,Vector3(0.24,0.24,1.8))
	_module("container_tall",Vector3(2.9,0.95,1.6),industrial,Vector3(0.85,1.9,0.85))
	# Close the far end with authored walls, not a skybox leak or visible primitive.
	var dark_finish := _finish(Color(0.025,0.035,0.04))
	for x in [-3.0,-1.5,0.0,1.5,3.0]:
		_module("wall",Vector3(x,1.55,-10.0),dark_finish,Vector3(1.5,3.1,0.3))
	_module("wall_door",Vector3(0,1.55,-9.75),industrial,Vector3(4.1,3.10,0.30))
	# Imported Kenney door meshes are visible; collision is invisible and cheap.
	for door_at in [Vector3(-3.40,1.3,1.4),Vector3(3.40,1.3,-0.9),Vector3(-3.40,1.3,-4.5),Vector3(3.40,1.3,-6.4)]:
		var door := _authored_door(door_at)
		if door != null: side_doors.append(door)
	# One door is an actual continuation, others remain sealed with LOCK feedback.
	if side_doors.size() >= 2: openable_door = side_doors[1]
	# v0.25: Laboratory GLBs and lights are built lazily, upon actually opening the door.
	# Mark the openable doorway with multiple repetitions of the licensed
	# original Sketchfab face texture, referencing the unsettling Level ! door.
	var warning_texture := Assets.path("vendor/sketchfab_smiler_face.png")
	if ResourceLoader.exists(warning_texture):
		for i in range(1):
			var warning := Sprite3D.new()
			warning.name = "SketchfabSmilerDoorMark_%d" % i
			warning.texture = load(warning_texture)
			warning.pixel_size = 0.00040
			warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			warning.shaded = false
			warning.position = Vector3(3.13,1.50,-0.9)
			add_child(warning)
	var frowner_file := Assets.path("vendor/frowner_derivative.png")
	if ResourceLoader.exists(frowner_file):
		frowner = Sprite3D.new()
		frowner.name = "FrownerInspired_CC_BY_Derivative"
		frowner.texture = load(frowner_file)
		frowner.position = frowner_position
		frowner.pixel_size = 0.00145
		frowner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		frowner.shaded = false
		frowner.no_depth_test = false
		frowner.visible = false
		add_child(frowner)
	# The interactive body has a simple invisible physical floor and perimeter.
	walkable_floor = StaticBody3D.new()
	walkable_floor.name = "InvisibleFacilityPhysics"
	add_child(walkable_floor)
	_barrier(Vector3(0,-0.17,-3.0),Vector3(7.4,0.30,14.7))
	_barrier(Vector3(-3.8,1.45,-3.0),Vector3(0.35,3.0,14.8))
	_barrier(Vector3(3.8,1.45,-6.1),Vector3(0.35,3.0,8.0))
	_barrier(Vector3(3.8,1.45,2.45),Vector3(0.35,3.0,3.3))
	for x in [4.55,6.05]: _module("floor_panel",Vector3(x,-0.06,-0.9),floor_finish,Vector3(1.5,0.18,2.1))
	_barrier(Vector3(5.45,-0.17,-0.9),Vector3(4.15,0.30,2.2))
	_barrier(Vector3(0,1.45,-10.1),Vector3(7.6,3.0,0.35))
	_barrier(Vector3(0,1.45,4.1),Vector3(7.6,3.0,0.35))
	# Small Plastic Torch: licensed Poly Haven original imported GLB.
	var flashlight_path := Assets.path("vendor/flashlight_cc0.glb")
	if not ResourceLoader.exists(flashlight_path):
		push_error("Missing verified CC0 flashlight GLB: " + flashlight_path)
	else:
		flashlight_world = _flashlight_model()
		flashlight_world.name = "PolyHaven_CC0_Flashlight_Pickup"
		flashlight_world.position = flashlight_pickup_position
		flashlight_world.rotation = Vector3(0.15,0.35,PI * 0.46)
		add_child(flashlight_world)
	# Invisible colliders are disabled whenever the cinematic facility is hidden.
	set_physics_active(false)
	# Author's original Sketchfab GLB is baked to this transparent sprite.
	# It faces the viewer rather than behaving as a skinned pursuer.
	var sprite_path := Assets.path("vendor/sketchfab_smiler_face.png")
	if not ResourceLoader.exists(sprite_path):
		push_error("Missing verified Sketchfab Smiler sprite: " + sprite_path)
	else:
		var sprite := Sprite3D.new()
		sprite.name = "SketchfabSmilerTexture_OriginalGeometryBake"
		sprite.texture = load(sprite_path)
		sprite.pixel_size = 0.0020
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.no_depth_test = true
		sprite.shaded = false
		sprite.no_depth_test = true
		sprite.double_sided = true
		sprite.transparent = true
		sprite.position = Vector3(0,1.50,-5.4)
		add_child(sprite)
		smiler = sprite
		smiler.visible = false
	smiler_sound = AudioStreamPlayer3D.new()
	smiler_sound.name = "SmilerTwoStageAudio"
	smiler_sound.position = Vector3(0,1.5,-4.6)
	smiler_sound.max_distance = 25.0
	var scare_path := "res://audio/smiler_sting.wav"
	if ResourceLoader.exists(scare_path): smiler_sound.stream = load(scare_path)
	add_child(smiler_sound)
	door_audio = AudioStreamPlayer3D.new()
	door_audio.name = "LockedDoorImpact"
	door_audio.max_distance = 15.0
	var lock_path := "res://audio/door_locked.wav"
	if ResourceLoader.exists(lock_path): door_audio.stream = load(lock_path)
	add_child(door_audio)
	near_door_audio = AudioStreamPlayer3D.new()
	near_door_audio.name = "ApproachingLockedDoor_Creak"
	near_door_audio.max_distance = 13.0
	var creak_path := "res://audio/door_creak.wav"
	if ResourceLoader.exists(creak_path): near_door_audio.stream = load(creak_path)
	add_child(near_door_audio)
	slam_audio = AudioStreamPlayer3D.new()
	slam_audio.name = "SmilerDoor_SpatialSlam"
	slam_audio.max_distance = 16.0
	if ResourceLoader.exists("res://audio/door_slam.wav"): slam_audio.stream = load("res://audio/door_slam.wav")
	add_child(slam_audio)
	pickup_audio = AudioStreamPlayer3D.new()
	pickup_audio.name = "Flashlight_Pickup3D"
	pickup_audio.max_distance = 10.0
	if ResourceLoader.exists("res://audio/flashlight_pickup.wav"): pickup_audio.stream = load("res://audio/flashlight_pickup.wav")
	add_child(pickup_audio)
	# A distant shutter has no floodlighting. Forward view ends in darkness.
	for at in [Vector3(1.9,2.7,1.4),Vector3(-1.7,2.7,-1.8)]:
		var light := SpotLight3D.new()
		light.position = at
		light.light_color = Color(0.54,0.74,0.83)
		light.light_energy = 1.32
		light.spot_range = 5.1
		light.spot_angle = 43.0
		light.shadow_enabled = false
		add_child(light)
		light.look_at(at+Vector3(0,-2.2,-0.3))
		facility_lights.append(light)
	# A weak, localised emergency spill reveals only the immediate floor
	# and near wall texture; the distant corridor remains unlit.
	var near_spill := OmniLight3D.new()
	near_spill.name = "ColdEmergencySpill_NearAwakeOnly"
	near_spill.position = Vector3(-1.4, 1.45, 2.2)
	near_spill.light_color = Color(0.50, 0.72, 0.82)
	near_spill.light_energy = 1.85
	near_spill.omni_range = 6.5
	near_spill.shadow_enabled = false
	add_child(near_spill)
	facility_lights.append(near_spill)
	low_rumble = AudioStreamPlayer3D.new()
	low_rumble.name = "DistantVentilation_Rumble"
	low_rumble.position = Vector3(0,1.8,-5.0)
	low_rumble.max_distance = 20.0
	var sound_path := Assets.path("vendor/hum.mp3")
	if ResourceLoader.exists(sound_path): low_rumble.stream = load(sound_path)
	add_child(low_rumble)
	far_clang = AudioStreamPlayer3D.new()
	far_clang.name = "SomethingBeyondTheShutter_3D"
	far_clang.position = Vector3(0,1.6,-8.6)
	far_clang.max_distance = 18.0
	far_clang.unit_size = 1.4
	var door_f = "res://audio/elevator_door.wav"
	if ResourceLoader.exists(door_f): far_clang.stream = load(door_f)
	add_child(far_clang)
	visible = false
	set_process(false)

func begin_frowner() -> void:
	if frowner_started or frowner_finished or not is_instance_valid(frowner): return
	frowner_started = true
	frowner_timer = 0.0
	frowner.visible = true
	frowner.modulate.a = 0.0
	create_tween().tween_property(frowner,"modulate:a",0.9,0.65)

func update_frowner(delta: float) -> void:
	if not frowner_started or frowner_finished: return
	frowner_timer += delta
	if frowner_timer > 2.6:
		frowner_finished = true
		var fade := create_tween()
		fade.tween_property(frowner,"modulate:a",0.0,1.6)
		fade.finished.connect(func():
			if is_instance_valid(frowner): frowner.visible = false)

func reveal_torch_smiler() -> void:
	if smiler_flashlight_faded or not is_instance_valid(smiler): return
	smiler.modulate.a = 1.0
	smiler.position = Vector3(0.0,1.6,-3.2)
	smiler.visible = true

func smiler_flashlight_hit() -> void:
	if smiler_flashlight_faded or not is_instance_valid(smiler) or not smiler.visible: return
	smiler_flashlight_faded = true
	var fade := create_tween()
	fade.tween_property(smiler,"modulate:a",0.0,0.27)
	fade.finished.connect(func():
		if is_instance_valid(smiler): smiler.visible = false)

func _build_laboratory() -> void:
	if is_instance_valid(laboratory_root): return
	laboratory_root = Node3D.new()
	laboratory_root.name = "StreamedLaboratory_GLBSector"
	add_child(laboratory_root)
	module_target = laboratory_root
	# A single watertight, authored and batch-merged Kenney GLB shell.
	var shell := Assets.path("vendor/laboratory_shell_cc0.glb")
	if not ResourceLoader.exists(shell): push_error("Missing sealed laboratory GLB")
	else:
		var scene := load(shell).instantiate()
		scene.name = "KenneyCC0_SealedLaboratory_GLBBatched"
		laboratory_root.add_child(scene)
		for m in scene.find_children("*","MeshInstance3D",true,false):
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.46,0.53,0.54)
			material.roughness = 0.83
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			(m as MeshInstance3D).material_override = material
		laboratory_modules = 58
	var steel := _finish(Color(0.27,0.34,0.36))
	for spot in [Vector3(9.0,1.25,-3.1),Vector3(12.8,1.25,-4.8)]:
		_module("computer_screen",spot,steel,Vector3(0.75,0.85,0.45))
		laboratory_modules += 1
	for spot in [Vector3(8.4,0.9,-5.7),Vector3(13.7,0.9,-2.2)]:
		_module("container_tall",spot,steel,Vector3(0.9,1.8,0.9))
		laboratory_modules += 1
	var lab_light := OmniLight3D.new()
	lab_light.position = Vector3(10.6,2.55,-3.1)
	lab_light.light_color = Color(0.65,0.83,0.90)
	lab_light.light_energy = 2.8
	lab_light.omni_range = 9.0
	lab_light.shadow_enabled = false
	laboratory_root.add_child(lab_light)
	lab_central_light = lab_light
	var emergency := SpotLight3D.new()
	emergency.name = "AbandonedLab_Emergency"
	emergency.position = Vector3(13.25,2.65,-5.15)
	emergency.light_color = Color(0.90,0.93,0.87)
	emergency.light_energy = 2.1
	emergency.spot_range = 8.0
	emergency.spot_angle = 62.0
	emergency.shadow_enabled = false
	laboratory_root.add_child(emergency)
	emergency.look_at(Vector3(10.8,0.9,-3.4))
	lab_emergency_light = emergency
	module_target = null
	lab_physics = StaticBody3D.new()
	lab_physics.name = "Laboratory_ProxyCollision"
	laboratory_root.add_child(lab_physics)
	_barrier(Vector3(11,-0.17,-3.3),Vector3(7.8,0.3,8.5),lab_physics)
	# Leave a traversable entry from the corridor side.
	_barrier(Vector3(7.0,1.5,-5.1),Vector3(0.3,3.0,5.0),lab_physics)
	_barrier(Vector3(7.0,1.5,0.4),Vector3(0.3,3.0,0.4),lab_physics)
	_barrier(Vector3(15,1.5,-3.3),Vector3(0.3,3.0,8.5),lab_physics)
	_barrier(Vector3(11,1.5,-7.6),Vector3(8,3.0,0.3),lab_physics)
	_barrier(Vector3(11,1.5,0.6),Vector3(8,3.0,0.3),lab_physics)
	set_physics_active(true)

func _flashlight_model() -> Node3D:
	var model := Assets.fitted("vendor/flashlight_cc0.glb", 1.0)
	var dimensions: Vector3 = model.get_meta("dimensions", Vector3.ONE)
	model.scale *= 0.24 / maxf(dimensions.x, maxf(dimensions.y, dimensions.z))
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return model

func reset_facility() -> void:
	if door_tween != null and door_tween.is_running(): door_tween.kill()
	if is_instance_valid(laboratory_root): laboratory_root.queue_free()
	laboratory_root = null
	lab_physics = null
	lab_central_light = null
	lab_emergency_light = null
	laboratory_entered = false
	laboratory_modules = 0
	door_slammed = false
	lab_power_failed = false
	lab_power_restored = false
	flashlight_collected = false
	if is_instance_valid(flashlight_world): flashlight_world.visible = true
	frowner_started = false
	frowner_finished = false
	frowner_timer = 0.0
	smiler_flashlight_faded = false
	if is_instance_valid(frowner): frowner.visible = false
	if is_instance_valid(smiler): smiler.modulate.a = 1.0
	if is_instance_valid(openable_door):
		var hinge := openable_door.get_meta("hinge") as Node3D
		if is_instance_valid(hinge): hinge.rotation.y = 0.0
		openable_door.set_meta("opened",false)
	if is_instance_valid(slam_audio): slam_audio.stop()
	set_physics_active(visible)

func _authored_door(at: Vector3) -> Node3D:
	var source := Assets.path("vendor/wakeup_door_single_closed.glb")
	if not ResourceLoader.exists(source): return null
	var node := Node3D.new()
	node.name = "KenneyAuthoredInteractiveDoor"
	node.position = at
	node.rotation.y = PI * 0.5 if at.x < 0 else -PI * 0.5
	var hinge := Node3D.new()
	hinge.name = "ActualDoorHinge"
	hinge.position.x = -0.77
	node.add_child(hinge)
	var mesh := Assets.fitted("vendor/wakeup_door_single_closed.glb",2.35)
	mesh.position.x = 0.77
	hinge.add_child(mesh)
	var body := StaticBody3D.new()
	body.name = "SolidDoorPanel"
	body.position = mesh.position
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5,2.3,0.18)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	hinge.add_child(body)
	node.set_meta("hinge",hinge)
	node.set_meta("body",body)
	node.set_meta("opened",false)
	add_child(node)
	return node

func set_physics_active(enabled: bool) -> void:
	if not is_instance_valid(walkable_floor): return
	walkable_floor.collision_layer = 1 if enabled else 0
	walkable_floor.collision_mask = 1 if enabled else 0
	if is_instance_valid(lab_physics):
		lab_physics.collision_layer = 1 if enabled else 0
		lab_physics.collision_mask = 1 if enabled else 0
	for door in side_doors:
		if is_instance_valid(door):
			var body := door.get_meta("body") as StaticBody3D
			if is_instance_valid(body):
				body.collision_layer = 1 if enabled and not bool(door.get_meta("opened",false)) else 0
				body.collision_mask = body.collision_layer

func _barrier(at: Vector3, size: Vector3, parent_body: StaticBody3D = null) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.position = at
	collision.shape = shape
	var target: StaticBody3D = parent_body if is_instance_valid(parent_body) else walkable_floor
	target.add_child(collision)

func smiler_stage(_progress: float, stage: String) -> void:
	if not is_instance_valid(smiler): return
	smiler.visible = stage == "watch" or stage == "near"
	if stage == "watch": smiler.position = Vector3(0,1.54,-5.4)
	if stage == "near": smiler.position = Vector3(0,1.52,-2.35)
	if is_instance_valid(smiler_sound):
		smiler_sound.position = smiler.position

func nearest_door(player_position: Vector3, max_distance: float = 1.8) -> Node3D:
	var best: Node3D = null
	var shortest := max_distance
	for door in side_doors:
		var distance := player_position.distance_to(door.global_position)
		if distance < shortest:
			shortest = distance
			best = door
	return best

func player_near_door(player_position: Vector3) -> Node3D:
	return nearest_door(player_position,1.55)

func play_door_proximity(door: Node3D) -> void:
	if not is_instance_valid(door) or not is_instance_valid(near_door_audio): return
	near_door_audio.global_position = door.global_position
	var now := Time.get_ticks_msec()
	if now - proximity_last_ms < 2500: return
	proximity_last_ms = now
	if near_door_audio.stream != null and not near_door_audio.playing: near_door_audio.play()

func _animate_door(opening: bool) -> void:
	if not is_instance_valid(openable_door): return
	if door_tween != null and door_tween.is_running(): door_tween.kill()
	var hinge := openable_door.get_meta("hinge") as Node3D
	var body := openable_door.get_meta("body") as StaticBody3D
	if not is_instance_valid(hinge): return
	openable_door.set_meta("opened",opening)
	# Never swing a solid collider through the player's capsule.
	if is_instance_valid(body):
		body.collision_layer = 0
		body.collision_mask = 0
	door_tween = create_tween()
	door_tween.tween_property(hinge, "rotation:y", -1.44 if opening else 0.0, 0.56 if opening else 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not opening and is_instance_valid(body):
		door_tween.finished.connect(func():
			if is_instance_valid(body) and door_slammed and not lab_power_restored and visible:
				body.collision_layer = 1
				body.collision_mask = 1)

func update_visitor(player_position: Vector3) -> bool:
	if not laboratory_entered or door_slammed or player_position.x < 5.8: return false
	door_slammed = true
	lab_power_failed = true
	_animate_door(false)
	if is_instance_valid(slam_audio):
		slam_audio.global_position = openable_door.global_position
		if slam_audio.stream != null: slam_audio.play()
	if is_instance_valid(lab_central_light):
		var flicker := create_tween()
		flicker.tween_property(lab_central_light,"light_energy",0.0,0.16)
		flicker.tween_property(lab_central_light,"light_energy",0.8,0.10)
		flicker.tween_property(lab_central_light,"light_energy",0.05,0.15)
	if is_instance_valid(lab_emergency_light):
		lab_emergency_light.light_color = Color(1.0,0.13,0.09)
		lab_emergency_light.light_energy = 0.66
	return true

func door_result(player_position: Vector3) -> String:
	if laboratory_entered and lab_power_failed and not lab_power_restored and player_position.distance_to(backup_panel_position) < 2.15:
		lab_power_restored = true
		lab_power_failed = false
		if is_instance_valid(lab_central_light):
			create_tween().tween_property(lab_central_light,"light_energy",1.8,0.75)
		if is_instance_valid(lab_emergency_light):
			lab_emergency_light.light_color = Color(0.52,0.83,0.71)
			lab_emergency_light.light_energy = 1.2
		_animate_door(true)
		if is_instance_valid(near_door_audio) and near_door_audio.stream != null:
			near_door_audio.global_position = backup_panel_position
			near_door_audio.play()
		return "POWER"
	if not flashlight_collected and player_position.distance_to(flashlight_pickup_position) < 1.55:
		if not is_instance_valid(flashlight_world): return "NONE"
		flashlight_collected = true
		flashlight_world.visible = false
		if is_instance_valid(pickup_audio) and pickup_audio.stream != null:
			pickup_audio.global_position = flashlight_pickup_position
			pickup_audio.play()
		return "FLASHLIGHT"
	var door := nearest_door(player_position,2.2)
	if door == null: return "NONE"
	if door == openable_door:
		if laboratory_entered: return "OPENED"
		laboratory_entered = true
		_build_laboratory()
		_animate_door(true)
		if is_instance_valid(near_door_audio) and near_door_audio.stream != null:
			near_door_audio.global_position = door.global_position
			near_door_audio.play()
		return "OPEN"
	if is_instance_valid(door_audio) and door_audio.stream != null:
		door_audio.global_position = door.global_position
		if not door_audio.playing: door_audio.play()
	return "LOCK"

func try_locked_door(player_position: Vector3) -> bool:
	var door := nearest_door(player_position,2.2)
	if door == null: return false
	if is_instance_valid(door_audio):
		door_audio.global_position = door.global_position
		if door_audio.stream != null: door_audio.play()
	return true

func _finish(color: Color, photo: String = "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.28
	m.roughness = 0.77
	if photo != "":
		var file := Assets.path("vendor/"+photo)
		if ResourceLoader.exists(file): m.albedo_texture = load(file)
	return m

func _module(source: String, at: Vector3, material: StandardMaterial3D, dimensions: Vector3) -> void:
	var name := "vendor/wakeup_"+source+".glb"
	if not ResourceLoader.exists(Assets.path(name)):
		push_error("Licensed facility GLB missing: "+name)
		return
	var model := Assets.fitted(name,dimensions.y)
	model.name = "Kenney_CC0_"+source
	model.position = at
	var source_dims: Vector3 = model.get_meta("dimensions",Vector3.ONE)
	model.scale = Vector3(
		dimensions.x / maxf(source_dims.x,0.01),
		dimensions.y / maxf(source_dims.y,0.01),
		dimensions.z / maxf(source_dims.z,0.01)
	)
	# Keep author-created mesh, only tint it to consistent desaturated concrete.
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).material_override = material
	if is_instance_valid(module_target): module_target.add_child(model)
	else: add_child(model)
	authored_modules += 1

func _exit_tree() -> void:
	for source in [low_rumble, far_clang, smiler_sound, door_audio, near_door_audio, slam_audio, pickup_audio]:
		if is_instance_valid(source):
			source.stop()
			source.stream = null
