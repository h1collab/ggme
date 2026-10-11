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
	# Required licensed Smiler: an authored external Sketchfab GLB, not code geometry.
	var smiler_path := Assets.path("vendor/sketchfab_smiler.glb")
	if not ResourceLoader.exists(smiler_path):
		push_error("Missing authorized Sketchfab Smiler GLB: "+smiler_path)
	else:
		smiler = Assets.fitted("vendor/sketchfab_smiler.glb",1.65)
		smiler.name = "SketchfabSmiler_SilentWatcher"
		smiler.position = Vector3(0,0,-6.2)
		add_child(smiler)
		smiler.visible = false
		for mesh in smiler.find_children("*","MeshInstance3D",true,false):
			(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

func _barrier(at: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.position = at
	collision.shape = shape
	walkable_floor.add_child(collision)

func smiler_stage(distance_t: float, stage: String) -> void:
	if not is_instance_valid(smiler): return
	smiler.visible = stage != "hidden"
	if stage == "watch":
		smiler.position = Vector3(0,0,-6.2)
		smiler.rotation.y = 0
	elif stage == "rush":
		smiler.position = Vector3(0,0,lerpf(-6.2,2.1,smoothstep(0.0,1.0,distance_t)))
		smiler.rotation.y = 0

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
	for source in [low_rumble, far_clang]:
		if is_instance_valid(source):
			source.stop()
			source.stream = null
