extends Node3D

# A contained film-set room for the new opening and title screen.
# Every visible surface and prop comes from the existing redistributable
# Huuxloc (CC BY 4.0), Poly Haven (CC0) and Cesium (CC BY 4.0) GLBs.
# No BoxMesh/primitive visible geometry and no additional network state.
const Assets = preload("backrooms_assets.gd")
const PHONE_AT := Vector3(0.15, 0.795, -0.45)
const CAMERA_FAR := Vector3(2.85, 2.32, 2.85)
const CAMERA_NEAR := Vector3(0.72, 1.33, 0.54)

var game: Node
var authored_piece_count := 0
var authored_prop_count := 0
var desk: Node3D

func _ready() -> void:
	name = "OtherShiftRoom_IndependentSet"
	if not is_instance_valid(game) or not is_instance_valid(game.level):
		push_error("The Other Shift room requires the imported licensed GLB mesh catalog")
		return
	var meshes: Dictionary = game.level.architecture_meshes
	var wall := _surface(Color(0.32, 0.36, 0.34), "concrete.jpg")
	var floor_material := _surface(Color(0.30, 0.28, 0.25), "carpet.jpg")
	var ceiling_material := _surface(Color(0.44, 0.43, 0.39), "ceiling.jpg")
	var trim := _surface(Color(0.20, 0.23, 0.22))
	_piece(meshes, "Floor", "Object_4", Vector3(0, -0.14, 0), Vector3(7.8, 0.28, 8.0), floor_material)
	_piece(meshes, "Ceiling", "Object_53", Vector3(0, 3.12, 0), Vector3(7.8, 0.16, 8.0), ceiling_material)
	for x in [-3.9, 3.9]:
		_piece(meshes, "Wall", "Object_10", Vector3(x, 1.52, 0), Vector3(0.18, 3.04, 8.0), wall)
	for z in [-4.0, 4.0]:
		_piece(meshes, "Wall", "Object_10", Vector3(0, 1.52, z), Vector3(7.8, 3.04, 0.18), wall)
	_piece(meshes, "Skirting", "Object_9", Vector3(-3.8, 0.09, 0), Vector3(0.16, 0.18, 8.0), trim)
	_piece(meshes, "Skirting", "Object_9", Vector3(3.8, 0.09, 0), Vector3(0.16, 0.18, 8.0), trim)
	desk = _prop("vendor/schooldesk.glb", Vector3(0.0, 0.0, -0.45), 0.76, 0.0, "PhoneDesk")
	_prop("vendor/schoolchair.glb", Vector3(-0.8, 0, 0.8), 0.89, -0.45, "EmptyChair")
	_prop("vendor/cabinet.glb", Vector3(-3.1, 0, -2.7), 1.75, 0.35, "SilentCabinet")
	_prop("vendor/shelf.glb", Vector3(3.08, 0, -2.3), 1.95, -0.45, "RecordsShelf")
	_prop("vendor/schoolchair.glb", Vector3(2.65, 0, 2.0), 0.89, 2.0, "WitnessSeat")
	var overhead := OmniLight3D.new()
	overhead.name = "ColdCeilingLamp"
	overhead.position = Vector3(-1.1, 2.77, -0.65)
	overhead.light_color = Color(0.75, 0.86, 0.84)
	overhead.light_energy = 0.86
	overhead.omni_range = 6.9
	overhead.shadow_enabled = false
	add_child(overhead)
	var desk_light := SpotLight3D.new()
	desk_light.name = "PhoneCloseupLight"
	desk_light.position = Vector3(1.75, 2.57, 0.85)
	desk_light.light_color = Color(0.92, 0.77, 0.61)
	desk_light.light_energy = 0.48
	desk_light.spot_range = 4.7
	desk_light.spot_angle = 48
	desk_light.shadow_enabled = false
	add_child(desk_light)
	# Godot look_at() requires the node to have entered the scene tree.
	desk_light.look_at(PHONE_AT, Vector3.UP)

func _surface(color: Color, photo: String = "") -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.89
	if photo != "":
		var file: String = Assets.path("vendor/" + photo)
		if ResourceLoader.exists(file):
			material.albedo_texture = load(file)
	return material

func _piece(meshes: Dictionary, role: String, key: String, at: Vector3, dimensions: Vector3, material: Material) -> void:
	if not meshes.has(key):
		push_error("Missing licensed room mesh " + key)
		return
	var authored: Mesh = meshes[key]
	var bounds: AABB = authored.get_aabb()
	var extent: Vector3 = bounds.size
	var view := MeshInstance3D.new()
	view.name = "OpeningLicensedGLB_" + role
	view.mesh = authored
	view.material_override = material
	view.set_meta("visual_source", "Huuxloc_CC_BY_4.0_" + key)
	var horizontal := role == "Wall" or role == "Skirting"
	var rotate_side := horizontal and dimensions.x > dimensions.z
	view.rotation.y = PI * 0.5 if rotate_side else 0.0
	if horizontal:
		var thickness := minf(dimensions.x, dimensions.z)
		var length := maxf(dimensions.x, dimensions.z)
		view.scale = Vector3(thickness / maxf(0.01, extent.x), dimensions.y / maxf(0.01, extent.y), length / maxf(0.01, extent.z))
	else:
		view.scale = Vector3(dimensions.x / maxf(0.01, extent.x), dimensions.y / maxf(0.01, extent.y), dimensions.z / maxf(0.01, extent.z))
	view.position = at + (-bounds.get_center() * view.scale).rotated(Vector3.UP, view.rotation.y)
	add_child(view)
	authored_piece_count += 1

func _prop(file: String, at: Vector3, height: float, rotation: float, label: String) -> Node3D:
	if not ResourceLoader.exists(Assets.path(file)):
		push_error("Missing authored GLB opening furniture: " + file)
		return null
	var prop: Node3D = Assets.fitted(file, height)
	prop.name = label
	prop.position = at
	prop.rotation.y = rotation
	add_child(prop)
	authored_prop_count += 1
	return prop
