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
	var source_name := "Object_4" if label == "Floor" else ("Object_53" if label == "Ceiling" else ("Object_9" if label == "Skirting" else "Object_10"))
	if not architecture_meshes.has(source_name): return null
	var view := MeshInstance3D.new()
	view.name = "LicensedGLB_%s" % label
	view.mesh = architecture_meshes[source_name]
	var bound := view.mesh.get_aabb()
	var extent: Vector3 = bound.size
	var horizontal := label in ["Wall", "Skirting"] and dimensions.x > dimensions.z
	view.rotation.y = PI * 0.5 if horizontal else 0.0
	if label in ["Wall", "Skirting"]:
		var thick := minf(dimensions.x, dimensions.z)
		var along := maxf(dimensions.x, dimensions.z)
		view.scale = Vector3(thick / maxf(0.01, extent.x), dimensions.y / maxf(0.01, extent.y), along / maxf(0.01, extent.z))
	else:
		view.scale = Vector3(dimensions.x / maxf(0.01, extent.x), 1.0, dimensions.z / maxf(0.01, extent.z))
	var local_center := -bound.get_center() * view.scale
	view.position = local_center.rotated(Vector3.UP, view.rotation.y)
	if label == "Floor": view.position.y += dimensions.y * 0.5
	if label == "Ceiling": view.position.y -= dimensions.y * 0.5
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
	var mesh: MeshInstance3D = null
	if label in ["Floor", "Ceiling", "Wall", "Skirting"]: mesh = _architectural_mesh(label, dimensions)
	if mesh == null:
		mesh = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = dimensions
		mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	if solid:
		# Single primitive collision proxy, not a per-triangle mesh: cheap on phones.
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
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
	var enamel := _plain(Color(0.11, 0.17, 0.18), 0.85)
	_box("AbandonedReceiver", Vector3(0, 0.48, 6), Vector3(1.15, 0.95, 0.6), enamel, true)
	var glass := _plain(Color(0.08, 0.22, 0.17), 0.48)
	glass.emission_enabled = true
	glass.emission = Color(0.04, 0.13, 0.09)
	_box("AudioFrequencyDisplay", Vector3(0, 0.9, 5.67), Vector3(0.72, 0.25, 0.02), glass, false)
	_sign("RECORDINGS / SIGNAL LOST", Vector3(0, 1.6, 5.78), 0.008)

func _relay(i: int) -> void:
	var p := relays[i]
	var cabinet := _box("MemoryRecorder", p + Vector3(0, 0.95, 0), Vector3(0.65, 1.45, 0.4), _plain(Color(0.22, 0.27, 0.27), 0.65), true)
	for y in [0.4, 0.7, 1.0]:
		_box("VentSlot", p + Vector3(0, y + 0.4, 0.208), Vector3(0.42, 0.025, 0.015), _plain(Color(0.05, 0.07, 0.07)), false)
	var status := _plain(Color(0.68, 0.31, 0.1))
	status.emission_enabled = true
	status.emission = status.albedo_color
	var led := _box("BreakerStatus", p + Vector3(0.18, 1.4, 0.21), Vector3(0.05, 0.06, 0.02), status, false)
	relay_visuals.append(led.get_child(0))
	_sign("TAPE %02d" % (i + 1), p + Vector3(0, 1.8, 0), 0.008)
	cabinet.set_meta("relay", i)

func _exit() -> void:
	_box("LiftFrame", Vector3(0, 1.4, -29.5), Vector3(2.8, 2.8, 0.2), _plain(Color(0.18, 0.21, 0.2), 0.65), true)
	for x in [-0.6, 0.6]:
		_box("LiftDoor", Vector3(x, 1.3, -29.36), Vector3(1.17, 2.55, 0.05), _plain(Color(0.36, 0.4, 0.37), 0.63), false)
	_sign("EXIT / %02d" % (index + 1), Vector3(0, 3.0, -29.2), 0.014)
	_sign("AUTHORIZED PERSONNEL", Vector3(0, 1.9, -29.28), 0.006)

func _office_details() -> void:
	var dirt := _plain(Color(0.27, 0.25, 0.15), 1.0)
	for i in range(16):
		var x := -14.8 if i % 2 == 0 else 14.8
		_box("WallpaperPeel", Vector3(x, 0.48, -2.0 - i * 1.7), Vector3(0.01, 0.11 + i % 3 * 0.05, 0.32), dirt, false)

func _service_details() -> void:
	var pipe_mat := _plain(Color(0.23, 0.28, 0.26), 0.7)
	for x in [-13.8, -13.3, 13.6]:
		var pipe := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.09
		cylinder.bottom_radius = 0.09
		cylinder.height = 39
		cylinder.radial_segments = 12
		pipe.mesh = cylinder
		pipe.material_override = pipe_mat
		pipe.position = Vector3(x, 2.8, -9)
		pipe.rotation.x = PI / 2
		add_child(pipe)
		for z in range(-27, 9, 4):
			_box("PipeClamp", Vector3(x, 2.8, z), Vector3(0.22, 0.25, 0.045), _plain(Color(0.12, 0.16, 0.16)), false)
	for z in [-5.0, -16.0, -27.0]:
		_box("CableTray", Vector3(0, 3.1, z), Vector3(1.2, 0.15, 5.0), pipe_mat, false)
		_sign("HIGH VOLTAGE / KEEP CLEAR", Vector3(9.0, 2.4, z + 7.16), 0.007)

func _pool_details() -> void:
	var water := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float ripple=sin(p.x*9.0+TIME*0.6)*cos(p.z*7.0-TIME*0.4);ALBEDO=vec3(0.055,0.24,0.25)+ripple*0.012;ROUGHNESS=0.24;SPECULAR=0.35;NORMAL_MAP=vec3(0.5+ripple*0.035,0.5+sin(p.z*11.0+TIME)*0.03,1.0);}"""
	water.shader = shader
	for x in [-8.0, 8.0]:
		_vault(x)
		var basin := _box("ShallowWater", Vector3(x, 0.026, -14.6), Vector3(7, 0.035, 7.4), water, false)
		pool_water = basin.get_child(0)
		for side in [-1.0, 1.0]:
			_box("PoolEdge", Vector3(x + side * 3.6, 0.10, -14.6), Vector3(0.18, 0.2, 7.8), wall_material, true)
		_sign("SHALLOW / 0.1m", Vector3(x, 2.5, -19.8), 0.012)

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

func _vault(center_x: float) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(24):
		var a := float(i) / 24 * PI
		var b := float(i + 1) / 24 * PI
		var left := Vector3(center_x - cos(a) * 4.0, 2.65 + sin(a) * 0.65, -10.2)
		var right := Vector3(center_x - cos(b) * 4.0, 2.65 + sin(b) * 0.65, -10.2)
		var back := Vector3(0, 0, -9.5)
		var na := Vector3(cos(a) * 0.65, -sin(a) * 4.0, 0).normalized()
		var nb := Vector3(cos(b) * 0.65, -sin(b) * 4.0, 0).normalized()
		vertices.append_array(PackedVector3Array([left, right + back, right, left, left + back, right + back]))
		normals.append_array(PackedVector3Array([na, nb, nb, na, na, nb]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var vault := MeshInstance3D.new()
	vault.name = "TiledBarrelVault"
	vault.mesh = mesh
	var double_sided := wall_material.duplicate() as ShaderMaterial
	var vault_shader := Shader.new()
	vault_shader.code = wall_material.shader.code.replace("shader_type spatial;", "shader_type spatial; render_mode cull_disabled;")
	double_sided.shader = vault_shader
	double_sided.set_shader_parameter("theme", index)
	double_sided.set_shader_parameter("surface", 0)
	vault.material_override = double_sided
	add_child(vault)
