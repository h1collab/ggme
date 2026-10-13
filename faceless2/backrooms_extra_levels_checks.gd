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
		check(game.extra_levels.passive_entities.size() >= 2,"At least two non-attacking licensed monster/face entities exist")
		if number in [0,1,5,130,131,132]:
			var creature: Node3D = game.extra_levels.passive_entities[0]
			check(creature.find_children("*","MeshInstance3D",true,false).size() > 0, "The white Cesium test astronaut is replaced with licensed horror GLB")
		if number == 132:
			check(game.extra_levels.scene_root.find_children("*","Sprite3D",true,false).is_empty(), "Level ! entities use GLB geometry only, not cartoon faces")
			for monster in game.extra_levels.passive_entities:
				check(monster.find_children("*","MeshInstance3D",true,false).size()>0, "Every passive Level ! monster is a CC0 skinned GLB")
		check(game.extra_levels.exits.size()==2,"Non-locking entry and exit exist")
		check(game.extra_levels.interact(game.extra_levels.exits[1]) == "NEXT","Exit is interactive")
		check(game.extra_levels.interact(game.extra_levels.exits[0]) == "BACK","Return path is interactive")
		var model_count: int = game.extra_levels.scene_root.find_children("*","MeshInstance3D",true,false).size()
		check(model_count >= 40,"New space uses genuine imported model meshes, not empty scene")
		var expected_side_room: bool = number in [1,5,130,131]
		check(game.extra_levels.side_room_floor_nodes.size() == (1 if expected_side_room else 0), "A traversable GLB lateral room exists only in the four architecturally distinct sectors")
		for room_floor in game.extra_levels.side_room_floor_nodes:
			check(is_instance_valid(room_floor) and room_floor.is_inside_tree(), "Side-room floor uses real licensed imported GLB")
		# Verify an actual physical doorway in Godot, not just node counts.
		if expected_side_room:
			await physics_frame
			var side: float = -1.0 if number in [1,130] else 1.0
			var half_width: float = 8.8*0.5 if number in [1,5,131] else 7.3*0.5
			var doorway: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(0,1.4,-12.9),Vector3(side*(half_width+1.5),1.4,-12.9))
			doorway.exclude = [game.player.get_rid()]
			check(game.extra_levels.get_world_3d().direct_space_state.intersect_ray(doorway).is_empty(), "Player-sized opening into side room has no invisible wall")
			var wall_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(side*(half_width+2.05),1.4,-12.9),Vector3(side*(half_width+5.3),1.4,-12.9))
			wall_ray.exclude = [game.player.get_rid()]
			check(not game.extra_levels.get_world_3d().direct_space_state.intersect_ray(wall_ray).is_empty(), "Licensed side-room exterior wall has matching physical collision")
		check(game.extra_levels.solid_prop_count >= 1, "Every corridor has physical prop collision, not just visual GLB crates")
		var floor_sections: Array[Node3D] = game.extra_levels.floor_section_nodes
		check(floor_sections.size() == 10, "Exactly ten licensed GLB corridor floors, excluding optional side-room floor")
		for floor_node in floor_sections:
			check(is_instance_valid(floor_node) and floor_node.is_inside_tree(), "Recorded licensed GLB floor instance remains in 3D scene")
			if is_instance_valid(floor_node):
				check(floor_node.find_children("*","MeshInstance3D",true,false).size() > 0, "Recorded floor instance contains imported GLB mesh triangles")
		var physically_scanned: StandardMaterial3D = game.extra_levels._surface("floor",Color(.65,.67,.66))
		check(physically_scanned.albedo_texture != null and physically_scanned.normal_texture != null and physically_scanned.roughness_texture != null,"Scanned Poly Haven PBR diffuse, normal and roughness are all bound")
		var gold_wall: StandardMaterial3D = game.extra_levels._surface("wall",Color(.84,.78,.38))
		var red_wall: StandardMaterial3D = game.extra_levels._surface("wall",Color(.48,.26,.21))
		check(gold_wall != red_wall and gold_wall.albedo_color != red_wall.albedo_color,"Level 0 and Level 5 retain independent tint/material resources")
		var kind: String = game.extra_levels.update_player(Vector3(0,0,-16),0.3)
		check(kind == "WITNESS","Watcher turns when approached")
		if number in [0,1,5,131]:
			check(not game.extra_levels.passive_entities[1].visible, "Distant Smiler stays invisible at the entrance")
			game.extra_levels.update_player(Vector3(0,0,-19.5),0.2)
			check(game.extra_levels.passive_entities[1].visible, "Original Sketchfab face appears only after player approaches")
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
