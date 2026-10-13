extends Node3D
# A SINGLE standalone, empty FPS playfield. No Backrooms levels, lifts,
# scripted doors, passive entities or generated visible mesh primitives.
# The ground is a grid of ORIGINAL Kenney CC0 floor-panel GLB triangles.
const Assets = preload("backrooms_assets.gd")
const WIDTH := 48.0
const TILE := 12.0
var ground: StaticBody3D
var light: DirectionalLight3D
var floor_modules: Array[Node3D] = []
var built := false

func _ready() -> void:
	name = "SingleEmpty_FPS_Arena_NoLevels"
	visible = false

func _floor_material() -> Material:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.81,.82,.79)
	material.roughness = .88
	var prefix := "vendor/pbr_concrete_floor_"
	for suffix in [".jpg",".png",".jpeg"]:
		var diffuse := Assets.path(prefix + "diffuse" + suffix)
		if ResourceLoader.exists(diffuse):
			material.albedo_texture = load(diffuse)
			break
	for suffix in [".jpg",".png",".jpeg"]:
		var normal := Assets.path(prefix + "normal" + suffix)
		if ResourceLoader.exists(normal):
			material.normal_enabled = true
			material.normal_texture = load(normal)
			material.normal_scale = .52
			break
	for suffix in [".jpg",".png",".jpeg"]:
		var rough := Assets.path(prefix + "rough" + suffix)
		if ResourceLoader.exists(rough):
			material.roughness_texture = load(rough)
			break
	return Assets.projected_pbr(material,.58)

func _collider(at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	ground.add_child(shape)

func build() -> void:
	if built: return
	built = true
	ground = StaticBody3D.new()
	ground.name = "Invisible_FloorAndBoundary_Physics_Only"
	add_child(ground)
	_collider(Vector3(0,-.31,0),Vector3(WIDTH,.64,WIDTH))
	for side in [-1.0,1.0]:
		_collider(Vector3(side*(WIDTH*.5+.13),1.5,0),Vector3(.30,3.0,WIDTH+.65))
		_collider(Vector3(0,1.5,side*(WIDTH*.5+.13)),Vector3(WIDTH+.65,3.0,.30))
	var finish: Material = _floor_material()
	for x in range(4):
		for z in range(4):
			var tile: Node3D = Assets.fitted("vendor/wakeup_floor_panel.glb",.16)
			tile.name = "KenneyCC0_PhysicalArenaFloor_GLB"
			var dims: Vector3 = tile.get_meta("dimensions",Vector3.ONE)
			tile.scale = Vector3(TILE/maxf(dims.x,.01),1.0,TILE/maxf(dims.z,.01))
			tile.position = Vector3((float(x)-1.5)*TILE,-.16,(float(z)-1.5)*TILE)
			tile.set_meta("original_kenney_glb","wakeup_floor_panel.glb")
			for surface in tile.find_children("*","MeshInstance3D",true,false):
				(surface as MeshInstance3D).material_override = finish
				(surface as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tile)
			floor_modules.append(tile)
	light = DirectionalLight3D.new()
	light.name = "Daylight_FPS_Arena_No_Shadows_Mobile"
	light.rotation_degrees = Vector3(-48,22,0)
	light.light_energy = 1.15
	light.light_color = Color(1,.96,.88)
	light.shadow_enabled = false
	add_child(light)

func activate() -> void:
	build()
	visible = true
	ground.collision_layer = 1

func deactivate() -> void:
	visible = false
	if is_instance_valid(ground): ground.collision_layer = 0

func spawn_for(slot: int) -> Vector3:
	# Stable spawn ring, all > 5m apart from another living player.
	var locations: Array[Vector3] = [
		Vector3(-7,.12,7), Vector3(7,.12,-7),
		Vector3(7,.12,7), Vector3(-7,.12,-7)]
	return locations[posmod(slot-1,locations.size())]
