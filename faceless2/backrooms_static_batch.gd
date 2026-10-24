extends RefCounted
# Render the same authored triangles/materials in bounded spatial cells.
# Source nodes remain for source-geometry/collision parity QA, never double drawn.
const CELL_SIZE := 24.0
static func build(root: Node3D) -> Dictionary:
	var groups: Dictionary = {}
	var sources: Array[MeshInstance3D] = []
	for node in root.find_children("*","MeshInstance3D",true,false):
		var source := node as MeshInstance3D
		if source.mesh == null or source.skin != null or not source.visible: continue
		var overridden := false
		for surface in range(source.mesh.get_surface_count()):
			if source.get_surface_override_material(surface) != null: overridden = true
		if overridden: continue # Keep uncommon per-surface overrides intact.
		var local: Transform3D = root.global_transform.affine_inverse()*source.global_transform
		var center := local*source.mesh.get_aabb().get_center()
		var material_id := source.material_override.get_instance_id() if source.material_override != null else 0
		# Keep the common basis on the GeometryInstance, where the renderer
		# detects non-uniform scale for inverse-transpose normal correction.
		# A non-uniform basis inside a MultiMesh instance can otherwise produce
		# incorrect lighting/triplanar projection despite exact vertex positions.
		var key := [source.mesh.get_instance_id(),material_id,source.cast_shadow,source.layers,local.basis,floori(center.x/CELL_SIZE),floori(center.z/CELL_SIZE)]
		if not groups.has(key): groups[key] = []
		groups[key].append({"source":source,"transform":local})
	var instances: Array[MultiMeshInstance3D] = []
	var source_count := 0
	for key in groups:
		var members: Array = groups[key]
		if members.size() < 2: continue
		var first: MeshInstance3D = members[0].source
		var batch_transform := Transform3D((members[0].transform as Transform3D).basis,Vector3.ZERO)
		var inverse := batch_transform.affine_inverse()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = first.mesh
		multimesh.instance_count = members.size()
		var buffer := PackedFloat32Array()
		buffer.resize(members.size()*12)
		var bounds := AABB()
		for i in range(members.size()):
			var transform: Transform3D = inverse*members[i].transform
			# Identical basis by construction; avoid roundoff in the inverse.
			transform.basis = Basis.IDENTITY
			# Godot's GPU buffer is three row-major 3x4 transform rows.
			var row := PackedFloat32Array([transform.basis.x.x,transform.basis.y.x,transform.basis.z.x,transform.origin.x,transform.basis.x.y,transform.basis.y.y,transform.basis.z.y,transform.origin.y,transform.basis.x.z,transform.basis.y.z,transform.basis.z.z,transform.origin.z])
			for column in range(12): buffer[i*12+column] = row[column]
			var box: AABB = transform*first.mesh.get_aabb()
			bounds = box if i == 0 else bounds.merge(box)
		multimesh.buffer = buffer
		multimesh.custom_aabb = bounds
		var batch := MultiMeshInstance3D.new()
		batch.name = "OriginalGLB_Batch_%d" % instances.size()
		batch.transform = batch_transform
		batch.multimesh = multimesh
		batch.material_override = first.material_override
		batch.cast_shadow = first.cast_shadow
		batch.layers = first.layers
		root.add_child(batch)
		batch.set_meta("authored_sources",members)
		batch.set_meta("submitted_buffer",buffer)
		instances.append(batch)
		for member in members:
			(member.source as MeshInstance3D).visible = false
			sources.append(member.source)
		source_count += members.size()
	return {"batches":instances,"sources":sources,"source_count":source_count,"batch_count":instances.size()}
