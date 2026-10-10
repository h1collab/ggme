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
