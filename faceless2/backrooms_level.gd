extends Node3D
const Assets = preload("backrooms_assets.gd")

# Architectural dimensions in metres. All walkable surfaces have matching physics.
var index := 0
var fixtures: Array = []
var doors: Array = []
var relay_visuals: Array = []
var cameras: Array = []
var relays: Array[Vector3] = []
var console_position := Vector3(0, 0, 6)
var exit_position := Vector3(0, 0, -27)
var spawn := Vector3(0, 0.05, 9)
var lamp_material: StandardMaterial3D
var wall_material: ShaderMaterial
var floor_material: ShaderMaterial
var pool_water: MeshInstance3D
var water_material: ShaderMaterial
var water_materials: Array[ShaderMaterial] = []
var wet_regions: Array[Rect2] = []
var water_clock := 0.0
var ripple_buffer: Array[Vector4] = []
var splash_particles: CPUParticles3D
var lift_left: MeshInstance3D
var lift_right: MeshInstance3D
var lift_lamp: OmniLight3D
var lift_cab: Node3D
var lift_indicator: Label3D
var shaft_markers: Array[Node3D] = []
var lift_progress := 0.0
var title := ""
var subtitle := ""
var architecture_meshes: Dictionary = {}
var shadow_refresh := 0.0
var shadow_focus := Vector3(999, 999, 999)

func build(level: int) -> void:
	index = level
	name = "AuthenticGLBArchitecture"
	_load_architecture()
	title = ["FACELESS 2 / 失联楼层", "FACELESS 2 / 地下回声", "FACELESS 2 / 静水之下"][index]
	subtitle = ["走廊里没有出口。", "脚步比你晚半拍。", "水里有不属于你的倒影。"][index]
	wall_material = _surface(0)
	floor_material = _surface(1)
	var ceiling := _surface(2)
	lamp_material = _plain(Color(0.91, 0.89, 0.72), 0.7)
	lamp_material.emission_enabled = true
	lamp_material.emission = Color(0.95, 0.87, 0.66) if index == 0 else Color(0.71, 0.87, 0.92)
	lamp_material.emission_energy_multiplier = 1.2
	for x in [-10.0, 0.0, 10.0]:
		for z in [7.8, -0.6, -9.0, -17.4, -25.8]:
			_box("Floor", Vector3(x, -0.15, z), Vector3(10, 0.3, 8.4), floor_material, true)
			_box("Ceiling", Vector3(x, 3.45, z), Vector3(10, 0.18, 8.4), ceiling, true)
	for x in [-15.0, 15.0]:
		_wall(Vector3(x, 1.7, -9), Vector3(0.25, 3.4, 42))
	for z in [12.0, -30.0]:
		_wall(Vector3(0, 1.7, z), Vector3(30, 3.4, 0.25))
	# A central passage with repeated connected rooms, not disconnected showcase boxes.
	for z in [2.0, -9.0, -20.0]:
		for x in [-9.0, 9.0]:
			_wall(Vector3(x, 1.7, z), Vector3(12, 3.4, 0.22))
	for z in [-3.5, -14.5, -25.0]:
		for x in [-3.0, 3.0]:
			_wall(Vector3(x, 1.7, z), Vector3(0.24, 3.4, 4.8))
	# Columns create varied sight lines, while retaining at least 2.4 m clearance.
	for z in [-3.5, -14.5, -25.0]:
		for x in [-11.4, 11.4]:
			_wall(Vector3(x, 1.7, z), Vector3(0.75, 3.4, 0.75))
	for z in [7.0, -4.0, -15.0, -25.5]:
		for x in [-9.0, 0.0, 9.0]:
			_fixture(Vector3(x, 3.28, z), 0 if z > -9 else (1 if z > -20 else 2))
	_console()
	# There is no FNAF shutter control room in Faceless 2.
	# The central corridor stays open so the player can explore freely.
	relays.assign([Vector3(-12.8, 0, -5), Vector3(12.8, 0, -16), Vector3(-12.8, 0, -26.5)])
	for i in range(3): _relay(i)
	cameras.clear()
	_exit()
	if index == 1: _service_details()
	elif index == 2: _pool_details()
	else: _office_details()
	_water_details()
	_external_props()

func _load_architecture() -> void:
	architecture_meshes.clear()
	var source_path := Assets.path("vendor/huuxloc_backroom.glb")
	if not ResourceLoader.exists(source_path): return
	var scene: PackedScene = load(source_path)
	var source := scene.instantiate()
	for mesh in source.find_children("*", "MeshInstance3D", true, false):
		# Authored 3D meshes: walls/skirting, carpet and gridded ceiling.
		# They share immutable GPU mesh resources across the whole level.
		if mesh.mesh != null: architecture_meshes[String(mesh.name)] = mesh.mesh
	source.free()

func _architectural_mesh(label: String, dimensions: Vector3) -> MeshInstance3D:
	# Every visible static surface is a mesh authored in Huuxloc's CC BY 4.0
	# architecture GLB. No runtime BoxMesh, PlaneMesh or CylinderMesh.
	# Primitive boxes remain ONLY as invisible broad-phase collision shapes.
	var source_name := "Object_4" if label in ["Floor", "ShallowWater", "LiftThreshold", "AudioFrequencyDisplay", "Diffuser"] else ("Object_53" if label == "Ceiling" else ("Object_9" if label == "Skirting" else ("Object_10" if label in ["Wall", "LiftDoorLeft", "LiftDoorRight", "LiftBack"] else "Object_68")))
	if not architecture_meshes.has(source_name):
		push_error("Required licensed GLB mesh missing: " + source_name)
		return null
	var view := MeshInstance3D.new()
	view.name = "LicensedGLB_%s" % label
	view.mesh = architecture_meshes[source_name]
	view.set_meta("visual_source", "Huuxloc_CC_BY_4.0_" + source_name)
	var bound: AABB = view.mesh.get_aabb()
	var extent: Vector3 = bound.size
	var horizontal := label in ["Wall", "Skirting"] and dimensions.x > dimensions.z
	view.rotation.y = PI * 0.5 if horizontal else 0.0
	if label in ["Wall", "Skirting"]:
		var thick := minf(dimensions.x, dimensions.z)
		var along := maxf(dimensions.x, dimensions.z)
		view.scale = Vector3(thick / maxf(0.01, extent.x), dimensions.y / maxf(0.01, extent.y), along / maxf(0.01, extent.z))
	else:
		view.scale = Vector3(dimensions.x / maxf(0.01, extent.x), dimensions.y / maxf(0.01, extent.y), dimensions.z / maxf(0.01, extent.z))
	view.position = (-bound.get_center() * view.scale).rotated(Vector3.UP, view.rotation.y)
	return view

func _surface(kind: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform int theme = 0;
uniform int surface = 0;
uniform sampler2D surface_photo: source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D photo_normal: hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D photo_rough: filter_linear_mipmap, repeat_enable;
uniform bool photo_enabled = false;
uniform bool concrete_pbr = false;
varying vec3 world;
varying vec3 world_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 p = surface!=0 || abs(world_normal.y)>0.5 ? world.xz : (abs(world_normal.x)>0.5 ? world.zy : world.xy);
 float broad=noise(p*1.7)*0.5+noise(p*5.1)*0.25+noise(p*17.0)*0.25;
 float grain=noise(p*63.0);
 vec3 col=vec3(0.52,0.47,0.26); float rough=0.93;
 if(theme==0){
  if(surface==0){float stripe=pow(abs(sin(p.x*34.0)),12.0);col=mix(vec3(0.53,0.47,0.28),vec3(0.62,0.56,0.36),broad)*mix(0.95,1.0,stripe);col*=1.0-0.2*(1.0-smoothstep(0.0,0.65,world.y));}
  if(surface==1){col=mix(vec3(0.24,0.21,0.14),vec3(0.34,0.30,0.2),broad);col*=mix(0.93,1.06,grain);}
 }else if(theme==1){col=mix(vec3(0.28,0.30,0.29),vec3(0.42,0.43,0.40),broad);if(surface==1){col*=0.67;rough=0.88;}}
 else {vec2 tile=fract(p*2.0);float aa=max(fwidth(p.x),fwidth(p.y))*2.0;float grout=smoothstep(0.025-aa,0.025+aa,min(tile.x,tile.y))*smoothstep(0.025-aa,0.025+aa,1.0-max(tile.x,tile.y));col=mix(vec3(0.35,0.42,0.41),vec3(0.70,0.79,0.76),grout)*(0.97+broad*0.04);rough=surface==1?0.38:0.5;}
 if(surface==2 && theme==0){vec2 tile=fract(p*1.667);float seam=step(0.02,min(tile.x,tile.y))*step(max(tile.x,tile.y),0.98);col=mix(vec3(0.25),vec3(0.60,0.59,0.53),seam);}
 if(surface==2 && theme==1){col*=0.73;}
 if(photo_enabled){col=texture(surface_photo,p*0.5).rgb*(0.90+broad*0.10);if(theme==0 && surface==0){col*=vec3(0.90,0.86,0.69);}}
 ALBEDO=col;ROUGHNESS=rough;SPECULAR=theme==2?0.2:0.06;
 NORMAL_MAP=vec3(0.5+(grain-0.5)*0.035,0.5+(noise(p.yx*60.0)-0.5)*0.035,1.0);
 if(concrete_pbr){NORMAL_MAP=texture(photo_normal,p*0.5).rgb;ROUGHNESS=texture(photo_rough,p*0.5).r;}
}"""
	material.shader = shader
	material.set_shader_parameter("theme", index)
	material.set_shader_parameter("surface", kind)
	var photos := [["wallpaper.jpg", "carpet.jpg", "ceiling.jpg"], ["concrete.jpg", "concrete.jpg", "concrete.jpg"], ["pooltile.jpg", "poolfloor.jpg", "pooltile.jpg"]]
	var photo_path := Assets.path("vendor/" + photos[index][kind])
	if ResourceLoader.exists(photo_path):
		material.set_shader_parameter("surface_photo", load(photo_path))
		material.set_shader_parameter("photo_enabled", true)
	if index == 1 and ResourceLoader.exists(Assets.path("vendor/concrete_normal.jpg")):
		material.set_shader_parameter("photo_normal", load(Assets.path("vendor/concrete_normal.jpg")))
		material.set_shader_parameter("photo_rough", load(Assets.path("vendor/concrete_rough.jpg")))
		material.set_shader_parameter("concrete_pbr", true)
	return material

func _external_props() -> void:
	var placements := [
		["schooldesk.glb", Vector3(-8,0,-7.1), 0.76, 0.0],
		["schooldesk.glb", Vector3(8,0,-7.1), 0.76, PI],
		["schoolchair.glb", Vector3(-8,0,6), 0.9, 0.3],
		["schoolchair.glb", Vector3(-12,0,-12), 0.9, -0.4],
		["cabinet.glb", Vector3(13.7,0,7), 1.2, -PI/2],
		["shelf.glb", Vector3(-13.7,0,-17), 2.0, PI/2]]
	if index != 1:
		# A real licensed cabinet occludes the creature's torso; only its face
		# briefly peeks over the furniture in the dark side aisle.
		placements.append(["cabinet.glb", Vector3(-4.22, 0, -7.48), 1.42, PI / 2])
	if index == 1:
		placements.append(["barrel.glb",Vector3(10.8,0,-26.7),0.95,0.0])
		placements.append(["barrel.glb",Vector3(10.0,0,-25.3),0.95,0.3])
	var prop_id := 0
	for item in placements:
		var file: String = "vendor/" + item[0]
		if not ResourceLoader.exists(Assets.path(file)): continue
		var body := StaticBody3D.new()
		body.name = "ScannedProp_%02d_%s" % [prop_id, item[0].trim_suffix(".glb")]
		prop_id += 1
		body.position = item[1]
		body.rotation.y = item[3]
		add_child(body)
		var model := Assets.fitted(file, item[2])
		body.add_child(model)
		var shape := BoxShape3D.new()
		shape.size = model.get_meta("dimensions")
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = shape.size.y * 0.5
		body.add_child(collision)

func _plain(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic_specular = 0.15
	return material

func _box(label: String, pos: Vector3, dimensions: Vector3, material: Material, solid: bool) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = label
	body.position = pos
	add_child(body)
	var mesh := _architectural_mesh(label, dimensions)
	if mesh != null:
		mesh.material_override = material
		body.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new() # Invisible collision proxy, not a visible mesh.
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)
	return body

func _wall(pos: Vector3, dimensions: Vector3) -> void:
	_box("Wall", pos, dimensions, wall_material, true)
	var trim := _plain(Color(0.25, 0.23, 0.15) if index == 0 else Color(0.19, 0.23, 0.23), 0.93)
	_box("Skirting", Vector3(pos.x, 0.08, pos.z), Vector3(dimensions.x + 0.04, 0.16, dimensions.z + 0.04), trim, false)

func _fixture(pos: Vector3, channel: int) -> void:
	_box("FluorescentHousing", pos, Vector3(1.5, 0.1, 0.5), _plain(Color(0.31, 0.32, 0.27)), false)
	var diffuser := _box("Diffuser", pos + Vector3(0, -0.06, 0), Vector3(1.36, 0.015, 0.37), lamp_material.duplicate(), false)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, -0.3, 0)
	light.light_color = Color(1.0, 0.91, 0.73) if index == 0 else Color(0.77, 0.89, 0.96)
	light.light_energy = 1.15 if index == 0 else 1.4
	light.omni_range = 9.2
	light.omni_attenuation = 1.2
	# Only the console lights cast shadows; limited budget on Android Mobile.
	light.shadow_enabled = false
	add_child(light)
	fixtures.append({"light":light, "mesh":diffuser, "channel":channel})

func _sign(text: String, pos: Vector3, scale_size: float = 0.019, render_layer: int = 1) -> Label3D:
	var sign := Label3D.new()
	sign.text = text
	sign.position = pos
	sign.pixel_size = scale_size
	sign.font_size = 26
	sign.modulate = Color(0.72, 0.79, 0.7)
	sign.outline_size = 0
	sign.no_depth_test = false
	sign.shaded = true
	sign.layers = render_layer
	var lines := text.split("\n")
	var longest := 0
	for line in lines: longest = maxi(longest, line.length())
	var backing := _box("SignPlate", pos + Vector3(0, 0, -0.015), Vector3(longest * scale_size * 26 * 0.58 + 0.10, lines.size() * scale_size * 32 + 0.09, 0.025), _plain(Color(0.13, 0.16, 0.14)), false)
	backing.get_child(0).layers = render_layer
	add_child(sign)
	return sign

func _console() -> void:
	# Authored CC0 desk and cabinet instead of a hand-built cuboid terminal.
	var desk := Assets.fitted("vendor/schooldesk.glb", 0.89)
	desk.name = "LicensedInvestigationDesk"
	desk.position = console_position
	desk.rotation.y = PI
	add_child(desk)
	var monitor := Assets.fitted("vendor/cabinet.glb", 0.65)
	monitor.name = "LicensedFieldArchive"
	monitor.position = console_position + Vector3(1.2, 0, -0.3)
	add_child(monitor)
	_sign("INVESTIGATION / EVIDENCE LOG", Vector3(0, 1.53, 5.7), 0.008)

func _relay(i: int) -> void:
	# Each objective is a *different physical investigation object*, never
	# three identical phone-repair boxes. All meshes are licensed external GLBs.
	var p := relays[i]
	var files := ["schooldesk.glb", "cabinet.glb", "barrel.glb"]
	var heights := [0.86, 1.31, 1.06]
	var body := Node3D.new()
	body.name = "LicensedEvidence_%d" % i
	body.position = p
	add_child(body)
	var object: Node3D = Assets.fitted("vendor/" + files[i], heights[i])
	object.name = "OriginalGLB_%s" % files[i]
	body.add_child(object)
	var status := _plain(Color(0.73, 0.33, 0.11))
	status.emission_enabled = true
	status.emission = status.albedo_color
	status.emission_energy_multiplier = 0.75
	var lamp: Node3D = _box("EvidenceIndicator", p + Vector3(0, heights[i] + 0.08, 0), Vector3(0.16, 0.025, 0.11), status, false)
	relay_visuals.append(lamp.get_child(0))
	_sign(["EVIDENCE / ARCHIVE", "EVIDENCE / WATERMARK", "EVIDENCE / SIGNAL"][i], p + Vector3(0, heights[i] + 0.45, 0), 0.007)

func _exit() -> void:
	# A real six-second lift scene is shared by host/client state; player camera
	# control remains LOCAL, never transmitted as a forced look RPC.
	var frame := _plain(Color(0.19, 0.24, 0.24), 0.53)
	var brushed := _plain(Color(0.35, 0.39, 0.37), 0.38)
	var dark := _plain(Color(0.095, 0.14, 0.15), 0.67)
	lift_cab = Node3D.new()
	lift_cab.name = "AnimatedLiftCabin"
	add_child(lift_cab)
	_box("LiftBack", Vector3(0, 1.45, -29.54), Vector3(2.5, 2.9, 0.09), dark, false)
	for x in [-1.45, 1.45]:
		_box("LiftJamb", Vector3(x, 1.55, -28.94), Vector3(0.20, 3.1, 1.35), frame, true)
		_box("LiftCabinWall", Vector3(x * 0.85, 1.48, -28.82), Vector3(0.06, 2.85, 1.25), brushed, false)
	_box("LiftLintel", Vector3(0, 3.03, -28.93), Vector3(3.06, 0.15, 1.2), frame, false)
	_box("LiftThreshold", Vector3(0, 0.017, -28.91), Vector3(2.7, 0.035, 1.48), brushed, false)
	lift_left = _box("LiftDoorLeft", Vector3(-0.62, 1.47, -28.25), Vector3(1.24, 2.82, 0.06), brushed, false).get_child(0)
	lift_right = _box("LiftDoorRight", Vector3(0.62, 1.47, -28.25), Vector3(1.24, 2.82, 0.06), brushed, false).get_child(0)
	# Narrow seams and a lit floor indicator, without per-frame shadows.
	_box("LiftCentreRail", Vector3(0, 2.92, -28.20), Vector3(0.017, 0.12, 0.012), frame, false)
	lift_lamp = OmniLight3D.new()
	lift_lamp.name = "LiftInteriorLight"
	lift_lamp.position = Vector3(0, 2.65, -28.83)
	lift_lamp.light_color = Color(0.67, 0.86, 0.77)
	lift_lamp.light_energy = 0.18
	lift_lamp.omni_range = 3.6
	lift_lamp.shadow_enabled = false
	add_child(lift_lamp)
	_sign("LIFT  /  LEVEL %02d" % (index + 1), Vector3(0, 3.17, -28.20), 0.010)
	lift_indicator = Label3D.new()
	lift_indicator.name = "InteriorFloorDisplay"
	lift_indicator.text = "L%02d / WAIT" % (index + 1)
	lift_indicator.position = Vector3(0, 2.34, -28.31)
	lift_indicator.rotation.y = PI
	lift_indicator.pixel_size = 0.0042
	lift_indicator.font_size = 43
	lift_indicator.modulate = Color(0.67, 0.96, 0.81)
	lift_indicator.outline_size = 0
	lift_indicator.shaded = false
	add_child(lift_indicator)
	# Scrolling slit lights appear through a narrow rear shaft window.
	# These give a strong descent cue without moving collision bodies or
	# requiring a real-time reflection or second off-screen environment.
	var marker_mat := _plain(Color(0.12, 0.30, 0.34), 0.5)
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(0.05, 0.22, 0.23)
	marker_mat.emission_energy_multiplier = 0.8
	for i in range(5):
		var marker: Node3D = _box("PassingShaftLight", Vector3(1.08, 0.6 + float(i) * 0.45, -29.38), Vector3(0.06, 0.08, 0.026), marker_mat, false)
		shaft_markers.append(marker)
	animate_lift(0.0)

func animate_lift(t: float) -> void:
	lift_progress = t
	if not is_instance_valid(lift_left): return
	# Approach -> doors slide -> board -> close -> physical elevator shake.
	var opening := smoothstep(0.0, 1.15, t)
	var closing := smoothstep(2.15, 3.3, t)
	var gap := maxf(0.0, opening - closing)
	lift_left.position.x = -1.06 * gap
	lift_right.position.x = 1.06 * gap
	lift_lamp.light_energy = 0.18 + 0.85 * gap + (0.1 * sin(t * 24.0) if t > 3.2 else 0.0)
	# Passing shaft markers and a changing floor readout imply downward
	# acceleration; collision geometry stays static for safe P2P gameplay.
	if is_instance_valid(lift_indicator):
		lift_indicator.text = "L%02d / ↓  %02dm" % [index + 1, int(maxf(t - 3.2, 0.0) * 9.0)] if t > 3.2 else ("L%02d / BOARD" % (index + 1) if gap > 0.04 else "L%02d / WAIT" % (index + 1))
	for i in range(shaft_markers.size()):
		shaft_markers[i].position.y = 0.45 + fposmod((float(i) * 0.52) + maxf(t - 3.2, 0.0) * 2.1, 2.2)
	lift_cab.position.y = (sin(t * 18.0) * 0.012 if t > 3.25 else 0.0)

func add_water_step(at: Vector3) -> bool:
	if index != 2 or not is_instance_valid(pool_water): return false
	if at.z < -18.3 or at.z > -10.9: return false
	if not ((-11.5 < at.x and at.x < -4.5) or (4.5 < at.x and at.x < 11.5)): return false
	# Ring impulses are capped; shader loops over eight uniforms without
	# allocating meshes, particle systems or textures on each step.
	ripple_buffer.push_front(Vector4(at.x, at.z, water_clock, 0.86))
	if ripple_buffer.size() > 8: ripple_buffer.resize(8)
	if is_instance_valid(splash_particles):
		splash_particles.position = Vector3(at.x, 0.075, at.z)
		splash_particles.restart()
	return true

func update_water(delta: float) -> void:
	if not is_instance_valid(water_material): return
	water_clock += delta
	# Expire impulses even if a player stops in the water.
	for i in range(ripple_buffer.size() - 1, -1, -1):
		if water_clock - ripple_buffer[i].z >= 2.5: ripple_buffer.remove_at(i)
	var uniforms := PackedVector4Array()
	for i in range(8): uniforms.push_back(ripple_buffer[i] if i < ripple_buffer.size() else Vector4(-100, -100, -100, 0))
	water_material.set_shader_parameter("impulses", uniforms)
	water_material.set_shader_parameter("water_seconds", water_clock)

func _office_details() -> void:
	var dirt := _plain(Color(0.27, 0.25, 0.15), 1.0)
	for i in range(16):
		var x := -14.8 if i % 2 == 0 else 14.8
		_box("WallpaperPeel", Vector3(x, 0.48, -2.0 - i * 1.7), Vector3(0.01, 0.11 + i % 3 * 0.05, 0.32), dirt, false)

func _service_details() -> void:
	# Real CC0 industrial furniture replaces procedural cylinder pipes and clamps.
	for k in range(3):
		var side := -12.0 if k % 2 == 0 else 12.0
		var z := -5.0 - float(k) * 9.5
		var storage := Assets.fitted("vendor/shelf.glb", 2.25)
		storage.name = "LicensedServiceRacking_%d" % k
		storage.position = Vector3(side, 0, z)
		storage.rotation.y = PI * 0.5 if side < 0 else -PI * 0.5
		add_child(storage)
	for z in [-5.0, -16.0, -27.0]:
		_sign("HIGH VOLTAGE / KEEP CLEAR", Vector3(9.0, 2.4, z + 7.16), 0.007)

func _pool_details() -> void:
	# The pools still have real wall-collider rims, now with authored GLB geometry.
	for x in [-8.0, 8.0]:
		for side in [-1.0, 1.0]:
			_box("PoolEdge", Vector3(x + side * 3.6, 0.10, -14.6), Vector3(0.18, 0.2, 7.8), wall_material, true)
		_sign("SHALLOW / 0.1m", Vector3(x, 2.5, -19.8), 0.012)

func _water_details() -> void:
	# Shallow flooding exists on ALL three floors. Each pool is an actual
	# GLB-authored plane with a per-zone irregular alpha edge; no new mesh.
	water_materials.clear()
	wet_regions.clear()
	ripple_buffer.clear()
	water_clock = 0.0
	water_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform float water_seconds = 0.0;
uniform vec4 impulses[8];
uniform vec2 zone_center = vec2(0.0,0.0);
uniform vec2 zone_size = vec2(1.0,1.0);
uniform float flood_depth = 0.55;
varying vec3 world_point;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float wave(vec2 p,float t){return sin(p.x*13.0+t*2.9)*0.45+sin(dot(p,vec2(5.6,8.3))-t*3.4)*0.30+sin(dot(p,vec2(-13.1,2.9))+t*1.7)*0.25;}
float rings(vec2 p){float sum=0.0;for(int i=0;i<8;i++){vec4 e=impulses[i];float age=water_seconds-e.z;if(age<0.0||age>2.5)continue;float r=length(p-e.xy);float front=r-age*1.55;sum+=e.w*sin(front*17.0)*exp(-abs(front)*7.0)*exp(-age*1.35);}return sum;}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_point.xz;
 vec2 q=(p-zone_center)/max(zone_size,vec2(0.01));
 float irregular=(noise(p*3.2)-0.5)*0.09 + (noise(p*9.1)-0.5)*0.025;
 float shoreline=max(abs(q.x),abs(q.y))+irregular;
 float coverage=1.0-smoothstep(0.36,0.51,shoreline);
 float ring=rings(p);
 float h=wave(p,water_seconds)*0.027+ring*0.065;
 float hx=wave(p+vec2(0.016,0.0),water_seconds)*0.027+rings(p+vec2(0.016,0.0))*0.065;
 float hz=wave(p+vec2(0.0,0.016),water_seconds)*0.027+rings(p+vec2(0.0,0.016))*0.065;
 vec3 n=normalize(vec3((h-hx)*30.0,1.0,(h-hz)*30.0));
 vec3 eye=normalize(CAMERA_POSITION_WORLD-world_point);
 float fresnel=pow(1.0-max(dot(n,eye),0.0),4.0);
 float wet=noise(p*0.9)*0.12;
 ALBEDO=mix(vec3(0.047,0.09,0.08),vec3(0.22,0.28,0.29),fresnel*0.64+wet)+abs(ring)*vec3(0.06,0.08,0.075);
 ROUGHNESS=mix(0.24,0.065,fresnel)+clamp(abs(ring)*0.20,0.0,0.22);
 SPECULAR=0.85;METALLIC=0.0;
 NORMAL=normalize(mat3(VIEW_MATRIX)*n);
 ALPHA=(0.46+0.40*flood_depth+0.12*fresnel)*coverage;
} """
	water_material.shader = shader
	var empty := PackedVector4Array()
	for i in range(8): empty.push_back(Vector4(-100,-100,-100,0))
	water_material.set_shader_parameter("impulses",empty)
	var pools: Array = []
	match index:
		0: pools = [Vector4(0.0,-3.2,5.4,7.0),Vector4(-8.0,-12.3,7.7,5.4),Vector4(0.0,-21.2,5.2,9.1),Vector4(8.3,6.2,8.4,5.0)]
		1: pools = [Vector4(0.0,-5.8,5.8,10.5),Vector4(8.0,-17.0,10.8,7.8),Vector4(-9.0,-24.1,9.0,8.4),Vector4(0.0,7.6,5.6,5.8)]
		2: pools = [Vector4(-8.0,-14.6,7.0,7.4),Vector4(8.0,-14.6,7.0,7.4),Vector4(0.0,-22.0,5.6,13.1),Vector4(0.0,4.0,6.4,10.3)]
	for i in range(pools.size()):
		var pool: Vector4 = pools[i]
		var mat := water_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("impulses",empty)
		mat.set_shader_parameter("zone_center",Vector2(pool.x,pool.y))
		mat.set_shader_parameter("zone_size",Vector2(pool.z,pool.w))
		mat.set_shader_parameter("flood_depth",0.58 if index==0 else (0.81 if index==1 else 1.0))
		var panel: Node3D = _box("ShallowWater",Vector3(pool.x,0.075,pool.y),Vector3(pool.z,0.012,pool.w),mat,false)
		if i==0: pool_water=panel.get_child(0) as MeshInstance3D
		water_materials.append(mat)
		wet_regions.append(Rect2(Vector2(pool.x-pool.z*0.5,pool.y-pool.w*0.5),Vector2(pool.z,pool.w)))
	water_material = water_materials[0]
	# Only one emitter is used across ALL pools. Its droplet mesh comes from
	# a Huuxloc-authored GLB support detail, never SphereMesh-generated geometry.
	splash_particles=CPUParticles3D.new()
	splash_particles.name="PuddleFootfallSpray"
	splash_particles.one_shot=true
	splash_particles.emitting=false
	splash_particles.amount=7
	splash_particles.lifetime=0.31
	splash_particles.explosiveness=1.0
	splash_particles.direction=Vector3.UP
	splash_particles.spread=50.0
	splash_particles.initial_velocity_min=0.45
	splash_particles.initial_velocity_max=1.1
	splash_particles.gravity=Vector3(0,-6.0,0)
	splash_particles.scale_amount_min=0.007
	splash_particles.scale_amount_max=0.015
	splash_particles.color=Color(0.61,0.79,0.81,0.55)
	splash_particles.mesh=architecture_meshes["Object_68"]
	add_child(splash_particles)

func add_water_step(at: Vector3) -> bool:
	if wet_regions.is_empty(): return false
	var wet := false
	for zone in wet_regions:
		if zone.has_point(Vector2(at.x,at.z)):
			wet=true
			break
	if not wet: return false
	ripple_buffer.push_front(Vector4(at.x,at.z,water_clock,0.86))
	if ripple_buffer.size()>8: ripple_buffer.resize(8)
	if is_instance_valid(splash_particles):
		splash_particles.position=Vector3(at.x,0.09,at.z)
		splash_particles.restart()
	return true

func update_water(delta: float) -> void:
	if water_materials.is_empty(): return
	water_clock+=delta
	for i in range(ripple_buffer.size()-1,-1,-1):
		if water_clock-ripple_buffer[i].z>=2.5: ripple_buffer.remove_at(i)
	var uniforms := PackedVector4Array()
	for i in range(8): uniforms.push_back(ripple_buffer[i] if i<ripple_buffer.size() else Vector4(-100,-100,-100,0))
	for mat in water_materials:
		mat.set_shader_parameter("impulses",uniforms)
		mat.set_shader_parameter("water_seconds",water_clock)

func update_state(closed: Array, lights_on: bool, anomaly: int, repaired: Array, time: float, focus: Vector3 = Vector3.ZERO, shadow_budget: int = 2) -> void:
	shadow_refresh += get_process_delta_time()
	if shadow_refresh >= 0.35 or shadow_focus.distance_to(focus) > 3.0:
		shadow_refresh = 0
		shadow_focus = focus
		var ordered := fixtures.duplicate()
		ordered.sort_custom(func(a, b): return a.light.position.distance_squared_to(focus) < b.light.position.distance_squared_to(focus))
		for i in range(ordered.size()):
			var light: OmniLight3D = ordered[i].light
			var should_shadow := i < shadow_budget and light.position.distance_squared_to(focus) < 150.0
			if light.shadow_enabled != should_shadow: light.shadow_enabled = should_shadow
	for i in range(doors.size()):
		doors[i].position.y = lerpf(doors[i].position.y, 1.3 if closed[i] else 4.3, 0.18)
	for fixture in fixtures:
		var light: OmniLight3D = fixture.light
		var unstable: bool = fixture.channel == anomaly
		var diffuser: MeshInstance3D = fixture.mesh.get_child(0)
		var material: StandardMaterial3D = diffuser.material_override
		material.emission_energy_multiplier = (1.2 if lights_on else 0.1) * (0.1 if unstable and fmod(time, 1.6) < 0.8 else 1.0)
		light.light_energy = (1.15 if index == 0 else 1.4) * (0.22 if not lights_on else 1.0) * (0.25 if unstable and fmod(time, 1.6) < 0.8 else 1.0)
	for i in range(3):
		var mat: StandardMaterial3D = relay_visuals[i].material_override
		mat.albedo_color = Color(0.18, 0.63, 0.40) if repaired[i] else Color(0.68, 0.31, 0.1)
		mat.emission = mat.albedo_color

