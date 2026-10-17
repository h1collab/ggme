extends Node3D
# Cinematic-only underground secret facility. Reused imported Kenney CC0 GLBs.
const Assets = preload("backrooms_assets.gd")
const CAMERA_GROUND := Vector3(0, 0.32, 3.1)
const CAMERA_UP := Vector3(0, 1.62, 3.1)
const LOOK_GROUND := Vector3(0, -0.4, 0.35)
const LOOK_DARKNESS := Vector3(0, 1.26, -18.0)
var authored_modules := 0
var facility_lights: Array[Light3D] = []
var low_rumble: AudioStreamPlayer3D
var far_clang: AudioStreamPlayer3D
var smiler: Node3D
var smiler_glow: OmniLight3D
var smiler_sound: AudioStreamPlayer3D
var door_audio: AudioStreamPlayer3D
var near_door_audio: AudioStreamPlayer3D
var door_notice_until := 0.0
var walkable_floor: StaticBody3D
var side_doors: Array[Node3D] = []
var openable_door: Node3D
var laboratory_entered := false
var laboratory_modules := 0
var laboratory_spawn := Vector3(11.0,0.12,-3.0)
var laboratory_root: Node3D
var lab_physics: StaticBody3D
var lab_central_light: OmniLight3D
var lab_emergency_light: SpotLight3D
var lab_power_failed := false
var lab_power_restored := false
var door_slammed := false
var flashlight_collected := false
var flashlight_world: Node3D
var flashlight_pickup_position := Vector3(0.64,0.14,2.25)
var backup_panel_position := Vector3(12.8,1.25,-4.8)
var slam_audio: AudioStreamPlayer3D
var pickup_audio: AudioStreamPlayer3D
var module_target: Node3D
var door_tween: Tween
var proximity_last_ms := -100000
var frowner: Sprite3D
var frowner_started := false
var frowner_finished := false
var frowner_timer := 0.0
var frowner_position := Vector3(-3.05,1.63,-4.4)
var smiler_flashlight_faded := false
# Isolated room story: two genuine Kenney switches, delayed footsteps and
# a streamed observation wing. No recurrent light/audio/model allocations.
var breaker_position := Vector3(9.0,1.25,-5.4)
var breaker_isolated := false
var breaker_model: Node3D
var backup_model: Node3D
var observation_root: Node3D
var observation_shutter: Node3D
var observation_shutter_body: StaticBody3D
var observation_chair: Node3D
var observation_light: OmniLight3D
var observation_physics: StaticBody3D
var observation_console_position := Vector3(11.15,1.24,-10.85)
var observation_seen := false
var signal_traced := false
var delayed_steps: AudioStreamPlayer3D
var breaker_click: AudioStreamPlayer3D
var _chair_tween: Tween
var _shutter_tween: Tween
var _facility_mat: StandardMaterial3D

func _ready() -> void:
	name = "WakeupFacility_Area51Inspired"
	# Facility is a plausible black-site research space, not an official Area 51 layout.
	var concrete := _photographic_pbr("worn_plaster_wall", Color(0.95,0.94,0.92), 1.2)
	# Real verified Poly Haven CC0 diffuse/normal/roughness replace the
	# untextured metal-colored slabs on our supplemental imported GLBs.
	var industrial := _photographic_pbr("rusty_metal_sheet", Color(0.58,0.64,0.65), 0.82)
	var floor_finish := _photographic_pbr("concrete_floor", Color(0.91,0.91,0.91), 1.0)
	# CPU-baked original Kenney Space Station GLB corridor: 75 original modules
	# in a few draw batches instead of 75 repeated Godot PackedScene hierarchies.
	var corridor_path := Assets.path("vendor/facility_corridor_cc0.glb")
	if not ResourceLoader.exists(corridor_path):
		push_error("Missing validated authored Kenney corridor GLB: " + corridor_path)
	else:
		var corridor: Node3D = load(corridor_path).instantiate()
		corridor.name = "KenneyCC0_Corridor75ModulesBatched"
		add_child(corridor)
		var rock := _photographic_pbr("worn_plaster_wall", Color(0.93,0.93,0.94), 1.0)
		var ceiling_finish := _photographic_pbr("rusty_metal_sheet", Color(0.55,0.57,0.58), 0.82)
		for node in corridor.find_children("*","MeshInstance3D",true,false):
			var mesh := node as MeshInstance3D
			var semantic := String(mesh.name).to_lower()
			# Batch groups from the verified Kenney CC0 GLB, now with planar UVs:
			# floor, wall and roof are separate meshes with genuine PBR materials.
			if semantic.contains("floor"):
				mesh.material_override = floor_finish
			elif semantic.contains("roof") or semantic.contains("ceiling"):
				mesh.material_override = ceiling_finish
			else:
				mesh.material_override = rock
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		authored_modules += 75
		# The original Kenney wall has decorative narrow openings. Back
		# every NON-DOOR slot with real, opaque Kenney floor-panel GLB
		# vertices rotated vertically, so flashlight rays do not reveal the
		# empty world through the authored wall cutouts.
		var infill_mat := Assets.projected_pbr(concrete,0.72)
		for z in [3.0,1.5,0.0,-1.5,-3.0,-4.5,-6.0,-7.5,-9.0]:
			_opaque_glb(Vector3(-4.00,1.54,z),Vector3(.12,3.12,1.55),infill_mat,true)
			# The only unlocked physical exit is x>0, z~-0.9.
			if z not in [0.0,-1.5]:
				_opaque_glb(Vector3(4.00,1.54,z),Vector3(.12,3.12,1.55),infill_mat,true)
	for z in [3.0,-2.0,-7.0]:
		for x in [-3.6,3.6]:
			_module("wall_pillar",Vector3(x,1.5,z),industrial,Vector3(0.4,3.0,0.4))
	# The earlier oversized floating Kenney door mesh at x=-2.8 had no
	# matching collision or walkable doorway. Remove that orphan render node.
	# Remove floating eye-level surplus GLB display/monitor blocks intersecting
	# the real corridor. The original batched Kenney GLB walls remain fully PBR.
	for i in range(5):
		_module("pipe",Vector3(-3.45,2.65,1.6-i*2.0),industrial,Vector3(0.24,0.24,1.8))
	_module("container_tall",Vector3(2.9,0.95,1.6),industrial,Vector3(0.85,1.9,0.85))
	# Authored corridor end wall is already included in the offline combined GLB.
	# Seal the real far end of the corridor with licensed opaque GLB geometry,
	# rather than another window-shaped fake door over a dark void.
	_opaque_glb(Vector3(0,1.53,-9.75),Vector3(4.14,3.12,.21),Assets.projected_pbr(industrial,0.72))
	# Restore visible depth at the far door with genuine Kenney GLB pipes
	# and pillars. No new primitive render geometry, no dynamic shadows.
	_module("pipe",Vector3(-1.8,2.62,-8.6),industrial,Vector3(.20,.24,2.15))
	_module("pipe",Vector3(1.8,2.62,-8.6),industrial,Vector3(.20,.24,2.15))
	_module("wall_pillar",Vector3(-2.40,1.5,-9.4),industrial,Vector3(.35,3.0,.35))
	_module("wall_pillar",Vector3(2.40,1.5,-9.4),industrial,Vector3(.35,3.0,.35))
	# Imported Kenney door meshes are visible; collision is invisible and cheap.
	for door_at in [Vector3(-3.40,1.3,1.4),Vector3(3.40,1.3,-0.9),Vector3(-3.40,1.3,-4.5),Vector3(3.40,1.3,-6.4)]:
		var door := _authored_door(door_at)
		if door != null: side_doors.append(door)
	# One door is an actual continuation, others remain sealed with LOCK feedback.
	if side_doors.size() >= 2: openable_door = side_doors[1]
	# v0.25: Laboratory GLBs and lights are built lazily, upon actually opening the door.
	# Mark the openable doorway with multiple repetitions of the licensed
	# original Sketchfab face texture, referencing the unsettling Level ! door.
	# Do not billboard a second Smiler onto the right-hand wall. The authored
	# GLB door frame itself marks the passage without duplicate penetrating eyes.
	var frowner_file := Assets.path("vendor/frowner_online_ccby.png")
	if ResourceLoader.exists(frowner_file):
		frowner = Sprite3D.new()
		frowner.name = "FrownerInspired_InternetTwemoji_CC_BY4"
		frowner.texture = load(frowner_file)
		frowner.position = frowner_position
		frowner.pixel_size = 0.00145
		frowner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		frowner.shaded = false
		frowner.no_depth_test = false
		frowner.visible = false
		add_child(frowner)
	# The interactive body has a simple invisible physical floor and perimeter.
	walkable_floor = StaticBody3D.new()
	walkable_floor.name = "InvisibleFacilityPhysics"
	add_child(walkable_floor)
	_barrier(Vector3(0,-0.17,-3.0),Vector3(7.4,0.30,14.7))
	_barrier(Vector3(-3.8,1.45,-3.0),Vector3(0.35,3.0,14.8))
	_barrier(Vector3(3.8,1.45,-6.1),Vector3(0.35,3.0,8.0))
	_barrier(Vector3(3.8,1.45,2.45),Vector3(0.35,3.0,3.3))
	for x in [4.55,6.05]: _module("floor_panel",Vector3(x,-0.06,-0.9),floor_finish,Vector3(1.5,0.18,2.1))
	# The right-hand interactive exit formerly opened into an UNBUILT
	# black void. Build a shallow, fully enclosed Kenney GLB airlock,
	# with solid PBR side walls, a real roof and an opaque far bulkhead.
	var vestibule_mat := Assets.projected_pbr(industrial,0.72)
	_opaque_glb(Vector3(5.30,1.54,.38),Vector3(3.02,3.12,.15),vestibule_mat)
	_opaque_glb(Vector3(5.30,1.54,-2.14),Vector3(3.02,3.12,.15),vestibule_mat)
	_opaque_glb(Vector3(6.81,1.54,-.88),Vector3(.18,3.12,2.60),vestibule_mat,true)
	_module("floor_panel",Vector3(5.30,3.04,-.88),industrial,Vector3(3.08,.17,2.58))
	_barrier(Vector3(5.30,3.06,-.88),Vector3(3.08,.22,2.58))
	_barrier(Vector3(5.45,-0.17,-0.9),Vector3(4.15,0.30,2.2))
	_barrier(Vector3(5.30,1.45,.38),Vector3(3.05,2.95,.19))
	_barrier(Vector3(5.30,1.45,-2.14),Vector3(3.05,2.95,.19))
	_barrier(Vector3(6.81,1.45,-.88),Vector3(.22,2.95,2.60))
	_barrier(Vector3(0,1.45,-10.1),Vector3(7.6,3.0,0.35))
	_barrier(Vector3(0,1.45,4.1),Vector3(7.6,3.0,0.35))
	# Small Plastic Torch: licensed Poly Haven original imported GLB.
	var flashlight_path := Assets.path("vendor/flashlight_cc0.glb")
	if not ResourceLoader.exists(flashlight_path):
		push_error("Missing verified CC0 flashlight GLB: " + flashlight_path)
	else:
		flashlight_world = _flashlight_model()
		flashlight_world.name = "PolyHaven_CC0_Flashlight_Pickup"
		flashlight_world.position = flashlight_pickup_position
		flashlight_world.rotation = Vector3(0.15,0.35,PI * 0.46)
		add_child(flashlight_world)
	# Invisible colliders are disabled whenever the cinematic facility is hidden.
	set_physics_active(false)
	# Author's original Sketchfab GLB is baked to this transparent sprite.
	# It faces the viewer rather than behaving as a skinned pursuer.
	var sprite_path := Assets.path("vendor/sketchfab_smiler_face.png")
	if not ResourceLoader.exists(sprite_path):
		push_error("Missing verified Sketchfab Smiler sprite: " + sprite_path)
	else:
		var sprite := Sprite3D.new()
		sprite.name = "SketchfabSmilerTexture_OriginalGeometryBake"
		sprite.texture = load(sprite_path)
		sprite.pixel_size = 0.0020
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.no_depth_test = false
		sprite.shaded = false
		# Depth-tested against the facility walls; NEVER draw the face through concrete.
		sprite.double_sided = true
		sprite.transparent = true
		sprite.position = Vector3(0,1.50,-5.4)
		add_child(sprite)
		smiler = sprite
		smiler.visible = false
	smiler_sound = AudioStreamPlayer3D.new()
	smiler_sound.name = "SmilerTwoStageAudio"
	smiler_sound.position = Vector3(0,1.5,-4.6)
	smiler_sound.max_distance = 25.0
	var scare_path := "res://audio/smiler_sting.wav"
	if ResourceLoader.exists(scare_path): smiler_sound.stream = load(scare_path)
	add_child(smiler_sound)
	door_audio = AudioStreamPlayer3D.new()
	door_audio.name = "LockedDoorImpact"
	door_audio.max_distance = 15.0
	var lock_path := "res://audio/door_locked.wav"
	if ResourceLoader.exists(lock_path): door_audio.stream = load(lock_path)
	add_child(door_audio)
	near_door_audio = AudioStreamPlayer3D.new()
	near_door_audio.name = "ApproachingLockedDoor_Creak"
	near_door_audio.max_distance = 13.0
	var creak_path := "res://audio/door_creak.wav"
	if ResourceLoader.exists(creak_path): near_door_audio.stream = load(creak_path)
	add_child(near_door_audio)
	slam_audio = AudioStreamPlayer3D.new()
	slam_audio.name = "SmilerDoor_SpatialSlam"
	slam_audio.max_distance = 16.0
	if ResourceLoader.exists("res://audio/door_slam.wav"): slam_audio.stream = load("res://audio/door_slam.wav")
	add_child(slam_audio)
	pickup_audio = AudioStreamPlayer3D.new()
	pickup_audio.name = "Flashlight_Pickup3D"
	pickup_audio.max_distance = 10.0
	if ResourceLoader.exists("res://audio/flashlight_pickup.wav"): pickup_audio.stream = load("res://audio/flashlight_pickup.wav")
	add_child(pickup_audio)
	breaker_click = AudioStreamPlayer3D.new()
	breaker_click.name = "Circuit_Isolation_Contact3D"
	breaker_click.max_distance = 11.0
	if ResourceLoader.exists("res://audio/flashlight_click.wav"):
		breaker_click.stream = load("res://audio/flashlight_click.wav")
	add_child(breaker_click)
	delayed_steps = AudioStreamPlayer3D.new()
	delayed_steps.name = "ObservationFootstep_TheOneBehindYou"
	delayed_steps.max_distance = 13.0
	var echoed_step := Assets.path("vendor/monster_step.ogg")
	if ResourceLoader.exists(echoed_step): delayed_steps.stream = load(echoed_step)
	add_child(delayed_steps)
	# A distant shutter has no floodlighting. Forward view ends in darkness.
	for at in [Vector3(1.9,2.7,1.4),Vector3(-1.7,2.7,-1.8)]:
		var light := SpotLight3D.new()
		light.position = at
		light.light_color = Color(0.54,0.74,0.83)
		light.light_energy = 0.98
		light.spot_range = 5.1
		light.spot_angle = 43.0
		light.shadow_enabled = false
		add_child(light)
		light.look_at(at+Vector3(0,-2.2,-0.3))
		facility_lights.append(light)
	# A weak, localised emergency spill reveals only the immediate floor
	# and near wall texture; the distant corridor remains unlit.
	var near_spill := OmniLight3D.new()
	near_spill.name = "ColdEmergencySpill_NearAwakeOnly"
	near_spill.position = Vector3(-1.4, 1.45, 2.2)
	near_spill.light_color = Color(0.50, 0.72, 0.82)
	near_spill.light_energy = 1.36
	near_spill.omni_range = 6.5
	near_spill.shadow_enabled = false
	add_child(near_spill)
	facility_lights.append(near_spill)
	var distant_lamp := SpotLight3D.new()
	distant_lamp.name = "LowCostShutterDoorReveal"
	distant_lamp.position = Vector3(-0.85,2.73,-7.95)
	distant_lamp.light_color = Color(.94,.53,.36)
	distant_lamp.light_energy = 0.78
	distant_lamp.spot_range = 4.15
	distant_lamp.spot_angle = 36.0
	distant_lamp.shadow_enabled = false
	add_child(distant_lamp)
	distant_lamp.look_at(Vector3(0,1.2,-9.65))
	facility_lights.append(distant_lamp)
	low_rumble = AudioStreamPlayer3D.new()
	low_rumble.name = "DistantVentilation_Rumble"
	low_rumble.position = Vector3(0,1.8,-5.0)
	low_rumble.max_distance = 20.0
	var sound_path := Assets.path("vendor/hum.mp3")
	if ResourceLoader.exists(sound_path): low_rumble.stream = load(sound_path)
	add_child(low_rumble)
	far_clang = AudioStreamPlayer3D.new()
	far_clang.name = "SomethingBeyondTheShutter_3D"
	far_clang.position = Vector3(0,1.6,-8.6)
	far_clang.max_distance = 18.0
	far_clang.unit_size = 1.4
	var door_f = "res://audio/elevator_door.wav"
	if ResourceLoader.exists(door_f): far_clang.stream = load(door_f)
	add_child(far_clang)
	visible = false
	set_process(false)

func begin_frowner() -> void:
	if frowner_started or frowner_finished or not is_instance_valid(frowner): return
	frowner_started = true
	frowner_timer = 0.0
	frowner.visible = true
	frowner.modulate.a = 0.0
	create_tween().tween_property(frowner,"modulate:a",0.9,0.65)

func update_frowner(delta: float) -> void:
	if not frowner_started or frowner_finished: return
	frowner_timer += delta
	if frowner_timer > 2.6:
		frowner_finished = true
		var fade := create_tween()
		fade.tween_property(frowner,"modulate:a",0.0,1.6)
		fade.finished.connect(func():
			if is_instance_valid(frowner): frowner.visible = false)

func reveal_torch_smiler() -> void:
	if smiler_flashlight_faded or not is_instance_valid(smiler): return
	smiler.modulate.a = 1.0
	smiler.position = Vector3(0.0,1.6,-3.2)
	smiler.visible = true

func smiler_flashlight_hit() -> void:
	if smiler_flashlight_faded or not is_instance_valid(smiler) or not smiler.visible: return
	smiler_flashlight_faded = true
	var fade := create_tween()
	fade.tween_property(smiler,"modulate:a",0.0,0.27)
	fade.finished.connect(func():
		if is_instance_valid(smiler): smiler.visible = false)

func _build_laboratory() -> void:
	if is_instance_valid(laboratory_root): return
	laboratory_root = Node3D.new()
	laboratory_root.name = "StreamedLaboratory_GLBSector"
	add_child(laboratory_root)
	module_target = laboratory_root
	# A single watertight, authored and batch-merged Kenney GLB shell.
	var shell := Assets.path("vendor/laboratory_shell_cc0.glb")
	if not ResourceLoader.exists(shell): push_error("Missing sealed laboratory GLB")
	else:
		var scene: Node3D = load(shell).instantiate()
		scene.name = "KenneyCC0_SealedLaboratory_GLBBatched"
		laboratory_root.add_child(scene)
		var material := _finish(Color(0.44,0.50,0.53),"concrete.jpg")
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		for m in scene.find_children("*","MeshInstance3D",true,false):
			(m as MeshInstance3D).material_override = material
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		laboratory_modules = 58
	var steel := _finish(Color(0.27,0.34,0.36))
	# The players physically flip original Kenney wall-switch GLBs, not UI menus.
	breaker_model = Assets.fitted("vendor/wakeup_wall_switch.glb",0.65)
	breaker_model.name = "KenneyIsolationBreaker_PhysicalGLB"
	breaker_model.position = breaker_position
	breaker_model.rotation.y = PI*0.5
	laboratory_root.add_child(breaker_model)
	backup_model = Assets.fitted("vendor/wakeup_wall_switch.glb",0.65)
	backup_model.name = "KenneyEmergencyReactorSwitch_PhysicalGLB"
	backup_model.position = backup_panel_position
	backup_model.rotation.y = -PI*0.5
	laboratory_root.add_child(backup_model)
	for spot in [Vector3(9.0,1.25,-3.1),Vector3(12.8,1.25,-4.8)]:
		_module("computer_screen",spot,steel,Vector3(0.75,0.85,0.45))
		laboratory_modules += 1
	for spot in [Vector3(8.4,0.9,-5.7),Vector3(13.7,0.9,-2.2)]:
		_module("container_tall",spot,steel,Vector3(0.9,1.8,0.9))
		laboratory_modules += 1
	var lab_light := OmniLight3D.new()
	lab_light.position = Vector3(10.6,2.55,-3.1)
	lab_light.light_color = Color(0.65,0.83,0.90)
	lab_light.light_energy = 2.8
	lab_light.omni_range = 9.0
	lab_light.shadow_enabled = false
	laboratory_root.add_child(lab_light)
	lab_central_light = lab_light
	var emergency := SpotLight3D.new()
	emergency.name = "AbandonedLab_Emergency"
	emergency.position = Vector3(13.25,2.65,-5.15)
	emergency.light_color = Color(0.90,0.93,0.87)
	emergency.light_energy = 2.1
	emergency.spot_range = 8.0
	emergency.spot_angle = 62.0
	emergency.shadow_enabled = false
	laboratory_root.add_child(emergency)
	emergency.look_at(Vector3(10.8,0.9,-3.4))
	lab_emergency_light = emergency
	# A real imported door blocks the observation chamber until both controls
	# are deliberately operated. The remote GLB wing is still not instantiated.
	observation_shutter = Assets.fitted("vendor/wakeup_door_single_closed.glb",2.45)
	observation_shutter.name = "KenneyAuthored_SlidingObservationAirlock"
	observation_shutter.position = Vector3(11.0,-0.05,-7.27)
	laboratory_root.add_child(observation_shutter)
	observation_shutter_body = StaticBody3D.new()
	observation_shutter_body.name = "ObservationAirlockCollision"
	observation_shutter_body.position.y = 1.22
	var shutter_shape := BoxShape3D.new()
	shutter_shape.size = Vector3(1.54,2.46,0.23)
	var shutter_collision := CollisionShape3D.new()
	shutter_collision.shape = shutter_shape
	observation_shutter_body.add_child(shutter_collision)
	observation_shutter.add_child(observation_shutter_body)
	module_target = null
	lab_physics = StaticBody3D.new()
	lab_physics.name = "Laboratory_ProxyCollision"
	laboratory_root.add_child(lab_physics)
	_barrier(Vector3(11,-0.17,-3.3),Vector3(7.8,0.3,8.5),lab_physics)
	# Leave a traversable entry from the corridor side.
	_barrier(Vector3(7.0,1.5,-5.1),Vector3(0.3,3.0,5.0),lab_physics)
	_barrier(Vector3(7.0,1.5,0.4),Vector3(0.3,3.0,0.4),lab_physics)
	_barrier(Vector3(15,1.5,-3.3),Vector3(0.3,3.0,8.5),lab_physics)
	# Exclude observation door opening from the end-wall collision.
	_barrier(Vector3(8.65,1.5,-7.6),Vector3(2.4,3.0,0.3),lab_physics)
	_barrier(Vector3(13.35,1.5,-7.6),Vector3(2.4,3.0,0.3),lab_physics)
	_barrier(Vector3(11,1.5,0.6),Vector3(8,3.0,0.3),lab_physics)
	set_physics_active(true)

func _open_observation_shutter() -> void:
	if not is_instance_valid(observation_shutter) or _shutter_tween != null and _shutter_tween.is_running(): return
	if is_instance_valid(observation_shutter_body):
		observation_shutter_body.collision_layer = 0
		observation_shutter_body.collision_mask = 0
	_shutter_tween = create_tween()
	_shutter_tween.tween_property(observation_shutter,"position:y",2.55,1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(slam_audio) and slam_audio.stream != null:
		slam_audio.global_position = observation_shutter.global_position
		slam_audio.play()

func _build_observation_wing() -> void:
	if is_instance_valid(observation_root) or not is_instance_valid(laboratory_root): return
	var wing_path := Assets.path("vendor/observation_wing_cc0.glb")
	if not ResourceLoader.exists(wing_path):
		push_error("Missing batched Kenney observation wing GLB: " + wing_path)
		return
	observation_root = Node3D.new()
	observation_root.name = "OnDemandObservationSector"
	laboratory_root.add_child(observation_root)
	var geometry: Node3D = load(wing_path).instantiate()
	geometry.name = "KenneyCC0_SealedObservationGLB"
	observation_root.add_child(geometry)
	var finish := _finish(Color(0.33,0.39,0.41),"concrete.jpg")
	for node in geometry.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		mesh.material_override = finish
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var table := Assets.fitted("vendor/wakeup_computer_screen.glb",1.18)
	table.position = observation_console_position
	table.name = "Observation_EchoTrace_PhysicalTerminal"
	observation_root.add_child(table)
	observation_chair = Assets.fitted("vendor/wakeup_chair.glb",1.14)
	observation_chair.name = "KenneyObservationChair_AnomalousRotation"
	observation_chair.position = Vector3(10.0,0.03,-9.7)
	observation_chair.rotation.y = 0.4
	observation_root.add_child(observation_chair)
	observation_physics = StaticBody3D.new()
	observation_physics.name = "WingCollisionProxies"
	observation_root.add_child(observation_physics)
	var body: StaticBody3D = observation_physics
	_barrier(Vector3(11,-0.17,-9.82),Vector3(6.2,0.30,5.15),body)
	_barrier(Vector3(8.0,1.48,-9.82),Vector3(.3,3.05,5.2),body)
	_barrier(Vector3(14.0,1.48,-9.82),Vector3(.3,3.05,5.2),body)
	_barrier(Vector3(11,1.48,-12.10),Vector3(6.2,3.05,.30),body)
	observation_light = OmniLight3D.new()
	observation_light.position = Vector3(11.0,2.55,-9.7)
	observation_light.light_color = Color(0.55,0.78,0.88)
	observation_light.light_energy = 1.6
	observation_light.omni_range = 5.9
	observation_light.shadow_enabled = false
	observation_root.add_child(observation_light)

func update_observation(player_position: Vector3) -> bool:
	# A physical environmental reaction, triggered by proximity once per run.
	if not is_instance_valid(observation_root) or observation_seen or player_position.z > -8.5: return false
	observation_seen = true
	if is_instance_valid(observation_chair):
		_chair_tween = create_tween()
		_chair_tween.tween_property(observation_chair,"rotation:y",3.65,2.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(delayed_steps) and delayed_steps.stream != null:
		# The noise emanates from the vacant spot behind the player's own path.
		delayed_steps.global_position = player_position + Vector3(0,0,2.0)
		delayed_steps.play()
	if is_instance_valid(observation_light):
		var pulse := create_tween()
		pulse.tween_property(observation_light,"light_energy",0.0,0.23)
		pulse.tween_property(observation_light,"light_energy",1.4,0.8)
	return true

func _flashlight_model() -> Node3D:
	var model := Assets.fitted("vendor/flashlight_cc0.glb", 1.0)
	var dimensions: Vector3 = model.get_meta("dimensions", Vector3.ONE)
	model.scale *= 0.24 / maxf(dimensions.x, maxf(dimensions.y, dimensions.z))
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return model

func reset_facility() -> void:
	if door_tween != null and door_tween.is_running(): door_tween.kill()
	if _shutter_tween != null and _shutter_tween.is_running(): _shutter_tween.kill()
	if _chair_tween != null and _chair_tween.is_running(): _chair_tween.kill()
	if is_instance_valid(laboratory_root): laboratory_root.queue_free()
	laboratory_root = null
	lab_physics = null
	lab_central_light = null
	lab_emergency_light = null
	breaker_model = null
	backup_model = null
	observation_root = null
	observation_shutter = null
	observation_shutter_body = null
	observation_chair = null
	observation_light = null
	observation_physics = null
	breaker_isolated = false
	observation_seen = false
	signal_traced = false
	if is_instance_valid(delayed_steps): delayed_steps.stop()
	if is_instance_valid(breaker_click): breaker_click.stop()
	laboratory_entered = false
	laboratory_modules = 0
	door_slammed = false
	lab_power_failed = false
	lab_power_restored = false
	flashlight_collected = false
	if is_instance_valid(flashlight_world): flashlight_world.visible = true
	frowner_started = false
	frowner_finished = false
	frowner_timer = 0.0
	smiler_flashlight_faded = false
	if is_instance_valid(frowner): frowner.visible = false
	if is_instance_valid(smiler): smiler.modulate.a = 1.0
	if is_instance_valid(openable_door):
		var hinge := openable_door.get_meta("hinge") as Node3D
		if is_instance_valid(hinge): hinge.rotation.y = 0.0
		openable_door.set_meta("opened",false)
	if is_instance_valid(slam_audio): slam_audio.stop()
	set_physics_active(visible)

func _authored_door(at: Vector3) -> Node3D:
	var source := Assets.path("vendor/wakeup_floor_panel.glb")
	if not ResourceLoader.exists(source): return null
	var node := Node3D.new()
	node.name = "KenneyAuthoredInteractiveDoor"
	# Assets.fitted() places the authored GLB base at Y=0, not at its centre.
	node.position = Vector3(at.x,0.015,at.z)
	node.rotation.y = PI * 0.5 if at.x < 0 else -PI * 0.5
	var hinge := Node3D.new()
	hinge.name = "ActualDoorHinge"
	hinge.position.x = -0.77
	node.add_child(hinge)
	# The source door_single_closed.glb has a large stylised cut-out that
	# looked like a giant "2" and exposed unbuilt space. Use an actual
	# Kenney CC0 opaque GLB plate with scan-based PBR, plus a real Kenney
	# switch GLB as latch; the existing door hinge and collision still move.
	var door_finish := _photographic_pbr("rusty_metal_sheet",Color(.76,.81,.82),.95)
	door_finish.metallic = .25
	door_finish.roughness = .64
	var mesh := Assets.licensed_panel(Vector3(.77,1.175,0),Vector3(1.50,2.35,.16),
		Assets.projected_pbr(door_finish,.83))
	mesh.name = "KenneyCC0_OpaqueWorkingDoorGLB"
	hinge.add_child(mesh)
	var latch := Assets.fitted("vendor/wakeup_wall_switch.glb",.19)
	latch.name = "KenneyCC0_PhysicalDoorLatchGLB"
	latch.position = Vector3(1.34,1.12,.13)
	hinge.add_child(latch)
	var body := StaticBody3D.new()
	body.name = "SolidDoorPanel"
	body.position = Vector3(.77,1.175,0) # exactly the opaque GLB panel centre
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5,2.3,0.18)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	hinge.add_child(body)
	node.set_meta("hinge",hinge)
	node.set_meta("body",body)
	node.set_meta("opened",false)
	add_child(node)
	return node

func set_physics_active(enabled: bool) -> void:
	if not is_instance_valid(walkable_floor): return
	walkable_floor.collision_layer = 1 if enabled else 0
	walkable_floor.collision_mask = 1 if enabled else 0
	if is_instance_valid(lab_physics):
		lab_physics.collision_layer = 1 if enabled else 0
		lab_physics.collision_mask = 1 if enabled else 0
	if is_instance_valid(observation_physics):
		observation_physics.collision_layer = 1 if enabled else 0
		observation_physics.collision_mask = 1 if enabled else 0
	if is_instance_valid(observation_shutter_body):
		var shut: int = 1 if enabled and not lab_power_restored else 0
		observation_shutter_body.collision_layer = shut
		observation_shutter_body.collision_mask = shut
	for door in side_doors:
		if is_instance_valid(door):
			var body := door.get_meta("body") as StaticBody3D
			if is_instance_valid(body):
				body.collision_layer = 1 if enabled and not bool(door.get_meta("opened",false)) else 0
				body.collision_mask = body.collision_layer

# Adds only original publisher-authored GLB geometry (NOT BoxMesh). All
# enlarged holes have a true textured rear surface and safe physical walls.
func _opaque_glb(at: Vector3, extent: Vector3, material: Material, side_wall: bool = false) -> Node3D:
	var plate := Assets.licensed_panel(at,extent,material,side_wall)
	plate.name = "KenneyCC0_SolidBackedGLB"
	add_child(plate)
	authored_modules += 1
	return plate

func _barrier(at: Vector3, size: Vector3, parent_body: StaticBody3D = null) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.position = at
	collision.shape = shape
	var target: StaticBody3D = parent_body if is_instance_valid(parent_body) else walkable_floor
	target.add_child(collision)

func smiler_clear_ray(from_eye: Vector3, player_rid: RID) -> bool:
	# Occlusion is checked by physics (and the Sprite3D uses depth testing).
	# The same predicate is required before counting spotlight exposure.
	if not is_instance_valid(smiler) or not smiler.visible: return false
	var query := PhysicsRayQueryParameters3D.create(from_eye,smiler.global_position)
	query.exclude = [player_rid]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func smiler_stage(_progress: float, stage: String) -> void:
	if not is_instance_valid(smiler): return
	smiler.visible = stage == "watch" or stage == "near"
	if stage == "watch": smiler.position = Vector3(0,1.54,-5.4)
	if stage == "near": smiler.position = Vector3(0,1.52,-2.35)
	if is_instance_valid(smiler_sound):
		smiler_sound.position = smiler.position

func nearest_door(player_position: Vector3, max_distance: float = 1.8) -> Node3D:
	var best: Node3D = null
	var shortest := max_distance
	for door in side_doors:
		var distance := player_position.distance_to(door.global_position)
		if distance < shortest:
			shortest = distance
			best = door
	return best

func player_near_door(player_position: Vector3) -> Node3D:
	return nearest_door(player_position,1.55)

func play_door_proximity(door: Node3D) -> void:
	if not is_instance_valid(door) or not is_instance_valid(near_door_audio): return
	near_door_audio.global_position = door.global_position
	var now := Time.get_ticks_msec()
	if now - proximity_last_ms < 2500: return
	proximity_last_ms = now
	if near_door_audio.stream != null and not near_door_audio.playing: near_door_audio.play()

func _animate_door(opening: bool) -> void:
	if not is_instance_valid(openable_door): return
	if door_tween != null and door_tween.is_running(): door_tween.kill()
	var hinge := openable_door.get_meta("hinge") as Node3D
	var body := openable_door.get_meta("body") as StaticBody3D
	if not is_instance_valid(hinge): return
	openable_door.set_meta("opened",opening)
	# Never swing a solid collider through the player's capsule.
	if is_instance_valid(body):
		body.collision_layer = 0
		body.collision_mask = 0
	door_tween = create_tween()
	door_tween.tween_property(hinge, "rotation:y", -1.44 if opening else 0.0, 0.56 if opening else 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not opening and is_instance_valid(body):
		door_tween.finished.connect(func():
			if is_instance_valid(body) and door_slammed and not lab_power_restored and visible:
				body.collision_layer = 1
				body.collision_mask = 1)

func update_visitor(player_position: Vector3) -> bool:
	if not laboratory_entered or door_slammed or player_position.x < 5.8: return false
	door_slammed = true
	lab_power_failed = true
	_animate_door(false)
	if is_instance_valid(slam_audio):
		slam_audio.global_position = openable_door.global_position
		if slam_audio.stream != null: slam_audio.play()
	if is_instance_valid(lab_central_light):
		var flicker := create_tween()
		flicker.tween_property(lab_central_light,"light_energy",0.0,0.16)
		flicker.tween_property(lab_central_light,"light_energy",0.8,0.10)
		flicker.tween_property(lab_central_light,"light_energy",0.05,0.15)
	if is_instance_valid(lab_emergency_light):
		lab_emergency_light.light_color = Color(1.0,0.13,0.09)
		lab_emergency_light.light_energy = 0.66
	return true

func door_result(player_position: Vector3) -> String:
	# Two switches must be operated in physical order. Their locations are
	# visibly modelled by human-authored Kenney GLBs, not a text-entry riddle.
	if lab_power_restored and not signal_traced and is_instance_valid(observation_root) and player_position.distance_to(observation_console_position) < 1.6:
		signal_traced = true
		if is_instance_valid(delayed_steps) and delayed_steps.stream != null:
			delayed_steps.global_position = Vector3(11.2,1.0,-11.6)
			delayed_steps.play()
		if is_instance_valid(observation_light):
			var surge := create_tween()
			surge.tween_property(observation_light,"light_energy",0.18,0.25)
			surge.tween_property(observation_light,"light_energy",2.0,0.6)
		return "TRACE"
	if laboratory_entered and door_slammed and not lab_power_restored and player_position.distance_to(breaker_position) < 1.5:
		if breaker_isolated: return "ISOLATED"
		breaker_isolated = true
		if is_instance_valid(breaker_model):
			create_tween().tween_property(breaker_model,"rotation:z",-0.40,0.27)
		if is_instance_valid(breaker_click) and breaker_click.stream != null:
			breaker_click.global_position = breaker_position
			breaker_click.play()
		if is_instance_valid(lab_emergency_light):
			lab_emergency_light.light_color = Color(0.96,0.46,0.16)
			lab_emergency_light.light_energy = 1.12
		return "BREAKER"
	if laboratory_entered and lab_power_failed and not lab_power_restored and player_position.distance_to(backup_panel_position) < 1.65:
		if not breaker_isolated: return "SHORT"
		lab_power_restored = true
		lab_power_failed = false
		if is_instance_valid(backup_model):
			create_tween().tween_property(backup_model,"rotation:z",0.35,0.35)
		if is_instance_valid(lab_central_light):
			create_tween().tween_property(lab_central_light,"light_energy",1.8,0.75)
		if is_instance_valid(lab_emergency_light):
			lab_emergency_light.light_color = Color(0.52,0.83,0.71)
			lab_emergency_light.light_energy = 1.2
		_animate_door(true)
		_build_observation_wing()
		_open_observation_shutter()
		if is_instance_valid(near_door_audio) and near_door_audio.stream != null:
			near_door_audio.global_position = backup_panel_position
			near_door_audio.play()
		return "POWER"
	if not flashlight_collected and player_position.distance_to(flashlight_pickup_position) < 1.55:
		if not is_instance_valid(flashlight_world): return "NONE"
		flashlight_collected = true
		flashlight_world.visible = false
		if is_instance_valid(pickup_audio) and pickup_audio.stream != null:
			pickup_audio.global_position = flashlight_pickup_position
			pickup_audio.play()
		return "FLASHLIGHT"
	var door := nearest_door(player_position,2.2)
	if door == null: return "NONE"
	if door == openable_door:
		# v0.28 RETIRES the visually unconvincing laboratory entirely.
		# The authored real-GLB door opens onto playable Level 0 instead.
		# Do not instantiate the old laboratory or the observation wing.
		if not bool(door.get_meta("opened",false)): _animate_door(true)
		if is_instance_valid(near_door_audio) and near_door_audio.stream != null:
			near_door_audio.global_position = door.global_position
			if not near_door_audio.playing: near_door_audio.play()
		return "THRESHOLD"
	if is_instance_valid(door_audio) and door_audio.stream != null:
		door_audio.global_position = door.global_position
		if not door_audio.playing: door_audio.play()
	return "LOCK"

func try_locked_door(player_position: Vector3) -> bool:
	var door := nearest_door(player_position,2.2)
	if door == null: return false
	if is_instance_valid(door_audio):
		door_audio.global_position = door.global_position
		if door_audio.stream != null: door_audio.play()
	return true

func _photographic_pbr(name: String, tint: Color, scale: float = 1.0) -> StandardMaterial3D:
	# Real publisher-scanned Poly Haven CC0 albedo/normal/roughness maps
	# verified upstream (size + MD5) by fetch_real_backrooms_assets.py.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.86
	mat.metallic = 0.03
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The authored GLB UV0 and StandardMaterial3D wrap the sampled scan maps.
	mat.uv1_scale = Vector3(scale,scale,1.0)
	for ext in [".jpg",".png",".jpeg"]:
		var diffuse := Assets.path("vendor/pbr_%s_diffuse%s" % [name,ext])
		if ResourceLoader.exists(diffuse):
			mat.albedo_texture = load(diffuse)
			break
	if mat.albedo_texture == null:
		push_error("Licensed photogrammetry diffuse missing: " + name)
	for ext in [".jpg",".png",".jpeg"]:
		var normal := Assets.path("vendor/pbr_%s_normal%s" % [name,ext])
		if ResourceLoader.exists(normal):
			mat.normal_enabled = true
			mat.normal_texture = load(normal)
			mat.normal_scale = 0.45
			break
	for ext in [".jpg",".png",".jpeg"]:
		var rough := Assets.path("vendor/pbr_%s_rough%s" % [name,ext])
		if ResourceLoader.exists(rough):
			mat.roughness_texture = load(rough)
			break
	return mat

func _finish(color: Color, photo: String = "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.28
	m.roughness = 0.77
	if photo != "":
		var file := Assets.path("vendor/"+photo)
		if ResourceLoader.exists(file): m.albedo_texture = load(file)
	return m

func _module(source: String, at: Vector3, material: StandardMaterial3D, dimensions: Vector3) -> void:
	var name := "vendor/wakeup_"+source+".glb"
	if not ResourceLoader.exists(Assets.path(name)):
		push_error("Licensed facility GLB missing: "+name)
		return
	var model := Assets.fitted(name,dimensions.y)
	model.name = "Kenney_CC0_"+source
	model.position = at
	# Ground the source GLB against the physically collidable floor. These
	# coordinates historically supplied geometric CENTERS to base-aligned GLBs.
	if source in ["wall","wall_pillar","wall_door","door_single_closed","container_tall"]:
		model.position.y -= dimensions.y * 0.5
	var source_dims: Vector3 = model.get_meta("dimensions",Vector3.ONE)
	model.scale = Vector3(
		dimensions.x / maxf(source_dims.x,0.01),
		dimensions.y / maxf(source_dims.y,0.01),
		dimensions.z / maxf(source_dims.z,0.01)
	)
	# Keep author-created mesh, only tint it to consistent desaturated concrete.
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).material_override = material
	if is_instance_valid(module_target): module_target.add_child(model)
	else: add_child(model)
	authored_modules += 1

func _exit_tree() -> void:
	for source in [low_rumble, far_clang, smiler_sound, door_audio, near_door_audio, slam_audio, pickup_audio, breaker_click, delayed_steps]:
		if is_instance_valid(source):
			source.stop()
			source.stream = null
