extends SceneTree
# The filesystem is only a harness command/status channel. All room, pose,
# fire, roster and disconnect state must travel through actual ENet/HTTP.
var game: Node3D
var role := "client"
var label := "client"
var directory := ""
var room := ""
var output := ""
var port := 24711
var slots := 4
var selected_map := -1
var elapsed := 0.0
var serial := 0
var started := false
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        var pair := arg.trim_prefix("--").split("=",true,1)
        if pair.size() != 2: continue
        match pair[0]:
            "role": role = pair[1]
            "label": label = pair[1]
            "directory": directory = pair[1]
            "room": room = pair[1]
            "output": output = pair[1]
            "port": port = int(pair[1])
            "slots": slots = int(pair[1])
            "map": selected_map = int(pair[1])
    call_deferred("run")
func run() -> void:
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.ui.intro_timer.stop()
    game.set_process(false)
    game.player.set_physics_process(false)
    game.rooms.configure("" if role.begins_with("lan_") else directory)
    game.rooms.game_port = port
    if role == "lan_host":
        # Two real UDP peers on CI's single machine: release the host's
        # unused discovery listener and route real announcements to loopback.
        game.rooms.receiver.close()
        game.rooms.broadcaster.set_dest_address("127.0.0.1",game.rooms.DISCOVERY_PORT)
        game.rooms.create_room(true,slots,"LAN regression",selected_map)
    elif role == "lan_quick": game.rooms.quick_match()
    elif role == "host": game.rooms.create_room(true,slots,"FPS regression",selected_map)
    elif role == "quick":
        game.rooms.quick_match()
        game.rooms.quick_match() # duplicate UI request must be single-flight
    elif role == "cancel":
        game.rooms.quick_match()
        game.rooms.quick_match()
        await create_timer(.15).timeout
        game.rooms.cancel_match()
    elif role == "raw":
        # Open real UDP but deliberately DO NOT authenticate membership.
        game.multiplayer.connected_to_server.disconnect(game.net._connected)
        game.net.join("127.0.0.1",port,"")
    elif role == "overflow": game.net.join("127.0.0.1",port,"overflow")
    else: game.rooms.join_code(room)
    started = true
    print("FPS_SESSION_PROCESS ",label)
func _process(delta: float) -> bool:
    if not is_instance_valid(game) or not started: return false
    elapsed += delta
    if elapsed < .10: return false
    elapsed = 0
    var command_path := output.path_join(label+"-command.json")
    if FileAccess.file_exists(command_path):
        var command: Variant = JSON.parse_string(FileAccess.get_file_as_string(command_path))
        DirAccess.remove_absolute(command_path)
        if command is Dictionary:
            serial = int(command.get("serial",0))
            match str(command.get("op","")):
                "fire":
                    var v: Array = command.get("direction",[0,0,-1])
                    for i in range(int(command.get("count",1))):
                        game.net._fps_fire.rpc_id(1,Vector3(float(v[0]),float(v[1]),float(v[2])))
                "aim":
                    var v: Array = command.get("direction",[0,0,-1])
                    var direction := Vector3(float(v[0]),float(v[1]),float(v[2])).normalized()
                    game.player.yaw = atan2(-direction.x,-direction.z)
                    game.player.rotation.y = game.player.yaw
                    game.player.pitch = asin(direction.y)
                    game.player.camera.rotation.x = game.player.pitch
                "reload": game.net.request_fps_reload()
                "pose": game.net._submit_pose.rpc_id(1,Vector3(10000,0,10000),0.0,false,0.0)
                "handshake": game.net._hello.rpc_id(1,game.net.PROTOCOL,game.net.password)
                "move":
                    var event := InputEventKey.new()
                    event.physical_keycode = KEY_W
                    event.pressed = bool(command.get("pressed",false))
                    game.ui.close_panels()
                    game.player.set_physics_process(true)
                    Input.parse_input_event(event)
                "leave": game.net.leave()
                "quit":
                    started = false
                    call_deferred("shutdown")
                    return false
    game.ui.refresh()
    var pose_data := {}
    for id in game.net.poses:
        var p: Vector3 = game.net.poses[id].p
        pose_data[str(id)] = [p.x,p.y,p.z,float(game.net.poses[id].y)]
    var data := {"mode":game.net.mode,"transport_connected":is_instance_valid(game.net.peer) and game.net.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED,"members":game.net.members.size(),
        "id":game.multiplayer.get_unique_id(),"active":game.fps.active,
        "arena":game.fps_arena.visible,"can_fire":game.fps.match_can_fire(),
        "impact_serial":game.fps.last_impact_serial,"impact_marks":game.fps.impact_sprites.size(),"impact_authority":game.fps.impact_serial,"hit_serials":game.fps.hit_serials,"hit_marker":game.fps.last_confirmed_serial,"match_attempts":game.rooms.match_attempts,"matching":game.rooms.matching,"kills":game.fps.kill_events,"map":game.fps_arena.map_id,"geometry":game.fps_arena.layout_digest,
        "hp":game.fps.health_by_peer,"ammo":game.fps.ammo_by_peer,
        "scores":game.fps.scores,"stock":game.fps.reserve_by_peer,"seats":game.net.seats,"poses":pose_data,
        "directory":game.rooms.directory_url,"room":game.rooms.room_code,"capacity":game.net.max_crew,
        "running":game.running,"panel":game.ui.panel_kind,
        "hud":game.ui.fps_status_label.text,"serial":serial}
    var path := output.path_join(label+"-state.json")
    var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data))
        file.close()
        DirAccess.rename_absolute(path+".tmp",path)
    return false

func shutdown() -> void:
    game.net.leave()
    for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
        for sound in game.find_children("*",kind,true,false):
            sound.stop()
            sound.set("stream",null)
    game.queue_free()
    game = null
    for i in range(12): await process_frame
    print("FPS_SESSION_SHUTDOWN ",label)
    quit()
