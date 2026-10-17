extends RefCounted
# Fixed server rules shared by renderer, HUD and authority. No client damage values.
const Assets = preload("backrooms_assets.gd")
const DATA := [
	{"label":"M4A1", "zh":"突击步枪", "file":"fps_m4a1.glb", "capacity":24, "reserve":120, "damage":25, "rate":.12, "reload":1.65, "range":125.0, "length":.88},
	{"label":"SIDEARM", "zh":"手枪", "file":"fps_pistol.glb", "capacity":12, "reserve":72, "damage":34, "rate":.20, "reload":1.25, "range":65.0, "length":.29},
	{"label":"PRECISION", "zh":"狙击步枪", "file":"fps_sniper.glb", "capacity":5, "reserve":25, "damage":100, "rate":1.05, "reload":2.5, "range":125.0, "length":1.12},
	{"label":"KNIFE", "zh":"战术刀", "file":"fps_knife.glb", "capacity":0, "reserve":0, "damage":50, "rate":.45, "reload":0.0, "range":2.0, "length":.29}
]
static func valid(index: int) -> bool: return index >= 0 and index < DATA.size()
static func spec(index: int) -> Dictionary: return DATA[index] if valid(index) else DATA[0]
static func model(index: int) -> Node3D:
	var entry := spec(index)
	var root := Node3D.new()
	var scene: Node3D = load(Assets.path("vendor/"+str(entry.file))).instantiate()
	root.add_child(scene)
	# Original meshes are normalized from their actual imported bounds.
	var bounds := AABB()
	var first := true
	for node in scene.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		var local := Transform3D.IDENTITY
		var current: Node3D = mesh
		while current != scene:
			local = current.transform*local
			current = current.get_parent()
		var box: AABB = local*mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var factor: float = float(entry.length)/(maxf(bounds.size.y,maxf(bounds.size.z,bounds.size.x)) if index == 3 else maxf(bounds.size.z,maxf(bounds.size.x,.01)))
	scene.scale = Vector3.ONE*factor
	scene.position = -bounds.get_center()*factor
	var reference: Vector3 = Vector3(.013,-.085,.072) if index == 0 else [Vector3.ZERO,Vector3(.02,-.06,0),Vector3(.02,-.17,0),Vector3.ZERO][index]
	root.set_meta("grip_local",scene.transform*reference)
	root.set_meta("source_bounds",bounds)
	return root
