extends SceneTree
var game: Node3D
var failed := false
func check(ok: bool, message: String) -> void:
    if not ok:
        failed = true
        push_error("FAIL: "+message)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.ui.intro_timer.stop()
    game.net.leave()
    game.prologue.phase = "ended"
    game.running = true
    game.open_backrooms_level(2)
    game.player.set_physics_process(false)
    var fps: Node3D = game.fps
    check(fps.active and fps.level_id == 2,"Level 2 enters FPS combat scene")
    check(fps.weapon_model != null and fps.weapon_model.find_children("*","MeshInstance3D",true,false).size() >= 2,"Original publisher CC0 blaster GLB visible")
    check(fps.target_remaining == 4 and fps.sentries.size() == 4,"Four separately collidable GLB security targets exist")
    check(not fps.reload() and fps.magazine == 24,"Full magazine cannot reload")
    var initial_ammo: int = fps.magazine
    var initial_reserve: int = fps.reserve
    var bullet: String = fps.fire()
    check(bullet in ["MISS","HIT","WALL","KILL"],"Crosshair ray-based firing returns physical hit/miss")
    check(fps.magazine == initial_ammo - 1,"Fire subtracts exactly one round")
    check(fps.fire() == "COOLDOWN","Firing rate stops impossible repeat damage")
    check(fps.reload(),"R initiates actual timed reload")
    fps.advance(2.0)
    check(fps.magazine == fps.MAGAZINE_CAPACITY and fps.reserve == initial_reserve - 1,"Reload restores rounds from the actual reserve")
    fps.set_aim(true)
    check(fps.aiming,"ADS can be enabled")
    fps.set_aim(false)
    fps.damage_player(12)
    check(fps.health == 88,"Unshielded damage affects actual player HP")
    fps.damage_player(12)
    check(fps.health == 88,"Invulnerability window stops multiple hits in the same frame")
    var blocked: String = game.extra_levels.interact(game.player.global_position)
    check(blocked == "SECURITY_LOCKED","Level 2 exit stays blocked while active security targets remain")
    for body in fps.sentries:
        if is_instance_valid(body):
            body.collision_layer = 0
            body.visible = false
    fps.target_remaining = 0
    check(game.extra_levels.interact(game.player.global_position) != "SECURITY_LOCKED","Security objective opens original real GLB stair controls")
    game.open_backrooms_level(1)
    check(not fps.active and fps.sentries.is_empty(),"Leaving FPS sector clears targets and viewmodel, retains older levels")
    game.net.leave()
    for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
        for sound in game.find_children("*",kind,true,false):
            (sound as Node).call("stop")
            (sound as Node).set("stream",null)
    for actor in game.find_children("*","AnimationPlayer",true,false):
        (actor as AnimationPlayer).stop()
    game.queue_free()
    for i in range(12): await process_frame
    if failed: quit(1)
    else:
        print("FACELESS2_FPS_CHECKS_PASS: original GLB gun, targets, physical shot, ammo, ADS, invulnerability, gated staircase")
        quit(0)
