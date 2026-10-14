extends Node3D
# Two independent authored-GLB FPS maps, selected once by the authoritative host.
const Assets = preload("backrooms_assets.gd")
const WIDTH := 48.0
const TILE := 12.0
const MAP_NAMES := ["CARGO COURTYARD", "MAINTENANCE HANGAR"]
const MAP_NAMES_ZH := ["货运庭院", "维修仓库"]
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

func _ready() -> void:
	name = "TwoStandalone_FPS_Maps_NoNarrativeLevels"
	visible = false
	set_process(false)

func random_map() -> int:
	# Exactly two outcomes: no modulo bias, never seeded by a joining client.
	return int(Crypto.new().generate_random_bytes(1)[0]) % 2

func map_title(chinese: bool = false) -> String:
	return MAP_NAMES_ZH[map_id] if chinese else MAP_NAMES[map_id]

func _pbr(surface: String, tint: Color, density: float, metallic: float = 0.0) -> Material:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = .80
	material.metallic = metallic
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for channel in ["diffuse","normal","rough"]:
		for suffix in [".jpg",".png",".jpeg"]:
			var path := Assets.path("vendor/pbr_%s_%s%s" % [surface,channel,suffix])
			if not ResourceLoader.exists(path): continue
			if channel == "diffuse": material.albedo_texture = load(path)
			elif channel == "normal":
				material.normal_enabled = true
				material.normal_texture = load(path)
				material.normal_scale = .45
			else: material.roughness_texture = load(path)
			break
	return Assets.projected_pbr(material,density)

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
	var model := Assets.licensed_panel(at,extent,finish,side)
	# Original fitted floor thickness begins at local Y=0: center it on the proxy.
	var authored: Vector3 = model.get_meta("dimensions",Vector3.ONE)
	model.position -= model.basis*Vector3(0,authored.y*.5,0)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
	var layout := Node3D.new()
	layout.name = "CargoCourtyard" if index == 0 else "MaintenanceHangar"
	add_child(layout)
	map_roots.append(layout)
	var plaster := _pbr("worn_plaster_wall",Color(.62,.65,.67),.55)
	var metal := _pbr("rusty_metal_sheet",Color(.54,.58,.61),1.0,.45)
	var wall_height := 3.4 if index == 0 else 6.0
	for side in [-1.0,1.0]:
		_panel(layout,"Perimeter_X_%s" % side,Vector3(side*23.9,wall_height*.5,0),Vector3(.28,wall_height,48.2),plaster,true)
		_panel(layout,"Perimeter_Z_%s" % side,Vector3(0,wall_height*.5,side*23.9),Vector3(48.2,wall_height,.28),plaster)
	# Deliberately keep both spawn diagonals and the central movement lanes clear.
	# Each side has cover pockets, with 3m+ passageways around actual proxies.
	for side in [-1.0,1.0]:
		for depth in [-1.0,1.0]:
			var at := Vector3(side*14,0,depth*5)
			_prop(layout,"Crate_%s_%s" % [side,depth],"wakeup_container_tall.glb",at,2.25,0,metal)
			_prop(layout,"ScannedBarrel_%s_%s" % [side,depth],"scan_barrel_02.glb",at+Vector3(side*2.4,0,1.5),1.1)
			_prop(layout,"ScannedBox_%s_%s" % [side,depth],"scan_cardboard_box_01.glb",at+Vector3(0,0,2.3),.75,.18*side)
	# Central islands remove the empty middle while retaining the spawn diagonals.
	for side in [-1.0,1.0]:
		for depth in [-1.0,1.0]:
			var pocket := Vector3(side*6,0,depth*3)
			for offset in [-.55,.55]:
				_prop(layout,"MidCover_%s_%s_%s" % [side,depth,offset],"wakeup_container_tall.glb",pocket+Vector3(offset,0,0),1.15,0,metal)
			_prop(layout,"MidBarrel_%s_%s" % [side,depth],"scan_barrel_02.glb",pocket+Vector3(side*1.25,0,.8),.95)
	if index == 0:
		for depth in [-1.0,1.0]:
			_panel(layout,"LoadingBay_%s" % depth,Vector3(0,1.6,depth*18),Vector3(10,3.2,.30),metal)
			_prop(layout,"UtilityPipe_%s" % depth,"wakeup_pipe.glb",Vector3(-19,0,depth*13),2.4,PI*.5,metal)
			_prop(layout,"BayPillar_%s" % depth,"wakeup_wall_pillar.glb",Vector3(6,0,depth*18),3.5,0,plaster,Vector2(.65,.65))
	else:
		# Real floor GLBs form roof wings with a 6m open skylight between them.
		_roof(layout,"Roof_West",Vector3(-13.5,6,0),Vector3(21,.20,48.2),metal)
		_roof(layout,"Roof_East",Vector3(13.5,6,0),Vector3(21,.20,48.2),metal)
		for depth in [-1.0,1.0]:
			_panel(layout,"ServiceBay_%s" % depth,Vector3(0,1.25,depth*17),Vector3(12,2.5,.28),metal)
			_prop(layout,"ServiceConsole_%s" % depth,"wakeup_computer_screen.glb",Vector3(-4,0,depth*18.8),1.3,PI if depth<0 else 0)
		for side in [-1.0,1.0]:
			for depth in [-1.0,1.0]:
				var at := Vector3(side*18,0,depth*15)
				_prop(layout,"RoofPillar_%s_%s" % [side,depth],"wakeup_wall_pillar.glb",at,6.0,0,plaster,Vector2(.75,.75))
				_prop(layout,"OriginalLamp_%s_%s" % [side,depth],"scan_industrial_wall_lamp.glb",at+Vector3(-side*.465,4.2,0),.55,-side*PI*.5)
				var lamp := OmniLight3D.new()
				lamp.position = at+Vector3(-side*2,4.5,0)
				lamp.light_color = Color(1,.82,.62)
				lamp.light_energy = 2.8
				lamp.omni_range = 15.0
				lamp.shadow_enabled = false
				layout.add_child(lamp)

func build() -> void:
	if built: return
	built = true
	ground = StaticBody3D.new()
	ground.name = "Invisible_FloorAndBoundary_Physics_Only"
	add_child(ground)
	_collider(ground,Vector3(0,-.31,0),Vector3(WIDTH,.64,WIDTH))
	var finish := _pbr("large_grey_tiles",Color(.8,.83,.86),.32)
	for x in range(4):
		for z in range(4):
			var tile := Assets.fitted("vendor/wakeup_floor_panel.glb",.16)
			var dimensions: Vector3 = tile.get_meta("dimensions",Vector3.ONE)
			tile.scale = Vector3((TILE+.10)/dimensions.x,1,(TILE+.10)/dimensions.z)
			tile.position = Vector3((x-1.5)*TILE,-.16-float(x+z)*.0003,(z-1.5)*TILE)
			for mesh in tile.find_children("*","MeshInstance3D",true,false):
				(mesh as MeshInstance3D).material_override = finish
				(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tile)
			floor_modules.append(tile)
	horizon = Assets.fitted("vendor/wakeup_floor_panel.glb",.16)
	var horizon_dimensions: Vector3 = horizon.get_meta("dimensions",Vector3.ONE)
	horizon.scale = Vector3(384.0/horizon_dimensions.x,1,384.0/horizon_dimensions.z)
	horizon.position.y = -.19
	add_child(horizon)
	_build_map(0)
	_build_map(1)
	light = DirectionalLight3D.new()
	light.name = "Sun_QualityShadows"
	light.rotation_degrees = Vector3(-28,-32,0)
	light.light_color = Color(1,.93,.82)
	light.shadow_bias = .10
	light.shadow_normal_bias = 1.5
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(light)
	local_shadow = Assets.fitted("vendor/crew.glb",1.75)
	for mesh in local_shadow.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow_animations = local_shadow.find_children("*","AnimationPlayer",true,false)
	add_child(local_shadow)

func apply_quality(quality: int) -> void:
	if not is_instance_valid(light): return
	light.shadow_enabled = quality > 0
	light.directional_shadow_max_distance = 24.0 if OS.has_feature("android") else 45.0

func _process(_delta: float) -> void:
	if not is_instance_valid(local_shadow): return
	var player: Node3D = get_parent().player
	local_shadow.global_position = player.global_position
	local_shadow.rotation.y = player.rotation.y
	var speed: float = Vector2(player.velocity.x,player.velocity.z).length()
	for animation in shadow_animations: (animation as AnimationPlayer).speed_scale = clampf(speed/2.6,0,1.5)

func activate(selected: int = 0) -> void:
	if selected < 0 or selected >= MAP_NAMES.size():
		push_error("Invalid authoritative FPS map ID")
		return
	build()
	map_id = selected
	visible = true
	set_process(true)
	ground.collision_layer = 1
	for index in range(map_roots.size()):
		map_roots[index].visible = index == map_id
		for body in map_roots[index].find_children("*","StaticBody3D",true,false):
			(body as StaticBody3D).collision_layer = 1 if index == map_id else 0
	var finish := _pbr("concrete_floor" if map_id==0 else "large_grey_tiles",Color(.73,.77,.8),.55 if map_id==0 else .32)
	for tile in floor_modules+[horizon]:
		for mesh in tile.find_children("*","MeshInstance3D",true,false): (mesh as MeshInstance3D).material_override = finish
	light.light_energy = .70 if map_id == 0 else .48
	apply_quality(get_parent().quality)
	var world: WorldEnvironment = get_parent().environment
	var sky_material := PanoramaSkyMaterial.new()
	var sky_path := Assets.path("vendor/fps_daylight_sky.hdr")
	if ResourceLoader.exists(sky_path): sky_material.panorama = load(sky_path)
	else: push_error("Verified original CC0 HDR sky is not packaged")
	sky_material.energy_multiplier = .50
	var sky := Sky.new()
	sky.sky_material = sky_material
	world.environment.sky = sky
	world.environment.background_mode = Environment.BG_SKY
	world.environment.fog_enabled = false
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(.62,.70,.80)
	world.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world.environment.ambient_light_energy = .38 if map_id == 0 else .58
	world.environment.tonemap_exposure = .90
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
	var locations: Array[Vector3] = [Vector3(-7,.12,7),Vector3(7,.12,-7),Vector3(7,.12,7),Vector3(-7,.12,-7)]
	return locations[posmod(slot-1,locations.size())]
