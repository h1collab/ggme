extends SceneTree
var failed := false
func check(value: bool, note: String) -> void:
	if not value:
		failed = true
		push_error("FAIL: " + note)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop()
	game.net.leave()
	game.prologue.phase = "ended"
	game.running = true
	game.ui.prologue_finished()
	check(not game.extra_levels.visible,"No extra sector visible at title")
	for number in [0,1,2,5,6,130,131,132,133]:
		game.open_backrooms_level(number)
		check(game.extra_levels.visible and game.extra_levels.current == number,"New level loads in authored GLB zone")
		check(game.extra_levels.scene_root != null,"Actual separate 3D level root exists")
		check(game.extra_levels.colliders.get_child_count() >= 5,"Walls and floor have physics collision")
		check(game.extra_levels.passive_entities.size() >= 2,"Non-attacking 3D witness and licensed sprite are present")
		check(game.extra_levels.exits.size()==2,"Non-locking entry and exit exist")
		check(game.extra_levels.interact(game.extra_levels.exits[1]) == "NEXT","Exit is interactive")
		check(game.extra_levels.interact(game.extra_levels.exits[0]) == "BACK","Return path is interactive")
		var model_count: int = game.extra_levels.scene_root.find_children("*","MeshInstance3D",true,false).size()
		check(model_count >= 40,"New space uses genuine imported model meshes, not empty scene")
		var kind: String = game.extra_levels.update_player(Vector3(0,0,-16),0.3)
		check(kind == "WITNESS","Watcher turns when approached")
		check(game.extra_levels.update_player(Vector3(0,0,-16),0.3).is_empty(),"Watcher never repeats every frame")
		check(game.extra_levels.update_player(Vector3(0,0,-24),0.3) == "VANISH","Non-attacking entity leaves space")
		check(game.extra_levels.update_player(Vector3(0,0,-24),0.3).is_empty(),"Vanishing event is one shot")
		game.extra_levels.clear()
		check(not game.extra_levels.visible and game.extra_levels.scene_root == null,"Leaving sector removes environment and physics")
	game.open_backrooms_level(1)
	game.player.global_position = game.extra_levels.exits[1]
	game.player.interact_or_locked_door()
	check(game.extra_levels.current == 2,"Interactive transition Level 1 to Level 2")
	game.player.global_position = game.extra_levels.exits[1]
	game.player.interact_or_locked_door()
	check(game.extra_levels.current == 130,"Interactive transition Level 2 to Level 130")
	game.player.global_position = game.extra_levels.exits[0]
	game.player.interact_or_locked_door()
	check(game.extra_levels.current == 2,"Interactive return Level 130 to Level 2")
	game.show_title_room()
	check(not game.extra_levels.visible,"Main menu releases new zone")
	# Release original imported GLB resources and streams before engine teardown.
	game.net.leave()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for sound in game.find_children("*",kind,true,false):
			sound.stop()
			sound.stream = null
	for animator in game.find_children("*","AnimationPlayer",true,false): animator.stop()
	game.queue_free()
	for i in range(16): await process_frame
	await create_timer(0.4).timeout
	if not failed:
		print("Faceless 2 extra levels checks: PASS / licensed GLB scenes, passive entities and traversable links")
		quit(0)
	else: quit(1)
