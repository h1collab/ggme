extends RefCounted

static func path(file: String) -> String:
	var packaged := "res://assets/" + file
	return packaged if ResourceLoader.exists(packaged) else "res://faceless2/assets/" + file

static func fitted(file: String, height: float) -> Node3D:
	var model: Node3D = load(path(file)).instantiate()
	var bounds := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var transform := Transform3D.IDENTITY
		var current: Node3D = mesh
		while current != model:
			transform = current.transform * transform
			current = current.get_parent()
		var box: AABB = transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var factor := height / maxf(bounds.size.y, 0.01)
	var wrapper := Node3D.new()
	wrapper.add_child(model)
	model.scale = Vector3.ONE * factor
	model.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	wrapper.set_meta("dimensions", bounds.size * factor)
	for player in model.find_children("*", "AnimationPlayer", true, false):
		for animation_name in player.get_animation_list():
			if animation_name == "RESET": continue
			player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
			player.play(animation_name)
			break
	return wrapper

# The verified Kenney CC0 floor-panel GLB is closed, textured source
# geometry. Re-orient its ORIGINAL authored triangles into thin vertical
# infill plates. This is NOT BoxMesh / generated visible geometry: only
# invisible collision ever uses primitive shapes.
static func licensed_panel(at: Vector3, extent: Vector3, material: Material, side_wall: bool = false) -> Node3D:
	var plate := fitted("vendor/wakeup_floor_panel.glb",0.16)
	plate.name = "KenneyCC0_OpaqueImportedGLBPlate"
	var original: Vector3 = plate.get_meta("dimensions",Vector3.ONE)
	# Rotate local XZ floor surface upright: X becomes horizontal, Z vertical,
	# the authored Y thickness becomes the door/wall thickness. Side walls
	# rotate ninety degrees around Y without ever synthesizing mesh vertices.
	var width := extent.z if side_wall else extent.x
	var thickness := extent.x if side_wall else extent.z
	plate.scale = Vector3(width/maxf(original.x,0.01),
		thickness/maxf(original.y,0.01),
		extent.y/maxf(original.z,0.01))
	plate.rotation = Vector3(PI*0.5,PI*0.5 if side_wall else 0.0,0.0)
	plate.position = at
	plate.set_meta("original_kenney_glb","wakeup_floor_panel.glb")
	plate.set_meta("world_extent",extent)
	for mesh_node in plate.find_children("*","MeshInstance3D",true,false):
		var mesh := mesh_node as MeshInstance3D
		if material != null: mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return plate

# Use a world-metric PBR projection for only the GLB sealing plates. It
# prevents the scanned texture from stretching 15m over one source UV shell,
# without raising draw calls for every original wall/prop mesh on mobile.
static func projected_pbr(original: Material, repeats_per_meter: float = 0.68, world_locked: bool = true) -> Material:
	if not (original is StandardMaterial3D): return original
	var mat := (original as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = world_locked
	mat.uv1_scale = Vector3(repeats_per_meter,repeats_per_meter,repeats_per_meter)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
