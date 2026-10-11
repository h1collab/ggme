extends Node3D

# Single-player, locally directed prologue. Never sends camera RPCs.
# Authored GLB room/desk are already present in the first-floor level.
const Assets = preload("backrooms_assets.gd")
const FAR := Vector3(2.85, 2.32, 2.85)
const NEAR := Vector3(0.72, 1.33, 0.54)
const PHONE_AT := Vector3(0.15, 0.795, -0.45)
const PUSH_SECONDS := 2.65
const RING_SECONDS := 2.0
const STATIC_SECONDS := 2.5
const FALL_SECONDS := 2.05

var game: Node
var camera: Camera3D
var phone: Node3D
var witness: Node3D
var ringtone: AudioStreamPlayer3D
var hangup: AudioStreamPlayer
var interference: AudioStreamPlayer3D
var fall_audio: AudioStreamPlayer
var phase := "inactive"
var clock := 0.0
var active := false
var answered := false
var model_is_iphone17 := false

func _ready() -> void:
	name = "OtherShiftPrologue"
	camera = Camera3D.new()
	camera.name = "SurveillanceToPhoneCamera"
	camera.fov = 59.0
	camera.near = 0.025
	add_child(camera)
	camera.position = FAR
	camera.look_at(PHONE_AT)
	camera.current = false
	# A correctly licensed high-detail iPhone model can be installed under
	# iphone17_pro.glb; until then a real third-party phone GLB is required.
	var exact_path := Assets.path("vendor/iphone17_pro.glb")
	model_is_iphone17 = ResourceLoader.exists(exact_path)
	var phone_file := "vendor/iphone17_pro.glb" if model_is_iphone17 else "vendor/phone_fallback.glb"
	if not ResourceLoader.exists(Assets.path(phone_file)):
		push_error("Prologue phone GLB unavailable: " + phone_file)
	else:
		phone = Assets.fitted(phone_file, 0.158)
		phone.name = "LicensedPhoneGLB"
		phone.position = PHONE_AT
		phone.rotation.x = -PI * 0.5
		add_child(phone)
	# The silent person in the recovered recording is a real skinned GLB,
	# not a generated primitive; this figure does not appear in multiplayer.
	if ResourceLoader.exists(Assets.path("vendor/crew.glb")):
		witness = Assets.fitted("vendor/crew.glb", 1.73)
		witness.name = "SeatedInvestigatorSilhouette"
		witness.position = Vector3(-1.65, 0.0, 4.25)
		witness.rotation.y = -0.7
		add_child(witness)
		for anim_node in witness.find_children("*", "AnimationPlayer", true, false):
			var animator := anim_node as AnimationPlayer
			animator.speed_scale = 0.0
	ringtone = AudioStreamPlayer3D.new()
	ringtone.name = "IncomingCall3D"
	ringtone.position = PHONE_AT + Vector3(0, 0.12, 0)
	ringtone.max_distance = 16.0
	ringtone.unit_size = 1.1
	_apply_sound(ringtone, "phone_ring.wav")
	add_child(ringtone)
	hangup = AudioStreamPlayer.new()
	hangup.name = "CallDisconnect"
	_apply_sound(hangup, "phone_disconnect.wav")
	add_child(hangup)
	interference = AudioStreamPlayer3D.new()
	interference.name = "MovingRadioStatic"
	interference.max_distance = 24.0
	interference.unit_size = 0.9
	interference.volume_db = -8.0
	_apply_sound(interference, "phone_static.wav")
	add_child(interference)
	fall_audio = AudioStreamPlayer.new()
	fall_audio.name = "LossOfFloor"
	_apply_sound(fall_audio, "phone_fall.wav")
	add_child(fall_audio)
	visible = false
	set_process(false)

func _apply_sound(sound: Node, filename: String) -> void:
	var path := "res://audio/" + filename
	if not ResourceLoader.exists(path):
		path = "res://faceless2/audio/" + filename
	if ResourceLoader.exists(path):
		sound.set("stream", load(path))
	else:
		push_warning("Missing prologue audio: " + filename)

func begin() -> void:
	if not is_instance_valid(phone):
		push_error("Cannot begin opening cinematic without licensed phone GLB.")
		return
	if not is_instance_valid(game) or not is_instance_valid(game.level): return
	_stop_audio()
	game.net.leave()
	game.running = false
	game.level.visible = false
	game.prologue_room.visible = true
	game.player.visible = false
	game.player.set_physics_process(false)
	game.player.cancel_focus()
	game.player.camera.current = false
	visible = true
	camera.make_current()
	camera.position = FAR
	camera.rotation = Vector3.ZERO
	camera.fov = 59.0
	camera.look_at(PHONE_AT)
	answered = false
	clock = 0.0
	phase = "push"
	active = true
	set_process(true)
	game.ui.open_prologue()
	game.ui.prologue_stage("push")

func answer() -> void:
	if not active or phase != "ring" or answered: return
	answered = true
	if ringtone.playing: ringtone.stop()
	_transition("disconnect")

func _transition(next_phase: String) -> void:
	phase = next_phase
	clock = 0.0
	game.ui.prologue_stage(next_phase)
	match next_phase:
		"ring":
			if ringtone.stream != null: ringtone.play()
		"disconnect":
			if hangup.stream != null: hangup.play()
		"static":
			if interference.stream != null: interference.play()
		"fall":
			if interference.playing: interference.stop()
			if fall_audio.stream != null: fall_audio.play()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not active or delta <= 0: return
	clock += minf(delta, 0.15)
	match phase:
		"push":
			var t := smoothstep(0.0, PUSH_SECONDS, clock)
			camera.position = FAR.lerp(NEAR, t)
			camera.look_at(PHONE_AT + Vector3(0, 0.08, 0), Vector3.UP)
			camera.fov = lerpf(59.0, 42.0, t)
			if clock >= PUSH_SECONDS: _transition("ring")
		"ring":
			# The protagonist answers even when players do not tap the screen;
			# touch/E can accelerate this event.
			if clock >= RING_SECONDS: answer()
		"disconnect":
			if clock >= 0.40: _transition("static")
		"static":
			# The noise begins on the phone and circles the local listener.
			var angle := clock * TAU / STATIC_SECONDS
			var position_around := Vector3(sin(angle) * 1.6, 0.08 + sin(angle * 0.7) * 0.3, cos(angle) * 1.6)
			interference.global_position = camera.global_position + position_around
			camera.rotation.z = sin(clock * 8.0) * 0.014
			if clock >= STATIC_SECONDS: _transition("fall")
		"fall":
			var descent := clock / FALL_SECONDS
			camera.position.y = NEAR.y - 7.2 * descent * descent
			camera.rotation.z = lerpf(0.0, 0.24, descent)
			camera.fov = lerpf(42.0, 74.0, descent)
			game.ui.prologue_fade(smoothstep(0.45, 1.0, descent))
			if clock >= FALL_SECONDS: finish()

func finish() -> void:
	if not active: return
	_stop_audio()
	phase = "ended"
	active = false
	set_process(false)
	game.ui.prologue_finished()

func exit_to_menu() -> void:
	_stop_audio()
	active = false
	phase = "inactive"
	set_process(false)
	visible = true
	game.show_title_room()
	game.ui.menu()

func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E or event.physical_keycode == KEY_ENTER:
			answer()
		elif event.physical_keycode == KEY_ESCAPE:
			exit_to_menu()

func _stop_audio() -> void:
	for sound in [ringtone, hangup, interference, fall_audio]:
		if is_instance_valid(sound):
			sound.stop()

func _exit_tree() -> void:
	for sound in [ringtone, hangup, interference, fall_audio]:
		if is_instance_valid(sound):
			sound.stop()
			sound.stream = null
