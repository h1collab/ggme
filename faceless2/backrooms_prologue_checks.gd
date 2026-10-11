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
	game.start_prologue()
	var prologue: Node3D = game.prologue
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
	check(game.language == "en" and game.ui.call_title.text == "Unknown Caller", "English is default and phone shows Unknown Caller")
	game.set_language("zh")
	check(game.ui.call_title.text == "未知号码", "Switching to Chinese updates the incoming call without restarting")
	game.set_language("en")
	check(game.ui.call_title.text == "Unknown Caller", "Switch back to English updates the call")
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
	check(prologue.phase == "ended" and not prologue.active, "Prologue ends at black fade, no additional floor")
	check(game.ui.panel_kind == "prologue_end", "Ending screen allows replay")
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
		print("Faceless 2 prologue checks: PASS / real GLB phone, CCTV push, call, spatial static, fall, replay")
		quit(0)
	else:
		quit(1)
