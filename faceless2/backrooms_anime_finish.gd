extends RefCounted
# Shared texture-free anime palette. Authored geometry/UVs/rigs stay intact.
const Surface = preload("fps_anime_surface.gdshader")
const Outline = preload("fps_anime_outline.gdshader")
static var cache: Dictionary = {}
static var outline: ShaderMaterial

static func material(color: Color, edged: bool = false, weapon: bool = false, grid: float = 0.0, fracture: float = 0.0) -> ShaderMaterial:
	var key := [color,edged,weapon,grid,fracture]
	if cache.has(key): return cache[key]
	var finish := ShaderMaterial.new()
	finish.shader = Surface
	finish.set_shader_parameter("ink_color",color)
	finish.set_shader_parameter("viewmodel",weapon)
	finish.set_shader_parameter("grid_strength",grid)
	finish.set_shader_parameter("fracture_strength",fracture)
	if edged:
		if outline == null:
			outline = ShaderMaterial.new()
			outline.shader = Outline
		finish.next_pass = outline
	cache[key] = finish
	return finish

static func weapon_mesh(mesh: MeshInstance3D) -> void:
	var part := str(mesh.name).to_lower()
	var color := Color(.72,.80,.98)
	if "mag" in part or "clip" in part: color = Color(.51,.30,.83)
	elif "stock" in part or "grip" in part or "handle" in part: color = Color(.15,.19,.36)
	elif "barrel" in part or "sight" in part or "scope" in part: color = Color(.18,.67,.78)
	mesh.material_override = material(color,true,true)

static func weapon(root: Node3D) -> void:
	for node in root.find_children("*","MeshInstance3D",true,false): weapon_mesh(node as MeshInstance3D)

static func character(root: Node3D, seat: int) -> void:
	var accents := [Color(.48,.32,.84),Color(.23,.64,.78),Color(.72,.38,.58),Color(.67,.62,.36),Color(.42,.57,.85),Color(.82,.48,.31)]
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			var color := Color(.85,.85,.90)
			if original != null:
				var luminance := original.albedo_color.get_luminance()
				color = Color(.045,.04,.075) if luminance < .16 else (accents[posmod(seat-1,6)] if luminance < .6 else Color(.86,.87,.94))
			mesh.set_surface_override_material(surface,material(color,true))
