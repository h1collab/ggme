extends Node3D
# Source-authored CC0 M4A1, original PBR, WRAD skinned hands,
# physics-ray hitscan, magazine/reload, ADS, recoil, health and responsive
# non-humanoid security targets. No visible primitive weapon/enemy meshes.
const Assets = preload("backrooms_assets.gd")
const Arsenal = preload("backrooms_arsenal.gd")
const WeaponFinish = preload("fps_weapon_finish.gdshader")
const MAGAZINE_CAPACITY := 24
const MAX_RANGE := 70.0
const RATE_SECONDS := 0.12
const RELOAD_SECONDS := 1.65
const HIP_RECOIL_IMPULSE := .040
const ADS_RECOIL_IMPULSE := .024
const RECOIL_RETURN_SPEED := 14.0
const MATCH_SECONDS := 300.0
const SCORE_LIMIT := 10
const INTERMISSION_SECONDS := 8.0

var game: Node
var active := false
var equipped := false
var aiming := false
var magazine := MAGAZINE_CAPACITY
var reserve := 96
var health := 100
var level_id := -1
var target_remaining := 0
var confirmed_hits := 0
var defeated := 0
var shot_cooldown := 0.0
var reload_time := 0.0
var enemy_timer := 2.8
var invulnerable_time := 0.0
var visual_recoil := 0.0
var hit_feedback_time := 0.0
var combat_clock := 0.0
var weapon_pivot: Node3D
var weapon_model: Node3D
var grip_hands: Node3D
var grip_skeleton: Skeleton3D
var grip_ready := false
var grip_error := 999.0
var grip_mesh_error := 999.0
var grip_surface_error := 999.0
var grip_mounts: Array[Dictionary] = []
# Measured in the original M4A1 coordinates: pistol grip and fore-end.
const GUN_SCALE := 1.0
const GRIP_POINTS := [Vector3(.013,-.085,.072),Vector3(0,-.006,-.235)]
var wall_retract := 0.0
var wall_probe_seconds := 0.0
var wall_clearance := 100.0
var wall_probe_origin := Vector3.INF
var wall_probe_direction := Vector3.ZERO
var wall_planes: Array[Dictionary] = []
var weapon_vertices := PackedVector3Array()
var weapon_triangles := PackedVector3Array()
var wall_support_points := PackedVector3Array()
var reload_visual_seconds := 0.0
var sentries: Array[StaticBody3D] = []
var health_by_peer: Dictionary = {}
var ammo_by_peer: Dictionary = {}
var scores: Dictionary = {}
var deaths: Dictionary = {}
var weapon_by_peer: Dictionary = {}
var loadouts: Dictionary = {}
var switch_ends: Dictionary = {}
var selected_weapon := 0
var local_equip_end := 0
var extra_weapons: Array[Node3D] = []
var rifle_supports := PackedVector3Array()
var hand_rest_transforms: Array[Transform3D] = []
var rifle_finger_poses: Array[Quaternion] = []
var shot_events: Array[Dictionary] = []
var shot_serial := 0
var last_shot_serial := 0
var remote_shots: Array[AudioStreamPlayer3D] = []
var switch_audio: AudioStreamPlayer
var result_audio: AudioStreamPlayer
var damage_audio: AudioStreamPlayer
var shot_sounds: Array[AudioStream] = []

var kill_events: Array[Dictionary] = []
var kill_serial := 0
var hit_serials: Dictionary = {}
var last_confirmed_serial := 0
var damage_feedback_time := 0.0
var reserve_by_peer: Dictionary = {}
var reload_ends: Dictionary = {}
var reload_blocks: Dictionary = {}
var reload_block_ammo: Dictionary = {}
var reload_durations: Dictionary = {}
var shot_ticks: Dictionary = {}
var shot_audio: AudioStreamPlayer
var reload_audio: AudioStreamPlayer
var impact_audio: AudioStreamPlayer
var weapon_finish_ready := false
var muzzle_light: OmniLight3D
var muzzle_flash_time := 0.0
var rifle_magazine: Node3D
var rifle_handle: Node3D
var magazine_rest := Vector3.ZERO
var handle_rest := Vector3.ZERO
var left_hand_rest := Transform3D.IDENTITY
var magazine_contact := Vector3.ZERO
var magazine_contact_ready := false
var impacts: Array[Dictionary] = []
var impact_serial := 0
var last_impact_serial := 0
var impact_sprites: Array[Sprite3D] = []
var impact_ages: Array[float] = []
var training_enabled := false
var training_hits := 0
const TRAINING_SECONDS := 45.0
var training_time := 0.0
var training_shots := 0
var training_finished := false
var training_best := 0
var training_targets: Array[StaticBody3D] = []
var round_id := 1
var round_remaining := MATCH_SECONDS
var round_over := false
var round_break := 0.0
var round_winners: Array[int] = []
var round_winner_seats: Array[int] = []
var round_ready: Dictionary = {}
var round_tick_msec := 0

func _ready() -> void:
    name = "Faceless2_KenneyCC0_FPS"
    set_process(false)
    weapon_pivot = Node3D.new()
    weapon_pivot.name = "CameraMounted_LicensedCC0M4A1GLB"
    game.player.camera.add_child(weapon_pivot)
    weapon_pivot.position = Vector3(.24,-.22,-.64)
    weapon_pivot.rotation = Vector3(-.04,-.08,-.025)
    if ResourceLoader.exists(Assets.path("vendor/fps_m4a1.glb")):
        weapon_model = load(Assets.path("vendor/fps_m4a1.glb")).instantiate()
        weapon_model.name = "Nisu_CC0_M4A1_OriginalAuthoredParts"
        weapon_model.scale = Vector3.ONE * GUN_SCALE
        weapon_pivot.add_child(weapon_model)
        for node in weapon_model.find_children("*","MeshInstance3D",true,false):
            var mesh := node as MeshInstance3D
            mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            _finish_rifle(mesh)
            var local: Transform3D = weapon_pivot.global_transform.affine_inverse()*mesh.global_transform
            # Eight source-mesh bounds corners conservatively contain every
            # vertex. Cache them once; close-wall frames need only 13*8 tests.
            var bounds := mesh.get_aabb()
            for corner in range(8):
                wall_support_points.append(local*bounds.get_endpoint(corner))
            for surface in range(mesh.mesh.get_surface_count()):
                var arrays: Array = mesh.mesh.surface_get_arrays(surface)
                var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                for vertex in vertices: weapon_vertices.append(local*vertex)
                var faces: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
                for index in faces: weapon_triangles.append(local*vertices[index])
    else:
        push_error("Source-verified CC0 M4A1 GLB not packaged")
    # New, genuinely rigged WRAD ARMS CC0 authored GLB replaces the
    # separated Sketchfab hands ONLY in FPS mode. The mesh, source skin,
    # texture, fingers and wrist joints remain from the original GLB.
    # The gun AND both hands share one pivot: ADS, recoil and gait never
    # make a hand slide away from the rifle.
    grip_hands = Node3D.new()
    grip_hands.name = "LicensedWRAD_SkinnedTwoHandWeaponMount"
    weapon_pivot.add_child(grip_hands)
    # Each hand is a separately source-trimmed GLB, still using the
    # original rigged skin and texture, not generated geometry. Keeping
    # transforms rigidly on the same weapon pivot prevents dislocated IK
    # elbows and divergent ADS/running/recoil animation.
    var mounted := 0
    for side in ["r","l"]:
        var path := Assets.path("vendor/fps_wrad_grip_%s.glb" % side)
        if not ResourceLoader.exists(path):
            push_error("Verified WRAD CC0 skinned %s hand GLB missing" % side)
            continue
        var hand: Node3D = load(path).instantiate()
        hand.name = "WRAD_CC0_Skinned_%s_ActualGLBGrip" % side
        grip_hands.add_child(hand)
        var skeletons: Array[Node] = hand.find_children("*","Skeleton3D",true,false)
        if skeletons.is_empty():
            push_error("Original WRAD %s hand has no skinned Skeleton3D" % side)
            continue
        var skel := skeletons[0] as Skeleton3D
        var wrist := skel.find_bone("wrist."+side)
        var socket := skel.find_bone("socket."+side)
        if wrist < 0 or socket < 0:
            push_error("WRAD authored wrist/socket missing")
            continue
        if side == "r": grip_skeleton = skel
        _curl_hand_fingers(skel,side)
        # Align the authored wrist frame, not an AABB of unused vertices.
        # Y points along the palm; X is palm normal; Z is thumb side.
        var left_forward := Vector3(.35,.25,-.90).normalized()
        var left_normal := (Vector3.UP-left_forward*left_forward.y).normalized()
        var right_forward := Vector3(-.18,.80,-.57).normalized()
        var right_normal := (Vector3.RIGHT-right_forward*right_forward.x).normalized()
        var palm := Basis(right_normal,right_forward,right_normal.cross(right_forward)) if side == "r" else Basis(left_normal,left_forward,left_normal.cross(left_forward))
        var source_wrist: Transform3D = hand.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(wrist)
        var aligned := Transform3D(palm.scaled(Vector3.ONE*.10),Vector3.ZERO) * source_wrist.affine_inverse()
        hand.transform = aligned
        var target: Vector3 = weapon_model.transform * GRIP_POINTS[0 if side == "r" else 1]
        var actual: Vector3 = grip_hands.to_local(skel.to_global(skel.get_bone_global_pose(socket).origin))
        hand.position += target-actual
        _tuck_forearm(hand,skel,side,wrist)
        grip_mounts.append({"hand":hand,"skeleton":skel,"socket":socket,"target":target})
        for part in hand.find_children("*","MeshInstance3D",true,false):
            var skin_mesh := part as MeshInstance3D
            skin_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            for surface in range(skin_mesh.mesh.get_surface_count()):
                var source_material := skin_mesh.get_active_material(surface) as StandardMaterial3D
                if source_material == null: continue
                var skin_finish := source_material.duplicate() as StandardMaterial3D
                skin_finish.albedo_color *= Color(.72,.71,.69,1.0)
                skin_finish.roughness = .78
                skin_finish.metallic = 0.0
                skin_finish.metallic_specular = .28
                # The shadow-only full body uses another authored pose;
                # its limbs must not stripe the separate first-person rig.
                skin_finish.disable_receive_shadows = true
                skin_mesh.set_surface_override_material(surface,skin_finish)
        mounted += 1
    _calibrate_grip_surfaces()
    _pose_trigger_finger()
    measure_grip()
    grip_ready = mounted == 2 and grip_error < .002 and grip_mesh_error < .005 and grip_surface_error < .0005
    print("FPS_ORIGINAL_CC0_TWO_HAND_GRIP=",mounted)
    rifle_magazine = weapon_model.find_child("Magazine",true,false)
    rifle_handle = weapon_model.find_child("Charging_Handle",true,false)
    if is_instance_valid(rifle_magazine):
        magazine_rest = rifle_magazine.position
        _calibrate_magazine_contact()
    if is_instance_valid(rifle_handle): handle_rest = rifle_handle.position
    if grip_hands.get_child_count() == 2: left_hand_rest = grip_hands.get_child(1).transform
    weapon_pivot.visible = false
    shot_audio = _audio("fps_shot.wav",-12)
    reload_audio = _audio("fps_reload.wav",-15)
    impact_audio = _audio("fps_impact.wav",-12)
    muzzle_light = OmniLight3D.new()
    muzzle_light.name = "ShortShotIllumination_NoFakeMuzzleMesh"
    muzzle_light.position = Vector3(0,.04,-.53)
    muzzle_light.light_color = Color(1,.72,.38)
    muzzle_light.light_energy = 1.1
    muzzle_light.omni_range = 1.3
    muzzle_light.shadow_enabled = false
    muzzle_light.visible = false
    weapon_pivot.add_child(muzzle_light)

# Rigidly turn the authored elbow down beyond the view, then articulate the
# original wrist in the opposite direction to keep its complete hand frame.
# No bone length, bind matrix, vertex or skin weight is stretched/replaced.
    _build_arsenal()

func weapon_spec(index: int = -1) -> Dictionary:
    return Arsenal.spec(selected_weapon if index < 0 else index)

func peer_weapon(id: int) -> int: return int(weapon_by_peer.get(id,0))

func _build_arsenal() -> void:
    rifle_supports = wall_support_points.duplicate()
    for hand in grip_hands.get_children(): hand_rest_transforms.append(hand.transform)
    for bone in range(grip_skeleton.get_bone_count()): rifle_finger_poses.append(grip_skeleton.get_bone_pose_rotation(bone))
    for index in range(1,4):
        var model := Arsenal.model(index)
        model.name = "OriginalCC0_"+str(Arsenal.spec(index).label)
        weapon_pivot.add_child(model)
        # Source guns point -X; orient -Z in the same camera-space rig.
        model.rotation.y = -PI*.5 if index != 3 else 0.0
        model.rotation.x = -PI*.5 if index == 3 else 0.0
        model.position = Vector3(0,.005,-.07) if index == 1 else Vector3(0,.025,-.10)
        model.visible = false
        extra_weapons.append(model)
        for node in model.find_children("*","MeshInstance3D",true,false):
            (node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    switch_audio = _audio("fps_switch.wav",-15)
    result_audio = _audio("fps_result.wav",-12)
    damage_audio = _audio("fps_damage.wav",-17)
    for file in ["fps_shot.wav","fps_pistol.wav","fps_sniper.wav","fps_knife.wav"]:
        var path: String = "res://audio/"+str(file)
        shot_sounds.append(load(path) if ResourceLoader.exists(path) else null)
    for index in range(8):
        var player := AudioStreamPlayer3D.new()
        player.max_distance = 95
        player.unit_size = 8
        player.volume_db = -12
        game.add_child(player)
        remote_shots.append(player)

func _apply_weapon(index: int) -> void:
    if not Arsenal.valid(index): return
    var changed := selected_weapon != index
    selected_weapon = index
    for bone in range(rifle_finger_poses.size()): grip_skeleton.set_bone_pose_rotation(bone,rifle_finger_poses[bone])
    if index == 3: _curl_hand_fingers(grip_skeleton,"r")
    if changed:
        local_equip_end = Time.get_ticks_msec()+250
        aiming = false
        reload_visual_seconds = 0
        game.player.trigger_buffer = 0
        if is_instance_valid(switch_audio) and switch_audio.stream != null: switch_audio.play()
    weapon_model.visible = index == 0
    wall_support_points = rifle_supports.duplicate()
    for i in range(extra_weapons.size()): extra_weapons[i].visible = i+1 == index
    for i in range(grip_hands.get_child_count()):
        var hand: Node3D = grip_hands.get_child(i)
        hand.transform = hand_rest_transforms[i]
        hand.visible = index == 0
    # Source wrist socket is measured against each imported grip geometry.
    if index > 0:
        var source := extra_weapons[index-1]
        wall_support_points.clear()
        for part in source.find_children("*","MeshInstance3D",true,false):
            var mesh := part as MeshInstance3D
            var local: Transform3D = weapon_pivot.global_transform.affine_inverse()*mesh.global_transform
            for corner in range(8): wall_support_points.append(local*mesh.get_aabb().get_endpoint(corner))
        var right: Node3D = grip_hands.get_child(0)
        var skel: Skeleton3D = grip_mounts[0].skeleton
        var socket: int = grip_mounts[0].socket
        var references := [Vector3(.02,-.06,0),Vector3(.02,-.17,0),Vector3(0,0,0)]
        var original: Node3D = source.get_child(0)
        var nominal: Vector3 = weapon_pivot.to_local(original.to_global(references[index-1]))
        var contact := Vector3.INF
        var distance := INF
        # Nearest point on original source triangles, not an invented socket
        # success flag. Preserve for regression measurement and visual review.
        for part in source.find_children("*","MeshInstance3D",true,false):
            var mesh := part as MeshInstance3D
            var local: Transform3D = weapon_pivot.global_transform.affine_inverse()*mesh.global_transform
            for surface in range(mesh.mesh.get_surface_count()):
                var arrays: Array = mesh.mesh.surface_get_arrays(surface)
                var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
                for face in range(0,indices.size(),3):
                    var point := closest_triangle_point(nominal,local*vertices[indices[face]],local*vertices[indices[face+1]],local*vertices[indices[face+2]])
                    if point.distance_squared_to(nominal) < distance:
                        contact = point
                        distance = point.distance_squared_to(nominal)
        source.set_meta("actual_grip_contact",contact)
        right.position += contact-grip_hands.to_local(skel.to_global(skel.get_bone_global_pose(socket).origin))
        right.visible = true
        if index == 2:
            var left: Node3D = grip_hands.get_child(1)
            var left_skel: Skeleton3D = grip_mounts[1].skeleton
            var support: Vector3 = weapon_pivot.to_local(original.to_global(Vector3(-.75,-.08,0)))
            left.position += support-grip_hands.to_local(left_skel.to_global(left_skel.get_bone_global_pose(grip_mounts[1].socket).origin))
            left.visible = true
    shot_audio.stream = shot_sounds[index] if shot_sounds.size() == 4 else shot_audio.stream
    wall_probe_origin = Vector3.INF

func select_weapon(index: int) -> bool:
    if not active or level_id != -2 or not Arsenal.valid(index): return false
    if reload_time > 0 or round_over or game.ui.modal: return false
    game.net.request_fps_weapon(index)
    return true

func server_weapon(peer_id: int, index: int) -> bool:
    if not game.net.authoritative() or not active or level_id != -2 or not health_by_peer.has(peer_id): return false
    if not Arsenal.valid(index) or round_over or reload_ends.has(peer_id) or peer_weapon(peer_id) == index: return false
    var now := Time.get_ticks_msec()
    if now < int(switch_ends.get(peer_id,0)): return false
    var old := peer_weapon(peer_id)
    # Save before switching: cycling never refills ammunition or shortens a shot.
    loadouts[peer_id][old] = {"ammo":int(ammo_by_peer[peer_id]),"reserve":int(reserve_by_peer[peer_id])}
    switch_ends[peer_id] = maxi(now+250,int(shot_ticks.get(peer_id,-999999))+int(Arsenal.spec(old).rate*1000))
    weapon_by_peer[peer_id] = index
    ammo_by_peer[peer_id] = int(loadouts[peer_id][index].ammo)
    reserve_by_peer[peer_id] = int(loadouts[peer_id][index].reserve)
    game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)
    return true

func shot_direction() -> Vector3:
    var camera: Camera3D = game.player.camera
    var forward: Vector3 = -camera.global_basis.z
    if not game.player.third_person: return forward
    var origin: Vector3 = game.player.eye_position()
    var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position+forward*float(weapon_spec().range),1)
    query.exclude = [game.player.get_rid()]
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    var target: Vector3 = hit.position if not hit.is_empty() else camera.global_position+forward*float(weapon_spec().range)
    var direction := (target-origin).normalized()
    return direction if direction.dot(forward) >= .92 else forward

func _tuck_forearm(hand: Node3D, skel: Skeleton3D, side: String, wrist: int) -> void:
    skel.force_update_all_bone_transforms()
    var wrist_before := grip_hands.global_transform.affine_inverse()*skel.global_transform*skel.get_bone_global_pose(wrist)
    var elbow := skel.find_bone("forearm."+side)
    if elbow < 0:
        push_error("Original WRAD forearm joint missing")
        return
    var elbow_at := grip_hands.to_local(skel.to_global(skel.get_bone_global_pose(elbow).origin))
    var segment_length := elbow_at.distance_to(wrist_before.origin)
    var along := (elbow_at-wrist_before.origin).normalized()
    var desired := Vector3(.50,-.94,.12).normalized() if side == "r" else Vector3(-.45,-.90,.70).normalized()
    var turn := Basis(Quaternion(along,desired))
    hand.transform = Transform3D(turn,wrist_before.origin-turn*wrist_before.origin)*hand.transform
    var desired_wrist := skel.global_transform.affine_inverse()*grip_hands.global_transform*wrist_before
    var parent := skel.get_bone_parent(wrist)
    var parent_pose := skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
    # Godot 4 pose already contains the local rest transform.
    var pose := parent_pose.affine_inverse()*desired_wrist
    skel.set_bone_pose_position(wrist,pose.origin)
    skel.set_bone_pose_rotation(wrist,pose.basis.orthonormalized().get_rotation_quaternion())
    skel.force_update_all_bone_transforms()
    var after := grip_hands.global_transform.affine_inverse()*skel.global_transform*skel.get_bone_global_pose(wrist)
    if after.origin.distance_to(wrist_before.origin) > .0001 or after.basis.orthonormalized().get_rotation_quaternion().angle_to(wrist_before.basis.orthonormalized().get_rotation_quaternion()) > .001:
        push_error("Forearm articulation displaced the authored wrist frame")
    var elbow_after := grip_hands.to_local(skel.to_global(skel.get_bone_global_pose(elbow).origin))
    if absf(elbow_after.distance_to(after.origin)-segment_length) > .0001:
        push_error("Forearm articulation changed the original bone length")

# Pose only the authored right index joints toward the real trigger guard.
# Work in skeleton space and recover the local pose through parent/rest bases;
# neither skin weights nor mesh vertices are replaced or stretched.
func _pose_trigger_finger() -> void:
    if not is_instance_valid(grip_skeleton): return
    var goals := [Vector3(.005,-.045,.028),Vector3(-.001,-.043,.022),Vector3(.003,-.054,.021)]
    for index in range(3):
        var bone := grip_skeleton.find_bone("finger_index%d.r" % (index+1))
        var child := grip_skeleton.find_bone("finger_index%d.r" % (index+2)) if index < 2 else -1
        if bone < 0: continue
        grip_skeleton.force_update_all_bone_transforms()
        var current: Transform3D = grip_skeleton.get_bone_global_pose(bone)
        var along := (grip_skeleton.get_bone_global_pose(child).origin-current.origin).normalized() if child >= 0 else current.basis.y.normalized()
        var goal: Vector3 = grip_skeleton.to_local(weapon_pivot.to_global(goals[index]))
        var target := (goal-current.origin).normalized()
        var rotated := Basis(Quaternion(along,target))*current.basis
        var parent := grip_skeleton.get_bone_parent(bone)
        var parent_basis := grip_skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
        var pose := parent_basis.inverse()*rotated
        grip_skeleton.set_bone_pose_rotation(bone,pose.orthonormalized().get_rotation_quaternion())
    grip_skeleton.force_update_all_bone_transforms()

func _finish_rifle(mesh: MeshInstance3D) -> void:
    for surface in range(mesh.mesh.get_surface_count()):
        var material := mesh.get_active_material(surface) as StandardMaterial3D
        if material == null or material.albedo_texture == null or material.normal_texture == null or material.roughness_texture == null or material.metallic_texture == null:
            push_error("Original CC0 M4A1 PBR channels not embedded")
            continue
        var finish := material.duplicate() as StandardMaterial3D
        finish.disable_receive_shadows = true
        finish.roughness = .85
        finish.normal_scale = .5
        mesh.set_surface_override_material(surface,finish)
        weapon_finish_ready = true

# The left palm supports the actual authored magazine base during removal /
# insertion. Derive its contact from source triangles, not a floating offset.
func _calibrate_magazine_contact() -> void:
    var mesh := rifle_magazine as MeshInstance3D
    if mesh == null: return
    var desired := Vector3(0,-.18,-.055)
    var closest := Vector3.ZERO
    var distance := INF
    var local := weapon_pivot.global_transform.affine_inverse()*mesh.global_transform
    for surface in range(mesh.mesh.get_surface_count()):
        var arrays: Array = mesh.mesh.surface_get_arrays(surface)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
        for i in range(0,indices.size(),3):
            var point := closest_triangle_point(desired,local*vertices[indices[i]],local*vertices[indices[i+1]],local*vertices[indices[i+2]])
            if desired.distance_to(point) < distance:
                closest = point
                distance = desired.distance_to(point)
    magazine_contact_ready = distance < .025
    if not magazine_contact_ready: push_error("Original M4A1 magazine base contact calibration failed")
    magazine_contact = mesh.to_local(weapon_pivot.to_global(closest))

func closest_triangle_point(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
    var normal := (b-a).cross(c-a).normalized()
    var projected := point-normal*(point-a).dot(normal)
    if _distance_to_triangle(projected,a,b,c) <= .00001: return projected
    var closest := Geometry3D.get_closest_point_to_segment(point,a,b)
    for edge in [Geometry3D.get_closest_point_to_segment(point,b,c),Geometry3D.get_closest_point_to_segment(point,c,a)]:
        if point.distance_squared_to(edge) < point.distance_squared_to(closest): closest = edge
    return closest

func reload_contact_error() -> float:
    if not magazine_contact_ready or grip_mounts.size() != 2: return INF
    var mount: Dictionary = grip_mounts[1]
    var socket: Vector3 = mount.skeleton.to_global(mount.skeleton.get_bone_global_pose(mount.socket).origin)
    return socket.distance_to(rifle_magazine.to_global(magazine_contact))

func reload_skin_contact_error() -> float:
    if not magazine_contact_ready or grip_mounts.size() != 2: return INF
    var mount: Dictionary = grip_mounts[1]
    var contact: Vector3 = rifle_magazine.to_global(magazine_contact)
    var error := INF
    for mesh in mount.hand.find_children("*","MeshInstance3D",true,false):
        for surface in range(mesh.mesh.get_surface_count()):
            for point in skinned_surface_points(mesh,mount.skeleton,surface): error = minf(error,point.distance_to(contact))
    return error

# Project nominal grasp sockets onto actual imported rifle triangles. Keep
# nominal distance bounded; changing a model cannot silently move sockets far.
func _calibrate_grip_surfaces() -> void:
    for mount in grip_mounts:
        var desired: Vector3 = mount.target
        var closest := desired
        var distance := INF
        for i in range(0,weapon_triangles.size(),3):
            var a: Vector3 = weapon_triangles[i]
            var b: Vector3 = weapon_triangles[i+1]
            var c: Vector3 = weapon_triangles[i+2]
            var normal := (b-a).cross(c-a).normalized()
            var projected := desired-normal*(desired-a).dot(normal)
            var point: Vector3 = projected
            if _distance_to_triangle(projected,a,b,c) > .00001:
                var edges := [Geometry3D.get_closest_point_to_segment(desired,a,b),Geometry3D.get_closest_point_to_segment(desired,b,c),Geometry3D.get_closest_point_to_segment(desired,c,a)]
                point = edges[0]
                for edge in edges:
                    if desired.distance_squared_to(edge) < desired.distance_squared_to(point): point = edge
            var error := desired.distance_to(point)
            if error < distance: distance = error; closest = point
        if distance > .035: push_error("Rifle nominal grip lies too far from authored surface")
        (mount.hand as Node3D).position += closest-desired
        mount.target = closest

func _finish_weapon(mesh: MeshInstance3D) -> void:
    for surface in range(mesh.mesh.get_surface_count()):
        var original := mesh.get_active_material(surface) as StandardMaterial3D
        if original == null or original.albedo_texture == null:
            push_error("Authored Kenney atlas missing from GLB material")
            continue
        var finish := ShaderMaterial.new()
        finish.shader = WeaponFinish
        finish.set_shader_parameter("source_atlas",original.albedo_texture)
        for binding in {"detail_albedo":"diffuse","detail_normal":"normal","detail_roughness":"rough","detail_metallic":"metal"}:
            var path := Assets.path("vendor/pbr_weapon_metal_%s.jpg" % {"detail_albedo":"diffuse","detail_normal":"normal","detail_roughness":"rough","detail_metallic":"metal"}[binding])
            if not ResourceLoader.exists(path):
                push_error("Verified weapon PBR texture missing: "+path)
                continue
            finish.set_shader_parameter(binding,load(path))
        mesh.set_surface_override_material(surface,finish)
        weapon_finish_ready = true

func trigger_recoil() -> void:
    if is_instance_valid(game.fps_arena.local_shadow): game.fps_arena.local_shadow.shot_seconds = .22
    # Bounded rig-only impulse; aiming/shot authority are never rotated.
    var impulse := ADS_RECOIL_IMPULSE if aiming else HIP_RECOIL_IMPULSE
    visual_recoil = minf(visual_recoil+impulse,impulse*1.15)
    muzzle_flash_time = .075 if selected_weapon != 3 else 0.0
    if is_instance_valid(muzzle_light): muzzle_light.visible = selected_weapon != 3

# Posing fingers uses authored WRAD skeleton bones only. No full-arm
# shoulder/elbow IK, which visibly bent the source upper arms across the gun.
func _curl_hand_fingers(skel: Skeleton3D, side: String) -> void:
    for finger in ["pinky","ring","middle","index","thumb"]:
        for segment in [1,2,3]:
            var bone: int = skel.find_bone("finger_%s%d.%s" % [finger,segment,side])
            if bone < 0: continue
            var curl := .95 if segment == 1 else (1.02 if segment == 2 else .45)
            if finger == "thumb": curl *= .58
            if finger == "index" and side == "r" and selected_weapon != 3: curl *= .60
            var direction := 1.0 if side == "r" else -1.0
            # Finger local Y is its length; bend toward the palm about Z.
            # Multiplication on the right retains each authored joint frame.
            var axis := Vector3.BACK
            if finger == "thumb":
                # Calibrated on actual WRAD distal joints in the mounted GLB rig:
                # right opposition is -Z; left opposition is -X. The former
                # common +X bend left both thumbs projecting away from the gun.
                axis = Vector3.BACK if side == "r" else Vector3.RIGHT
                direction = -1.0
                curl = (.4 if side == "r" else .7)*(1.0 if segment < 3 else .6)
            skel.set_bone_pose_rotation(bone,
                skel.get_bone_pose_rotation(bone)*Quaternion(axis,curl*direction))
    skel.force_update_all_bone_transforms()

# Recompute from real imported bones and CPU-skinned source vertices.
# A perturbed hand transform MUST increase this error; mounted count is not QA.
func measure_grip() -> void:
    grip_error = 0.0 if grip_mounts.size() == 2 else 999.0
    grip_mesh_error = 0.0 if grip_mounts.size() == 2 else 999.0
    grip_surface_error = 0.0 if grip_mounts.size() == 2 else 999.0
    for mount in grip_mounts:
        var skel := mount.skeleton as Skeleton3D
        skel.force_update_all_bone_transforms()
        var target: Vector3 = weapon_pivot.to_global(mount.target)
        var socket: Vector3 = skel.to_global(skel.get_bone_global_pose(int(mount.socket)).origin)
        grip_error = maxf(grip_error,socket.distance_to(target))
        var surface_error := 999.0
        for i in range(0,weapon_triangles.size(),3):
            surface_error = minf(surface_error,_distance_to_triangle(mount.target,weapon_triangles[i],weapon_triangles[i+1],weapon_triangles[i+2]))
        grip_surface_error = maxf(grip_surface_error,surface_error)
        var closest := 999.0
        for part in (mount.hand as Node3D).find_children("*","MeshInstance3D",true,false):
            var mesh := part as MeshInstance3D
            if mesh.skin == null: continue
            for surface in range(mesh.mesh.get_surface_count()):
                for posed in skinned_surface_points(mesh,skel,surface):
                    closest = minf(closest,posed.distance_to(target))
        grip_mesh_error = maxf(grip_mesh_error,closest)
    print("FPS_GRIP_GEOMETRY socket_m=",grip_error," skin_contact_m=",grip_mesh_error," gun_surface_m=",grip_surface_error)

# Inspection path only, never the per-frame animation path. Original skin
# indices/inverse binds determine each point, rather than unposed mesh bounds.
func skinned_surface_points(mesh: MeshInstance3D, skel: Skeleton3D, surface: int) -> PackedVector3Array:
    var arrays: Array = mesh.mesh.surface_get_arrays(surface)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
    var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
    var influences: int = bones.size()/maxi(1,vertices.size())
    var points := PackedVector3Array()
    for vertex in range(vertices.size()):
        var posed := Vector3.ZERO
        for influence in range(influences):
            var k := vertex*influences+influence
            if weights[k] <= 0: continue
            var bind := bones[k]
            var bone := skel.find_bone(mesh.skin.get_bind_name(bind))
            if bone < 0: bone = mesh.skin.get_bind_bone(bind)
            if bone < 0: continue
            posed += (skel.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind)*vertices[vertex])*weights[k]
        points.append(skel.to_global(posed))
    return points

func _distance_to_triangle(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
    var normal := (b-a).cross(c-a)
    if normal.length_squared() > .000000000001:
        normal = normal.normalized()
        var signed_distance := (point-a).dot(normal)
        var projected := point-normal*signed_distance
        if normal.dot((b-a).cross(projected-a)) >= -.00000001 and normal.dot((c-b).cross(projected-b)) >= -.00000001 and normal.dot((a-c).cross(projected-c)) >= -.00000001:
            return absf(signed_distance)
    return minf(point.distance_to(Geometry3D.get_closest_point_to_segment(point,a,b)),minf(point.distance_to(Geometry3D.get_closest_point_to_segment(point,b,c)),point.distance_to(Geometry3D.get_closest_point_to_segment(point,c,a))))

func _audio(filename: String, volume: float) -> AudioStreamPlayer:
    var sound := AudioStreamPlayer.new()
    sound.volume_db = volume
    sound.name = "FPS_" + filename
    var path := "res://audio/" + filename
    if ResourceLoader.exists(path): sound.stream = load(path)
    add_child(sound)
    return sound

func is_equipped() -> bool:
    return active and equipped

# Competitive matches start with two connected players, not four.
func match_can_fire() -> bool:
    if not active or not game.fps_arena.visible: return false
    if game.net.mode == "solo": return true
    if round_over: return false
    if game.net.mode == "host": return game.net.members.size() >= 2
    return game.net.mode == "client" and health_by_peer.size() >= 2

func enter_arena() -> void:
    leave_level()
    kill_events.clear()
    impacts.clear()
    impact_serial = 0
    last_impact_serial = 0
    kill_serial = 0
    last_confirmed_serial = 0
    damage_feedback_time = 0.0
    round_id = 1
    round_remaining = MATCH_SECONDS
    round_over = false
    round_break = 0.0
    round_winners.clear()
    round_winner_seats.clear()
    round_ready.clear()
    round_tick_msec = Time.get_ticks_msec()
    active = true
    wall_probe_origin = Vector3.INF
    wall_probe_seconds = 0.0
    wall_planes.clear()
    wall_retract = 0.0
    equipped = true
    level_id = -2
    health = 100
    magazine = MAGAZINE_CAPACITY
    reserve = 120
    if is_instance_valid(weapon_pivot): weapon_pivot.visible = true
    # This also fixes visual QA scripts which intentionally disable
    # player physics: the old distant Sketchfab hands may NOT reappear.
    if is_instance_valid(game.player.viewmodel_root): game.player.viewmodel_root.visible = false
    if is_instance_valid(game.player.leg_root): game.player.leg_root.visible = false
    if is_instance_valid(game.player.flashlight_rig): game.player.flashlight_rig.visible = false
    if is_instance_valid(game.player.torch): game.player.torch.visible = false
    set_process(true)
    if game.net.authoritative(): register_peer(1)

func register_peer(id: int) -> void:
    if not game.net.authoritative(): return
    deaths[id] = 0
    weapon_by_peer[id] = 0
    loadouts[id] = {}
    for index in range(4): loadouts[id][index] = {"ammo":int(Arsenal.spec(index).capacity),"reserve":int(Arsenal.spec(index).reserve)}
    health_by_peer[id] = 100
    ammo_by_peer[id] = MAGAZINE_CAPACITY
    scores[id] = 0
    reserve_by_peer[id] = 120
    hit_serials[id] = 0
    reload_blocks[id] = 0
    reload_block_ammo[id] = -1
    reload_durations[id] = 0

func remove_peer(id: int) -> void:
    deaths.erase(id)
    weapon_by_peer.erase(id)
    loadouts.erase(id)
    switch_ends.erase(id)
    health_by_peer.erase(id)
    ammo_by_peer.erase(id)
    scores.erase(id)
    reserve_by_peer.erase(id)
    reload_ends.erase(id)
    reload_blocks.erase(id)
    reload_block_ammo.erase(id)
    reload_durations.erase(id)
    shot_ticks.erase(id)
    hit_serials.erase(id)
    round_ready.erase(id)

func enter_level(number: int) -> void:
    # There is no authoritative replication yet for added-layer combat:
    # do NOT give remote clients independent target damage or false scores.
    var solo: bool = game.net.mode == "solo"
    leave_level()
    if not solo: return
    active = true
    equipped = true
    level_id = number
    health = 100
    magazine = MAGAZINE_CAPACITY
    reserve = 96
    enemy_timer = 3.5
    if is_instance_valid(weapon_pivot) and is_instance_valid(weapon_model):
        weapon_pivot.visible = true
    set_process(true)
    if is_instance_valid(game.player.viewmodel_root): game.player.viewmodel_root.visible = false
    if is_instance_valid(game.player.flashlight_rig): game.player.flashlight_rig.visible = false
    if is_instance_valid(game.player.torch): game.player.torch.visible = false
    if number == 2:
        _spawn_sentry(Vector3(-.45,1.55,-8.0),3,0)
        _spawn_sentry(Vector3(-4.30,1.45,-12.85),3,1)
        _spawn_sentry(Vector3(.65,1.5,-19.0),3,2)
        _spawn_sentry(Vector3(-.55,1.55,-24.5),4,3)
        game.ui.show_timed_hint(game.ui.localized(
            "LEVEL 2 / SECURITY BREACH — LEFT CLICK / R TO RELOAD",
            "层级 2 / 安全系统失控——鼠标左键射击 / R 换弹"),4.0)

func leave_level() -> void:
    active = false
    equipped = false
    aiming = false
    reload_visual_seconds = 0.0
    reload_time = 0.0
    if is_instance_valid(rifle_magazine): rifle_magazine.position = magazine_rest
    if is_instance_valid(rifle_handle): rifle_handle.position = handle_rest
    if is_instance_valid(grip_hands) and grip_hands.get_child_count() == 2: grip_hands.get_child(1).transform = left_hand_rest
    level_id = -1
    set_process(false)
    if is_instance_valid(weapon_pivot): weapon_pivot.visible = false
    if is_instance_valid(game) and is_instance_valid(game.player) and is_instance_valid(game.player.viewmodel_root):
        game.player.viewmodel_root.visible = not game.player.flashlight_owned
    if is_instance_valid(game) and is_instance_valid(game.player) and is_instance_valid(game.player.camera):
        game.player.camera.fov = 76.0
    for target in sentries:
        if is_instance_valid(target): target.queue_free()
    sentries.clear()
    for target in training_targets:
        if is_instance_valid(target): target.queue_free()
    training_targets.clear()
    training_enabled = false
    training_hits = 0
    training_shots = 0
    training_time = 0.0
    training_finished = false
    for sprite in impact_sprites:
        if is_instance_valid(sprite): sprite.queue_free()
    impact_sprites.clear()
    impact_ages.clear()
    target_remaining = 0
    deaths.clear()
    weapon_by_peer.clear()
    loadouts.clear()
    switch_ends.clear()
    shot_events.clear()
    shot_serial = 0
    last_shot_serial = 0
    if not extra_weapons.is_empty(): _apply_weapon(0)
    game.player.set_third_person(false)
    local_equip_end = 0
    health_by_peer.clear()
    ammo_by_peer.clear()
    scores.clear()
    reserve_by_peer.clear()
    reload_ends.clear()
    reload_blocks.clear()
    reload_block_ammo.clear()
    reload_durations.clear()
    shot_ticks.clear()
    hit_serials.clear()
    hit_feedback_time = 0.0
    game.player.trigger_buffer = 0.0
    visual_recoil = 0.0
    muzzle_flash_time = 0.0
    if is_instance_valid(muzzle_light): muzzle_light.visible = false

func _spawn_sentry(at: Vector3, hitpoints: int, index: int) -> void:
    if not ResourceLoader.exists(Assets.path("vendor/fps_target_large.glb")):
        push_error("Verified Kenney target GLB missing")
        return
    var body := StaticBody3D.new()
    body.name = "SentryTrainingTarget_KenneyGLB_%d" % index
    body.position = at
    # Ray-only body: the invisible proxy must not block human movement.
    body.collision_layer = 2
    body.collision_mask = 0
    body.set_meta("fps_target",true)
    body.set_meta("hitpoints",hitpoints)
    body.set_meta("base_position",at)
    body.set_meta("sentry_index",index)
    var collider := CollisionShape3D.new()
    var hit_shape := SphereShape3D.new()
    hit_shape.radius = .48
    collider.shape = hit_shape
    body.add_child(collider)
    var model: Node3D = Assets.fitted("vendor/fps_target_large.glb",.92)
    model.name = "ActualKenneyCC0_MechanicalTargetGLB"
    model.rotation.y = PI * .5
    model.position.y = -.46
    body.add_child(model)
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        (mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    game.extra_levels.scene_root.add_child(body)
    sentries.append(body)
    target_remaining += 1

func _process(delta: float) -> void:
    advance(delta)

func advance(delta: float) -> void:
    if not active: return
    if level_id == -2 and game.net.mode == "host": _advance_match_clock()
    if training_enabled and game.running and not game.ui.modal:
        training_time = maxf(0.0,training_time-delta)
        if training_time <= 0.0: _finish_training()
    shot_cooldown = maxf(0.0,shot_cooldown-delta)
    invulnerable_time = maxf(0.0,invulnerable_time-delta)
    hit_feedback_time = maxf(0.0,hit_feedback_time-delta)
    damage_feedback_time = maxf(0.0,damage_feedback_time-delta)
    combat_clock += delta
    for i in range(impact_sprites.size()-1,-1,-1):
        impact_ages[i] += delta
        if impact_ages[i] > 25.0:
            impact_sprites[i].queue_free()
            impact_sprites.remove_at(i)
            impact_ages.remove_at(i)
        elif impact_ages[i] > 23.0: impact_sprites[i].modulate.a = (25.0-impact_ages[i])*.5
    if level_id == -2 and game.net.authoritative():
        finish_server_reloads()
    if reload_time > 0.0 and level_id != -2:
        reload_time -= delta
        if reload_time <= 0.0:
            var transfer := mini(MAGAZINE_CAPACITY-magazine,reserve)
            magazine += transfer
            reserve -= transfer
            reload_time = 0.0
    visual_recoil *= exp(-delta*RECOIL_RETURN_SPEED)
    muzzle_flash_time = maxf(0.0,muzzle_flash_time-delta)
    if is_instance_valid(muzzle_light): muzzle_light.visible = muzzle_flash_time > 0.0
    reload_visual_seconds = maxf(0.0,reload_visual_seconds-delta)
    # Movement/look changes refresh immediately; idle probes run at 10Hz.
    wall_probe_seconds -= delta
    var eye: Vector3 = game.player.camera.global_position
    var fwd: Vector3 = -game.player.camera.global_transform.basis.z
    if wall_probe_seconds <= 0.0 or eye.distance_squared_to(wall_probe_origin) > .000625 or fwd.dot(wall_probe_direction) < .9988:
        wall_probe_seconds = .10
        wall_probe_origin = eye
        wall_probe_direction = fwd
        wall_clearance = 100.0
        wall_planes.clear()
        for lateral in [-.12,0.0,.30]:
            var origin: Vector3 = eye+game.player.camera.global_basis.x*lateral
            var probe := PhysicsRayQueryParameters3D.create(origin,origin+fwd*1.12,1)
            probe.exclude = [game.player.get_rid()]
            var hit_wall: Dictionary = get_world_3d().direct_space_state.intersect_ray(probe)
            if not hit_wall.is_empty():
                wall_clearance = minf(wall_clearance,maxf(.15,(hit_wall.position-eye).dot(fwd)))
                wall_planes.append({"p":hit_wall.position,"n":hit_wall.normal})
        wall_retract = clampf((1.12-wall_clearance)/.78,0.0,1.0)
    if is_instance_valid(weapon_pivot):
        weapon_pivot.visible = equipped and not game.player.third_person and not (selected_weapon == 2 and aiming)
        var motion: float = clampf(Vector2(game.player.velocity.x,game.player.velocity.z).length()/4.3,0.0,1.0)
        var walking: float = sin(game.player.motion_clock)
        var base := Vector3(.23 + walking*.004*motion,
            -.19 - absf(walking)*.006*motion + game.player.landing_dip*.35,
            -.48 + visual_recoil*.30)
        var aim_blend: float = pow(1.0-wall_retract,2.0) if aiming else 0.0
        base = base.lerp(Vector3(.000824,-.0773845,-.48+visual_recoil*.22),aim_blend)
        var reload_phase := sin((1.0-clampf(reload_visual_seconds/maxf(.01,float(weapon_spec().reload)),0.0,1.0))*PI)
        base.y += wall_retract*.09+reload_phase*.20
        base.z += wall_retract*.08
        base.x -= wall_retract*.13
        weapon_pivot.position = weapon_pivot.position.lerp(base,minf(1.0,delta*12.0))
        var pitch := -.04*(1.0-aim_blend)+visual_recoil*.20+reload_phase*.20+wall_retract*.19
        weapon_pivot.rotation.x = lerpf(weapon_pivot.rotation.x,pitch,minf(1.0,delta*11.0))
        weapon_pivot.rotation.y = lerp_angle(weapon_pivot.rotation.y,-.08*(1.0-aim_blend)+wall_retract*1.65,minf(1.0,delta*9.0))
        weapon_pivot.rotation.z = lerpf(weapon_pivot.rotation.z,-.025*(1.0-aim_blend)-wall_retract*.075,minf(1.0,delta*9.0))
        if selected_weapon == 3 and shot_cooldown > 0:
            var slash := sin((1.0-clampf(shot_cooldown/.45,0,1))*PI)
            weapon_pivot.rotation.z += slash*.65
            weapon_pivot.position.x -= slash*.12
        if wall_retract > .001:
            _fit_near_wall()
    if selected_weapon == 0 and is_instance_valid(rifle_magazine):
        var phase := 1.0-clampf(reload_visual_seconds/RELOAD_SECONDS,0.0,1.0)
        var travel := smoothstep(.16,.43,phase)*(1.0-smoothstep(.59,.78,phase)) if reload_visual_seconds > 0 else 0.0
        rifle_magazine.position = magazine_rest+Vector3(-.015,-.16,.025)*travel
        if grip_hands.get_child_count() == 2:
            var left: Node3D = grip_hands.get_child(1)
            left.transform = left_hand_rest
            var reach := smoothstep(0.0,.16,phase)*(1.0-smoothstep(.78,.98,phase)) if reload_visual_seconds > 0 else 0.0
            if magazine_contact_ready:
                var contact: Vector3 = grip_hands.to_local(rifle_magazine.to_global(magazine_contact))
                left.position += (contact-grip_mounts[1].target)*reach
        if is_instance_valid(rifle_handle):
            rifle_handle.position = handle_rest+Vector3(0,0,.045)*sin(clampf((phase-.80)/.18,0.0,1.0)*PI) if reload_visual_seconds > 0 else handle_rest
    game.player.camera.fov = lerpf(game.player.camera.fov,lerpf(76.0,24.0 if selected_weapon == 2 else 59.0,pow(1.0-wall_retract,2.0)) if aiming and equipped else 76.0,minf(1.0,delta*9.0))
    if level_id != 2 or target_remaining <= 0 or game.ui.modal: return
    enemy_timer -= delta
    if enemy_timer <= 0.0:
        enemy_timer = 2.55
        # A sentry can fire only if an actual unobstructed ray to the
        # first-person player exists. No wall-penetrating remote damage.
        for enemy in sentries:
            if not is_instance_valid(enemy) or int(enemy.get_meta("hitpoints",0)) <= 0: continue
            var vec: Vector3 = game.player.camera.global_position-enemy.global_position
            if vec.length() > 16.5: continue
            var ray := PhysicsRayQueryParameters3D.create(
                enemy.global_position,game.player.camera.global_position)
            ray.collision_mask = 1
            var obstacle: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
            if obstacle.is_empty() or obstacle.get("collider") == game.player:
                damage_player(9)
            break

# Fit the complete original rifle between the measured wall and the camera
# near plane. Sideways port-arms keeps the receiver/hands in view. No scaling.
func _fit_near_wall() -> void:
    var rear := 0.0
    var near_limit: float = game.player.camera.near+.015
    var lower := -INF
    var upper := INF
    for step in range(9):
        rear = 0.0
        for point in wall_support_points:
            var z: float = (weapon_pivot.basis*point).z
            rear = maxf(rear,z)
        upper = -near_limit-rear-.04
        lower = -INF
        for plane in wall_planes:
            var normal: Vector3 = game.player.camera.global_basis.inverse()*plane.n
            var point: Vector3 = game.player.camera.to_local(plane.p)
            var support := INF
            for vertex in wall_support_points: support = minf(support,normal.dot(weapon_pivot.basis*vertex))
            var required: float = normal.dot(point)+.04-support
            if normal.z > .1:
                lower = maxf(lower,(required-normal.x*weapon_pivot.position.x-normal.y*weapon_pivot.position.y)/normal.z)
            else:
                var along := Vector3(normal.x,normal.y,0)
                var shortage: float = required-normal.dot(weapon_pivot.position)
                if shortage > 0 and along.length_squared() > .01: weapon_pivot.position += along*shortage/along.length_squared()
        if lower <= upper: break
        weapon_pivot.rotation.y = lerpf(weapon_pivot.rotation.y,PI*.5,.5)
    # At an oblique wall, Z-only fitting may have no feasible interval.
    # Keep the actual camera near-plane bound, then slide laterally along
    # the real wall normal rather than moving the entire rifle behind us.
    weapon_pivot.position.z = minf(maxf(weapon_pivot.position.z,lower),upper)
    if lower > upper:
        for plane in wall_planes:
            var normal: Vector3 = game.player.camera.global_basis.inverse()*plane.n
            var point: Vector3 = game.player.camera.to_local(plane.p)
            var support := INF
            for vertex in wall_support_points: support = minf(support,normal.dot(weapon_pivot.basis*vertex))
            var shortage: float = normal.dot(point)+.04-support-normal.dot(weapon_pivot.position)
            if shortage > 0 and absf(normal.x) > .1: weapon_pivot.position.x += shortage/normal.x

func set_aim(value: bool) -> void:
    aiming = active and equipped and selected_weapon != 3 and value and reload_time <= 0.0

func select_blaster() -> void:
    if not active: return
    equipped = true
    if is_instance_valid(weapon_pivot): weapon_pivot.visible = true
    if is_instance_valid(game.player.flashlight_rig): game.player.flashlight_rig.visible = false
    if is_instance_valid(game.player.torch): game.player.torch.visible = false
    if is_instance_valid(game.player.viewmodel_root): game.player.viewmodel_root.visible = false

func select_flashlight() -> void:
    if not active or not game.player.flashlight_owned:
        if active: game.ui.show_timed_hint(game.ui.localized(
            "FIND THE FLASHLIGHT BEFORE SWITCHING", "拾取手电后才能切换"),1.2)
        return
    equipped = false
    aiming = false
    if is_instance_valid(weapon_pivot): weapon_pivot.visible = false
    if is_instance_valid(game.player.flashlight_rig): game.player.flashlight_rig.visible = true

func reload() -> bool:
    if active and level_id == -2:
        if selected_weapon == 3 or not equipped or not match_can_fire() or reload_time > 0 or magazine >= int(weapon_spec().capacity) or reserve <= 0: return false
        reload_visual_seconds = float(weapon_spec().reload)
        reload_time = float(weapon_spec().reload)
        aiming = false
        if reload_audio.stream != null: reload_audio.play()
        game.net.request_fps_reload()
        return true
    if not active or not equipped or reload_time > 0.0 or magazine >= int(weapon_spec().capacity) or reserve <= 0: return false
    reload_time = float(weapon_spec().reload)
    aiming = false
    if reload_audio.stream != null: reload_audio.play()
    return true

func remaining_targets() -> int:
    return target_remaining

func fire() -> String:
    if active and level_id == -2:
        if not game.running or game.ui.modal or not equipped or not match_can_fire(): return "LOCKED"
        if reload_time > 0: return "RELOADING"
        if Time.get_ticks_msec() < local_equip_end: return "COOLDOWN"
        if shot_cooldown > 0.0 or (magazine <= 0 and selected_weapon != 3): return "COOLDOWN"
        shot_cooldown = float(weapon_spec().rate)
        trigger_recoil()
        if shot_audio.stream != null: shot_audio.play()
        game.net.request_fps_fire(shot_direction())
        return "REQUESTED"
    if not active or not equipped or not game.running or game.ui.modal: return "LOCKED"
    if reload_time > 0.0: return "RELOADING"
    if shot_cooldown > 0.0: return "COOLDOWN"
    if magazine <= 0:
        reload()
        return "EMPTY"
    magazine -= 1
    shot_cooldown = float(weapon_spec().rate)
    trigger_recoil()
    if shot_audio.stream != null: shot_audio.play()
    var eye: Vector3 = game.player.camera.global_position
    var direction: Vector3 = -game.player.camera.global_transform.basis.z
    var query := PhysicsRayQueryParameters3D.create(eye,eye+direction*MAX_RANGE)
    query.exclude = [game.player.get_rid()]
    query.collision_mask = 3 # Solid world layer 1 + targets layer 2.
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty(): return "MISS"
    var target := hit.get("collider") as StaticBody3D
    if not is_instance_valid(target) or not target.has_meta("fps_target"): return "WALL"
    var hp := int(target.get_meta("hitpoints",0))
    if hp <= 0: return "WALL"
    hp -= 1
    confirmed_hits += 1
    hit_feedback_time = .21
    target.set_meta("hitpoints",hp)
    if impact_audio.stream != null: impact_audio.play()
    if hp <= 0:
        target.collision_layer = 0
        target.visible = false
        target_remaining -= 1
        defeated += 1
        if target_remaining == 0 and level_id == 2:
            game.ui.show_timed_hint(game.ui.localized(
                "SECURITY OFFLINE — CLIMB TO THE STAIR SELECTOR",
                "警戒系统已解除——前往楼梯顶端按钮"),3.2)
        return "KILL"
    var tween := create_tween()
    tween.tween_property(target,"scale",Vector3(.92,.92,.92),.065)
    tween.tween_property(target,"scale",Vector3.ONE,.12)
    return "HIT"

func damage_player(amount: int) -> void:
    if not active or invulnerable_time > 0.0: return
    health = maxi(0,health-amount)
    invulnerable_time = .35
    if health == 0:
        # Solo checkpoint recovery: no forced remote-camera control and
        # no zero-health soft lock inside a closed elevator or wall.
        health = 100
        invulnerable_time = 2.3
        game.player.reset_to(Vector3(0,.10,2.2))
        game.ui.show_timed_hint(game.ui.localized(
            "RESPAWNED AT SECURITY ENTRY", "已在警戒区入口重生"),3.0)

# Validated on the host, not by the shooting client.
func server_fire(shooter: int, direction: Vector3) -> bool:
    if not active or level_id != -2 or not game.net.authoritative() or not match_can_fire(): return false
    if not health_by_peer.has(shooter) or int(health_by_peer[shooter]) <= 0: return false
    if not direction.is_finite() or absf(direction.length()-1.0) > .05: return false
    direction = direction.normalized()
    if reload_ends.has(shooter):
        reload_blocks[shooter] = int(reload_blocks.get(shooter,0))+1
        reload_block_ammo[shooter] = int(ammo_by_peer.get(shooter,0))
        return false
    if shooter != 1 and not game.net.poses.has(shooter): return false
    # The server has the last validated body yaw. Arbitrary client-provided
    # 180-degree backshots are rejected, independently of claimed hits.
    var facing_yaw: float = game.player.yaw if shooter == 1 else float(game.net.poses[shooter].y)
    var facing_pitch: float = game.player.pitch if shooter == 1 else float(game.net.poses[shooter].get("pitch",0.0))
    var facing := Vector3(-sin(facing_yaw)*cos(facing_pitch),sin(facing_pitch),-cos(facing_yaw)*cos(facing_pitch))
    if direction.dot(facing) < .92: return false
    var spec := Arsenal.spec(peer_weapon(shooter))
    var melee := peer_weapon(shooter) == 3
    var now: int = Time.get_ticks_msec()
    if now < int(switch_ends.get(shooter,0)): return false
    if now - int(shot_ticks.get(shooter,-999999)) < int(float(spec.rate)*1000.0)-2: return false
    if not melee and int(ammo_by_peer.get(shooter,0)) <= 0: return false
    shot_ticks[shooter] = now
    if not melee: ammo_by_peer[shooter] = int(ammo_by_peer[shooter])-1
    var origin: Vector3 = game.player.eye_position() if shooter == 1 else game.net.poses[shooter].p + Vector3(0,1.58,0)
    shot_serial += 1
    shot_events.append({"serial":shot_serial,"peer":shooter,"weapon":peer_weapon(shooter),"p":origin})
    if shot_events.size() > 12: shot_events.pop_front()
    var shot_range: float = float(spec.range)
    var world_query := PhysicsRayQueryParameters3D.create(origin,origin+direction*shot_range,1)
    world_query.exclude = [game.player.get_rid()]
    var world_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(world_query)
    if not world_hit.is_empty():
        impact_serial += 1
        impacts.append({"serial":impact_serial,"p":world_hit.position,"n":world_hit.normal})
        if impacts.size() > 32: impacts.pop_front()
    if game.net.mode == "solo" and training_enabled:
        training_shots += 1
        var target_query := PhysicsRayQueryParameters3D.create(origin,origin+direction*MAX_RANGE,2)
        var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(target_query)
        if not hit.is_empty() and (world_hit.is_empty() or origin.distance_to(hit.position) < origin.distance_to(world_hit.position)):
            var target: StaticBody3D = hit.collider
            if target in training_targets:
                training_hits += 1
                hit_serials[shooter] = int(hit_serials.get(shooter,0))+1
                target.set_meta("last_hit",Time.get_ticks_msec())
                var model := target.get_child(0) as Node3D
                var feedback := create_tween()
                feedback.tween_property(model,"rotation:z",-.16,.07)
                feedback.tween_property(model,"rotation:z",0.0,.14)
    var nearest := 1000.0
    var victim := -1
    for id in health_by_peer:
        var candidate: int = int(id)
        if candidate == shooter or int(health_by_peer[candidate]) <= 0: continue
        if candidate != 1 and not game.net.poses.has(candidate): continue
        var pos: Vector3 = game.player.position if candidate == 1 else game.net.poses[candidate].p
        var t: float = _capsule_entry(origin,direction,pos)
        if t < .2 or t > shot_range or t >= nearest: continue
        var ray := PhysicsRayQueryParameters3D.create(origin,origin+direction*t)
        ray.collision_mask = 1
        ray.exclude = [game.player.get_rid()]
        if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
        nearest = t
        victim = candidate
    if victim >= 0:
        hit_serials[shooter] = int(hit_serials.get(shooter,0))+1
        health_by_peer[victim] = maxi(0,int(health_by_peer[victim])-int(spec.damage))
        if int(health_by_peer[victim]) == 0:
            deaths[victim] = int(deaths.get(victim,0))+1
            scores[shooter] = int(scores.get(shooter,0))+1
            kill_serial += 1
            kill_events.append({"serial":kill_serial,"killer":shooter,"victim":victim})
            if kill_events.size() > 4: kill_events.pop_front()
            health_by_peer[victim] = 100
            game.net.send_fps_respawn(victim,game.fps_arena.spawn_for(int(game.net.seats.get(victim,1))))
            if game.net.mode == "host" and int(scores[shooter]) >= SCORE_LIMIT: _finish_match()
    game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)
    return true

func server_reload(shooter: int) -> bool:
    if not active or not game.net.authoritative() or not ammo_by_peer.has(shooter) or not match_can_fire(): return false
    var spec := Arsenal.spec(peer_weapon(shooter))
    if peer_weapon(shooter) == 3 or int(ammo_by_peer[shooter]) >= int(spec.capacity): return false
    if reload_ends.has(shooter) or int(reserve_by_peer.get(shooter,0)) <= 0: return false
    reload_ends[shooter] = Time.get_ticks_msec()+int(float(spec.reload)*1000)
    game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)
    return true

# Only the actual host's monotonic clock advances match rules. A room with
# one member pauses the remaining clock; client frame rate cannot shorten it.
func _advance_match_clock() -> void:
    var now := Time.get_ticks_msec()
    var seconds := maxf(0.0,float(now-round_tick_msec)/1000.0) if round_tick_msec > 0 else 0.0
    round_tick_msec = now
    if round_over:
        round_break = maxf(0.0,round_break-seconds)
        if round_break <= 0.0 or (game.net.members.size() >= 2 and round_ready.size() == game.net.members.size()): _next_match()
    elif game.net.members.size() >= 2:
        round_remaining = maxf(0.0,round_remaining-seconds)
        if round_remaining <= 0.0: _finish_match()

func _finish_match() -> void:
    if game.net.mode != "host" or round_over: return
    round_over = true
    round_break = INTERMISSION_SECONDS
    round_tick_msec = Time.get_ticks_msec()
    round_ready.clear()
    round_winners.clear()
    var best := -1
    for peer_id in scores:
        if not game.net.members.has(peer_id): continue
        var value := int(scores[peer_id])
        if value > best: best = value; round_winners.clear()
        if value == best: round_winners.append(int(peer_id))
    round_winners.sort()
    round_winner_seats.clear()
    for peer_id in round_winners: round_winner_seats.append(int(game.net.seats.get(peer_id,1)))
    reload_ends.clear()
    game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)

func server_ready(peer_id: int) -> bool:
    if game.net.mode != "host" or not round_over or not game.net.members.has(peer_id): return false
    if round_ready.has(peer_id): return false
    round_ready[peer_id] = true
    game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)
    return true

func _next_match() -> void:
    if game.net.mode != "host": return
    round_id += 1
    round_over = false
    round_remaining = MATCH_SECONDS
    round_break = 0.0
    round_ready.clear()
    round_winners.clear()
    round_tick_msec = Time.get_ticks_msec()
    round_winner_seats.clear()
    reload_ends.clear()
    reload_time = 0.0
    shot_ticks.clear()
    switch_ends.clear()
    shot_events.clear()
    kill_events.clear()
    impacts.clear()
    for peer_id in health_by_peer:
        health_by_peer[peer_id] = 100
        ammo_by_peer[peer_id] = MAGAZINE_CAPACITY
        reserve_by_peer[peer_id] = 120
        scores[peer_id] = 0
        deaths[peer_id] = 0
        weapon_by_peer[peer_id] = 0
        loadouts[peer_id] = {}
        for index in range(4): loadouts[peer_id][index] = {"ammo":int(Arsenal.spec(index).capacity),"reserve":int(Arsenal.spec(index).reserve)}
        game.net.send_fps_respawn(int(peer_id),game.fps_arena.spawn_for(int(game.net.seats.get(peer_id,1))))
    _clear_round_cosmetics()
    game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)

func _clear_round_cosmetics() -> void:
    for sprite in impact_sprites:
        if is_instance_valid(sprite): sprite.queue_free()
    impact_sprites.clear()
    impact_ages.clear()
    visual_recoil = 0.0
    reload_visual_seconds = 0.0
    game.player.trigger_buffer = 0.0

func combat_state() -> Dictionary:
    var remaining := {}
    for id in reload_ends:
        remaining[id] = maxf(0.0,float(int(reload_ends[id])-Time.get_ticks_msec())/1000.0)
    return {"weapons":weapon_by_peer.duplicate(),"deaths":deaths.duplicate(),"shots":shot_events.duplicate(true),"reserve":reserve_by_peer,"reload":remaining,"map_id":game.fps_arena.map_id,"kills":kill_events.duplicate(true),"impacts":impacts.duplicate(true),"hits":hit_serials.duplicate(),"seats":game.net.seats.duplicate(),"round":{"id":round_id,"seconds":round_remaining,"over":round_over,"break":round_break,"winners":round_winners.duplicate(),"winner_seats":round_winner_seats.duplicate(),"ready":round_ready.keys()}}

func finish_server_reloads() -> void:
    var changed := false
    for id in reload_ends.keys():
        if Time.get_ticks_msec() < int(reload_ends[id]): continue
        var spec := Arsenal.spec(peer_weapon(int(id)))
        reload_durations[id] = Time.get_ticks_msec()-(int(reload_ends[id])-int(float(spec.reload)*1000))
        var transfer := mini(int(spec.capacity)-int(ammo_by_peer.get(id,0)),int(reserve_by_peer.get(id,0)))
        ammo_by_peer[id] = int(ammo_by_peer.get(id,0))+transfer
        reserve_by_peer[id] = int(reserve_by_peer.get(id,0))-transfer
        reload_ends.erase(id)
        changed = true
    if changed: game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)

func receive_fps_state(hp: Dictionary, ammo: Dictionary, points: Dictionary, combat: Dictionary) -> void:
    if int(combat.get("map_id",game.fps_arena.map_id)) != game.fps_arena.map_id: return
    var info: Dictionary = combat.get("round",{})
    var next_round := int(info.get("id",round_id))
    if next_round != round_id:
        _clear_round_cosmetics()
    round_id = next_round
    round_remaining = clampf(float(info.get("seconds",round_remaining)),0,MATCH_SECONDS)
    var was_over := round_over
    round_over = bool(info.get("over",round_over))
    if round_over and not was_over and is_instance_valid(result_audio) and result_audio.stream != null: result_audio.play()
    round_break = clampf(float(info.get("break",round_break)),0,INTERMISSION_SECONDS)
    round_winners.clear()
    for winner in info.get("winners",[]): round_winners.append(int(winner))
    round_winner_seats.clear()
    for seat in info.get("winner_seats",[]): round_winner_seats.append(clampi(int(seat),1,4))
    round_ready.clear()
    for peer_id in info.get("ready",[]): round_ready[int(peer_id)] = true
    for event in combat.get("impacts",[]):
        if event is Dictionary and int(event.get("serial",0)) > last_impact_serial:
            last_impact_serial = int(event.serial)
            _show_impact(event.p,event.n)
    kill_events.clear()
    for event in combat.get("kills",[]):
        if event is Dictionary: kill_events.append(event.duplicate())
    game.net.seats = combat.get("seats",game.net.seats).duplicate()
    health_by_peer = hp.duplicate()
    ammo_by_peer = ammo.duplicate()
    scores = points.duplicate()
    deaths = combat.get("deaths",{}).duplicate()
    weapon_by_peer = combat.get("weapons",{}).duplicate()
    var own: int = game.multiplayer.get_unique_id() if game.net.mode != "solo" else 1
    if peer_weapon(own) != selected_weapon: _apply_weapon(peer_weapon(own))
    for event in combat.get("shots",[]):
        if int(event.get("serial",0)) <= last_shot_serial: continue
        last_shot_serial = int(event.serial)
        var peer_id := int(event.peer)
        if peer_id == own: continue
        var player := remote_shots[last_shot_serial%remote_shots.size()]
        player.global_position = event.p
        player.stream = shot_sounds[clampi(int(event.weapon),0,3)]
        if player.stream != null: player.play()
        if game.crew.has(peer_id): game.crew[peer_id].shot_seconds = .22
    reserve_by_peer = combat.get("reserve",{}).duplicate()
    hit_serials = combat.get("hits",{}).duplicate()
    var id: int = game.multiplayer.get_unique_id() if game.net.mode != "solo" else 1
    var next_hit: int = int(combat.get("hits",{}).get(id,0))
    if next_hit > last_confirmed_serial: hit_feedback_time = .20
    last_confirmed_serial = next_hit
    if int(hp.get(id,100)) < health:
        damage_feedback_time = .35
        if damage_audio.stream != null: damage_audio.play()
    health = int(hp.get(id,100))
    magazine = int(ammo.get(id,MAGAZINE_CAPACITY))
    reserve = int(combat.get("reserve",{}).get(id,120))
    reload_time = float(combat.get("reload",{}).get(id,0.0))

func _show_impact(at: Vector3, normal: Vector3) -> void:
    if not at.is_finite() or not normal.is_finite() or normal.length_squared() < .5: return
    var sprite := Sprite3D.new()
    sprite.name = "Original_2D_BallisticSurfaceMark"
    var path := "res://ui/hud/impact.svg"
    if not ResourceLoader.exists(path): path = "res://faceless2/hud_icons/impact.svg"
    sprite.texture = load(path)
    sprite.pixel_size = .0018
    sprite.shaded = true
    sprite.no_depth_test = false
    sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    game.fps_arena.add_child(sprite)
    sprite.global_position = at+normal.normalized()*.006
    sprite.look_at(sprite.global_position+normal,Vector3.RIGHT if absf(normal.y)>.95 else Vector3.UP)
    sprite.rotate_object_local(Vector3.BACK,float(last_impact_serial)*2.399)
    impact_sprites.append(sprite)
    impact_ages.append(0.0)
    if impact_sprites.size() > 48:
        impact_sprites.pop_front().queue_free()
        impact_ages.pop_front()

func toggle_training() -> void:
    if not active or level_id != -2 or game.net.mode != "solo": return
    training_enabled = not training_enabled
    training_hits = 0
    training_shots = 0
    training_finished = false
    training_time = TRAINING_SECONDS if training_enabled else 0.0
    for target in training_targets:
        if is_instance_valid(target): target.queue_free()
    training_targets.clear()
    if not training_enabled: return
    for x in [-2.0,0.0,2.0]:
        var target := StaticBody3D.new()
        target.name = "OptionalSoloOriginalKenneyTarget"
        target.position = Vector3(x,1.6,-9)
        target.collision_layer = 2
        target.collision_mask = 0
        var model := Assets.fitted("vendor/fps_target_large.glb",.75)
        model.position.y = -.375
        target.add_child(model)
        var shape := CollisionShape3D.new()
        var capsule := SphereShape3D.new()
        capsule.radius = .38
        shape.shape = capsule
        target.add_child(shape)
        game.fps_arena.add_child(target)
        training_targets.append(target)

func _finish_training() -> void:
    training_enabled = false
    training_finished = true
    training_time = 0.0
    for target in training_targets:
        if is_instance_valid(target): target.queue_free()
    training_targets.clear()
    training_best = maxi(training_best,training_hits)
    game.save_settings()
    game.ui.show_timed_hint(game.ui.localized(
        "DRILL COMPLETE · %d HITS · %d%% · BEST %d · T TO RESTART",
        "挑战结束 · 命中 %d · 准确率 %d%% · 纪录 %d · T 再来一局") % [training_hits,training_accuracy(),training_best],8.0)

func training_accuracy() -> int:
    return roundi(100.0*training_hits/maxi(1,training_shots))

# Exact ray entry into the SAME upright capsule used by CharacterBody3D.
# A torso-only sphere silently missed eye-height and lower-leg shots.
func _capsule_entry(origin: Vector3, direction: Vector3, body_position: Vector3) -> float:
    var radius: float = game.player.COLLISION_RADIUS
    var half_axis: float = game.player.COLLISION_HEIGHT*.5-radius
    var offset := origin-body_position-Vector3(0,game.player.COLLISION_CENTER_Y,0)
    var nearest := INF
    var a := direction.x*direction.x+direction.z*direction.z
    var b := 2.0*(offset.x*direction.x+offset.z*direction.z)
    var c := offset.x*offset.x+offset.z*offset.z-radius*radius
    var disc := b*b-4.0*a*c
    if a > .00000001 and disc >= 0:
        for t in [(-b-sqrt(disc))/(2*a),(-b+sqrt(disc))/(2*a)]:
            if t >= 0 and absf(offset.y+direction.y*t) <= half_axis: nearest = minf(nearest,t)
    for side in [-1.0,1.0]:
        var cap := offset-Vector3(0,side*half_axis,0)
        var projection := cap.dot(direction)
        var discriminant := projection*projection-cap.length_squared()+radius*radius
        if discriminant < 0: continue
        for t in [-projection-sqrt(discriminant),-projection+sqrt(discriminant)]:
            if t >= 0: nearest = minf(nearest,t)
    return nearest
