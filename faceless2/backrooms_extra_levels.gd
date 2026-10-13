extends Node3D
# Additional standalone, collidable Backrooms levels: original imported GLB meshes only.
const Assets = preload("backrooms_assets.gd")
const LEVELS := [0,1,2,5,6,130,131,132,133]
# Level Fun, Level ! and Level EX use distinct numeric routing IDs.
const LEVEL_FUN := 131
const LEVEL_BANG := 132
const LEVEL_EX := 133
const ROUTE := [0,1,2,130,5,6,131,132,133]
func next_level() -> int:
	return ROUTE[(ROUTE.find(current)+1) % ROUTE.size()]
func previous_level() -> int:
	return ROUTE[posmod(ROUTE.find(current)-1,ROUTE.size())]
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
var event_tweens: Array[Tween] = []
var floor_section_nodes: Array[Node3D] = []
var side_room_floor_nodes: Array[Node3D] = []
var solid_prop_count := 0

func _ready() -> void:
	name = "GLB_NineLevel_Exploration"
	visible = false
	set_process(false)
	spatial_sound = AudioStreamPlayer3D.new()
	spatial_sound.max_distance = 18.0
	var path := Assets.path("vendor/monster_step.ogg")
	if ResourceLoader.exists(path): spatial_sound.stream = load(path)
	add_child(spatial_sound)

func _surface(kind: String, tint: Color) -> StandardMaterial3D:
	# Cache by both real PBR scan and per-level tint; by-kind caching
	# made Level 0/5/Fun silently inherit a previous level's color.
	var cache_key := "%s_%s" % [kind,tint.to_html()]
	if mat_cache.has(cache_key): return mat_cache[cache_key]
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
				mat.normal_scale = 0.55
				break
		for suffix in [".jpg",".png",".jpeg"]:
			var rough := Assets.path("vendor/pbr_"+name+"_rough"+suffix)
			if ResourceLoader.exists(rough):
				mat.roughness_texture = load(rough)
				break
	mat_cache[cache_key] = mat
	return mat

func _piece(file: String, pos: Vector3, dimensions: Vector3, material: Material = null, yaw: float = 0.0) -> Node3D:
	var full := Assets.path("vendor/wakeup_"+file+".glb")
	if not ResourceLoader.exists(full):
		push_error("Licensed Kenney architecture GLB missing: "+full)
		return null
	var node := Assets.fitted("vendor/wakeup_"+file+".glb",dimensions.y)
	node.name = "LicensedKenney_"+file
	node.position = pos
	# Assets.fitted() sets the imported GLB's mesh BOTTOM at local y=0.
	# Wall placements previously supplied their vertical CENTER as y, making
	# every solid wall hover ~1.5m above the invisible collision wall.
	# Only correct upright wall/door modules; floors, pipes, props and roofs
	# are already placed by their base elevation.
	if file in ["wall","wall_window","wall_door","wall_pillar","door_single_closed"]:
		node.position.y -= dimensions.y * 0.5
	node.rotation.y = yaw
	var original_size: Vector3 = node.get_meta("dimensions",Vector3.ONE)
	node.scale = Vector3(dimensions.x/maxf(original_size.x,.02),dimensions.y/maxf(original_size.y,.02),dimensions.z/maxf(original_size.z,.02))
	if material != null:
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			(mesh as MeshInstance3D).material_override = material
			(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(node)
	if file == "floor_panel": floor_section_nodes.append(node)
	return node

func _solid(pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = pos
	colliders.add_child(collider)

# A real GLB prop is still rendered by its licensed mesh; the inexpensive
# invisible collision proxy keeps players out of its center. No visible boxes.
func _solid_prop(at: Vector3, size: Vector3) -> void:
	_solid(Vector3(at.x, size.y * 0.5, at.z), size)
	solid_prop_count += 1

# These side rooms are a continuous extension of the two removed corridor
# wall GLBs (z = -11.1 / -14.7, module depth 3.68). The OPENING is therefore
# [-16.54,-9.26]. Match actual room walls AND invisible collision to it:
# the old 5.2m room left 2m of invisible void and camera-wall intersections.
func _side_room(side: float, z: float, width: float, wall_mat: Material, floor_mat: Material, ceiling_mat: Material) -> void:
	var room_center := side * (width * 0.5 + 2.05)
	var room_length := 7.30
	var half_length := room_length * 0.5
	var floor := _piece("floor_panel",Vector3(room_center,-.07,z),Vector3(4.15,.16,room_length),floor_mat)
	if floor != null: side_room_floor_nodes.append(floor)
	_piece("structure_panel",Vector3(room_center,3.22,z),Vector3(4.2,.23,room_length),ceiling_mat)
	_piece("wall",Vector3(side*(width*.5+4.10),1.56,z),Vector3(.22,3.15,room_length),wall_mat)
	_piece("wall",Vector3(room_center,1.56,z-half_length),Vector3(4.2,3.15,.22),wall_mat)
	_piece("wall",Vector3(room_center,1.56,z+half_length),Vector3(4.2,3.15,.22),wall_mat)
	# Real GLB jambs make the doorway legible; only their centre is collidable.
	for end in [-1.0,1.0]:
		_piece("wall_pillar",Vector3(side*(width*.5+.15),1.56,z+end*half_length),Vector3(.27,3.12,.32),wall_mat)
	# Left/right room ends and floor are solid; the entrance is unobstructed.
	_solid(Vector3(room_center,-.18,z),Vector3(4.2,.33,room_length+.05))
	_solid(Vector3(side*(width*.5+4.16),1.46,z),Vector3(.32,3.0,room_length+.05))
	_solid(Vector3(room_center,1.46,z-half_length),Vector3(4.3,3.0,.30))
	_solid(Vector3(room_center,1.46,z+half_length),Vector3(4.3,3.0,.30))
	_light(Vector3(room_center,2.65,z),Color(.67,.76,.72),0.90,4.8)

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
		var image := "vendor/sketchfab_smiler_face.png" if kind == "smiler" else "vendor/frowner_online_ccby.png"
		if not ResourceLoader.exists(Assets.path(image)): return
		var sprite := Sprite3D.new()
		sprite.texture = load(Assets.path(image))
		sprite.pixel_size = 0.00125
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.no_depth_test = false
		sprite.shaded = false
		# Sketchfab-baked transparent face participates in depth testing.
		# It is revealed only after approach; it is NEVER embedded in a wall.
		sprite.visible = kind != "smiler"
		avatar = sprite
	else:
		# The white astronaut was the Cesium SAMPLE HUMAN ("crew.glb").
		# Use the already-licensed CC0 horror-creature skeleton/meshes instead;
		# no generated or primitive body mesh, and no active attack AI.
		if not ResourceLoader.exists(Assets.path("entity.glb")):
			push_error("Missing verified HorrorGameMaker CC0 entity.glb")
			return
		avatar = Assets.fitted("entity.glb",1.75)
		for anim in avatar.find_children("*","AnimationPlayer",true,false):
			(anim as AnimationPlayer).stop()
		avatar.visible = false
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
	var layout_mat: Material = wall_mat if level_number in [0,1,131] else (industrial if level_number in [2,6,132,133] else hospital)
	if level_number == 0: layout_mat = _surface("wall",Color(.84,.78,.38))
	if level_number == 5: layout_mat = _surface("wall",Color(.48,.26,.21))
	if level_number == 131: layout_mat = _surface("wall",Color(.82,.39,.68))
	if level_number == 132: layout_mat = _surface("rust",Color(.74,.20,.17))
	var floor_render: Material = floor_mat if level_number in [0,1,131] else (industrial if level_number in [2,6,132,133] else hospital)
	if level_number == 0: floor_render = carpet
	if level_number == 5: floor_render = _surface("carpet",Color(.64,.20,.20))
	if level_number == 131: floor_render = _surface("tile",Color(.66,.53,.65))
	var width := 8.8 if level_number in [0,1,5,131] else (4.6 if level_number in [2,6,132] else 7.3)
	var total_length := 34.0 if level_number == 1 else (35.0 if level_number == 2 else 32.0)
	# Reused authored Kenney building module, closed shell with door-shaped openings.
	var w := width/2.0
	# Ten continuous licensed GLB floor panels instead of 70 grid cells.
	# This reduces seams and scene nodes without a visible primitive mesh.
	for z in range(0,10):
		var point := Vector3(0.0,-.07,3.3-float(z)*3.6)
		_piece("floor_panel",point,Vector3(width+.06,.16,3.62),floor_render)
	# GLB side-room mouth is at z ~= -11.1. Avoid both visual walls and
	# invisible corridor colliders across this opening. Floor continues through.
	var has_side_room := level_number in [1,5,130,131]
	var side_sign := -1.0 if level_number in [1,130] else 1.0
	for z in range(0,10):
		var zpos := 3.3-float(z)*3.6
		for side in [-1.0,1.0]:
			if has_side_room and side == side_sign and z in [4,5]: continue
			_piece("wall",Vector3(side*w,1.56,zpos),Vector3(.22,3.15,3.68),layout_mat)
		_piece("structure_panel",Vector3(0,3.22,zpos),Vector3(width,.23,3.68),layout_mat)
	_solid(Vector3(0,-.18,-13.0),Vector3(width,.33,37.8))
	for side in [-1.0,1.0]:
		if has_side_room and side == side_sign:
			# Sections border the genuine 7.2 m opening but leave its middle clear.
			_solid(Vector3(side*w,1.46,-2.63),Vector3(.32,3.0,13.25))
			_solid(Vector3(side*w,1.46,-24.17),Vector3(.32,3.0,15.26))
		else:
			_solid(Vector3(side*w,1.46,-13.0),Vector3(.32,3.0,37.8))
	if has_side_room: _side_room(side_sign,-12.9,width,layout_mat,floor_render,layout_mat)
	_solid(Vector3(0,1.46,-31.3),Vector3(width,3.0,.3))
	_solid(Vector3(0,1.46,4.6),Vector3(width,3.0,.3))
	var max_range := 5 if level_number == 2 else 7
	for i in range(max_range):
		var z := 1.0 - float(i)*5.15
		if level_number in [0,1,5,131]:
			_piece("container_tall",Vector3(-w+0.84,.02,z),Vector3(.9,2.05,1.0),industrial)
			_solid_prop(Vector3(-w+0.84,0,z),Vector3(.88,1.9,.94))
			_piece("container_tall",Vector3(w-1.1,.04,z-1.2),Vector3(1.45,.65,1.1),carpet)
			_solid_prop(Vector3(w-1.1,0,z-1.2),Vector3(1.35,.60,1.04))
			if i%2==0: _piece("pipe",Vector3(-w+.18,2.95,z),Vector3(.24,.26,2.8),industrial)
		elif level_number in [2,6,132,133]:
			for side in [-1,1]:
				_piece("pipe",Vector3(float(side)*(w-.24),2.6,z),Vector3(.22,.30,4.3),industrial)
				_piece("pipe",Vector3(float(side)*(w-.32),1.7,z-1.8),Vector3(.38,.42,.4),industrial)
			if i%2 == 0:
				_piece("container_tall",Vector3(w-1.0,.03,z),Vector3(.65,1.7,.75),industrial)
				_solid_prop(Vector3(w-1.0,0,z),Vector3(.60,1.55,.71))
		else:
			_piece("wall_window",Vector3(w-.22,1.65,z),Vector3(.35,2.5,2.3),hospital)
			_piece("computer_screen",Vector3(-w+.7,1.1,z),Vector3(.65,.9,.30),hospital)
			if i%2==0:
				_scan("wheelchair_01",Vector3(-w+1.15,.07,z-.8),1.25)
		if i % 2 == 0:
			var lamp_tone := Color(.64,.77,.74)
			if level_number == 0: lamp_tone = Color(1.0,.79,.47)
			elif level_number == 2: lamp_tone = Color(.96,.43,.24)
			elif level_number == 5: lamp_tone = Color(.94,.63,.35)
			elif level_number == 6: lamp_tone = Color(.22,.30,.34)
			elif level_number == 130: lamp_tone = Color(.71,.82,1.0)
			elif level_number == 131: lamp_tone = Color(.93,.40,.66)
			elif level_number == 132: lamp_tone = Color(.96,.26,.20)
			elif level_number == 133: lamp_tone = Color(.32,.72,.72)
			_light(Vector3(0,2.8,z),lamp_tone,1.16 if level_number != 6 else 0.12,5.7)
	if level_number in [0,1,5,131]:
		_scan("cardboard_box_01",Vector3(-w+1.55,.08,-13.2),.86)
	else:
		_scan("Barrel_02",Vector3(w-.95,.06,-13.2),1.1)
	if level_number in [2,6,132,133]: _scan("modular_airduct_circular_01",Vector3(0,2.74,-18.0),2.3)
	if level_number == 130: _scan("industrial_wall_lamp",Vector3(0,2.65,-19.0),.5)
	# None of the new entities can injure, collide with or chase the player.
	if level_number in [0,1,5,131]:
		_passive("faceless_witness",Vector3(-1.5,.03,-17.5),PI)
		# The corridor endpoint has a Kenney GLB door behind the face.
		# Place the face in open AIR, not x=w-.20 inside a side wall.
		_passive("smiler",Vector3(0.0,1.64,-27.2),PI)
	elif level_number == 132:
		# LEVEL !: only original CC0 horror-creature GLB meshes, not a
		# smile/frown emoji or a white Cesium astronaut.
		_passive("faceless_witness",Vector3(-.75,.03,-20.5),PI)
		_passive("faceless_witness",Vector3(.85,.03,-27.0),PI)
	elif level_number in [2,6,133]:
		_passive("frowner",Vector3(0,1.7,-23.0),PI)
		_passive("faceless_witness",Vector3(-1.05,.03,-26.5),PI)
	else:
		_passive("faceless_witness",Vector3(-1.85,.03,-19.0),PI)
		_passive("frowner",Vector3(2.6,1.6,-28.0),PI)
# Distinct licensed scanned hero props and topology accents per level.
	# No primitive render meshes; BoxShape3D remains collision-only.
	if level_number == 0:
		for j in range(6):
			_piece("wall",Vector3((-w+.5) if j%2==0 else (w-.5),1.5,-3.0-j*4.1),Vector3(width*.33,3.0,.24),layout_mat,PI/2)
	elif level_number == 5:
		for z in [-5.0,-14.0,-23.0]:
			_scan("chandelier_03",Vector3(0,2.43,z),.82)
			_scan("vintage_day_bed",Vector3(-w+1.7,.04,z-1.3),1.1)
		_scan("gothicbed_01",Vector3(w-1.8,.02,-18),1.2)
	elif level_number == 6:
		for lamp in area_lights: lamp.light_energy = 0.055
		_scan("wooden_lantern_01",Vector3(-w+.6,.35,-19),.7)
	elif level_number == 130:
		_scan("vintage_day_bed",Vector3(-w+1.4,.05,-15),1.0)
	elif level_number == 131:
		for z in [-7.0,-16.0,-25.0]:
			_scan("rubber_duck_toy",Vector3(-w+.9,.20,z),.55)
			_scan("painted_wooden_sofa",Vector3(w-1.0,.07,z),1.12)
	elif level_number == 132:
		for z in [-8.0,-18.0,-25.0]:
			_scan("bar_chair_round_01",Vector3(w-.7,.05,z),.86)
	elif level_number == 133:
		for z in [-9.0,-19.0,-26.0]:
			_scan("industrial_wall_lamp",Vector3(-w+.2,2.4,z),.54)
	# Break up the repeating hallway with real authored GLB side rooms,
	# scanning one-off props and architectural choke points. Every visible
	# structural piece is an imported mesh, collisions remain cheap invisible
	# shapes, leaving a >=2.4 m walkable central evacuation lane.
	if level_number == 0:
		for i in range(5):
			var z := -3.7 - float(i)*5.5
			var wall_side := -1.0 if i%2==0 else 1.0
			_piece("wall",Vector3(wall_side*(w-1.7),1.52,z),Vector3(3.15,3.1,.19),layout_mat)
			_solid(Vector3(wall_side*(w-1.7),1.52,z),Vector3(3.0,3.0,.23))
			_piece("wall_pillar",Vector3(-wall_side*1.8,1.5,z-.65),Vector3(.25,3.0,.25),layout_mat)
	elif level_number == 5:
		_scan("gothicbed_01",Vector3(-w+1.45,.03,-4.0),1.1)
		_scan("painted_wooden_sofa",Vector3(w-1.15,.03,-6.0),.93)
		_scan("chandelier_03",Vector3(0,2.40,-3.0),.88)
	elif level_number == 6:
		_piece("wall",Vector3(-w+.8,1.5,-7.5),Vector3(.2,3.0,4.2),industrial)
		_piece("pipe",Vector3(w-.3,2.3,-3.0),Vector3(.45,.45,4.2),industrial)
	elif level_number == 130:
		_scan("wheelchair_01",Vector3(w-1.25,.03,-2.9),1.1)
		_scan("vintage_day_bed",Vector3(-w+1.75,.04,-5.5),1.03)
		_piece("wall_window",Vector3(-w+.15,1.7,-7.6),Vector3(.25,2.5,2.0),hospital)
	elif level_number == 131:
		_scan("painted_wooden_sofa",Vector3(w-1.25,.02,-3.5),1.04)
		_scan("rubber_duck_toy",Vector3(-w+.85,.25,-3.5),.65)
		_light(Vector3(-1.2,2.5,-4.5),Color(.92,.25,.59),1.65,6.4)
	elif level_number == 132:
		# Level ! uses authored Kenney CC0 door/bulkhead GLBs, and an
		# industrial Poly Haven scan, not visible primitive corridor meshes.
		_scan("bar_chair_round_01",Vector3(w-1.02,.03,-3.5),.86)
		_piece("pipe",Vector3(-w+.4,2.40,-4.0),Vector3(.35,.35,4.7),industrial)
		for chamber_z in [-7.0,-17.0,-26.5]:
			_piece("door_single_closed",Vector3(w-.13,1.38,chamber_z),Vector3(.20,2.70,1.30),industrial)
			_piece("wall_pillar",Vector3(-w+.32,1.55,chamber_z-.8),Vector3(.42,3.10,.38),industrial)
		_light(Vector3(.5,2.4,-5.4),Color(1,.13,.11),1.38,6.0)
	elif level_number == 133:
		_piece("wall_window",Vector3(-w+.10,1.7,-5.8),Vector3(.25,2.5,2.3),hospital)
		_scan("industrial_wall_lamp",Vector3(w-.2,2.5,-3.5),.45)
		_scan("modular_airduct_circular_01",Vector3(-w+.45,2.8,-7.0),1.2)
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
			witness.visible = true
			var turn := create_tween()
			event_tweens.append(turn)
			turn.tween_property(witness,"rotation:y",witness.rotation.y+PI,1.7)
		return "WITNESS"
	# Only after approach should a distant Smiler appear. Keeping the
	# depth-tested Sprite3D hidden at entrance prevents a floating wall sticker.
	if at.z < -18.0 and not event_flags.has("smiler_revealed") and current in [0,1,5,131]:
		event_flags["smiler_revealed"] = true
		if passive_entities.size() > 1: passive_entities[1].visible = true
	if at.z < -22.4 and not event_flags.has("vanishing"):
		event_flags["vanishing"] = true
		if passive_entities.size()>1:
			var last := passive_entities[1]
			last.visible = true
			var fade := create_tween()
			event_tweens.append(fade)
			fade.tween_property(last,"scale",Vector3(.02,.02,.02),2.1)
		return "VANISH"
	return ""

func clear() -> void:
	set_process(false)
	for tween in event_tweens:
		if tween != null and tween.is_running(): tween.kill()
	event_tweens.clear()
	if is_instance_valid(spatial_sound): spatial_sound.stop()
	if is_instance_valid(scene_root): scene_root.queue_free()
	scene_root = null
	colliders = null
	passive_entities.clear()
	floor_section_nodes.clear()
	side_room_floor_nodes.clear()
	solid_prop_count = 0
	area_lights.clear()
	exits.clear()
	event_flags.clear()
	visible = false
	current = 0
