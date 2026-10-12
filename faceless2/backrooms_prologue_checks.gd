extends SceneTree

var game: Node3D
var failed := false

func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL: " + detail)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.ui.menu()
	check(game.ui.panel_kind == "menu", "New opening title displays before any story")
	check(not game.level.visible and game.prologue_room.visible, "Old yellow corridor stays hidden behind independent room")
	check(game.prologue_room.authored_piece_count >= 6 and game.prologue_room.authored_prop_count >= 5, "Independent scene uses licensed GLB furniture and architecture")
	check(game.prologue.camera.current and game.prologue.visible, "Title view uses the furnished opening room camera")
	var legacy_label_found := false
	for label_node in game.ui.find_children("*", "Label", true, false):
		if (label_node as Label).text.contains("THE BUILDING THAT RETURNED"): legacy_label_found = true
	check(not legacy_label_found, "Legacy chapter card is absent from the new story menu")
	game.start_prologue()
	var prologue: Node3D = game.prologue
	check(not game.level.visible and game.prologue_room.visible, "Cinematic never exposes the old corridor")
	check(prologue.active and prologue.phase == "push", "Story starts with remote 3D camera")
	check(prologue.camera.current, "Surveillance camera owns local opening view")
	check(prologue.phone != null and is_instance_valid(prologue.phone), "Real external GLB phone loaded")
	check(prologue.phone != null and prologue.phone.find_children("*", "MeshInstance3D", true, false).size() > 0, "Imported phone uses authored external GLB mesh")
	check(prologue.model_is_iphone17, "Licensed Ranguel iPhone 17 Pro GLB loads, not placeholder")
	check(not game.running and not game.player.visible, "Old evidence loop cannot hijack opening")
	check(game.ui.panel_kind == "prologue", "Mobile opening HUD is present")
	check(prologue.ringtone.stream != null and prologue.hangup.stream != null, "Ringtone and disconnect audio packaged")
	check(prologue.interference.stream != null and prologue.fall_audio.stream != null, "Static and falling audio packaged")
	for i in range(19): prologue.advance(0.15)
	check(prologue.phase == "ring", "Fast 3D camera push reaches the phone")
	check(not prologue.screen_surface.visible, "No UI call text overlays the authored iPhone GLB")
	game.set_language("zh")
	prologue.update_phone_language()
	check(not prologue.screen_surface.visible, "Phone call overlay remains absent in Chinese")
	game.set_language("en")
	prologue.screen_label.text = "未知号码" if game.language == "zh" else "UNKNOWN CALLER"
	check(prologue.screen_label.text == "UNKNOWN CALLER", "Switch back to English updates on-phone caller")
	prologue.answer()
	check(prologue.phase == "disconnect" and prologue.answered, "Player can answer the incoming call")
	# advance() intentionally caps a single frame to 0.15s; exercise real frames.
	for i in range(4): prologue.advance(0.15)
	check(prologue.phase == "static", "Disconnect is followed by interference")
	prologue.advance(0.15)
	check(prologue.interference.position != Vector3.ZERO, "Interference is a physical moving 3D emitter")
	for i in range(18): prologue.advance(0.15)
	check(prologue.phase == "fall", "Call switches to physical fall")
	for i in range(15): prologue.advance(0.15)
	check(prologue.phase == "black", "Falling enters blackout rather than old final ending")
	for i in range(9): prologue.advance(0.15)
	check(prologue.phase == "wake" and game.wakeup_room.visible and not game.level.visible, "Camera wakes in separate underground facility")
	check(game.wakeup_room.authored_modules >= 80, "Underground facility assembled entirely from real authored CC0 GLBs")
	check(prologue.wake_camera.current and prologue.wake_camera.position.y < 0.5, "First-person camera begins near the floor")
	check(game.wakeup_room.side_doors.size() >= 4, "Genuine authorized GLB side doors around the waking player")
	check(game.wakeup_room.smiler != null, "Authorized Sketchfab Smiler GLB loads")
	check(prologue.wake_hands != null, "Licensed Sketchfab FPS hands GLB loads")
	for i in range(41): prologue.advance(0.15)
	check(game.ui.wakeup_text.text == "Where am I?", "English subtitle types naturally")
	prologue.advance(0.15)
	check(prologue.phase == "smiler_wait_turn", "Smiler waits for player direction, with translation locked")
	check(not game.wakeup_room.smiler.visible, "Smiler is hidden before intentional camera turn")
	for i in range(18): prologue.advance(0.15)
	check(prologue.phase == "smiler_wait_turn", "Smiler does not trigger merely after waiting")
	prologue.look_before_smiler(Vector2(-590,0))
	for i in range(4):
		if prologue.phase != "smiler_wait_turn": break
		prologue.advance(0.15)
	check(prologue.phase == "smiler_watch" or prologue.phase == "smiler_gap", "Player turning triggers first flash")
	check(game.wakeup_room.smiler is Sprite3D, "Original Sketchfab GLB rasterized as a real transparent 3D sprite")
	for i in range(12):
		if prologue.phase == "smiler_gap": break
		prologue.advance(0.15)
	check(prologue.phase == "smiler_gap" and not game.wakeup_room.smiler.visible, "First apparition vanishes, without charging player")
	for i in range(10):
		if prologue.phase == "smiler_near": break
		prologue.advance(0.15)
	check(prologue.phase == "smiler_near", "Second apparition flashes much nearer")
	check(game.wakeup_room.smiler.position.z > -3.0, "Second Smiler appears near player without forward interpolation")
	for i in range(6):
		if prologue.phase == "ended": break
		prologue.advance(0.15)
	check(prologue.phase == "ended" and not prologue.active, "Player controls unlock only after second flash")
	check(not game.wakeup_room.smiler.visible, "Smiler hidden after second flash")
	check(game.running and game.player.visible and game.player.camera.current and not game.ui.modal, "First-person controls restored")
	check(game.ui.panel_kind == "prologue_end" and game.wakeup_room.visible, "Persistent facility remains visible without persistent subtitle card")
	game.player.request_jump()
	check(game.player.jump_requested, "Jump input is accepted in story after scare")
	check(game.wakeup_room.side_doors.size() >= 4, "Multiple licensed GLB doors remain in facility")
	check(game.wakeup_room.get_node_or_null("KenneyCC0_Corridor75ModulesBatched") != null, "Facility corridor original Kenney GLBs are statically batched")
	check(game.wakeup_room.laboratory_modules == 0 and game.wakeup_room.laboratory_root == null, "Offscreen lab GLBs/lights are not created until entrance")
	check(game.player.torch.visible == false and not game.player.flashlight_owned, "Flashlight cannot illuminate before pickup")
	check(game.wakeup_room.flashlight_world != null, "Authorized CC0 physical flashlight GLB present")
	check(game.wakeup_room.door_result(game.wakeup_room.flashlight_pickup_position) == "FLASHLIGHT", "Ground flashlight can be picked up")
	game.player.take_flashlight()
	check(game.wakeup_room.smiler.visible, "After pickup, playable Smiler appears for flashlight-driven disappearance")
	game.player.toggle_torch()
	game.player.camera.look_at(game.wakeup_room.smiler.global_position)
	game.player._physics_process(0.22)
	check(game.wakeup_room.smiler_flashlight_faded, "Actual spotlight angle, distance, and exposure banish visible Smiler")
	game.player.toggle_torch()
	check(game.player.flashlight_owned and game.player.flashlight_model.visible, "Pickup equips licensed physical model in skinned viewmodel")
	game.player.toggle_torch()
	check(game.player.torch.visible, "Owned flashlight actually illuminates")
	game.wakeup_room.begin_frowner()
	check(game.wakeup_room.frowner_started and game.wakeup_room.frowner.visible, "Frowner derivative appears only at next story beat")
	game.wakeup_room.update_frowner(4.0)
	check(game.wakeup_room.frowner_finished, "Frowner fades and releases local gaze")
	check(game.wakeup_room.openable_door != null, "One Smiler-marked hallway door leads to laboratory")
	var locked_door: Node3D = game.wakeup_room.side_doors[0]
	check(game.wakeup_room.door_result(locked_door.global_position) == "LOCK", "Sealed door returns explicit LOCK")
	check(not game.wakeup_room.laboratory_entered, "Locked hallway door must not load the lab")
	var lab_door: Node3D = game.wakeup_room.openable_door
	check(game.wakeup_room.door_result(lab_door.global_position) == "OPEN", "Smiler-marked door can open")
	check(game.wakeup_room.laboratory_entered and lab_door.visible and game.wakeup_room.laboratory_modules >= 45, "Opening animates sourced GLB and streams GLB lab")
	check(game.wakeup_room.update_visitor(Vector3(9,0.12,-3)), "Entering lab slams door and cuts power once")
	check(not game.wakeup_room.update_visitor(Vector3(9,0.12,-3)), "No repeated jumpscare per entry")
	check(game.wakeup_room.observation_root == null, "Sealed observation wing is not allocated before power")
	check(game.wakeup_room.door_result(game.wakeup_room.backup_panel_position) == "SHORT", "Shorted backup power cannot bypass the isolation breaker")
	check(not game.wakeup_room.breaker_isolated, "Failed backup attempt did not change the breaker")
	check(game.wakeup_room.door_result(game.wakeup_room.breaker_position) == "BREAKER", "Player physically isolates the Kenney GLB breaker")
	check(game.wakeup_room.breaker_isolated, "Breaker state is latched and visible")
	check(game.wakeup_room.door_result(game.wakeup_room.breaker_position) == "ISOLATED", "Isolation switch cannot be repeatedly farmed")
	check(game.wakeup_room.door_result(game.wakeup_room.backup_panel_position) == "POWER", "Backup switch restores power and opens the observation shutter")
	check(game.wakeup_room.observation_root != null and game.wakeup_room.observation_shutter != null, "Complete authored observation GLB sector is loaded only after restoration")
	check(game.wakeup_room.lab_power_restored and not game.wakeup_room.lab_power_failed, "Power state transitions out of emergency mode")
	check(game.wakeup_room.update_observation(Vector3(11,0.12,-9.4)), "Inside observation wing, chair and rear footsteps react exactly once")
	check(not game.wakeup_room.update_observation(Vector3(11,0.12,-9.4)), "Observation chair cannot repeatedly jumpscare")
	check(game.wakeup_room.door_result(game.wakeup_room.observation_console_position) == "TRACE", "Physical observation terminal reveals the displaced footstep source")
	check(game.wakeup_room.signal_traced, "Story trace is latched and can be reset through replay")
	check(game.wakeup_room.observation_shutter_body.collision_layer == 0, "The opened GLB airlock has passable physics collision")
	# Real Godot CharacterBody3D integration, not a stage/position teleporter:
	# walk from the laboratory to the streamed observation sector through
	# the newly created physical doorway, using the existing PC controls.
	game.player.reset_to(Vector3(11.0,0.10,-6.45))
	game.player.set_physics_process(true)
	var advance_key := InputEventKey.new()
	advance_key.physical_keycode = KEY_W
	advance_key.pressed = true
	Input.parse_input_event(advance_key)
	for i in range(90): await physics_frame
	advance_key.pressed = false
	Input.parse_input_event(advance_key)
	game.player.set_physics_process(false)
	check(game.player.position.z < -8.2, "Player actually walks through the authored airlock into observation wing without a teleport")

	check(game.wakeup_room.laboratory_spawn.x > 7.0, "Open door leads into independent lab zone")
	
	game.start_prologue()
	check(game.wakeup_room.observation_root == null and not game.wakeup_room.signal_traced and not game.wakeup_room.breaker_isolated, "Replay clears observation geometry and all circuit story states")
	check(prologue.phase == "push" and prologue.active, "Replay resets the cinematic timeline")
	prologue.exit_to_menu()
	check(game.ui.panel_kind == "menu" and not prologue.active, "Exit restores main menu and local camera")
	game.set_language("zh")
	check(game.language == "zh", "Language changes to Chinese and is persisted")
	game.set_language("en")
	check(game.language == "en", "English can be restored as the default")
	game.net.leave()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for sound in game.find_children("*",kind,true,false):
			sound.stop()
			sound.stream = null
	for emitter in game.find_children("*","CPUParticles3D",true,false): emitter.emitting = false
	for anim in game.find_children("*","AnimationPlayer",true,false): anim.stop()
	game.queue_free()
	for i in range(8): await process_frame
	await create_timer(0.4).timeout
	if not failed:
		print("Faceless 2 prologue checks: PASS / GLB iPhone screen, underground CC0 base, ground POV, wake title and replay")
		quit(0)
	else:
		quit(1)
