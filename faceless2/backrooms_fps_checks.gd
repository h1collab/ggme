extends SceneTree
var game: Node3D
var failed := false
func check(ok: bool, msg: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL: "+msg)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop()
	game.net.leave()
	game.start_fps_arena()
	game.player.set_physics_process(false)
	var fps: Node3D = game.fps
	check(game.fps_arena.visible and game.fps_arena.floor_modules.size() == 16, "One open arena of sixteen real imported CC0 GLB tiles")
	check(fps.active and fps.level_id == -2, "FPS has no level ID or elevator")
	check(fps.weapon_model != null and fps.weapon_model.find_children("*","MeshInstance3D",true,false).size() >= 2, "Licensed original multi-mesh firearm")
	check(fps.sentries.is_empty(), "Arena has no scripted Level 2 enemies or Backrooms narrative targets")
	check(fps.health_by_peer.has(1) and fps.ammo_by_peer.has(1), "Authoritative host initializes HP and ammo")
	check(not fps.server_fire(1,Vector3(100,0,0)), "Invalid arbitrary firing vector rejected")
	var ammo: int = fps.ammo_by_peer[1]
	check(fps.server_fire(1,Vector3.FORWARD), "Host accepts normalized authoritative shot")
	check(int(fps.ammo_by_peer[1]) == ammo-1,"Server subtracts ammo once")
	check(not fps.server_fire(1,Vector3.FORWARD), "Server fire rate limit blocks duplicate shots")
	check(fps.server_reload(1),"Reload is server-authorized")
	check(int(fps.ammo_by_peer[1]) == fps.MAGAZINE_CAPACITY,"Magazine updated on server")
	check(game.fps_arena.spawn_for(1).distance_to(game.fps_arena.spawn_for(2)) > 5,"Players spawn in separate positions")
	game.show_title_room()
	check(not fps.active and not game.fps_arena.visible,"Leaving arena unloads combat and collision")
	game.net.leave()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for sound in game.find_children("*",kind,true,false):
			sound.stop()
			sound.set("stream",null)
	game.queue_free()
	for i in range(12): await process_frame
	if failed: quit(1)
	else:
		print("FACELESS2_FPS_CHECKS_PASS")
		quit(0)
