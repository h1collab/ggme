extends SceneTree
# Build-only conversion of verified authored FBX; no generated weapon geometry.
func _initialize() -> void: call_deferred("convert")
func convert() -> void:
	var model: Node3D = load("res://assets/vendor/m4a1_source/M4A1.fbx").instantiate()
	root.add_child(model)
	var triangles := 0
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/vendor/m4a1_source/M4A1_Base_Color.png")
	material.normal_enabled = true
	material.normal_texture = load("res://assets/vendor/m4a1_source/M4A1_Normal.png")
	material.normal_scale = .65
	material.roughness_texture = load("res://assets/vendor/m4a1_source/M4A1_Roughness.png")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.metallic_texture = load("res://assets/vendor/m4a1_source/M4A1_Metallic.png")
	material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.metallic = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
			mesh.set_surface_override_material(surface,material)
	if triangles != 9258:
		push_error("Original M4A1 triangle inventory mismatch: "+str(triangles)); quit(1); return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_scene(model,state) != OK or document.write_to_filesystem(state,"res://assets/vendor/fps_m4a1.glb") != OK:
		push_error("Licensed M4A1 conversion failed"); quit(1); return
	print("FPS_CC0_M4A1_GLB_PASS triangles=",triangles," original magazine, trigger, barrel, stock and charging handle retained")
	model.queue_free()
	await process_frame
	quit(0)
