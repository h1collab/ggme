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
				material.albedo_color = Color(0.56, 0.32, 0.21) if "Object_7" in mesh.name else Color(0.08, 0.11, 0.14)
				material.roughness = 0.78
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
