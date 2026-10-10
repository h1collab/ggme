extends Node3D

# Fixed pools: repeated rifle fire cannot accumulate scene nodes or timers.
const IMPACT_COUNT := 24
const TRACER_COUNT := 8
const BURST_COUNT := 8
var game: Node
var impacts: Array[MeshInstance3D] = []
var impact_life: Array[float] = []
var tracers: Array[MeshInstance3D] = []
var tracer_life: Array[float] = []
var bursts: Array[CPUParticles3D] = []
var impact_cursor := 0
var tracer_cursor := 0
var burst_cursor := 0
var quality := 2

func _ready() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = mix(vec3(0.035, 0.04, 0.043), vec3(0.12, 0.10, 0.07), smoothstep(0.35, 0.78, radius));
	ALPHA = 1.0 - smoothstep(0.65, 1.0, radius);
	if (ALPHA < 0.05) { discard; }
}
"""
	var mark_material := ShaderMaterial.new()
	mark_material.shader = shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.10, 0.10)
	plane.material = mark_material
	for i in range(IMPACT_COUNT):
		var mark := MeshInstance3D.new()
		mark.mesh = plane
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.visible = false
		add_child(mark)
		impacts.append(mark)
		impact_life.append(0.0)
	var light_material := StandardMaterial3D.new()
	light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light_material.albedo_color = Color(1.0, 0.73, 0.31)
	var streak := CylinderMesh.new()
	streak.top_radius = 0.006
	streak.bottom_radius = 0.006
	streak.height = 1.0
	streak.radial_segments = 4
	streak.material = light_material
	for i in range(TRACER_COUNT):
		var tracer := MeshInstance3D.new()
		tracer.mesh = streak
		tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tracer.visible = false
		add_child(tracer)
		tracers.append(tracer)
		tracer_life.append(0.0)
	var dust_material := StandardMaterial3D.new()
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.vertex_color_use_as_albedo = true
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.012
	particle_mesh.height = 0.024
	particle_mesh.radial_segments = 6
	particle_mesh.rings = 3
	particle_mesh.material = dust_material
	for i in range(BURST_COUNT):
		var burst := CPUParticles3D.new()
		burst.emitting = false
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.amount = 12
		burst.lifetime = 0.38
		burst.mesh = particle_mesh
		burst.direction = Vector3.UP
		burst.spread = 58
		burst.initial_velocity_min = 0.6
		burst.initial_velocity_max = 2.6
		burst.gravity = Vector3(0, -5, 0)
		burst.scale_amount_min = 0.5
		burst.scale_amount_max = 1.4
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(burst)
		bursts.append(burst)

func shot(start: Vector3, end: Vector3, normal: Vector3, actor_hit := false, enemy_shot := false) -> void:
	if quality > 0 and start.distance_to(end) > 0.5:
		var tracer := tracers[tracer_cursor]
		var direction := end - start
		var length := minf(direction.length(), 55.0)
		tracer.position = start + direction.normalized() * length * 0.5
		tracer.basis = Basis.looking_at(direction.normalized(), Vector3.UP if absf(direction.normalized().y) < 0.98 else Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5)
		tracer.scale = Vector3(1.3 if enemy_shot else 0.8, length, 1.3 if enemy_shot else 0.8)
		tracer.visible = true
		tracer_life[tracer_cursor] = 0.075 if enemy_shot else 0.045
		tracer_cursor = (tracer_cursor + 1) % TRACER_COUNT
	if normal.length_squared() < 0.1: return
	if quality > 0:
		var burst := bursts[burst_cursor]
		burst.position = end + normal * 0.02
		burst.direction = normal
		burst.color = Color(0.60, 0.65, 0.66) if actor_hit else Color(0.95, 0.72, 0.36)
		burst.amount = [4, 6, 12, 16][quality]
		burst.restart()
		burst.emitting = true
		burst_cursor = (burst_cursor + 1) % BURST_COUNT
	if actor_hit: return
	var mark := impacts[impact_cursor]
	var tangent := normal.cross(Vector3.UP if absf(normal.y) < 0.98 else Vector3.RIGHT).normalized()
	mark.basis = Basis(tangent, normal, tangent.cross(normal))
	mark.position = end + normal * 0.004
	mark.scale = Vector3.ONE
	mark.visible = true
	impact_life[impact_cursor] = 10.0
	impact_cursor = (impact_cursor + 1) % IMPACT_COUNT

func clear_effects() -> void:
	for i in range(IMPACT_COUNT):
		impacts[i].hide()
		impact_life[i] = 0
	for i in range(TRACER_COUNT):
		tracers[i].hide()
		tracer_life[i] = 0
	for burst in bursts: burst.emitting = false

func _process(delta: float) -> void:
	for i in range(TRACER_COUNT):
		if tracer_life[i] <= 0: continue
		tracer_life[i] = maxf(0, tracer_life[i] - delta)
		tracers[i].visible = tracer_life[i] > 0
	for i in range(IMPACT_COUNT):
		if impact_life[i] <= 0: continue
		impact_life[i] = maxf(0, impact_life[i] - delta)
		impacts[i].visible = impact_life[i] > 0
		impacts[i].scale = Vector3.ONE * minf(1, impact_life[i] * 0.5)
