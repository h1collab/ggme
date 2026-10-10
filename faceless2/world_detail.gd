extends Node3D

const AssetVisual = preload("res://scripts/asset_visual.gd")
var game: Node
var forest_batches: Array[MultiMeshInstance3D] = []
var relay_lights: Array[OmniLight3D] = []
var relay_materials: Array[StandardMaterial3D] = []
var relay_labels: Array[Label3D] = []
var quality := 2
var update_clock := 0.0
var shadow_clock := 0.0

func _ready() -> void:
	_build_sky()
	_build_forest()
	_build_road_reflectors()
	_build_relay_beacons()
	apply_quality(int(game.settings["quality"]))

func _build_sky() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type sky;
render_mode use_debanding;
uniform vec3 moon_direction = vec3(0.38, 0.40, -0.83);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y); }
void sky() {
	vec3 dir = normalize(EYEDIR);
	float height = clamp(dir.y, 0.0, 1.0);
	vec3 night = mix(vec3(0.025, 0.032, 0.043), vec3(0.005, 0.010, 0.020), pow(height, 0.42));
	vec2 uv = vec2(atan(dir.z, dir.x) / 6.2831853 + 0.5, asin(clamp(dir.y, -1.0, 1.0)) / 3.1415926 + 0.5);
	vec2 grid = uv * vec2(260.0, 140.0);
	vec2 cell = floor(grid);
	vec2 star = vec2(hash(cell), hash(cell + 29.0));
	float point = 1.0 - smoothstep(0.012, 0.065, length(fract(grid) - star));
	float stars = point * step(0.974, hash(cell + 71.0)) * smoothstep(0.08, 0.38, height);
	float cloud = smoothstep(0.20, 0.85, noise(dir.xz*5.0+dir.y*2.0)*0.6+noise(dir.xz*13.0)*0.4);
	night += vec3(0.012, 0.020, 0.028) * cloud * smoothstep(0.02, 0.4, height) * (1.0 - height);
	night += vec3(0.50, 0.61, 0.72) * stars * (1.0 - cloud * 0.55);
	float moon = dot(dir, normalize(moon_direction));
	float disc = smoothstep(0.999966, 0.999984, moon);
	float halo = pow(max(moon, 0.0), 1600.0) * 0.022;
	COLOR = night + vec3(0.68, 0.79, 0.92) * (disc * 0.9 + halo);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	game.environment.sky = sky
	game.environment.background_mode = Environment.BG_SKY
	game.environment.background_energy_multiplier = 0.8
	game.environment.fog_light_color = Color(0.085, 0.098, 0.115)
	game.environment.fog_sky_affect = 0.10
	# Match the shadow direction to the moon shown in the sky.
	game.moon_light.basis = Basis.looking_at(-Vector3(0.38, 0.40, -0.83).normalized(), Vector3.UP)

func _build_forest() -> void:
	var source := load("res://assets/pine_cluster.glb").instantiate() as Node3D
	add_child(source)
	var box := AssetVisual.bounds(source)
	var random := RandomNumberGenerator.new()
	random.seed = 2130213
	var transforms: Array[Transform3D] = []
	for i in range(72):
		var side := -1.0 if i % 2 == 0 else 1.0
		var position := Vector3(side * random.randf_range(14.5, 31.0), 0, random.randf_range(-115, 20))
		# Vista trees close the skyline beyond both ends without more draw calls.
		if i % 6 == 0:
			position.x = random.randf_range(-30,30)
			position.z = random.randf_range(-175,-128)
		elif i % 10 == 0:
			position.x = random.randf_range(-30,30)
			position.z = random.randf_range(38,78)
		position.y = game.GroundSurface.forest_height(position.x, position.z) - 0.035
		var factor := random.randf_range(5.0, 10.5) / box.size.y
		var basis := Basis(Vector3.UP, random.randf_range(-PI, PI)).scaled(Vector3.ONE * factor)
		transforms.append(Transform3D(basis, position - basis * Vector3(box.get_center().x, box.position.y, box.get_center().z)))
	for mesh in source.find_children("*", "MeshInstance3D", true, false):
		var relative: Transform3D = source.global_transform.affine_inverse() * mesh.global_transform
		var batch := MultiMeshInstance3D.new()
		batch.name = "ForestLayer%d" % forest_batches.size()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh.mesh
		multimesh.instance_count = transforms.size()
		for i in range(transforms.size()): multimesh.set_instance_transform(i, transforms[i] * relative)
		batch.multimesh = multimesh
		var original: Material = mesh.get_active_material(0)
		if original is BaseMaterial3D:
			var material := original.duplicate() as BaseMaterial3D
			material.albedo_color *= Color(0.55, 0.62, 0.70)
			material.roughness = 0.95
			material.roughness_texture = null
			material.metallic = 0
			material.metallic_texture = null
			# Keep distant foliage as matte as the nearby tree instances.
			material.metallic_specular = 0.0
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			batch.material_override = material
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		forest_batches.append(batch)
	source.free()

func _build_road_reflectors() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.15, 0.18, 0.19)
	concrete.roughness = 0.92
	var reflector := StandardMaterial3D.new()
	reflector.albedo_color = Color(0.82, 0.67, 0.35)
	reflector.emission_enabled = true
	reflector.emission = Color(0.48, 0.29, 0.065)
	var post := CylinderMesh.new()
	post.top_radius = 0.075
	post.bottom_radius = 0.105
	post.height = 0.72
	post.material = concrete
	var band := CylinderMesh.new()
	band.top_radius = 0.081
	band.bottom_radius = 0.085
	band.height = 0.065
	band.material = reflector
	for part in [post, band]:
		var batch := MultiMeshInstance3D.new()
		batch.name = "RoadReflectors" if part == band else "RoadPosts"
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = part
		instances.instance_count = 28
		for i in range(28):
			instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-4.75 if i % 2 == 0 else 4.75, 0.62 if part == band else 0.36, 4.0 - floorf(i / 2.0) * 8.0)))
		batch.multimesh = instances
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)

func _build_relay_beacons() -> void:
	for i in range(game.relays.size()):
		var relay: Node3D = game.relays[i]
		var label := Label3D.new()
		label.position = relay.global_position + Vector3(0, 2.4, 0)
		label.text = "RELAY %02d / OFFLINE" % (i + 1)
		label.font_size = 28
		label.pixel_size = 0.003
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.95, 0.57, 0.26)
		label.outline_size = 8
		label.visibility_range_end = 8
		add_child(label)
		relay_labels.append(label)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.055
		torus.outer_radius = 0.085
		torus.rings = 16
		torus.ring_segments = 8
		torus.material = material
		ring.mesh = torus
		ring.rotation.x = PI * 0.5
		ring.position = relay.global_position + Vector3(0, 1.5, 0.28)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		relay_materials.append(material)
		var light := OmniLight3D.new()
		light.position = ring.position
		light.omni_range = 2.8
		light.light_energy = 0.3
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 18
		light.distance_fade_length = 8
		add_child(light)
		relay_lights.append(light)
	refresh_relays()

func refresh_relays() -> void:
	for i in range(relay_materials.size()):
		var online: bool = game.relay_active[i]
		var color := Color(0.30, 0.92, 0.68) if online else Color(0.98, 0.50, 0.19)
		relay_materials[i].albedo_color = color
		relay_lights[i].light_color = color
		relay_labels[i].modulate = color
		relay_labels[i].text = "RELAY %02d / %s" % [i + 1, "ONLINE" if online else "OFFLINE"]

func apply_quality(value: int) -> void:
	quality = clampi(value, 0, 3)
	for light in game.street_lights: light.shadow_enabled = false
	shadow_clock = 0.0
	for batch in forest_batches: batch.multimesh.visible_instance_count = [18, 32, 52, 72][quality]
	for light in relay_lights: light.visible = quality > 0

func _process(delta: float) -> void:
	if not game.game_started: return
	update_clock += delta
	shadow_clock -= delta
	if shadow_clock <= 0 and is_instance_valid(game.player):
		shadow_clock = 0.3
		var nearest: SpotLight3D
		var distance := 12.0
		for light in game.street_lights:
			light.shadow_enabled = false
			var candidate: float = light.global_position.distance_to(game.player.global_position)
			if candidate < distance:
				distance = candidate
				nearest = light
		if nearest and quality >= 2: nearest.shadow_enabled = true
	for i in range(relay_lights.size()):
		relay_lights[i].light_energy = 0.28 if game.relay_active[i] else 0.25 + sin(update_clock * 2.4 + i) * 0.10
