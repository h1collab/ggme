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
	check(absf(prologue.phone_lowest_world_y() - (prologue.PHONE_DESK_TOP + 0.004)) < 0.015, "Rotated iPhone GLB rests on its actual desk top instead of floating")
	check(prologue.phone.visible, "Original licensed iPhone is visible only during its opening")
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
	check(not prologue.phone.visible and not prologue.witness.visible and not prologue.screen_surface.visible, "Opening iPhone and GLB silhouette are fully hidden at blackout")
	for i in range(9): prologue.advance(0.15)
	check(prologue.phase == "wake" and game.wakeup_room.visible and not game.level.visible, "Camera wakes in separate underground facility")
	check(not prologue.phone.visible and not prologue.witness.visible and not prologue.screen_surface.visible, "iPhone, figure and phone-screen mesh cannot float in wakeup facility")
	check(game.wakeup_room.find_children("Kenney_CC0_display_wall","Node3D",true,false).is_empty(), "Unanchored display GLB removed from facility")
	check(game.wakeup_room.find_children("Kenney_CC0_computer_screen","Node3D",true,false).is_empty(), "Floating screen GLB removed from facility")
	for member in game.wakeup_room.find_children("Kenney_CC0_wall_pillar","Node3D",true,false):
		check(absf((member as Node3D).global_position.y) < 0.10, "Visible GLB structural column is grounded at the physical floor")
	check(game.wakeup_room.authored_modules >= 80, "Underground facility assembled entirely from real authored CC0 GLBs")
	# The old decorative Kenney door left a cut-out showing infinite black
	# outside the world; real GLB backing and a fully enclosed vestibule
	# must be present even when the camera approaches from either side.
	# Node3D names get rewritten by Godot for sibling duplicates; query each
	# actual directly-instanced GLB wrapper by durable source provenance.
	var opaque_backers: Array[Node] = []
	for possible in game.wakeup_room.get_children():
		if possible is Node3D and possible.get_meta("original_kenney_glb","") == "wakeup_floor_panel.glb":
			opaque_backers.append(possible)
	print("FACILITY_GLBS_SOURCE_BACKING_COUNT=", opaque_backers.size())
	check(opaque_backers.size() >= 20, "Original Kenney CC0 GLB panels close the wall apertures, far door and physical exit vestibule")
	for panel in opaque_backers:
		check((panel as Node3D).get_meta("original_kenney_glb","") == "wakeup_floor_panel.glb",
			"Backing surfaces remain original licensed GLB triangles, not a BoxMesh")
	for entrance in game.wakeup_room.side_doors:
		var hinge: Node3D = entrance.get_meta("hinge") as Node3D
		check(is_instance_valid(hinge) and hinge.get_node_or_null("KenneyCC0_OpaqueWorkingDoorGLB") != null,
			"Each interactive door uses a solid licensed metal GLB instead of the giant 2-shaped cutout")
		check(is_instance_valid(hinge) and hinge.get_node_or_null("KenneyCC0_PhysicalDoorLatchGLB") != null,
			"Physical door handles retain the authored Kenney CC0 switch GLB")
	check(game.wakeup_room.find_children("Kenney_CC0_door_single_closed","Node3D",true,false).is_empty(),
		"No collidable corridor is covered by an unrelated floating cutout door GLB")
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
	check(game.player.viewmodel_root.position.y < -0.75,"Real imported Sketchfab arms rest in a lower, less intrusive first-person stance")
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		check(not game.ui.joystick.visible and not game.ui.light_button.visible,"PC viewport has no distracting phone joystick or LIGHT touch overlay")
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
	check(game.wakeup_room.smiler is Sprite3D and not (game.wakeup_room.smiler as Sprite3D).no_depth_test, "Smiler sprite respects 3D wall depth")
	check(game.wakeup_room.find_children("SketchfabSmilerDoorMark_*","Sprite3D",true,false).is_empty(), "No duplicate billboard Smiler is mounted on a corridor wall")
	var wall_floor_pbr: Array = game.wakeup_room.get_node("KenneyCC0_Corridor75ModulesBatched").find_children("*","MeshInstance3D",true,false)
	var pbr_floor_found := false
	var pbr_wall_found := false
	for member in wall_floor_pbr:
		var drawable := member as MeshInstance3D
		var material := drawable.material_override as StandardMaterial3D
		if material == null or material.albedo_texture == null or not material.normal_enabled or material.roughness_texture == null: continue
		if String(drawable.name).to_lower().contains("floor"): pbr_floor_found = true
		if String(drawable.name).to_lower().contains("wall"): pbr_wall_found = true
	check(pbr_floor_found and pbr_wall_found, "Actual scanned PBR diffuse/normal/roughness maps apply to imported GLB floor and wall meshes")
	check(not game.wakeup_room.smiler_clear_ray(Vector3(10.0,1.62,-3.2), game.player.get_rid()), "Solid GLB corridor wall occludes Smiler from outside")
	check(ResourceLoader.exists("res://assets/vendor/frowner_online_ccby.png"), "Packaged online CC BY original-expression Frowner sprite exists")
	check(is_instance_valid(game.player.leg_root) and game.player.leg_root.find_children("*","MeshInstance3D",true,false).size() > 0, "Genuine imported rigged boot GLB mesh exists")
	check(is_instance_valid(game.player.viewmodel_root) and game.player.viewmodel_root.find_children("*","MeshInstance3D",true,false).size() > 0, "Genuine imported Sketchfab hand GLB meshes exist")
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
	check(game.wakeup_room.openable_door != null, "One Smiler-marked Kenney GLB door exists")
	var locked_door: Node3D = game.wakeup_room.side_doors[0]
	check(game.wakeup_room.door_result(locked_door.global_position) == "LOCK", "Non-opening door still gives LOCK")
	check(not game.wakeup_room.laboratory_entered and game.wakeup_room.laboratory_root == null, "Retired lab never instantiates")
	var marked: Node3D = game.wakeup_room.openable_door
	check(game.wakeup_room.door_result(marked.global_position) == "THRESHOLD", "Old laboratory door now opens a Level 0 threshold")
	check(game.wakeup_room.laboratory_root == null and game.wakeup_room.laboratory_modules == 0, "No obsolete laboratory GLB allocated")
	check(not ResourceLoader.exists("res://assets/vendor/laboratory_shell_cc0.glb"),"Old laboratory GLB is excluded from new APK resources")
	game.open_backrooms_level(0)
	check(game.extra_levels.current == 0 and game.extra_levels.visible, "Playable actual imported GLB Level 0 loads")
	game.extra_levels.clear()
	game.wakeup_room.visible = true
	game.wakeup_room.set_physics_active(true)

	game.start_prologue()
	check(game.wakeup_room.laboratory_root == null and not game.wakeup_room.laboratory_entered, "Replay keeps obsolete laboratory removed")
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
