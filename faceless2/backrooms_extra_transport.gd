extends Node3D
# FACELESS 2: genuine Kenney CC0 GLB transport architecture. All Boxes and
# the staircase ramp below are INVISIBLE physics only; buttons, walls, treads,
# cabin, rails and moving doors are imported publisher-verified GLB meshes.
# Per-level route transitions are local solo events, not ENet replicated yet.
signal arrived(source_level: int, destination_level: int)
const Assets = preload("backrooms_assets.gd")
const FLOOR_IDS := [0,1,2,130,5,6,131,132,133]
const STAIR_EDGES := [2,6,132] # 2 -> 130; 6 -> Fun; ! -> EX
const ELEVATOR_SECONDS := 4.6
const STAIR_DOOR_SECONDS := 1.55

var source_level := 0
var passenger: CharacterBody3D
var buttons: Array[Dictionary] = []
var stations: Array[Dictionary] = []
var active := false
var elapsed := 0.0
var ride_start := Vector3.ZERO
var selected: Dictionary = {}
var motor_started := false
var finish_emitted := false
var metal: Material
var floor_finish: Material
var solid_steel: Material
var solid_tile: Material
var moving_steel: Material
var enclosed_panel_count := 0

func _ready() -> void:
	name = "KenneyCC0_InteractiveTransport"
	set_process(false)

func configure(level_id: int, route: Array, wall_material: Material, floor_material: Material, player_node: CharacterBody3D) -> void:
	source_level = level_id
	passenger = player_node
	metal = wall_material
	floor_finish = floor_material
	# Actual 1K Poly Haven CC0 PBR diffuse/normal/roughness is shared by
	# the cabin, door leafs and floor; only the broad GLB steel sealing
	# surfaces use metric world projection to avoid stretched native UVs.
	solid_steel = Assets.projected_pbr(wall_material,.74)
	# A door in motion must carry its own scan texture instead of sliding
	# through a world-locked triplanar pattern during the closing animation.
	moving_steel = Assets.projected_pbr(wall_material,.74,false)
	solid_tile = Assets.projected_pbr(floor_material,.82)
	var idx: int = route.find(source_level)
	if idx < 0: return
	_build_station(1, int(route[(idx+1)%route.size()]), source_level in STAIR_EDGES)
	# Backwards from the first new level remains the real original facility
	# threshold. Other return paths use the same transport as their source edge.
	if idx > 0:
		var previous: int = int(route[idx-1])
		_build_station(-1, previous, previous in STAIR_EDGES)

func _glb(file: String, at: Vector3, size: Vector3, material: Material = null) -> Node3D:
	var filename := "vendor/wakeup_" + file + ".glb"
	if not ResourceLoader.exists(Assets.path(filename)):
		push_error("Missing license-checked Kenney transport GLB: " + filename)
		return null
	var node: Node3D = Assets.fitted(filename,size.y)
	node.name = "TransportKenneyCC0_" + file
	node.position = at
	var source_size: Vector3 = node.get_meta("dimensions",Vector3.ONE)
	node.scale = Vector3(size.x/maxf(source_size.x,0.02),size.y/maxf(source_size.y,0.02),size.z/maxf(source_size.z,0.02))
	if file in ["wall","wall_pillar","wall_door","door_single_closed","wall_switch"]:
		# This catalog's fitted wrappers are BOTTOM aligned.
		node.position.y -= size.y*0.5
	for m in node.find_children("*","MeshInstance3D",true,false):
		var mesh := m as MeshInstance3D
		if material != null: mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _panel(at: Vector3, size: Vector3, material: Material, side_wall: bool = false) -> Node3D:
	# The imported Kenney CC0 floor_panel.glb has an opaque face.
	# Rotate ORIGINAL GLB triangles for elevator doors and bulkheads;
	# unlike the cut-out door_single_closed prefab, this seals the shaft.
	var panel := Assets.licensed_panel(at,size,material,side_wall)
	panel.name = "KenneyCC0_SolidElevatorOrStairGLB"
	add_child(panel)
	enclosed_panel_count += 1
	return panel

func _collision(at: Vector3, size: Vector3, parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "InvisibleTransportCollision"
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	(parent if is_instance_valid(parent) else self).add_child(body)
	return body

func floor_name(id: int) -> String:
	match id:
		130: return "130"
		131: return "FUN"
		132: return "!"
		133: return "EX"
		_: return str(id)

func _sign(message: String, at: Vector3, bright: bool = true, scale: float = 0.0017, mounted: bool = false) -> Label3D:
	var sign := Label3D.new()
	sign.name = "FloorIdentifier_" + message.replace(" ","_")
	sign.text = message
	sign.position = at
	sign.pixel_size = scale
	sign.font_size = 48
	sign.outline_size = 6
	sign.modulate = Color(0.83,0.95,0.89) if bright else Color(0.38,0.43,0.44)
	# Fixed placards on physical GLB panels should NOT billboard into the
	# player's eyes when approaching the switches; only distant wayfinding
	# markers use camera-facing typography.
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED if mounted else BaseMaterial3D.BILLBOARD_ENABLED
	if mounted: sign.rotation.y = -PI*0.5
	sign.no_depth_test = false
	var font_file := Assets.path("vendor/story_font.otf")
	if ResourceLoader.exists(font_file): sign.font = load(font_file)
	add_child(sign)
	return sign

func _button(at: Vector3, target: int, allowed: int, direction: int, kind: String) -> void:
	var holder := Node3D.new()
	holder.name = "PhysicalFloorButton_" + floor_name(target)
	holder.position = at
	add_child(holder)
	var switch := _glb("wall_switch",at,Vector3(.28,.28,.12),metal)
	if switch != null:
		# The actual imported GLB depresses into the cabin panel when pressed.
		switch.set_meta("button_target",target)
	_sign(floor_name(target),at+Vector3(-.19,.18,0),target == allowed,0.00105,true)
	buttons.append({"node":holder,"model":switch,"target":target,"allowed":allowed,"direction":direction,"kind":kind})

func _build_station(direction: int, destination: int, use_stairs: bool) -> void:
	if use_stairs: _build_stairs(direction,destination)
	else: _build_elevator(direction,destination)

func _build_elevator(direction: int, destination: int) -> void:
	var centre_z := -28.9 if direction == 1 else 3.05
	var entrance_z := centre_z + (1.30 if direction == 1 else -1.30)
	var station := {"direction":direction,"destination":destination,"kind":"elevator",
		"centre":Vector3(0,0,centre_z),"entrance_z":entrance_z}
	var metal_plate := metal
	# All these panels and moving doors retain Kenney's imported GLB triangles.
	_glb("floor_panel",Vector3(0,-.080,centre_z),Vector3(3.0,.18,2.74),solid_tile)
	_collision(Vector3(0,-.08,centre_z),Vector3(3.02,.36,2.75))
	# Physical roof cannot float 0.2m above the cabin walls.
	# Kenney structure_panel has through-apertures. Use the ORIGINAL CC0
	# floor_panel GLB as the ceiling: its verified underside is closed,
	# avoiding a black sky rectangle above the elevator passengers.
	var roof: Node3D = _glb("floor_panel",Vector3(0,2.82,centre_z),Vector3(3.12,.18,2.70),solid_steel)
	if is_instance_valid(roof): roof.name = "KenneyCC0_OpaqueElevatorRoofGLB"
	_collision(Vector3(0,2.87,centre_z),Vector3(3.08,.15,2.72))
	for side in [-1.0,1.0]:
		_glb("wall",Vector3(side*1.55,1.42,centre_z),Vector3(.18,2.85,2.65),metal_plate)
		_panel(Vector3(side*1.66,1.42,centre_z),Vector3(.12,2.88,2.67),solid_steel,true)
		_collision(Vector3(side*1.57,1.38,centre_z),Vector3(.23,2.75,2.65))
		_glb("wall_pillar",Vector3(side*1.58,1.43,entrance_z),Vector3(.20,2.86,.26),solid_steel)
	var far_z := centre_z - (1.33 if direction == 1 else -1.33)
	_glb("wall",Vector3(0,1.42,far_z),Vector3(3.12,2.85,.18),metal_plate)
	_panel(Vector3(0,1.42,far_z-.14*float(direction)),Vector3(3.13,2.88,.14),solid_steel)
	_collision(Vector3(0,1.38,far_z),Vector3(3.12,2.75,.20))
	# Two imported GLB halves slide together, and collision follows their
	# closed state. Initially OPEN so the player can walk inside the cabin.
	var left := _panel(Vector3(-1.10,1.34,entrance_z),Vector3(1.00,2.68,.15),moving_steel)
	var right := _panel(Vector3(1.10,1.34,entrance_z),Vector3(1.00,2.68,.15),moving_steel)
	var barrier := _collision(Vector3(0,1.36,entrance_z),Vector3(2.05,2.69,.18))
	barrier.collision_layer = 0
	barrier.collision_mask = 0
	station["door_left"] = left
	station["door_right"] = right
	station["closed_collision"] = barrier
	# Distinct physical authored switches for every floor. Only the next
	# adjacency is energized; wrong buttons are rejected, never teleport.
	# Real CC0 GLB panel mounting, rather than switches floating in the air.
	_panel(Vector3(1.43,1.55,centre_z),Vector3(.10,2.14,2.18),solid_steel,true)
	_sign("SELECT LEVEL",Vector3(1.07,2.33,centre_z),true,0.00078,true)
	for idx in range(FLOOR_IDS.size()):
		var floor_id: int = FLOOR_IDS[idx]
		var col: int = idx%3
		var row: int = idx/3
		var where := Vector3(1.22,1.02+row*.47,centre_z+.54-float(col)*.51)
		_button(where,floor_id,destination,direction,"elevator")
	# A small warm ceiling marker, no dynamic shadow cascade on Android.
	var light := SpotLight3D.new()
	light.position = Vector3(0,2.7,centre_z)
	# A readable PBR cabin must not become an unlit black shaft, even in
	# Level 6. Restrict the pooled, non-shadowed ceiling light to the lift.
	light.light_energy = 1.08
	light.light_color = Color(.78,.90,.84)
	light.spot_range = 4.35
	light.spot_angle = 63
	light.shadow_enabled = false
	add_child(light)
	light.look_at(Vector3(.18,1.0,centre_z-.12),Vector3.FORWARD)
	station["motor"] = _sound("elevator_move.wav",centre_z)
	station["door_audio"] = _sound("elevator_door.wav",centre_z)
	stations.append(station)

func _sound(file: String, z: float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.name = "PhysicalTransportAudio_" + file
	audio.position = Vector3(0,1.2,z)
	audio.max_distance = 12.0
	audio.volume_db = -10.0
	var path := "res://audio/" + file
	if ResourceLoader.exists(path): audio.stream = load(path)
	add_child(audio)
	return audio

func _build_stairs(direction: int, destination: int) -> void:
	# A concrete service stair is a genuine walkable incline: 8 distinct
	# Kenney CC0 floor GLB steps plus ONE smooth invisible convex ramp.
	var start_z := -25.90 if direction == 1 else -1.55
	var advance := -0.51 if direction == 1 else 0.51
	var landing_z := start_z + advance*7.5
	var station := {"direction":direction,"destination":destination,"kind":"stairs",
		"centre":Vector3(0,0,landing_z)}
	for i in range(8):
		var height := .10+float(i)*.127
		var z := start_z + float(i)*advance
		_glb("floor_panel",Vector3(0,height-.12,z),Vector3(2.40,.17,.53),floor_finish)
		# Side rails/banisters are original Kenney pipe GLBs (not cylinders).
		if i%2 == 0:
			for side in [-1.0,1.0]:
				_glb("pipe",Vector3(side*1.25,height+.67,z),Vector3(.13,.16,1.18),metal)
	var floor0 := start_z - advance*.50
	var floor1 := start_z + advance*7.50
	var ramp := StaticBody3D.new()
	ramp.name = "InvisibleSmoothStairWalkingRamp"
	var polygon := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for side in [-1.18,1.18]:
		pts.append(Vector3(side,-.21,floor0))
		pts.append(Vector3(side,-.21,floor1))
		pts.append(Vector3(side,0.0,floor0))
		pts.append(Vector3(side,1.02,floor1))
	polygon.points = pts
	var collider := CollisionShape3D.new()
	collider.shape = polygon
	ramp.add_child(collider)
	add_child(ramp)
	station["ramp"] = ramp
	# Solid rail colliders remain outside the 2.3m walkable lane; the
	# originals remain Kenney pipe GLBs, not procedural rail render meshes.
	for side in [-1.0,1.0]:
		_collision(Vector3(side*1.29,.96,(floor0+floor1)*.5),
			Vector3(.18,1.92,absf(floor1-floor0)+.9))
	var exit_z := landing_z+advance*.72
	# Stair portal has proper opaque CC0 GLB flanks and a short backed
	# end recess: no black void behind a window-shaped fake doorway.
	for side in [-1.0,1.0]:
		_panel(Vector3(side*.94,1.34,exit_z),Vector3(.70,2.68,.19),solid_steel)
	_panel(Vector3(0,1.34,exit_z+advance*.98),Vector3(2.59,2.68,.15),solid_steel)
	var exit_gate := _panel(Vector3(0,1.35,exit_z),Vector3(1.18,2.70,.16),moving_steel)
	var stair_barrier := _collision(Vector3(0,1.35,exit_z),Vector3(1.18,2.70,.18))
	station["closed_collision"] = stair_barrier
	station["door_left"] = exit_gate
	station["door_right"] = null
	_sign("STAIRS -> "+floor_name(destination),Vector3(0,2.45,landing_z+advance*.9),true)
	var button_where := Vector3(.93,1.39,landing_z+advance*.10)
	_panel(Vector3(1.16,1.39,landing_z+advance*.12),
		Vector3(.12,1.35,.74),solid_steel,true)
	_button(button_where,destination,destination,direction,"stairs")
	station["door_audio"] = _sound("elevator_door.wav",landing_z)
	# Low-cost stairwell lamp makes individual imported steps readable without
	# illuminating the entire oppressive corridor or rendering GPU shadows.
	var stair_lamp := SpotLight3D.new()
	stair_lamp.name = "StairTreadSafetyPool"
	stair_lamp.position = Vector3(0,2.75,landing_z-advance*3.1)
	stair_lamp.light_energy = 1.28
	stair_lamp.light_color = Color(.75,.80,.73)
	stair_lamp.spot_range = 6.2
	stair_lamp.spot_angle = 52
	stair_lamp.shadow_enabled = false
	add_child(stair_lamp)
	stair_lamp.look_at(Vector3(.18,.5,landing_z-advance*3.1),Vector3.FORWARD)
	stations.append(station)

func selected_button(destination: int, direction: int) -> Node3D:
	for button in buttons:
		if int(button["target"]) == destination and int(button["direction"]) == direction:
			return button["node"] as Node3D
	return null

func station_kind(direction: int) -> String:
	for station in stations:
		if int(station["direction"]) == direction: return String(station["kind"])
	return ""

func interact(player_at: Vector3, eye: Vector3, sight: Vector3) -> String:
	if active: return "BUSY"
	# Dot-product-only aiming could select a neighboring illuminated floor
	# switch even when the player pointed straight at a forbidden switch.
	# Use perpendicular distance to the actual view ray, AND proximity.
	var candidate: Dictionary = {}
	var smallest_offset := .18
	var eye_ray := sight.normalized()
	for button in buttons:
		var node := button["node"] as Node3D
		if not is_instance_valid(node): continue
		if player_at.distance_to(node.global_position) > 2.05: continue
		var target: Vector3 = node.global_position - eye
		var ahead := target.dot(eye_ray)
		if ahead < .15 or ahead > 2.25: continue
		var miss := (target - eye_ray*ahead).length()
		if miss < smallest_offset:
			smallest_offset = miss
			candidate = button
	if candidate.is_empty(): return "LOOK_AT_BUTTON"
	if int(candidate["target"]) != int(candidate["allowed"]): return "LOCKED"
	if String(candidate["kind"]) == "stairs" and player_at.y < .70: return "CLIMB_STAIRS"
	selected = {}
	for station in stations:
		if int(station["direction"]) == int(candidate["direction"]):
			selected = station.duplicate()
			break
	if selected.is_empty(): return "NONE"
	active = true
	elapsed = 0.0
	motor_started = false
	finish_emitted = false
	ride_start = passenger.global_position if is_instance_valid(passenger) else player_at
	if is_instance_valid(passenger):
		passenger.velocity = Vector3.ZERO
		passenger.set_physics_process(false)
	var source := candidate["model"] as Node3D
	if is_instance_valid(source):
		var press := create_tween()
		press.tween_property(source,"position:y",source.position.y-.035,.13)
		press.tween_property(source,"position:y",source.position.y,.17)
	var click := selected.get("door_audio") as AudioStreamPlayer3D
	if is_instance_valid(click) and click.stream != null: click.play()
	set_process(true)
	return "STAIRS" if String(selected["kind"]) == "stairs" else "LIFT"

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta
	if String(selected["kind"]) == "elevator":
		var left := selected["door_left"] as Node3D
		var right := selected["door_right"] as Node3D
		var close_t := clampf(elapsed/.90,0.0,1.0)
		close_t = close_t*close_t*(3.0-2.0*close_t)
		if is_instance_valid(left): left.position.x = lerpf(-1.10,-.49,close_t)
		if is_instance_valid(right): right.position.x = lerpf(1.10,.49,close_t)
		if elapsed >= .90:
			var door_body := selected["closed_collision"] as StaticBody3D
			if is_instance_valid(door_body): door_body.collision_layer = 1
		if elapsed >= 1.00 and not motor_started:
			motor_started = true
			var motor := selected["motor"] as AudioStreamPlayer3D
			if is_instance_valid(motor) and motor.stream != null: motor.play()
		if is_instance_valid(passenger) and elapsed > 1.0:
			# Small physical vertical motion + decaying cabin tremor.
			var t := clampf((elapsed-1.0)/2.55,0.0,1.0)
			var rise := .12*(t*t*(3.0-2.0*t)) + sin(elapsed*19.0)*.008*sin(PI*t)
			passenger.global_position = ride_start + Vector3(0,rise,0)
		if elapsed < ELEVATOR_SECONDS: return
	else:
		# Stairwell threshold GLB retracts only after player physically
		# climbed the ramp and pressed its labeled destination switch.
		var stair_door := selected["door_left"] as Node3D
		if is_instance_valid(stair_door):
			stair_door.position.x = clampf(elapsed/1.0,0.0,1.0)*1.45
		var stair_barrier := selected.get("closed_collision") as StaticBody3D
		if is_instance_valid(stair_barrier) and is_instance_valid(stair_door):
			# Physical wall follows the actual sliding GLB gate rather than
			# leaving an invisible obstruction across the visible opening.
			stair_barrier.position.x = stair_door.position.x
		if elapsed < STAIR_DOOR_SECONDS: return
	active = false
	set_process(false)
	if finish_emitted: return
	finish_emitted = true
	arrived.emit(source_level,int(selected["destination"]))

func deactivate() -> void:
	set_process(false)
	active = false
	if is_instance_valid(passenger): passenger.set_physics_process(false)
	for station in stations:
		var motor := station.get("motor") as AudioStreamPlayer3D
		if is_instance_valid(motor): motor.stop()
		var collision := station.get("closed_collision") as StaticBody3D
		if is_instance_valid(collision):
			collision.collision_layer = 0
			collision.collision_mask = 0
	for shape in find_children("*","CollisionObject3D",true,false):
		(shape as CollisionObject3D).collision_layer = 0
