extends SceneTree

var game: Node3D
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL: " + detail)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.start_solo()
	check(game.ui.panel_kind == "briefing", "Story first, no surveillance shift")
	check(game.story.actor != null, "Licensed external HorrorGameMaker GLB imported")
	check(not game.story.actor.find_children("*", "Skeleton3D", true, false).is_empty(), "Monster retains its real skin/skeleton")
	check(game.story.animation != null and game.story.animation.is_playing() and str(game.story.animation.current_animation).to_lower().contains("walk"), "Authored Walk2 animation imported")
	check(game.story.step_audio.stream != null and game.story.breath_audio.stream != null, "Positional recorded creature sounds loaded")
	check(game.ui.theme.default_font.has_char("岚".unicode_at(0)), "Chinese narrative font includes required glyphs")
	for layer in range(3):
		game.start_shift(layer)
		game.ui.close_panels()
		game.auto_turn = false
		for i in range(8): await physics_frame
		check(game.level.floor_material.get_shader_parameter("photo_enabled"), "Photographic GLB floor material / layer %d" % layer)
		check(game.level.wall_material.get_shader_parameter("photo_enabled"), "Photographic GLB wall material / layer %d" % layer)
		var origin: Vector3 = game.story.trigger + Vector3(0, 1.55, 0)
		var visible := PhysicsRayQueryParameters3D.create(origin, game.story.reveal_point + Vector3(0, 1.5, 0))
		var hidden := PhysicsRayQueryParameters3D.create(origin, game.story.hidden_point + Vector3(0, 1.5, 0))
		check(game.get_world_3d().direct_space_state.intersect_ray(visible).is_empty(), "Sighting has a clear end point")
		check(not game.get_world_3d().direct_space_state.intersect_ray(hidden).is_empty(), "Monster retreats behind real architecture")
		game.player.reset_to(game.level.spawn)
		game.story.update(1)
		check(not game.story.seen, "Nothing pops in far from scripted region")
		game.player.position = game.story.trigger
		game.ui.open_pause()
		game.story.update(3)
		check(not game.story.seen, "Menus do not trigger sightings")
		game.ui.close_panels()
		game.story.update(0.1)
		check(game.story.phase == "approach" and not game.story.actor.visible, "Sound leads visual encounter")
		game.story.update(1.0)
		check(game.story.actor.visible and game.story.animation.speed_scale > 0, "Skinned creature moves with walk animation")
		game.story.update(0.9)
		check(game.story.revealed and game.story.phase == "reveal", "Glance emerges from dark corner")
		check(game.player.focus_seconds == 0 and game.player.attention_hold == 0, "No automatic camera by default")
		check(game.story.animation.speed_scale == 0, "Creature does not treadmill in place while staring")
		game.story.update(game.story.duration + 0.05)
		check(game.story.phase == "retreat", "Monster departs without chase")
		game.story.update(1.4)
		check(game.story.phase == "done" and not game.story.actor.visible, "Retreat is finite and one-shot")
		game.story.update(10)
		check(game.story.phase == "done", "No sudden repeated jump scares")
		game.story.reset_layer(layer)
		game.auto_turn = true
		game.story.update(2.01)
		check(game.player.focus_seconds > 0, "Opt-in focus triggers locally")
		game.player.look(Vector2(8, 0))
		check(game.player.focus_seconds == 0 and game.player.attention_hold == 0, "Touch or mouse look cancels opt-in focus")
		var objective: Dictionary = game.next_objective()
		check(objective.text.contains("01"), "First missing clue is explained")
		game.repaired = [true, true, true]
		check(game.next_objective().text.contains("电梯"), "Last clue points toward exit")
	game.net.leave()
	game.queue_free()
	await create_timer(0.15).timeout
	if not failed:
		print("Faceless 2 story checks: PASS / authored skinned animation, corner occlusion, local suspense, menu and manual override, Chinese story")
		quit(0)
	else: quit(1)
