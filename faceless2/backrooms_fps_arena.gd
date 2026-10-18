extends Node3D
# Four independent authored-GLB FPS maps, selected once by the authoritative host.
const Assets = preload("backrooms_assets.gd")
const StaticBatch = preload("backrooms_static_batch.gd")
const WIDTH := 72.0
const LENGTH := 96.0
const TILE := 12.0
const MAP_NAMES := ["CARGO COURTYARD", "MAINTENANCE HANGAR", "RELAY DEPOT", "FOUNDRY CROSSING"]
const MAP_NAMES_ZH := ["货运庭院", "维修机库", "中继货站", "铸造交汇"]
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

func _ready() -> void:
	name = "FourStandalone_FPS_Maps_NoNarrativeLevels"
	visible = false
	set_process(false)

func random_map() -> int:
	# Four equiprobable outcomes: no modulo bias, never seeded by a joining client.
	return int(Crypto.new().generate_random_bytes(1)[0]) % 4

func map_title(chinese: bool = false) -> String:
	return MAP_NAMES_ZH[map_id] if chinese else MAP_NAMES[map_id]

func _pbr(surface: String, tint: Color, density: float, metallic: float = 0.0) -> Material:
	var key := "%s:%s:%s:%s" % [surface,tint,density,metallic]
	if material_cache.has(key): return material_cache[key]
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
	var projected := Assets.projected_pbr(material,density)
	material_cache[key] = projected
	return projected

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
	layout.name = ["CargoCourtyard","MaintenanceHangar","RelayDepot","FoundryCrossing"][index]
	add_child(layout)
	map_roots.append(layout)
	var plaster := _pbr("concrete_floor",Color(.83,.80,.73),.30)
	var metal := _pbr("rusty_metal_sheet",Color(.30,.34,.37),.72,.45)
	var wall_height := 3.4 if index == 0 else 6.0
	for side in [-1.0,1.0]:
		_panel(layout,"Perimeter_X_%s" % side,Vector3(side*(WIDTH*.5-.1),wall_height*.5,0),Vector3(.28,wall_height,LENGTH+.2),plaster,true)
		_panel(layout,"Perimeter_Z_%s" % side,Vector3(0,wall_height*.5,side*(LENGTH*.5-.1)),Vector3(WIDTH+.2,wall_height,.28),plaster)
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
			_prop(layout,"MidCover_%s_%s" % [side,depth],"wakeup_wall.glb",pocket,1.15,0,metal,Vector2(3.2,.35))
			_prop(layout,"MidBarrel_%s_%s" % [side,depth],"scan_barrel_02.glb",pocket+Vector3(side*1.25,0,.8),.95)
	# Authored GLB lane dividers create depth and separate long/short sightlines.
	# Keep the central 0..-9 training lane and all existing spawn pockets clear.
	for side in [-1.0,1.0]:
		for depth in [-1.0,1.0]:
			var x: float = side*(10.5 if index == 0 else 12.0)
			var z: float = depth*(11.5 if index == 0 else 12.8)
			_panel(layout,"RangeBoard_%s_%s" % [side,depth],Vector3(x,1.30,z),Vector3(4.0,2.6,.24),plaster)
			for dx in [-2.18,2.18]:
				_prop(layout,"RangePost_%s_%s_%s" % [side,depth,dx],"wakeup_wall_pillar.glb",Vector3(x+dx,0,z),2.95,0,metal,Vector2(.18,.3))
			var number := Label3D.new()
			number.text = "%02d" % (1+(1 if side>0 else 0)+(2 if depth>0 else 0))
			number.font_size = 90
			number.pixel_size = .006
			number.modulate = Color(.32,.12,.07)
			number.outline_size = 0
			number.no_depth_test = false
			number.position = Vector3(x,1.85,z-depth*.132)
			number.rotation.y = PI if depth>0 else 0.0
			layout.add_child(number)
			_prop(layout,"LaneLowCover_%s_%s" % [side,depth],"wakeup_wall.glb",Vector3(side*3.2,0,depth*13.5),.95,PI*.5,plaster,Vector2(.34,3.2))
	if index in [0,2]:
		for depth in [-1.0,1.0]:
			_panel(layout,"LoadingBay_%s" % depth,Vector3(0,1.6,depth*18),Vector3(10,3.2,.30),metal)
			_prop(layout,"UtilityPipe_%s" % depth,"wakeup_pipe.glb",Vector3(-19,0,depth*13),2.4,PI*.5,metal)
			_prop(layout,"BayPillar_%s" % depth,"wakeup_wall_pillar.glb",Vector3(6,0,depth*18),3.5,0,plaster,Vector2(.65,.65))
	else:
		# Real floor GLBs form roof wings with a 6m open skylight between them.
		_roof(layout,"Roof_West",Vector3(-19.5,6,0),Vector3(33,.20,LENGTH+.2),metal)
		_roof(layout,"Roof_East",Vector3(19.5,6,0),Vector3(33,.20,LENGTH+.2),metal)
		for depth in [-1.0,1.0]:
			_panel(layout,"ServiceBay_%s" % depth,Vector3(0,1.25,depth*17),Vector3(12,2.5,.28),metal)
			_prop(layout,"ServiceConsole_%s" % depth,"wakeup_computer_screen.glb",Vector3(-4,0,depth*18.8),1.3,PI if depth<0 else 0)
			_prop(layout,"ServicePipe_%s" % depth,"wakeup_pipe.glb",Vector3(9,0,depth*19.5),2.4,PI*.5,metal)
			_prop(layout,"ServiceStock_%s" % depth,"scan_cardboard_box_01.glb",Vector3(6,0,depth*19.8),.8,.3*depth)
		for side in [-1.0,1.0]:
			for depth in [-1.0,1.0]:
				var at := Vector3(side*18,0,depth*15)
				_prop(layout,"RoofPillar_%s_%s" % [side,depth],"wakeup_wall_pillar.glb",at,6.0,0,plaster,Vector2(.75,.75))
				_prop(layout,"OriginalLamp_%s_%s" % [side,depth],"scan_industrial_wall_lamp.glb",at+Vector3(-side*.465,4.2,0),.55,-side*PI*.5)
				var lamp := OmniLight3D.new()
				lamp.position = at+Vector3(-side*2,4.5,0)
				lamp.light_color = Color(1,.88,.73)
				lamp.light_energy = 2.25
				lamp.omni_range = 13.0
				lamp.shadow_enabled = false
				layout.add_child(lamp)

	# Two new rear sectors per side: alternating passageways connect the
	# original centre to long flank routes, with distinct courtyard/hangar cover.
	for end in [-1.0,1.0]:
		for sector in [0,1]:
			var z: float = end*(27.0+sector*12.0)
			for side in [-1.0,1.0]:
				var x: float = side*(18.0 if sector == 0 else 12.0)
				_panel(layout,"SectorDivider_%s_%s_%s" % [end,sector,side],Vector3(x,1.9,z),Vector3(14.0,3.8,.35),plaster)
				_panel(layout,"SectorReturn_%s_%s_%s" % [end,sector,side],Vector3(x+side*7,1.9,z+end*3),Vector3(.35,3.8,6),metal,true)
				_prop(layout,"FlankCargo_%s_%s_%s" % [end,sector,side],"wakeup_container_tall.glb",Vector3(side*29,0,z+end*3),2.4,PI*.5,metal,Vector2(3.0,5.5))
				_prop(layout,"SectorBarrel_%s_%s_%s" % [end,sector,side],"scan_barrel_02.glb",Vector3(side*7,0,z+end*4),1.0)
				var sign := Label3D.new()
				sign.text = ("CARGO" if index == 0 else "SERVICE")+" %s%d" % ["N" if end < 0 else "S",sector+1]
				sign.position = Vector3(x,2.5,z-end*.20)
				sign.rotation.y = PI if end > 0 else 0.0
				sign.font_size = 64
				sign.pixel_size = .012
				sign.no_depth_test = false
				layout.add_child(sign)
				if index == 1:
					_prop(layout,"ServiceLight_%s_%s_%s" % [end,sector,side],"scan_industrial_wall_lamp.glb",Vector3(x,3.6,z-end*.3),.55)
					var lamp := OmniLight3D.new()
					lamp.position = Vector3(x,4,z-end*3)
					lamp.light_color = Color(.72,.84,1)
					lamp.light_energy = 2.0
					lamp.omni_range = 15
					layout.add_child(lamp)

	if index == 2:
		# Relay depot: lateral cargo trains and offset bridge-gates produce long
		# flank routes with crossfire windows, rather than just recoloring map 0.
		for side in [-1.0,1.0]:
			for z in [-32.0,-20.0,20.0,32.0]:
				_prop(layout,"RelayCargo_%s_%s" % [side,z],"wakeup_container_tall.glb",Vector3(side*26,0,z),2.6,0,metal,Vector2(5,7))
			for z in [-10.0,10.0]:
				_panel(layout,"RelayGate_%s_%s" % [side,z],Vector3(side*25,3.6,z),Vector3(12,.35,.5),metal)
				_prop(layout,"RelayMast_%s_%s" % [side,z],"wakeup_wall_pillar.glb",Vector3(side*31,0,z),4.0,0,metal,Vector2(.65,.65))
	elif index == 3:
		# Foundry: alternating outer machine cells, open central skylight and
		# narrow cross-links; rear-sector route remains accessible on both ends.
		for side in [-1.0,1.0]:
			for z in [-31.0,-21.0,21.0,31.0]:
				_panel(layout,"FoundryCell_%s_%s" % [side,z],Vector3(side*27,1.5,z),Vector3(8,3,.35),metal)
				_prop(layout,"FoundryDuct_%s_%s" % [side,z],"wakeup_pipe.glb",Vector3(side*22,0,z+3),3.3,0,metal)
				_prop(layout,"FoundryConsole_%s_%s" % [side,z],"wakeup_computer_screen.glb",Vector3(side*25,0,z+2),1.1)

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
	var finish := _pbr("large_grey_tiles",Color(.8,.83,.86),.32)
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
	light.light_color = Color(1,.93,.82)
	light.shadow_bias = .04
	light.light_angular_distance = .65
	light.shadow_normal_bias = 1.0
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
	local_shadow.visible = not player.third_person or player.camera_clearance > .65
	var speed: float = Vector2(player.velocity.x,player.velocity.z).length()
	local_shadow.update_combat(speed,not player.is_on_floor() and absf(player.velocity.y) > .3,game.fps.selected_weapon,int(game.fps.hit_serials.get(own,0)),delta,player.pitch)
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
	for material in material_cache.values():
		var pbr := material as StandardMaterial3D
		if not pbr.has_meta("source_roughness"): pbr.set_meta("source_roughness",{"texture":pbr.roughness_texture})
		pbr.normal_enabled = quality > 0 and pbr.normal_texture != null
		pbr.roughness_texture = pbr.get_meta("source_roughness").texture if quality > 0 else null

func _process(delta: float) -> void:
	update_local_actor(delta)

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
	var finish := _pbr("concrete_floor" if map_id==0 else "large_grey_tiles",Color(.73,.77,.8),.36 if map_id==0 else .32)
	for tile in floor_modules+[horizon]:
		for mesh in tile.find_children("*","MeshInstance3D",true,false): (mesh as MeshInstance3D).material_override = finish
	for batch in floor_batch.get("batches",[]): batch.material_override = finish
	light.light_energy = .90 if map_id in [0,2] else .65
	apply_quality(get_parent().quality)
	var world: WorldEnvironment = get_parent().environment
	if cached_sky == null:
		var sky_material := PanoramaSkyMaterial.new()
		var sky_path := Assets.path("vendor/fps_daylight_sky.hdr")
		if ResourceLoader.exists(sky_path): sky_material.panorama = load(sky_path)
		else: push_error("Verified original CC0 HDR sky is not packaged")
		sky_material.energy_multiplier = .50
		cached_sky = Sky.new()
		cached_sky.sky_material = sky_material
	world.environment.sky = cached_sky
	world.environment.background_mode = Environment.BG_SKY
	world.environment.fog_enabled = false
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(.62,.70,.80)
	world.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world.environment.ambient_light_energy = .44 if map_id in [0,2] else .56
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
	var locations: Array[Vector3] = [Vector3(-7,.12,7),Vector3(7,.12,-7),Vector3(7,.12,7),Vector3(-7,.12,-7),Vector3(-27,.12,0),Vector3(27,.12,0)]
	return locations[posmod(slot-1,locations.size())]
