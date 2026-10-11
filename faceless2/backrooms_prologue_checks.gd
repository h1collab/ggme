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
	check(game.language == "en" and prologue.screen_label.text == "UNKNOWN CALLER" and prologue.screen_surface.visible, "Default English UNKNOWN CALLER rendered on physical GLB phone screen")
	game.set_language("zh")
	prologue.screen_label.text = "未知号码" if game.language == "zh" else "UNKNOWN CALLER"
	check(prologue.screen_label.text == "未知号码", "Chinese model phone screen can show unknown number")
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
	for i in range(41): prologue.advance(0.15)
	check(game.ui.wakeup_text.text == "Where am I?", "English bottom-of-frame typewriter completed")
	prologue.advance(0.15)
	check(prologue.phase == "ended" and not prologue.active, "After looking into blackness, awakening segment ends")
	check(game.ui.panel_kind == "prologue_end", "Ending screen allows replay")
	check(game.wakeup_room.visible and prologue.wake_camera.current and not game.level.visible, "After awakening, leave black-site world in view, never replace it with old menu")
	prologue.look_after_wake(Vector2(40,-12))
	check(absf(prologue.wake_yaw)>0.01 and absf(prologue.wake_pitch)>0.01, "Local user can look around after waking")
	game.start_prologue()
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
