extends RefCounted

# Measure in the holder's coordinates, including all imported transforms.
# Off-centre Sketchfab origins must never become camera-space offsets.
static func bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D: meshes.push_front(root)
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := mesh_bounds(root, mesh)
		result = box if first else result.merge(box)
		first = false
	return result

static func mesh_bounds(root: Node3D, mesh: MeshInstance3D) -> AABB:
	var relative := root.global_transform.affine_inverse() * mesh.global_transform
	if mesh.skin == null:
		return relative * mesh.get_aabb()
	# Imported skinned meshes store vertices in bind space. Mesh.get_aabb()
	# ignores their skeleton pose (90 degrees and 100x scale in these assets).
	var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
	if skeleton == null:
		return relative * mesh.get_aabb()
	var transforms: Array[Transform3D] = []
	var to_root := root.global_transform.affine_inverse() * skeleton.global_transform
	for bind in range(mesh.skin.get_bind_count()):
		var bone := mesh.skin.get_bind_bone(bind)
		if bone < 0:
			bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
		transforms.append(to_root * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
	var result := AABB()
	var first := true
	for surface in range(mesh.mesh.get_surface_count()):
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or weights.is_empty():
			continue
		var influences := weights.size() / vertices.size()
		for index in range(vertices.size()):
			var point := Vector3.ZERO
			for influence in range(influences):
				var offset := index * influences + influence
				if weights[offset] > 0.0:
					point += (transforms[bones[offset]] * vertices[index]) * weights[offset]
			result = AABB(point, Vector3.ZERO) if first else result.expand(point)
			first = false
	return result

static func fit_centered(holder: Node3D, content: Node3D, extent: float) -> void:
	var box := bounds(holder)
	var largest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if largest <= 0.001:
		return
	# Apply scale to an outer holder so a rig's imported basis remains intact.
	content.position -= box.get_center()
	holder.scale = Vector3.ONE * (extent / largest)

static func prepare_viewmodel(root: Node3D) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.mesh == null:
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface)
			if original is BaseMaterial3D:
				var material := original.duplicate() as BaseMaterial3D
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				material.roughness = maxf(material.roughness, 0.42)
				mesh.set_surface_override_material(surface, material)

static func prepare_world(root: Node3D, path: String) -> void:
	if path.ends_with("surveillance_tower.glb"):
		# The download includes a terrain exhibit and a stationary civilian in
		# bright red shorts. Keep the tower and ladder for the Blackwood outpost.
		for name in ["Plano_004_0", "Cubo_0", "Plano_006_0", "Plano_007_0", "Plano_008_0", "Cube_0", "Cube_1", "Cilindro_0"]:
			for node in root.find_children(name, "MeshInstance3D", true, false): node.free()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface)
			if original is BaseMaterial3D:
				var material := original.duplicate() as BaseMaterial3D
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				if path.ends_with("blackwood_soldier.glb"):
					# Imported cloth values are near mirror-smooth; face/mouth incorrectly metallic.
					material.metallic = 0.0
					material.metallic_texture = null
					material.roughness_texture = null
					material.roughness = 0.86 if "guard_" in material.resource_name else 0.64
					material.metallic_specular = 0.24
					material.albedo_color = Color(0.80, 0.80, 0.77)
					if "eyeball" in material.resource_name: material.roughness = 0.32
				if path.ends_with("pine_cluster.glb"):
					material.roughness = 0.95
					material.roughness_texture = null
					material.metallic = 0
					material.metallic_texture = null
					material.metallic_specular = 0.15
				mesh.set_surface_override_material(surface, material)

static func add_static_collision(root: Node3D) -> void:
	if root == null: return
	# Use the normalized visible geometry instead of a disconnected box.
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.skin != null: continue
		var body := StaticBody3D.new()
		mesh.add_child(body)
		var collider := CollisionShape3D.new()
		collider.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(collider)
