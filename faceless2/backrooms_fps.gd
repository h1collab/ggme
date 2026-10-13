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
var sentries: Array[StaticBody3D] = []
var shot_audio: AudioStreamPlayer
var reload_audio: AudioStreamPlayer
var impact_audio: AudioStreamPlayer

func _ready() -> void:
    name = "Faceless2_KenneyCC0_FPS"
    set_process(false)
    weapon_pivot = Node3D.new()
    weapon_pivot.name = "CameraMounted_CertifiedKenneyBlasterGLB"
    game.player.camera.add_child(weapon_pivot)
    weapon_pivot.position = Vector3(.48,-.45,-.78)
    weapon_pivot.rotation = Vector3(-.055,PI,.05)
    if ResourceLoader.exists(Assets.path("vendor/fps_blaster_f.glb")):
        weapon_model = Assets.fitted("vendor/fps_blaster_f.glb",.28)
        weapon_model.name = "Original_Kenney_BlasterF_CC0_GLB"
        weapon_model.scale = Vector3(.68,.68,.68)
        weapon_pivot.add_child(weapon_model)
        for node in weapon_model.find_children("*","MeshInstance3D",true,false):
            (node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    else:
        push_error("Source-verified Kenney Blaster GLB not packaged")
    weapon_pivot.visible = false
    shot_audio = _audio("fps_shot.wav",-12)
    reload_audio = _audio("fps_reload.wav",-15)
    impact_audio = _audio("fps_impact.wav",-12)

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
    if is_instance_valid(game) and is_instance_valid(game.player) and is_instance_valid(game.player.camera):
        game.player.camera.fov = 76.0
    for target in sentries:
        if is_instance_valid(target): target.queue_free()
    sentries.clear()
    target_remaining = 0

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
    if is_instance_valid(weapon_pivot):
        var motion: float = clampf(Vector2(game.player.velocity.x,game.player.velocity.z).length()/4.3,0.0,1.0)
        var walking: float = sin(game.player.motion_clock)
        var base := Vector3(.48 + walking*.012*motion,
            -.45 - absf(walking)*.013*motion,
            -.78 + visual_recoil)
        if aiming: base = Vector3(.10,-.32,-.73 + visual_recoil)
        weapon_pivot.position = weapon_pivot.position.lerp(base,minf(1.0,delta*12.0))
        weapon_pivot.rotation.x = lerpf(weapon_pivot.rotation.x,-.055+visual_recoil*.37,delta*11.0)
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
    if not active or not equipped or reload_time > 0.0 or magazine >= MAGAZINE_CAPACITY or reserve <= 0: return false
    reload_time = RELOAD_SECONDS
    aiming = false
    if reload_audio.stream != null: reload_audio.play()
    return true

func remaining_targets() -> int:
    return target_remaining

func fire() -> String:
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
