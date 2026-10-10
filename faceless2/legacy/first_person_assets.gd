extends RefCounted

# Asset-specific preparation for the model UIDs in sketchfab_assets.json.
# Keep the original geometry, UVs and materials; exclude the author's showcase
# duplicates and crop the full arm rig to first-person forearms and hands.
static func assemble_pistol(root: Node3D) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if "Glock_Mat4" not in mesh.name:
			mesh.free()
			continue
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_material(mesh.get_active_material(0))
		for index in range(0, indices.size(), 3):
			var keep := true
			for corner in range(3):
				var vertex := vertices[indices[index + corner]]
				keep = keep and absf(vertex.x) < 2.1 and absf(vertex.z) < 11.0
			if keep:
				for corner in range(3):
					var source := indices[index + corner]
					builder.set_normal(arrays[Mesh.ARRAY_NORMAL][source])
					builder.set_uv(arrays[Mesh.ARRAY_TEX_UV][source])
					builder.add_vertex(vertices[source])
		builder.index()
		builder.generate_tangents()
		mesh.mesh = builder.commit()

static func make_hands(source: Node3D) -> Node3D:
	var result := Node3D.new()
	var skeleton := source.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	# Curl the fingers in the original rig before baking the grip pose.
	for bone in range(skeleton.get_bone_count()):
		var name := String(skeleton.get_bone_name(bone))
		if name.begins_with("f_") and "_end_" not in name:
			var curl := 0.40 if ".01." in name else 0.60
			skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(Vector3.RIGHT, curl))
	skeleton.force_update_all_bone_transforms()
	for side in ["R", "L"]:
		var holder := Node3D.new()
		holder.name = "RightHand" if side == "R" else "LeftHand"
		result.add_child(holder)
		var wrist_bone := skeleton.find_bone("hand.R_010" if side == "R" else "hand.L_031")
		var wrist := skeleton.global_transform * skeleton.get_bone_global_pose(wrist_bone).origin
		var fingertip_bone := skeleton.find_bone("f_middle.03.R_end_054" if side == "R" else "f_middle.03.L_end_061")
		var fingertip := skeleton.global_transform * skeleton.get_bone_global_pose(fingertip_bone).origin
		var frame := Transform3D(Basis.looking_at((fingertip - wrist).normalized(), Vector3.UP), wrist)
		# Cover the cropped elbow with a tapered sleeve extending off screen.
		# The wrist/fingers remain the original rig geometry.
		var elbow_bone := skeleton.find_bone("forearm.R_04" if side == "R" else "forearm.L_08")
		var elbow := (frame.affine_inverse() * (skeleton.global_transform * skeleton.get_bone_global_pose(elbow_bone).origin)) * 0.012
		var sleeve_start := elbow * 0.65
		var sleeve_end := elbow + elbow.normalized() * 0.52
		var sleeve := MeshInstance3D.new()
		sleeve.name = "Sleeve"
		var cloth := CylinderMesh.new()
		cloth.top_radius = 0.046
		cloth.bottom_radius = 0.063
		cloth.height = sleeve_start.distance_to(sleeve_end)
		cloth.radial_segments = 20
		cloth.rings = 3
		sleeve.mesh = cloth
		var cloth_material := StandardMaterial3D.new()
		cloth_material.albedo_color = Color(0.042, 0.065, 0.075)
		cloth_material.roughness = 0.95
		sleeve.material_override = cloth_material
		sleeve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sleeve.position = (sleeve_start + sleeve_end) * 0.5
		sleeve.basis = Basis.looking_at((sleeve_end - sleeve_start).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
		holder.add_child(sleeve)
		for node in source.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.skin == null:
				continue
			var transforms: Array[Transform3D] = []
			for bind in range(mesh.skin.get_bind_count()):
				var bone := mesh.skin.get_bind_bone(bind)
				if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
				transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var influences := weights.size() / vertices.size()
				var posed := PackedVector3Array()
				var normals := PackedVector3Array()
				for index in range(vertices.size()):
					var position := Vector3.ZERO
					var normal := Vector3.ZERO
					for influence in range(influences):
						var offset := index * influences + influence
						var transform := transforms[bones[offset]]
						position += (transform * vertices[index]) * weights[offset]
						normal += (transform.basis.inverse().transposed() * arrays[Mesh.ARRAY_NORMAL][index]) * weights[offset]
					posed.append(position)
					normals.append((frame.basis.inverse() * normal).normalized())
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				var material := mesh.get_active_material(surface).duplicate() as BaseMaterial3D
				material.albedo_color = Color(0.46, 0.32, 0.24) if "Object_7" in mesh.name else Color(0.08, 0.11, 0.14)
				material.roughness = 0.72
				material.metallic_specular = 0.25
				builder.set_material(material)
				var count := 0
				for index in range(0, indices.size(), 3):
					var keep := true
					for corner in range(3):
						var vertex := posed[indices[index + corner]]
						keep = keep and vertex.y < 80.0 and (vertex.x < 0.0 if side == "R" else vertex.x > 0.0)
					if keep:
						for corner in range(3):
							var original := indices[index + corner]
							builder.set_normal(normals[original])
							builder.set_uv(arrays[Mesh.ARRAY_TEX_UV][original])
							builder.add_vertex((frame.affine_inverse() * posed[original]) * 0.012)
							count += 1
				if count > 0:
					builder.index()
					builder.generate_tangents()
					var visual := MeshInstance3D.new()
					visual.mesh = builder.commit()
					visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					holder.add_child(visual)
	return result
