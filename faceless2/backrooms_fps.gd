extends Node3D
# Faceless 2's first playable FPS loop: actual CC0 Kenney GLB blaster,
# physics-ray hitscan, magazine/reload, ADS, recoil, health and responsive
# non-humanoid security targets. No visible primitive weapon/enemy meshes.
const Assets = preload("backrooms_assets.gd")
const WeaponFinish = preload("fps_weapon_finish.gdshader")
const MAGAZINE_CAPACITY := 24
const MAX_RANGE := 37.0
const RATE_SECONDS := 0.19
const RELOAD_SECONDS := 1.65
const HIP_RECOIL_IMPULSE := .040
const ADS_RECOIL_IMPULSE := .024
const RECOIL_RETURN_SPEED := 14.0

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
# Measured in the original Kenney GLB coordinates: pistol grip and fore-end.
const GUN_SCALE := .55
const GRIP_POINTS := [Vector3(.024115504,-.077,.335),Vector3(0,-.023255516,-.245)]
var wall_retract := 0.0
var wall_probe_seconds := 0.0
var wall_clearance := 100.0
var weapon_vertices := PackedVector3Array()
var weapon_triangles := PackedVector3Array()
var reload_visual_seconds := 0.0
var sentries: Array[StaticBody3D] = []
var health_by_peer: Dictionary = {}
var ammo_by_peer: Dictionary = {}
var scores: Dictionary = {}
var kill_events: Array[Dictionary] = []
var kill_serial := 0
var reserve_by_peer: Dictionary = {}
var reload_ends: Dictionary = {}
var shot_ticks: Dictionary = {}
var shot_audio: AudioStreamPlayer
var reload_audio: AudioStreamPlayer
var impact_audio: AudioStreamPlayer
var weapon_finish_ready := false
var muzzle_light: OmniLight3D
var muzzle_flash_time := 0.0

func _ready() -> void:
    name = "Faceless2_KenneyCC0_FPS"
    set_process(false)
    weapon_pivot = Node3D.new()
    weapon_pivot.name = "CameraMounted_CertifiedKenneyBlasterGLB"
    game.player.camera.add_child(weapon_pivot)
    weapon_pivot.position = Vector3(.24,-.22,-.64)
    weapon_pivot.rotation = Vector3(-.04,-.08,-.025)
    if ResourceLoader.exists(Assets.path("vendor/fps_blaster_f_open_optic.glb")):
        weapon_model = load(Assets.path("vendor/fps_blaster_f_open_optic.glb")).instantiate()
        weapon_model.name = "Kenney_BlasterF_CC0_AuthoredOpenOpticSubset"
        weapon_model.scale = Vector3.ONE * GUN_SCALE
        weapon_pivot.add_child(weapon_model)
        for node in weapon_model.find_children("*","MeshInstance3D",true,false):
            var mesh := node as MeshInstance3D
            mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            _finish_weapon(mesh)
            var local: Transform3D = weapon_pivot.global_transform.affine_inverse()*mesh.global_transform
            for surface in range(mesh.mesh.get_surface_count()):
                var arrays: Array = mesh.mesh.surface_get_arrays(surface)
                var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                for vertex in vertices: weapon_vertices.append(local*vertex)
                var faces: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
                for index in faces: weapon_triangles.append(local*vertices[index])
    else:
        push_error("Source-verified Kenney Blaster GLB not packaged")
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
        var right_forward := Vector3(-.35,.32,-.88).normalized()
        var right_normal := (Vector3.RIGHT-right_forward*right_forward.x).normalized()
        var palm := Basis(right_normal,right_forward,right_normal.cross(right_forward)) if side == "r" else Basis(left_normal,left_forward,left_normal.cross(left_forward))
        var source_wrist: Transform3D = hand.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(wrist)
        var aligned := Transform3D(palm.scaled(Vector3.ONE*.10),Vector3.ZERO) * source_wrist.affine_inverse()
        hand.transform = aligned
        var target: Vector3 = weapon_model.transform * GRIP_POINTS[0 if side == "r" else 1]
        var actual: Vector3 = grip_hands.to_local(skel.to_global(skel.get_bone_global_pose(socket).origin))
        hand.position += target-actual
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
    measure_grip()
    grip_ready = mounted == 2 and grip_error < .002 and grip_mesh_error < .005 and grip_surface_error < .0005
    print("FPS_ORIGINAL_CC0_TWO_HAND_GRIP=",mounted)
    weapon_pivot.visible = false
    shot_audio = _audio("fps_shot.wav",-12)
    reload_audio = _audio("fps_reload.wav",-15)
    impact_audio = _audio("fps_impact.wav",-12)
    muzzle_light = OmniLight3D.new()
    muzzle_light.name = "ShortShotIllumination_NoFakeMuzzleMesh"
    muzzle_light.position = Vector3(0,.025,-.31)
    muzzle_light.light_color = Color(1,.72,.38)
    muzzle_light.light_energy = 1.1
    muzzle_light.omni_range = 1.3
    muzzle_light.shadow_enabled = false
    muzzle_light.visible = false
    weapon_pivot.add_child(muzzle_light)

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
    # Bounded rig-only impulse; aiming/shot authority are never rotated.
    var impulse := ADS_RECOIL_IMPULSE if aiming else HIP_RECOIL_IMPULSE
    visual_recoil = minf(visual_recoil+impulse,impulse*1.15)
    muzzle_flash_time = .075
    if is_instance_valid(muzzle_light): muzzle_light.visible = true

# Posing fingers uses authored WRAD skeleton bones only. No full-arm
# shoulder/elbow IK, which visibly bent the source upper arms across the gun.
func _curl_hand_fingers(skel: Skeleton3D, side: String) -> void:
    for finger in ["pinky","ring","middle","index","thumb"]:
        for segment in [1,2,3]:
            var bone: int = skel.find_bone("finger_%s%d.%s" % [finger,segment,side])
            if bone < 0: continue
            var curl := .95 if segment == 1 else (1.02 if segment == 2 else .45)
            if finger == "thumb": curl *= .58
            if finger == "index" and side == "r": curl *= .60
            var direction := 1.0 if side == "r" else -1.0
            # Finger local Y is its length; bend toward the palm about Z.
            # Multiplication on the right retains each authored joint frame.
            var axis := Vector3.BACK
            if finger == "thumb":
                axis = Vector3.RIGHT
                direction = 1.0
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
                var arrays: Array = mesh.mesh.surface_get_arrays(surface)
                var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
                var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
                var influences: int = bones.size()/maxi(1,vertices.size())
                for vertex in range(vertices.size()):
                    var posed := Vector3.ZERO
                    for influence in range(influences):
                        var k := vertex*influences+influence
                        if weights[k] <= 0: continue
                        var bind := bones[k]
                        var bone := skel.find_bone(mesh.skin.get_bind_name(bind))
                        if bone < 0: bone = mesh.skin.get_bind_bone(bind)
                        if bone < 0: continue
                        posed += (skel.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind) * vertices[vertex])*weights[k]
                    closest = minf(closest,skel.to_global(posed).distance_to(target))
        grip_mesh_error = maxf(grip_mesh_error,closest)
    print("FPS_GRIP_GEOMETRY socket_m=",grip_error," skin_contact_m=",grip_mesh_error," gun_surface_m=",grip_surface_error)

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
    if game.net.mode == "host": return game.net.members.size() >= 2
    return game.net.mode == "client" and health_by_peer.size() >= 2

func enter_arena() -> void:
    leave_level()
    kill_events.clear()
    kill_serial = 0
    active = true
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
    health_by_peer[id] = 100
    ammo_by_peer[id] = MAGAZINE_CAPACITY
    scores[id] = 0
    reserve_by_peer[id] = 120

func remove_peer(id: int) -> void:
    health_by_peer.erase(id)
    ammo_by_peer.erase(id)
    scores.erase(id)
    reserve_by_peer.erase(id)
    reload_ends.erase(id)
    shot_ticks.erase(id)

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
    target_remaining = 0
    health_by_peer.clear()
    ammo_by_peer.clear()
    scores.clear()
    reserve_by_peer.clear()
    reload_ends.clear()
    shot_ticks.clear()
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
    shot_cooldown = maxf(0.0,shot_cooldown-delta)
    invulnerable_time = maxf(0.0,invulnerable_time-delta)
    hit_feedback_time = maxf(0.0,hit_feedback_time-delta)
    combat_clock += delta
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
    # A conservative camera-to-wall ray keeps the entire rig (not just
    # the rifle) inside the capsule envelope at close surfaces.
    wall_probe_seconds -= delta
    if wall_probe_seconds <= 0.0:
        wall_probe_seconds = .10
        var eye: Vector3 = game.player.camera.global_position
        var fwd: Vector3 = -game.player.camera.global_transform.basis.z
        var probe := PhysicsRayQueryParameters3D.create(eye,eye+fwd*1.12)
        probe.collision_mask = 1
        probe.exclude = [game.player.get_rid()]
        var hit_wall: Dictionary = get_world_3d().direct_space_state.intersect_ray(probe)
        wall_clearance = 100.0 if hit_wall.is_empty() else eye.distance_to(hit_wall.position)
        wall_retract = clampf((1.12-wall_clearance)/.78,0.0,1.0)
    if is_instance_valid(weapon_pivot):
        var motion: float = clampf(Vector2(game.player.velocity.x,game.player.velocity.z).length()/4.3,0.0,1.0)
        var walking: float = sin(game.player.motion_clock)
        var base := Vector3(.24 + walking*.006*motion,
            -.22 - absf(walking)*.006*motion + game.player.landing_dip*.35,
            -.64 + visual_recoil*.30)
        if aiming: base = Vector3(0,-.100375,-.60 + visual_recoil*.22)
        var reload_phase := sin((1.0-clampf(reload_visual_seconds/RELOAD_SECONDS,0.0,1.0))*PI)
        base.y -= reload_phase*.14 + wall_retract*.16
        base.z += wall_retract*.20
        base.x -= wall_retract*.035
        weapon_pivot.position = weapon_pivot.position.lerp(base,minf(1.0,delta*12.0))
        var pitch := (0.0 if aiming else -.04)+visual_recoil*.20+reload_phase*.36-wall_retract*1.35
        weapon_pivot.rotation.x = lerpf(weapon_pivot.rotation.x,pitch,minf(1.0,delta*11.0))
        weapon_pivot.rotation.y = lerp_angle(weapon_pivot.rotation.y,0.0 if aiming else -.08,minf(1.0,delta*9.0))
        weapon_pivot.rotation.z = lerpf(weapon_pivot.rotation.z,(0.0 if aiming else -.025)+wall_retract*.10,minf(1.0,delta*9.0))
        if wall_retract > .001:
            # Use actual original GLB vertices in the current viewmodel basis,
            # not a fictitious AABB corner, to keep the muzzle/scope behind
            # the measured wall plane while the posture settles.
            var forward_extent := 0.0
            for vertex in weapon_vertices:
                forward_extent = maxf(forward_extent,-(weapon_pivot.basis*vertex).z)
            weapon_pivot.position.z = maxf(weapon_pivot.position.z,-wall_clearance+forward_extent+.025)
    game.player.camera.fov = lerpf(game.player.camera.fov,59.0 if aiming and equipped else 76.0,minf(1.0,delta*9.0))
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

func set_aim(value: bool) -> void:
    aiming = active and equipped and value and reload_time <= 0.0

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
        if not equipped or not match_can_fire() or reload_time > 0 or magazine >= MAGAZINE_CAPACITY or reserve <= 0: return false
        reload_visual_seconds = RELOAD_SECONDS
        reload_time = RELOAD_SECONDS
        aiming = false
        if reload_audio.stream != null: reload_audio.play()
        game.net.request_fps_reload()
        return true
    if not active or not equipped or reload_time > 0.0 or magazine >= MAGAZINE_CAPACITY or reserve <= 0: return false
    reload_time = RELOAD_SECONDS
    aiming = false
    if reload_audio.stream != null: reload_audio.play()
    return true

func remaining_targets() -> int:
    return target_remaining

func fire() -> String:
    if active and level_id == -2:
        if not game.running or game.ui.modal or not equipped or not match_can_fire(): return "LOCKED"
        if reload_time > 0: return "RELOADING"
        if shot_cooldown > 0.0 or magazine <= 0: return "COOLDOWN"
        shot_cooldown = RATE_SECONDS
        trigger_recoil()
        if shot_audio.stream != null: shot_audio.play()
        game.net.request_fps_fire(-game.player.camera.global_transform.basis.z)
        return "REQUESTED"
    if not active or not equipped or not game.running or game.ui.modal: return "LOCKED"
    if reload_time > 0.0: return "RELOADING"
    if shot_cooldown > 0.0: return "COOLDOWN"
    if magazine <= 0:
        reload()
        return "EMPTY"
    magazine -= 1
    shot_cooldown = RATE_SECONDS
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
    if reload_ends.has(shooter): return false
    if shooter != 1 and not game.net.poses.has(shooter): return false
    # The server has the last validated body yaw. Arbitrary client-provided
    # 180-degree backshots are rejected, independently of claimed hits.
    var facing_yaw: float = game.player.yaw if shooter == 1 else float(game.net.poses[shooter].y)
    var facing_pitch: float = game.player.pitch if shooter == 1 else float(game.net.poses[shooter].get("pitch",0.0))
    var facing := Vector3(-sin(facing_yaw)*cos(facing_pitch),sin(facing_pitch),-cos(facing_yaw)*cos(facing_pitch))
    if direction.dot(facing) < .92: return false
    var now: int = Time.get_ticks_msec()
    if now - int(shot_ticks.get(shooter,-999999)) < 185: return false
    if int(ammo_by_peer.get(shooter,0)) <= 0: return false
    shot_ticks[shooter] = now
    ammo_by_peer[shooter] = int(ammo_by_peer[shooter])-1
    var origin: Vector3 = game.player.camera.global_position if shooter == 1 else game.net.poses[shooter].p + Vector3(0,1.58,0)
    var nearest := 1000.0
    var victim := -1
    for id in health_by_peer:
        var candidate: int = int(id)
        if candidate == shooter or int(health_by_peer[candidate]) <= 0: continue
        if candidate != 1 and not game.net.poses.has(candidate): continue
        var pos: Vector3 = game.player.position if candidate == 1 else game.net.poses[candidate].p
        var offset: Vector3 = pos + Vector3(0,1.0,0)-origin
        var t: float = offset.dot(direction)
        if t < .2 or t > MAX_RANGE or t >= nearest: continue
        if (offset-direction*t).length() > .55: continue
        var ray := PhysicsRayQueryParameters3D.create(origin,origin+direction*t)
        ray.collision_mask = 1
        ray.exclude = [game.player.get_rid()]
        if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
        nearest = t
        victim = candidate
    if victim >= 0:
        health_by_peer[victim] = maxi(0,int(health_by_peer[victim])-25)
        if int(health_by_peer[victim]) == 0:
            scores[shooter] = int(scores.get(shooter,0))+1
            kill_serial += 1
            kill_events.append({"serial":kill_serial,"killer":shooter,"victim":victim})
            if kill_events.size() > 4: kill_events.pop_front()
            health_by_peer[victim] = 100
            game.net.send_fps_respawn(victim,game.fps_arena.spawn_for(int(game.net.seats.get(victim,1))))
    game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)
    return true

func server_reload(shooter: int) -> bool:
    if not active or not game.net.authoritative() or not ammo_by_peer.has(shooter) or not match_can_fire(): return false
    if int(ammo_by_peer[shooter]) >= MAGAZINE_CAPACITY: return false
    if reload_ends.has(shooter) or int(reserve_by_peer.get(shooter,0)) <= 0: return false
    reload_ends[shooter] = Time.get_ticks_msec()+int(RELOAD_SECONDS*1000)
    game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)
    return true

func combat_state() -> Dictionary:
    var remaining := {}
    for id in reload_ends:
        remaining[id] = maxf(0.0,float(int(reload_ends[id])-Time.get_ticks_msec())/1000.0)
    return {"reserve":reserve_by_peer,"reload":remaining,"map_id":game.fps_arena.map_id,"kills":kill_events.duplicate(true)}

func finish_server_reloads() -> void:
    var changed := false
    for id in reload_ends.keys():
        if Time.get_ticks_msec() < int(reload_ends[id]): continue
        var transfer := mini(MAGAZINE_CAPACITY-int(ammo_by_peer.get(id,0)),int(reserve_by_peer.get(id,0)))
        ammo_by_peer[id] = int(ammo_by_peer.get(id,0))+transfer
        reserve_by_peer[id] = int(reserve_by_peer.get(id,0))-transfer
        reload_ends.erase(id)
        changed = true
    if changed: game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)

func receive_fps_state(hp: Dictionary, ammo: Dictionary, points: Dictionary, combat: Dictionary) -> void:
    if int(combat.get("map_id",game.fps_arena.map_id)) != game.fps_arena.map_id: return
    kill_events.clear()
    for event in combat.get("kills",[]):
        if event is Dictionary: kill_events.append(event.duplicate())
    health_by_peer = hp.duplicate()
    ammo_by_peer = ammo.duplicate()
    scores = points.duplicate()
    var id: int = game.multiplayer.get_unique_id() if game.net.mode != "solo" else 1
    health = int(hp.get(id,100))
    magazine = int(ammo.get(id,MAGAZINE_CAPACITY))
    reserve = int(combat.get("reserve",{}).get(id,120))
    reload_time = float(combat.get("reload",{}).get(id,0.0))
