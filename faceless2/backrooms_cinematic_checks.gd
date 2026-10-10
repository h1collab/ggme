extends SceneTree

var failures: Array[String] = []
var game: Node3D

func check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		push_error("FAIL: " + msg)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.start_solo()
	game.ui.close_panels()
	check(game.player.viewmodel_root != null, "Licensed arm-only skinned GLB instantiated")
	check(game.player.walk_animation != null and game.player.walk_animation.get_animation_list().size() > 0, "Original Cesium walk animation preserved")
	var arm_meshes: Array = game.player.viewmodel_root.find_children("*", "MeshInstance3D", true, false)
	check(arm_meshes.size() > 0 and arm_meshes[0].mesh != null, "First-person arms render original authored geometry")
	check(game.story.voice_audio != null, "Generated neural narration player exists")
	check(ResourceLoader.exists("res://audio/voice/brief_0.ogg"), "Kokoro Mandarin first briefing is packaged")
	check(ResourceLoader.exists("res://audio/voice/tape_2_2.ogg"), "Kokoro final narrative clip is packaged")
	check(game.story.play_voice("warning"), "Neural audio plays without invoking OS speech")
	check(game.story.voice_audio.stream != null, "Generated OGG loaded into engine")
	game.voice_enabled = false
	check(not game.story.play_voice("warning"), "Generated narration can be disabled")
	game.voice_enabled = true
	game.start_shift(2)
	game.ui.close_panels()
	check(game.level.water_material != null, "Water uses a PBR-style shader")
	check(game.level.splash_particles != null and game.level.splash_particles.amount <= 9, "Splash emitter uses a bounded particle budget")
	var emitted: bool = game.level.add_water_step(Vector3(-8, 0, -14.6))
	check(emitted and game.level.ripple_buffer.size() == 1, "Stepping in shallow water produces one local wave")
	game.level.update_water(0.5)
	check(game.level.water_material.get_shader_parameter("water_seconds") >= 0.5, "Water shader advances the ripple time")
	var off: bool = game.level.add_water_step(Vector3(0, 0, 0))
	check(not off and game.level.ripple_buffer.size() == 1, "Dry ground does not splash")
	for i in range(24): game.level.add_water_step(Vector3(-8 + (i%3)*0.02, 0, -14.6))
	check(game.level.ripple_buffer.size() <= 8, "Footstep disturbances remain bounded")
	game.level.update_water(2.8)
	check(game.level.ripple_buffer.is_empty(), "Distant old ripples are removed")
	game.start_shift(0)
	game.ui.close_panels()
	var start_door: float = game.level.lift_left.position.x
	game.player.reset_to(game.level.exit_position)
	for i in range(3): game.apply_action("collect", i, game.level.relays[i] + Vector3(0, 0, 0.9), false)
	game.apply_action("transfer", 0, game.level.exit_position, false)
	check(game.lift_active and game.stage == 0, "Elevator ride starts instead of immediate level teleport")
	check(game.player.lift_riding, "Only a local player in the cabin receives motion")
	game._tick(1.05)
	check(game.level.lift_left.position.x < start_door - 0.45, "Left door slides open before descent")
	check(game.level.lift_right.position.x > 0.45, "Right door slides open before descent")
	game._tick(2.34)
	check(game.level.lift_left.position.x > -0.18, "Doors close before downward movement")
	check(game.lift_motor_started, "Elevator motor Foley starts on descent")
	game._tick(game.LIFT_RIDE_DURATION)
	check(game.stage == 1 and not game.lift_active, "Next level loads only after animated descent")
	check(not game.player.lift_riding, "Ride always releases local movement")
	game.ui.open_pause()
	check(game.ui.modal and game.player.focus_seconds == 0, "Menu cancels any scripted camera focus")
	game.ui.close_panels()
	game.net.leave()
	# End all live streaming decoders/particle emitters before tearing down
	# the imported skinned GLB scene. Godot may otherwise retain audio
	# playback resources beyond the final SceneTree tick in headless mode.
	for audio_kind in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for sound in game.find_children("*", audio_kind, true, false):
			sound.stop()
			sound.stream = null
	for emitter in game.find_children("*", "CPUParticles3D", true, false):
		emitter.emitting = false
	for anim in game.find_children("*", "AnimationPlayer", true, false):
		anim.stop()
	arm_meshes.clear()
	game.queue_free()
	for i in range(10): await process_frame
	await create_timer(0.8).timeout
	if failures.is_empty():
		print("Faceless 2 cinematic checks: PASS / imported arms, generated Mandarin, reactive water, animated elevator, bounded input")
		quit(0)
	else:
		quit(1)
