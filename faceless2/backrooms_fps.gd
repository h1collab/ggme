extends Node3D
# Faceless 2's first playable FPS loop: actual CC0 Kenney GLB blaster,
# physics-ray hitscan, magazine/reload, ADS, recoil, health and responsive
# non-humanoid security targets. No visible primitive weapon/enemy meshes.
const Assets = preload("backrooms_assets.gd")
const MAGAZINE_CAPACITY := 24
const MAX_RANGE := 37.0
const RATE_SECONDS := 0.19
const RELOAD_SECONDS := 1.65

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
var wall_retract := 0.0
var wall_probe_seconds := 0.0
var reload_visual_seconds := 0.0
var sentries: Array[StaticBody3D] = []
var health_by_peer: Dictionary = {}
var ammo_by_peer: Dictionary = {}
var scores: Dictionary = {}
var shot_ticks: Dictionary = {}
var shot_audio: AudioStreamPlayer
var reload_audio: AudioStreamPlayer
var impact_audio: AudioStreamPlayer

func _ready() -> void:
    name = "Faceless2_KenneyCC0_FPS"
    set_process(false)
    weapon_pivot = Node3D.new()
    weapon_pivot.name = "CameraMounted_CertifiedKenneyBlasterGLB"
    game.player.camera.add_child(weapon_pivot)
    weapon_pivot.position = Vector3(.30,-.34,-.72)
    weapon_pivot.rotation = Vector3(-.055,PI-.065,.065)
    if ResourceLoader.exists(Assets.path("vendor/fps_blaster_f.glb")):
        weapon_model = Assets.fitted("vendor/fps_blaster_f.glb",.34)
        weapon_model.name = "Original_Kenney_BlasterF_CC0_GLB"
        weapon_model.scale = Vector3(.82,.82,.82)
        weapon_pivot.add_child(weapon_model)
        for node in weapon_model.find_children("*","MeshInstance3D",true,false):
            (node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
        var hand: Node3D = Assets.fitted("vendor/fps_wrad_grip_%s.glb" % side,.18)
        hand.name = "WRAD_CC0_Skinned_%s_ActualGLBGrip" % side
        hand.position = Vector3(.07,.075,-.04) if side == "r" else Vector3(.12,-.055,-.30)
        hand.rotation = Vector3(.48,-1.10,.36) if side == "r" else Vector3(.66,1.05,-.53)
        grip_hands.add_child(hand)
        var skeletons: Array[Node] = hand.find_children("*","Skeleton3D",true,false)
        if skeletons.is_empty():
            push_error("Original WRAD %s hand has no skinned Skeleton3D" % side)
            continue
        var skel := skeletons[0] as Skeleton3D
        if side == "r": grip_skeleton = skel
        _curl_hand_fingers(skel,side)
        for part in hand.find_children("*","MeshInstance3D",true,false):
            (part as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mounted += 1
    grip_ready = mounted == 2
    grip_error = 0.0 if grip_ready else 999.0
    print("FPS_ORIGINAL_CC0_TWO_HAND_GRIP=",mounted)
    weapon_pivot.visible = false
    shot_audio = _audio("fps_shot.wav",-12)
    reload_audio = _audio("fps_reload.wav",-15)
    impact_audio = _audio("fps_impact.wav",-12)

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
            var axis := Vector3.RIGHT if finger != "thumb" else Vector3.FORWARD
            skel.set_bone_pose_rotation(bone,
                Quaternion(axis,curl*direction)*skel.get_bone_pose_rotation(bone))
    skel.force_update_all_bone_transforms()

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

func enter_arena() -> void:
    leave_level()
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
    if is_instance_valid(game.player.flashlight_rig): game.player.flashlight_rig.visible = false
    if is_instance_valid(game.player.torch): game.player.torch.visible = false
    set_process(true)
    if game.net.authoritative(): register_peer(1)

func register_peer(id: int) -> void:
    if not game.net.authoritative(): return
    health_by_peer[id] = 100
    ammo_by_peer[id] = MAGAZINE_CAPACITY
    scores[id] = 0

func remove_peer(id: int) -> void:
    health_by_peer.erase(id)
    ammo_by_peer.erase(id)
    scores.erase(id)
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
    shot_ticks.clear()

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
    if reload_time > 0.0:
        reload_time -= delta
        if reload_time <= 0.0:
            var transfer := mini(MAGAZINE_CAPACITY-magazine,reserve)
            magazine += transfer
            reserve -= transfer
            reload_time = 0.0
    visual_recoil = move_toward(visual_recoil,0.0,delta*4.2)
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
        wall_retract = 0.0 if hit_wall.is_empty() else clampf((1.12-eye.distance_to(hit_wall.position))/1.12,0.0,1.0)
    if is_instance_valid(weapon_pivot):
        var motion: float = clampf(Vector2(game.player.velocity.x,game.player.velocity.z).length()/4.3,0.0,1.0)
        var walking: float = sin(game.player.motion_clock)
        var base := Vector3(.30 + walking*.014*motion,
            -.34 - absf(walking)*.012*motion,
            -.72 + visual_recoil)
        if aiming: base = Vector3(.02,-.27,-.63 + visual_recoil)
        var reload_phase := sin((1.0-clampf(reload_visual_seconds/.85,0.0,1.0))*PI)
        base.y -= reload_phase*.14 + wall_retract*.16
        base.z += wall_retract*.40
        base.x -= wall_retract*.035
        weapon_pivot.position = weapon_pivot.position.lerp(base,minf(1.0,delta*12.0))
        var pitch := -.055+visual_recoil*.37+reload_phase*.40+wall_retract*.56
        weapon_pivot.rotation.x = lerpf(weapon_pivot.rotation.x,pitch,delta*11.0)
        weapon_pivot.rotation.z = lerpf(weapon_pivot.rotation.z,.065+wall_retract*.13,delta*9.0)
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
        reload_visual_seconds = .85
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
        if not game.running or game.ui.modal or not equipped: return "LOCKED"
        if shot_cooldown > 0.0 or magazine <= 0: return "COOLDOWN"
        shot_cooldown = RATE_SECONDS
        visual_recoil = .10
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
    visual_recoil = .11
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
    if not active or level_id != -2 or not game.net.authoritative(): return false
    if not health_by_peer.has(shooter) or int(health_by_peer[shooter]) <= 0: return false
    if not direction.is_finite() or absf(direction.length()-1.0) > .05: return false
    if shooter != 1 and not game.net.poses.has(shooter): return false
    # The server has the last validated body yaw. Arbitrary client-provided
    # 180-degree backshots are rejected, independently of claimed hits.
    var facing_yaw: float = game.player.yaw if shooter == 1 else float(game.net.poses[shooter].y)
    var facing: Vector3 = Vector3(-sin(facing_yaw),0,-cos(facing_yaw))
    var aim_flat: Vector3 = Vector3(direction.x,0,direction.z).normalized()
    if aim_flat.dot(facing) < .72: return false
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
        if t < .2 or t > 42.0 or t >= nearest: continue
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
            health_by_peer[victim] = 100
            game.net.send_fps_respawn(victim,game.fps_arena.spawn_for(victim))
    game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)
    return true

func server_reload(shooter: int) -> bool:
    if not active or not game.net.authoritative() or not ammo_by_peer.has(shooter): return false
    if int(ammo_by_peer[shooter]) >= MAGAZINE_CAPACITY: return false
    ammo_by_peer[shooter] = MAGAZINE_CAPACITY
    game.net.broadcast_fps_state(health_by_peer,ammo_by_peer,scores)
    return true

func receive_fps_state(hp: Dictionary, ammo: Dictionary, points: Dictionary) -> void:
    health_by_peer = hp.duplicate()
    ammo_by_peer = ammo.duplicate()
    scores = points.duplicate()
    var id: int = game.multiplayer.get_unique_id() if game.net.mode != "solo" else 1
    health = int(hp.get(id,100))
    magazine = int(ammo.get(id,MAGAZINE_CAPACITY))
