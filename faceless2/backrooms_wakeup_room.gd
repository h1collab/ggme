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
		_module("wall",Vector3(3.8,1.55,z),concrete,Vector3(0.22,3.1,1.5))
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
	for x in [-3.0,-1.5,0.0,1.5,3.0]:
		_module("wall",Vector3(x,1.55,-10.0),_finish(Color(0.025,0.035,0.04)),Vector3(1.5,3.1,0.3))
	_module("wall_door",Vector3(0,1.55,-9.75),industrial,Vector3(1.6,3.1,0.3))
	# Imported Kenney door meshes are visible; collision is invisible and cheap.
	for door_at in [Vector3(-3.40,1.3,1.4),Vector3(3.40,1.3,-0.9),Vector3(-3.40,1.3,-4.5),Vector3(3.40,1.3,-6.4)]:
		var door := _authored_door(door_at)
		if door != null: side_doors.append(door)
	# The interactive body has a simple invisible physical floor and perimeter.
	walkable_floor = StaticBody3D.new()
	walkable_floor.name = "InvisibleFacilityPhysics"
	add_child(walkable_floor)
	_barrier(Vector3(0,-0.17,-3.0),Vector3(7.4,0.30,14.7))
	_barrier(Vector3(-3.8,1.45,-3.0),Vector3(0.35,3.0,14.8))
	_barrier(Vector3(3.8,1.45,-3.0),Vector3(0.35,3.0,14.8))
	_barrier(Vector3(0,1.45,-10.1),Vector3(7.6,3.0,0.35))
	_barrier(Vector3(0,1.45,4.1),Vector3(7.6,3.0,0.35))
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

func _authored_door(at: Vector3) -> Node3D:
	var source := Assets.path("vendor/wakeup_door_single_closed.glb")
	if not ResourceLoader.exists(source): return null
	var node := Assets.fitted("vendor/wakeup_door_single_closed.glb",2.35)
	node.name = "KenneyAuthoredInteractiveDoor"
	node.position = at
	node.rotation.y = PI * 0.5 if at.x < 0 else -PI * 0.5
	add_child(node)
	return node

func set_physics_active(enabled: bool) -> void:
	if not is_instance_valid(walkable_floor): return
	walkable_floor.collision_layer = 1 if enabled else 0
	walkable_floor.collision_mask = 1 if enabled else 0

func _barrier(at: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.position = at
	collision.shape = shape
	walkable_floor.add_child(collision)

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
	if near_door_audio.stream != null: near_door_audio.play()

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
	add_child(model)
	authored_modules += 1

func _exit_tree() -> void:
	for source in [low_rumble, far_clang, smiler_sound, door_audio, near_door_audio]:
		if is_instance_valid(source):
			source.stop()
			source.stream = null
