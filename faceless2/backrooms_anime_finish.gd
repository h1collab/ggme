extends RefCounted
# Shared texture-free anime palette. Authored geometry/UVs/rigs stay intact.
const Surface = preload("fps_anime_surface.gdshader")
const Outline = preload("fps_anime_outline.gdshader")
static var cache: Dictionary = {}
static var outline: ShaderMaterial

static func material(color: Color, edged: bool = false, weapon: bool = false, grid: float = 0.0) -> ShaderMaterial:
	var key := [color,edged,weapon,grid]
	if cache.has(key): return cache[key]
	var finish := ShaderMaterial.new()
	finish.shader = Surface
	finish.set_shader_parameter("ink_color",color)
	finish.set_shader_parameter("viewmodel",weapon)
	finish.set_shader_parameter("grid_strength",grid)
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
