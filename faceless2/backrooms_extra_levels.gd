extends Node3D
# Additional standalone, collidable Backrooms levels: original imported GLB meshes only.
const Assets = preload("backrooms_assets.gd")
const LEVELS := [1,2,130]
const TITLES := {"1":"LEVEL 1 / HABITABLE ZONE","2":"LEVEL 2 / PIPE DREAMS","130":"LEVEL 130 / WELLBORN HOSPITAL"}
var current := 0
var scene_root: Node3D
var colliders: StaticBody3D
var exits: Array[Vector3] = []
var passive_entities: Array[Node3D] = []
var event_flags: Dictionary = {}
var spatial_sound: AudioStreamPlayer3D
var area_lights: Array[Light3D] = []
var mat_cache: Dictionary = {}
var visit_clock := 0.0

func _ready() -> void:
	name = "GLB_ThreeLevel_Exploration"
	visible = false
	set_process(false)
	spatial_sound = AudioStreamPlayer3D.new()
	spatial_sound.max_distance = 18.0
	var path := Assets.path("vendor/monster_step.ogg")
	if ResourceLoader.exists(path): spatial_sound.stream = load(path)
	add_child(spatial_sound)

func _surface(kind: String, tint: Color) -> StandardMaterial3D:
	if mat_cache.has(kind): return mat_cache[kind]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.88
	var mapping := {"floor":"concrete_floor", "wall":"worn_plaster_wall", "rust":"rusty_metal_sheet", "carpet":"dirty_carpet", "tile":"large_grey_tiles"}
	if mapping.has(kind):
		var name: String = mapping[kind]
		for suffix in [".jpg",".png",".jpeg"]:
			var diffuse := Assets.path("vendor/pbr_"+name+"_diffuse"+suffix)
			if ResourceLoader.exists(diffuse):
				mat.albedo_texture = load(diffuse)
				break
		for suffix in [".jpg",".png",".jpeg"]:
			var normal := Assets.path("vendor/pbr_"+name+"_normal"+suffix)
			if ResourceLoader.exists(normal):
				mat.normal_enabled = true
				mat.normal_texture = load(normal)
				break
			var rough := Assets.path("vendor/pbr_"+name+"_rough"+suffix)
			if ResourceLoader.exists(rough):
				mat.roughness_texture = load(rough)
				break
	mat_cache[kind] = mat
	return mat

func _piece(file: String, pos: Vector3, dimensions: Vector3, material: Material = null, yaw: float = 0.0) -> Node3D:
	var full := Assets.path("vendor/wakeup_"+file+".glb")
	if not ResourceLoader.exists(full):
		push_error("Licensed Kenney architecture GLB missing: "+full)
		return null
	var node := Assets.fitted("vendor/wakeup_"+file+".glb",dimensions.y)
	node.name = "LicensedKenney_"+file
	node.position = pos
	node.rotation.y = yaw
	var original_size: Vector3 = node.get_meta("dimensions",Vector3.ONE)
	node.scale = Vector3(dimensions.x/maxf(original_size.x,.02),dimensions.y/maxf(original_size.y,.02),dimensions.z/maxf(original_size.z,.02))
	if material != null:
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			(mesh as MeshInstance3D).material_override = material
			(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(node)
	return node

func _solid(pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = pos
	colliders.add_child(collider)

func _light(at: Vector3, color: Color, energy: float, distance: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = distance
	lamp.shadow_enabled = false
	scene_root.add_child(lamp)
	area_lights.append(lamp)

func _passive(kind: String, where: Vector3, facing: float) -> void:
	# Passive real model or licensed source-bake Sprite3D, never invented geometry.
	var avatar: Node3D
	if kind == "smiler" or kind == "frowner":
		var image := "vendor/sketchfab_smiler_face.png" if kind == "smiler" else "vendor/frowner_derivative.png"
		if not ResourceLoader.exists(Assets.path(image)): return
		var sprite := Sprite3D.new()
		sprite.texture = load(Assets.path(image))
		sprite.pixel_size = 0.0016
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.no_depth_test = false
		sprite.shaded = false
		avatar = sprite
	else:
		if not ResourceLoader.exists(Assets.path("vendor/crew.glb")): return
		avatar = Assets.fitted("vendor/crew.glb",1.75)
		for anim in avatar.find_children("*","AnimationPlayer",true,false):
			(anim as AnimationPlayer).speed_scale = 0.0
	avatar.name = "NonAttackingEntity_"+kind
	avatar.position = where
	avatar.rotation.y = facing
	scene_root.add_child(avatar)
	passive_entities.append(avatar)

func enter(level_number: int) -> Vector3:
	if not LEVELS.has(level_number): return Vector3.ZERO
	clear()
	current = level_number
	visible = true
	set_process(true)
	scene_root = Node3D.new()
	scene_root.name = "BackroomsLevel_%s_RealGLB" % level_number
	add_child(scene_root)
	colliders = StaticBody3D.new()
	colliders.name = "LevelPhysics"
	scene_root.add_child(colliders)
	event_flags.clear()
	visit_clock = 0.0
	var floor_mat := _surface("floor",Color(.65,.67,.66))
	var wall_mat := _surface("wall",Color(.74,.76,.68))
	var industrial := _surface("rust",Color(.62,.57,.53))
	var hospital := _surface("tile",Color(.83,.86,.85))
	var carpet := _surface("carpet",Color(.73,.72,.60))
	var layout_mat: Material = wall_mat if level_number == 1 else (industrial if level_number == 2 else hospital)
	var floor_render: Material = floor_mat if level_number == 1 else (industrial if level_number == 2 else hospital)
	var width := 8.8 if level_number == 1 else (4.6 if level_number == 2 else 7.3)
	var total_length := 34.0 if level_number == 1 else (35.0 if level_number == 2 else 32.0)
	# Reused authored Kenney building module, closed shell with door-shaped openings.
	var w := width/2.0
	for x in range(-3,4):
		for z in range(0,10):
			var point := Vector3(float(x)*width/7.0,-.07,3.3-float(z)*3.6)
			_piece("floor_panel",point,Vector3(width/7.0+.05,.16,3.62),floor_render)
	for z in range(0,10):
		var zpos := 3.3-float(z)*3.6
		_piece("wall",Vector3(-w,1.56,zpos),Vector3(.22,3.15,3.68),layout_mat)
		_piece("wall",Vector3(w,1.56,zpos),Vector3(.22,3.15,3.68),layout_mat)
		_piece("structure_panel",Vector3(0,3.22,zpos),Vector3(width,.23,3.68),layout_mat)
	_solid(Vector3(0,-.18,-13.0),Vector3(width,.33,37.8))
	_solid(Vector3(-w,1.46,-13.0),Vector3(.32,3.0,37.8))
	_solid(Vector3(w,1.46,-13.0),Vector3(.32,3.0,37.8))
	_solid(Vector3(0,1.46,-31.3),Vector3(width,3.0,.3))
	_solid(Vector3(0,1.46,4.6),Vector3(width,3.0,.3))
	var max_range := 5 if level_number == 2 else 7
	for i in range(max_range):
		var z := 1.0 - float(i)*5.15
		if level_number == 1:
			_piece("container_tall",Vector3(-w+0.84,.02,z),Vector3(.9,2.05,1.0),industrial)
			_piece("container_flat",Vector3(w-1.1,.04,z-1.2),Vector3(1.45,.65,1.1),carpet)
			if i%2==0: _piece("pipe",Vector3(-w+.18,2.95,z),Vector3(.24,.26,2.8),industrial)
		elif level_number == 2:
			for side in [-1,1]:
				_piece("pipe",Vector3(float(side)*(w-.24),2.6,z),Vector3(.22,.30,4.3),industrial)
				_piece("pipe_bend",Vector3(float(side)*(w-.32),1.7,z-1.8),Vector3(.38,.42,.4),industrial)
			if i%2 == 0: _piece("container_tall",Vector3(w-1.0,.03,z),Vector3(.65,1.7,.75),industrial)
		else:
			_piece("wall_window",Vector3(w-.22,1.65,z),Vector3(.35,2.5,2.3),hospital)
			_piece("computer_screen",Vector3(-w+.7,1.1,z),Vector3(.65,.9,.30),hospital)
			if i%2==0:
				_scan("wheelchair_01",Vector3(-w+1.15,.07,z-.8),1.25)
		if i % 2 == 0:
			_light(Vector3(0,2.8,z),Color(.64,.77,.74) if level_number==1 else (Color(1,.39,.25) if level_number==2 else Color(.68,.83,1.0)),1.55 if level_number != 2 else 1.05,6.4)
	if level_number == 1:
		_scan("cardboard_box_01",Vector3(-w+1.55,.08,-13.2),.86)
	else:
		_scan("Barrel_02",Vector3(w-.95,.06,-13.2),1.1)
	if level_number == 2: _scan("modular_airduct_circular_01",Vector3(0,2.74,-18.0),2.3)
	if level_number == 130: _scan("industrial_wall_lamp",Vector3(0,2.65,-19.0),.5)
	# None of the new entities can injure, collide with or chase the player.
	if level_number == 1:
		_passive("faceless_witness",Vector3(-1.5,.03,-17.5),PI)
		_passive("smiler",Vector3(w-.20,1.6,-24.0),PI)
	elif level_number == 2:
		_passive("frowner",Vector3(0,1.7,-23.0),PI)
		_passive("faceless_witness",Vector3(-1.05,.03,-26.5),PI)
	else:
		_passive("faceless_witness",Vector3(-1.85,.03,-19.0),PI)
		_passive("frowner",Vector3(2.6,1.6,-28.0),PI)
	_piece("wall_door",Vector3(0,1.45,-29.7),Vector3(2.1,2.7,.2),layout_mat)
	exits = [Vector3(0,0.1,2.0),Vector3(0,0.1,-28.2)]
	return Vector3(0,0.1,2.2)

func _scan(name: String, at: Vector3, height: float) -> void:
	var path := "vendor/scan_"+name.to_lower()+".glb"
	if not ResourceLoader.exists(Assets.path(path)):
		push_error("Licensed photogrammetry GLB missing: "+path)
		return
	var node := Assets.fitted(path,height)
	node.name = "PolyHaven_CC0_RealScan_"+name
	node.position = at
	scene_root.add_child(node)
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func interact(at: Vector3) -> String:
	if not visible or not is_instance_valid(scene_root): return "NONE"
	if at.distance_to(exits[1]) < 2.5:
		return "NEXT"
	if at.distance_to(exits[0]) < 1.4:
		return "BACK"
	return "NONE"

func update_player(at: Vector3, delta: float) -> String:
	if not visible: return ""
	visit_clock += delta
	if at.z < -13.5 and not event_flags.has("witness"):
		event_flags["witness"] = true
		if spatial_sound.stream != null:
			spatial_sound.global_position = at + Vector3(-1.6,0,2.5)
			spatial_sound.play()
		if not passive_entities.is_empty():
			var witness := passive_entities[0]
			create_tween().tween_property(witness,"rotation:y",witness.rotation.y+PI,1.7)
		return "WITNESS"
	if at.z < -22.4 and not event_flags.has("vanishing"):
		event_flags["vanishing"] = true
		if passive_entities.size()>1:
			var last := passive_entities[1]
			var fade := create_tween()
			fade.tween_property(last,"scale",Vector3(.02,.02,.02),2.1)
		return "VANISH"
	return ""

func clear() -> void:
	set_process(false)
	if is_instance_valid(spatial_sound): spatial_sound.stop()
	if is_instance_valid(scene_root): scene_root.queue_free()
	scene_root = null
	colliders = null
	passive_entities.clear()
	area_lights.clear()
	exits.clear()
	event_flags.clear()
	visible = false
	current = 0
