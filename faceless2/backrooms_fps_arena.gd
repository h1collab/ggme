extends Node3D
# Six independent collision layouts, selected once by the authoritative host.
const Assets = preload("backrooms_assets.gd")
const AnimeFinish = preload("backrooms_anime_finish.gd")
const StaticBatch = preload("backrooms_static_batch.gd")
const WIDTH := 72.0
const LENGTH := 96.0
const TILE := 12.0
const MAP_NAMES = preload("backrooms_map_catalog.gd").NAMES
const MAP_NAMES_ZH = preload("backrooms_map_catalog.gd").NAMES_ZH
var map_id := 0
var ground: StaticBody3D
var light: DirectionalLight3D
var floor_modules: Array[Node3D] = []
var map_roots: Array[Node3D] = []
var horizon: Node3D
var built := false
var local_shadow: Node3D
var shadow_animations: Array[Node] = []
var layout_digest := ""
var material_cache: Dictionary = {}
var batch_stats: Array[Dictionary] = []
var floor_root: Node3D
var floor_batch: Dictionary = {}
var cached_sky: Sky
var palette_map := 0
var architecture_mesh: BoxMesh

func _ready() -> void:
	name = "SixStandalone_FPS_Maps_NoNarrativeLevels"
	visible = false
	set_process(false)

func random_map() -> int:
	# Rejection sampling avoids modulo bias for a non-power-of-two map count.
	var value := 255
	var ceiling: int = 256-256%MAP_NAMES.size()
	while value >= ceiling:value = int(Crypto.new().generate_random_bytes(1)[0])
	return value%MAP_NAMES.size()

func map_title(chinese: bool = false) -> String:
	return MAP_NAMES_ZH[map_id] if chinese else MAP_NAMES[map_id]

func _anime_material(surface: String, tint: Color, density: float, metallic: float = 0.0) -> Material:
	var key := [surface,tint,density,metallic,palette_map]
	if material_cache.has(key): return material_cache[key]
	var ground_style := metallic == 0.0 and tint.r < .81
	var color := Color(.12,.12,.12) if ground_style else Color(.83,.83,.83)
	if metallic > 0.0: color = Color(.045,.045,.045)
	var finish := AnimeFinish.material(color,false,false,0.0,.65)
	material_cache[key] = finish
	return finish

func _collider(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	body.add_child(collision)

func _panel(parent: Node3D, label: String, at: Vector3, extent: Vector3, finish: Material, side: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	parent.add_child(body)
	# Clean authored block architecture: one shared 12-triangle cube, batched
	# by scale/basis. Scanned detail is reserved for the collidable crate props.
	if architecture_mesh == null:
		architecture_mesh = BoxMesh.new()
		architecture_mesh.size = Vector3.ONE
	var model := MeshInstance3D.new()
	model.mesh = architecture_mesh
	model.position = at
	model.scale = extent
	model.material_override = finish
	body.add_child(model)
	_collider(body,at,extent)
	return body

func _prop(parent: Node3D, label: String, file: String, at: Vector3, height: float, yaw: float = 0.0, finish: Material = null, footprint: Vector2 = Vector2.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.rotation.y = yaw
	parent.add_child(body)
	var model := Assets.fitted("vendor/"+file,height)
	var dimensions: Vector3 = model.get_meta("dimensions",Vector3.ONE)
	if footprint != Vector2.ZERO:
		model.scale = Vector3(footprint.x/dimensions.x,1,footprint.y/dimensions.z)
		dimensions = Vector3(footprint.x,dimensions.y,footprint.y)
		model.set_meta("dimensions",dimensions)
	body.add_child(model)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if finish != null: (mesh as MeshInstance3D).material_override = finish
		else:
			var color := Color(.35,.35,.35)
			if "box" in file: color = Color(.58,.58,.58)
			elif "computer" in file: color = Color(.025,.025,.025)
			elif "lamp" in file: color = Color(.95,.95,.95)
			(mesh as MeshInstance3D).material_override = AnimeFinish.material(color,true,false,0.0,.45)
	_collider(body,Vector3(0,dimensions.y*.5,0),dimensions)
	return body

func _roof(parent: Node3D, label: String, at: Vector3, extent: Vector3, finish: Material) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	parent.add_child(body)
	var model := Assets.fitted("vendor/wakeup_floor_panel.glb",.20)
	var dimensions: Vector3 = model.get_meta("dimensions",Vector3.ONE)
	model.scale = Vector3(extent.x/dimensions.x,extent.y/dimensions.y,extent.z/dimensions.z)
	body.add_child(model)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).material_override = finish
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_collider(body,Vector3(0,extent.y*.5,0),extent)

func _build_map(index: int) -> void:
	palette_map = index
	var layout := Node3D.new()
	layout.name = MAP_NAMES[index].replace(" ","")
	add_child(layout)
	map_roots.append(layout)
	var wall := _anime_material("alley_plaster",Color(.9,.9,.9),.3)
	var ink := _anime_material("ink_metal",Color(.2,.2,.2),.7,1.0)
	if index > 0:
		_build_distinct(layout,index,wall,ink)
		return
	# Solid building blocks define a narrow central alley and two outer lanes.
	# Cross streets at z=0 and +/-24 connect all six original spawn pockets.
	for side in [-1.0,1.0]:
		_panel(layout,"BoundaryX_%s" % side,Vector3(side*36,4,0),Vector3(.3,8,96),ink,true)
		_panel(layout,"BoundaryZ_%s" % side,Vector3(0,4,side*48),Vector3(72,8,.3),wall)
		for sector in [-1.0,1.0]:
			for block in range(2):
				var z: float = sector*(15.0+block*23.0)
				var height: float = 8.0+float((index+block)%3)*1.2
				_panel(layout,"Building_%s_%s_%d" % [side,sector,block],Vector3(side*14,height*.5,z),Vector3(20,height,14),wall)
				# One asymmetrical feature per facade instead of a repeating grid.
				var bay: float = -3.1 if (index+block+int(side))%2 == 0 else 2.7
				_panel(layout,"BlackWindow_%s_%s_%d" % [side,sector,block],Vector3(side*3.92,3.5+block*.8,z+bay),Vector3(.12,1.1,1.7+index*.2),ink,true)
				if (index+block)%2 == 0:
					_prop(layout,"DrainPipe_%s_%s_%d" % [side,sector,block],"wakeup_pipe.glb",Vector3(side*3.6,0,z-2.1),3.5,0,ink)
		for end in [-1.0 if side < 0 else 1.0]:
			var sign := Label3D.new()
			sign.text = ["404 / NULL","SIGNAL LOST","/// FRACTURE","ERROR_00"][index]
			sign.position = Vector3(side*3.82,3.2,end*15)
			sign.rotation.y = -side*PI*.5
			sign.font_size = 60
			sign.pixel_size = .012
			sign.modulate = Color.WHITE
			sign.outline_modulate = Color.BLACK
			layout.add_child(sign)
	# Map-specific return walls change sightlines but leave a 5m central passage.
	for end in [-1.0,1.0]:
		var z: float = end*(29.0+index*2.0)
		for side in [-1.0,1.0]:
			_panel(layout,"AlleyReturn_%s_%s" % [side,end],Vector3(side*7.2,1.25,z),Vector3(6.0,2.5,.35),ink)
		if index in [1,3]:
			_panel(layout,"OverheadBridge_%s" % end,Vector3(0,7.0,end*19),Vector3(24,.4,2.5),ink)
		_prop(layout,"EndSupply_%s" % end,"scan_cardboard_box_01.glb",Vector3(4,0,end*43),1.1,0,null,Vector2(1.5,1.5))

	_add_curated_crates(layout,0)

func _add_curated_crates(layout: Node3D, id: int) -> void:
	var entries: Array = preload("backrooms_map_layouts.gd").CRATES[id]
	for n in range(entries.size()):
		var point: Array = entries[n]
		_prop(layout,"CuratedCrate_%02d" % n,"scan_cardboard_box_01.glb",Vector3(float(point[0]),0,float(point[1])),1.1,0,null,Vector2(1.5,1.5))
	if id == 0:
		_prop(layout,"SingleStack_Crate","scan_cardboard_box_01.glb",Vector3(-3,1.1,-40),.75,0,null,Vector2(1.1,1.1))

func _build_distinct(layout: Node3D, id: int, wall: Material, ink: Material) -> void:
	var boundary_height := 4.5 if id == 4 else 8.0
	for side in [-1.0,1.0]:
		_panel(layout,"BoundaryX_%s" % side,Vector3(side*36,boundary_height*.5,0),Vector3(.3,boundary_height,96),ink)
		_panel(layout,"BoundaryZ_%s" % side,Vector3(0,boundary_height*.5,side*48),Vector3(72,boundary_height,.3),wall)
	var blocks: Array = preload("backrooms_map_layouts.gd").BLOCKS[id]
	for n in range(blocks.size()):
		var row: Array = blocks[n]
		var extent := Vector3(float(row[2]),float(row[4]),float(row[3]))
		var body: StaticBody3D = _panel(layout,"RouteBlock_%02d" % n,Vector3.ZERO,extent,ink if id == 5 else wall)
		body.position = Vector3(float(row[0]),extent.y*.5,float(row[1]))
		if row.size() > 5:body.rotation.y = deg_to_rad(float(row[5]))
	_add_curated_crates(layout,id)
	if id == 1:
		for z in [-18.0,24.0]:
			_panel(layout,"PassageBridge%s" % z,Vector3(0,7,z),Vector3(34,.4,3),ink)
		for x in [-4.0,4.0]:_landmark(layout,"Cable%s" % x,Vector3(x,6.5,0),Vector3(.06,.06,82),ink)
	elif id == 2:
		_landmark(layout,"FractureLeft",Vector3(-4,9,0),Vector3(5,.4,3),wall)
		_landmark(layout,"FractureRight",Vector3(4,11,0),Vector3(4,.4,3),wall)
		for n in range(5):
			var shard: MeshInstance3D = _landmark(layout,"Rift%d" % n,Vector3(-1+n*.55,10+n*.6,0),Vector3(.09,2,.15),wall)
			shard.rotation.z = -.2
	elif id == 3:
		_panel(layout,"CrossArchX",Vector3(0,8,0),Vector3(30,.4,2),ink)
		_panel(layout,"CrossArchZ",Vector3(0,9,0),Vector3(2,.4,36),ink)
	elif id == 4:
		for x in [-30.0,30.0]:
			for z in [-16.0,16.0]:
				_panel(layout,"CourtColumn%s_%s" % [x,z],Vector3(x,3.5,z),Vector3(1.2,7,1.2),wall)
		_panel(layout,"SignalPylon",Vector3(18,5,0),Vector3(.8,6,.8),wall)
		for n in range(8):
			var angle: float = n*TAU/8
			var ring: MeshInstance3D = _landmark(layout,"SignalRing%d" % n,Vector3(18+cos(angle)*2.4,8+sin(angle)*2.4,0),Vector3(1.95,.16,.3),wall)
			ring.rotation.z = angle+PI*.5
	elif id == 5:
		_panel(layout,"DepotRoof",Vector3(0,12,0),Vector3(70,.3,92),ink)
		for z in [-36.0,-12.0,12.0,36.0]:
			_panel(layout,"DepotTruss%s" % z,Vector3(0,11.5,z),Vector3(66,.35,.35),wall)
		for x in [-9.0,9.0]:_landmark(layout,"DepotLight%s" % x,Vector3(x,11.2,0),Vector3(.15,.08,80),wall)

func ground_plan(id: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for body in map_roots[id].find_children("*","StaticBody3D",true,false):
		for node in body.get_children():
			if node is CollisionShape3D and node.shape is BoxShape3D:
				var bounds: AABB = node.global_transform*AABB(-node.shape.size*.5,node.shape.size)
				if bounds.position.y < 2.5:
					result.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)))
	return result

func _landmark(parent: Node3D, label: String, at: Vector3, extent: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new();mesh.name = label;mesh.mesh = architecture_mesh
	mesh.position = at;mesh.scale = extent;mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func build() -> void:
	if built: return
	built = true
	ground = StaticBody3D.new()
	ground.name = "Invisible_FloorAndBoundary_Physics_Only"
	add_child(ground)
	_collider(ground,Vector3(0,-.31,0),Vector3(WIDTH,.64,LENGTH))
	floor_root = Node3D.new()
	floor_root.name = "OriginalGLB_Floor_Batches"
	add_child(floor_root)
	var finish := _anime_material("large_grey_tiles",Color(.8,.83,.86),.32)
	for x in range(6):
		for z in range(8):
			var tile := Assets.fitted("vendor/wakeup_floor_panel.glb",.16)
			var dimensions: Vector3 = tile.get_meta("dimensions",Vector3.ONE)
			tile.scale = Vector3((TILE+.10)/dimensions.x,1,(TILE+.10)/dimensions.z)
			tile.position = Vector3((x-2.5)*TILE,-.16-float(x+z)*.0003,(z-3.5)*TILE)
			for mesh in tile.find_children("*","MeshInstance3D",true,false):
				(mesh as MeshInstance3D).material_override = finish
				(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			floor_root.add_child(tile)
			floor_modules.append(tile)
	horizon = Assets.fitted("vendor/wakeup_floor_panel.glb",.16)
	var horizon_dimensions: Vector3 = horizon.get_meta("dimensions",Vector3.ONE)
	horizon.scale = Vector3(384.0/horizon_dimensions.x,1,384.0/horizon_dimensions.z)
	horizon.position.y = -.19
	floor_root.add_child(horizon)
	for index in range(MAP_NAMES.size()): _build_map(index)
	floor_batch = StaticBatch.build(floor_root)
	for layout in map_roots: batch_stats.append(StaticBatch.build(layout))
	light = DirectionalLight3D.new()
	light.name = "Sun_QualityShadows"
	light.rotation_degrees = Vector3(-38,-32,0)
	light.light_color = Color.WHITE
	# Flat cel colors make self-shadow acne especially visible on broad surfaces.
	light.shadow_bias = .16
	light.light_angular_distance = .65
	light.shadow_normal_bias = 2.0
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(light)
	local_shadow = preload("backrooms_combat_actor.gd").new()
	add_child(local_shadow)
	local_shadow.configure(1)

func update_local_actor(delta: float) -> void:
	if not is_instance_valid(local_shadow): return
	var game: Node = get_parent()
	var player: Node3D = game.player
	var own: int = game.multiplayer.get_unique_id() if game.net.mode != "solo" else 1
	var seat: int = int(game.net.seats.get(own,1))
	if int(local_shadow.seat) != seat:
		local_shadow.queue_free()
		local_shadow = preload("backrooms_combat_actor.gd").new()
		add_child(local_shadow)
		local_shadow.configure(seat)
	local_shadow.global_position = player.global_position
	local_shadow.rotation.y = player.rotation.y
	local_shadow.visible = not player.third_person or player.camera_body_visible
	var speed: float = Vector2(player.velocity.x,player.velocity.z).length()
	local_shadow.update_combat(speed,not player.is_on_floor() and (absf(player.velocity.y) > .3 or not combat_grounded(player.position)),game.fps.selected_weapon,int(game.fps.hit_serials.get(own,0)),delta,player.pitch,player.velocity.y)
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if player.third_person else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	if int(local_shadow.get_meta("last_shadow_mode",-1)) != mode or int(local_shadow.get_meta("last_shadow_weapon",-1)) != game.fps.selected_weapon:
		for mesh in local_shadow.meshes+local_shadow.held_meshes: (mesh as MeshInstance3D).cast_shadow = mode
		local_shadow.set_meta("last_shadow_mode",mode)
		local_shadow.set_meta("last_shadow_weapon",game.fps.selected_weapon)

func apply_quality(quality: int) -> void:
	if not is_instance_valid(light): return
	light.shadow_enabled = quality > 0
	light.directional_shadow_max_distance = float([0,20,28][quality]) if OS.has_feature("android") else 45.0
	# Small props fade LIGHT influence, not geometry: no holes or gameplay pop-in.
	for layout in map_roots:
		for lamp in layout.find_children("*","OmniLight3D",true,false):
			lamp.distance_fade_enabled = true
			lamp.distance_fade_begin = float([16,24,36][quality])
			lamp.distance_fade_length = 8.0

func _process(delta: float) -> void:
	update_local_actor(delta)

func activate(selected: int = 0) -> void:
	if selected < 0 or selected >= MAP_NAMES.size():
		push_error("Invalid authoritative FPS map ID")
		return
	build()
	map_id = selected
	palette_map = selected
	visible = true
	set_process(true)
	ground.collision_layer = 1
	for index in range(map_roots.size()):
		map_roots[index].visible = index == map_id
		for body in map_roots[index].find_children("*","StaticBody3D",true,false):
			(body as StaticBody3D).collision_layer = 1 if index == map_id else 0
	var finish := _anime_material("concrete_floor" if map_id==0 else "large_grey_tiles",Color(.73,.77,.8),.36 if map_id==0 else .32)
	for tile in floor_modules+[horizon]:
		for mesh in tile.find_children("*","MeshInstance3D",true,false): (mesh as MeshInstance3D).material_override = finish
	for batch in floor_batch.get("batches",[]): batch.material_override = finish
	light.light_energy = .90
	apply_quality(get_parent().quality)
	var world: WorldEnvironment = get_parent().environment
	if cached_sky == null:
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color(.025,.025,.025)
		sky_material.sky_horizon_color = Color(.48,.48,.48)
		sky_material.ground_bottom_color = Color(.06,.06,.06)
		sky_material.ground_horizon_color = Color(.48,.48,.48)
		sky_material.sky_curve = .28
		cached_sky = Sky.new()
		cached_sky.sky_material = sky_material
	world.environment.sky = cached_sky
	world.environment.background_mode = Environment.BG_SKY
	world.environment.fog_enabled = false
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(.78,.78,.78)
	world.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	world.environment.ambient_light_energy = .28
	world.environment.tonemap_exposure = 1.0
	layout_digest = geometry_digest()

func geometry_digest() -> String:
	var records: PackedStringArray = []
	for body in map_roots[map_id].find_children("*","StaticBody3D",true,false):
		var record := str(body.name)+str(body.global_transform)
		for node in body.get_children():
			if node is CollisionShape3D and node.shape is BoxShape3D:
				record += str(node.transform)+str(node.shape.size)
		records.append(record)
	records.sort()
	return "\n".join(records).sha256_text()

func deactivate() -> void:
	visible = false
	set_process(false)
	if is_instance_valid(ground): ground.collision_layer = 0
	for layout in map_roots:
		for body in layout.find_children("*","StaticBody3D",true,false): (body as StaticBody3D).collision_layer = 0

func spawn_for(slot: int) -> Vector3:
	var locations: Array[Vector3] = [Vector3(-7,.12,7),Vector3(7,.12,-7),Vector3(7,.12,7),Vector3(-7,.12,-7),Vector3(-27,.12,0),Vector3(27,.12,0)]
	return locations[posmod(slot-1,locations.size())]

func combat_grounded(at: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(at+Vector3(0,.12,0),at-Vector3(0,.18,0),1)
	ray.exclude = [get_parent().player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.normal.y > .6
