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
	var saved_turn: bool = game.auto_turn
	game.start_solo()
	check(game.ui.panel_kind == "briefing", "Solo begins with an explicit story and objective briefing")
	check(game.story.actor != null, "External HorrorGameMaker GLB imported")
	check(not game.story.actor.find_children("*", "Skeleton3D", true, false).is_empty(), "External monster retains its skin/skeleton")
	check(game.story.animation.is_playing() and str(game.story.animation.current_animation).to_lower().contains("walk"), "Original model walk animation imported and playing")
	check(game.story.step_audio.stream != null and game.story.breath_audio.stream != null, "Recorded positional monster audio loaded")
	check(game.ui.theme.default_font.has_char("岚".unicode_at(0)), "Bundled font contains Chinese story glyphs")
	for layer in range(3):
		game.start_shift(layer)
		game.ui.close_panels()
		game.auto_turn = true
		for frame in range(8): await physics_frame
		check(game.level.floor_material.get_shader_parameter("photo_enabled"), "Photographic floor texture layer %d" % layer)
		check(game.level.wall_material.get_shader_parameter("photo_enabled"), "Photographic wall texture layer %d" % layer)
		check(game.level.find_children("ScannedProp_*", "", true, false).size() >= 6, "External GLB props placed with collision")
		var origin: Vector3 = game.story.trigger + Vector3(0,1.58,0)
		var visible_ray := PhysicsRayQueryParameters3D.create(origin, game.story.reveal_point + Vector3(0,1.55,0))
		var hidden_ray := PhysicsRayQueryParameters3D.create(origin, game.story.hidden_point + Vector3(0,1.55,0))
		var space := game.get_world_3d().direct_space_state
		check(space.intersect_ray(visible_ray).is_empty(), "Revealed monster has a clear view from the trigger")
		check(not space.intersect_ray(hidden_ray).is_empty(), "Retreat endpoint is actually hidden by architecture")
		game.story.update(1)
		check(not game.story.seen, "No encounter outside its region")
		game.player.position = game.story.trigger
		game.ui.open_pause()
		game.story.update(3)
		check(not game.story.seen, "Menu does not trigger a camera event")
		game.ui.close_panels()
		game.story.update(0.1)
		check(game.story.phase == "approach" and not game.story.actor.visible, "Footsteps precede the visible approach")
		game.story.update(1.0)
		check(game.story.actor.visible and not game.story.revealed, "Actor emerges by moving from the occluded corner")
		game.story.update(0.8)
		check(game.story.phase == "reveal" and game.story.revealed, "Region reaches the monster reveal")
		check(game.player.focus_seconds > 0, "Optional camera focus begins")
		game.player._physics_process(0.1)
		check(absf(game.player.yaw) > 0.1, "Camera focus changes actual player yaw")
		game.player.look(Vector2(4,0))
		check(game.player.focus_seconds == 0 and game.player.attention_hold == 0, "Manual looking interrupts cinematic focus and releases movement")
		game.story.update(1.8)
		check(game.story.phase == "retreat", "Actor retreats after a short look")
		game.story.update(1.5)
		check(game.story.phase == "done" and not game.story.actor.visible, "Monster returns behind the wall and is hidden")
		game.story.update(10)
		check(game.story.phase == "done", "Encounter cannot repeat on the same layer")
		game.story.reset_layer(layer)
		game.auto_turn = false
		game.story.update(1.9)
		check(game.story.revealed and game.player.focus_seconds == 0, "Turning disabled still allows seeing and hearing the event")
		var objective: Dictionary = game.next_objective()
		check(objective.text.contains("01"), "First incomplete repair is explained")
		game.repaired = [true,true,true]
		check(game.next_objective().text.contains("报告"), "After repairs the objective directs players to monitoring")
	game.auto_turn = saved_turn
	game.net.leave()
	game.ui.monitor_view.world_3d = null
	game.queue_free()
	await create_timer(0.15).timeout
	if not failed: print("Backrooms story checks: PASS / Chinese briefing and font, external skinned GLB, recorded audio, photo materials, real corner occlusion, one-shot reveal/retreat, manual override, objectives")
	quit(1 if failed else 0)
