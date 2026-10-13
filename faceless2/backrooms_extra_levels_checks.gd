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
		check(game.extra_levels.scene_root.find_children("LicensedKenney_wall_door","Node3D",true,false).is_empty(),
			"New elevator/stairs portal has no obsolete intersecting decorative wall_door GLB")
		var sealing_panels: Array[Node] = game.extra_levels.scene_root.find_children("KenneyCC0_WallHoleInfillGLB*","Node3D",true,false)
		check(sealing_panels.size() >= 16, "GLB corridor wall cutouts and end caps are physically backed by licensed opaque original modules")
		for panel in sealing_panels:
			check((panel as Node3D).get_meta("original_kenney_glb","") == "wakeup_floor_panel.glb",
				"Every sealing panel is a reused Kenney GLB, not a generated visible primitive")
		check(game.extra_levels.passive_entities.size() >= 2,"At least two non-attacking licensed monster/face entities exist")
		if number in [0,1,5,130,131,132]:
			var creature: Node3D = game.extra_levels.passive_entities[0]
			check(creature.find_children("*","MeshInstance3D",true,false).size() > 0, "The white Cesium test astronaut is replaced with licensed horror GLB")
		if number == 132:
			check(game.extra_levels.scene_root.find_children("*","Sprite3D",true,false).is_empty(), "Level ! entities use GLB geometry only, not cartoon faces")
			for monster in game.extra_levels.passive_entities:
				check(monster.find_children("*","MeshInstance3D",true,false).size()>0, "Every passive Level ! monster is a CC0 skinned GLB")
		check(game.extra_levels.exits.size()==2,"Non-locking entry and exit exist")
		check(game.extra_levels.interact(game.extra_levels.exits[1]) != "NEXT","Level change is forbidden until the actual floor button is pressed")
		check(is_instance_valid(game.extra_levels.transport), "Original Kenney GLB transport scene is present")
		var transport: Node3D = game.extra_levels.transport
		check(transport.buttons.size() >= 1, "Each sector has at least one physical Kenney GLB floor selector")
		check(transport.enclosed_panel_count >= 3, "Lift and stairwell use genuine opaque imported CC0 GLB cabin/shaft panels")
		var licensed_steel: StandardMaterial3D = transport.metal as StandardMaterial3D
		var licensed_tile: StandardMaterial3D = transport.floor_finish as StandardMaterial3D
		check(licensed_steel != null and licensed_tile != null and
			licensed_steel.albedo_texture != null and licensed_steel.normal_texture != null and
			licensed_steel.roughness_texture != null and licensed_tile.albedo_texture != null and
			licensed_tile.normal_texture != null and licensed_tile.roughness_texture != null,
			"Cabin walls, steel doors and anti-slip floor all have actual verified PBR diffuse/normal/roughness maps")
		var steel_panels: Array[Node] = transport.find_children("KenneyCC0_SolidElevatorOrStairGLB*","Node3D",true,false)
		for panel in steel_panels:
			var surfaces: Array[Node] = (panel as Node3D).find_children("*","MeshInstance3D",true,false)
			check(not surfaces.is_empty() and (surfaces[0] as MeshInstance3D).material_override is StandardMaterial3D,
				"Each shaft sealing panel renders source GLB triangles with real PBR material")
		check(transport.station_kind(1) == ("stairs" if number in [2,6,132] else "elevator"), "Next connection uses the sector's authored stair/elevator route")
		if transport.station_kind(1) == "elevator":
			var roof_panels: Array[Node] = transport.find_children("KenneyCC0_OpaqueElevatorRoofGLB*","Node3D",true,false)
			check(not roof_panels.is_empty(), "Elevator roof is sealed using fully opaque verified Kenney source GLB instead of perforated structure_panel")
		if number != 0: check(transport.station_kind(-1) == ("stairs" if game.extra_levels.previous_level() in [2,6,132] else "elevator"), "Backward route matches incoming transport")
		for button in transport.buttons:
			check(is_instance_valid(button["model"]) and button["model"].find_children("*","MeshInstance3D",true,false).size()>0, "Every floor selector uses an actual Kenney GLB")
		var expected_destination: int = game.extra_levels.next_level()
		var main_button: Node3D = transport.selected_button(expected_destination,1)
		check(is_instance_valid(main_button),"Exactly keyed next-floor button exists")
		if is_instance_valid(main_button):
			var from_eye: Vector3 = main_button.global_position + Vector3(0,0,.78)
			var sight: Vector3 = (main_button.global_position-(from_eye+Vector3(0,1.3,0))).normalized()
			# Illegal target must not move the scene or start its elevator motor.
			# Elevator panels must expose all unique floors. Stairways have
			# exactly one physical exit switch, because they are walked.
			if transport.station_kind(1) == "elevator":
				var wrong: Node3D = transport.selected_button(number,1)
				check(is_instance_valid(wrong), "Elevator has distinct physical button for current floor")
				if is_instance_valid(wrong):
					var wrong_eye: Vector3 = wrong.global_position + Vector3(0,1.30,.35)
					check(transport.interact(wrong_eye,wrong_eye,(wrong.global_position-wrong_eye).normalized()) == "LOCKED", "Incorrect elevator button rejected")
				check(not transport.active,"Incorrect floor cannot begin a lift ride")
			else:
				check(transport.buttons.size() >= 1, "Stair exit has one correctly labeled real GLB switch")
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
		if number in [0,1,5,131]:
			check(not game.extra_levels.passive_entities[1].visible,
				"Original CC BY Smiler is invisible before the physical elevator entrance; no giant close-up face")
		check(game.extra_levels.update_player(Vector3(0,0,-24),0.3).is_empty(),"Vanishing event is one shot")
		game.extra_levels.clear()
		check(not game.extra_levels.visible and game.extra_levels.scene_root == null,"Leaving sector removes environment and physics")
	game.open_backrooms_level(1)
	var cabin: Node3D = game.extra_levels.transport
	var target: Node3D = cabin.selected_button(2,1)
	check(is_instance_valid(target), "Level 1 has unique Level 2 switch")
	if is_instance_valid(target):
		var eye: Vector3 = target.global_position + Vector3(0,1.3,.65)
		check(cabin.interact(eye,eye,(target.global_position-eye).normalized()) == "LIFT","Correct switch starts cabin closing animation")
		check(cabin.active, "Elevator remains busy and prevents duplicate rides")
		for tick in range(26): cabin._process(0.20)
		check(game.extra_levels.current == 2,"Elevator reaches Level 2 after real sequence, no immediate teleport")
	check(game.extra_levels.transport.station_kind(1) == "stairs", "Level 2 to 130 is physical stairs")
	game.show_title_room()
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
