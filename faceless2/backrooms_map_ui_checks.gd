extends SceneTree
const Catalog = preload("backrooms_map_catalog.gd")
var failed := false
var game: Node3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:failed = true;push_error("FAIL: "+message)
func run() -> void:
	root.size = Vector2i(1600,900)
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.ui.intro_timer.stop();game.set_process(false);game.net.leave()
	var ui: Control = game.ui
	var reveal: Control = ui.map_reveal
	reveal.set_process(false)
	for id in range(4):
		check(Catalog.texture(id) != null and Catalog.texture(id).get_width() <= 1800,"All four generated covers are real bounded textures")
		check(Catalog.texture(id) == Catalog.texture(id),"Cover textures are cached across carousel changes")
		check(Catalog.title(id) == game.fps_arena.MAP_NAMES[id],"Cover names share the actual arena catalog")
	ui.open_maps()
	for id in range(4):
		var panel: Panel = ui.panels.get_node("MapCard%d" % id)
		for child in panel.get_children():
			if child is Control:check(Rect2(Vector2.ZERO,panel.size).encloses(child.get_rect()),"Map card content remains inside its panel")
	var select: Button = ui.panels.get_node("MapCard2/Select")
	var at: Vector2 = select.get_global_transform_with_canvas()*(select.size*.5)
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new();event.index = 0;event.position = at;event.pressed = pressed;root.push_input(event,true)
	await process_frame
	check(ui.training_map == 2,"Actual viewport touch selects the third playable map")
	var digests := {}
	for id in range(4):
		ui.training_map = id;ui.begin_training_map()
		var elapsed := 0.0
		while reveal.visible and elapsed < 8:
			reveal.advance(.05);elapsed += .05
		check(not reveal.visible and reveal.last_committed == id and reveal.current == id,"Carousel completes on the chosen training map")
		check(reveal.visited.size() == 4,"Fast reel actually visits all four map covers")
		check(elapsed > 2 and elapsed < 6,"Reel has a bounded deceleration/confirmation duration")
		check(game.fps_arena.map_id == id and game.fps.active,"Reel completion enters the actual selected native arena")
		digests[game.fps_arena.geometry_digest()] = true
		game.player.set_physics_process(false)
	check(digests.size() == 4,"All four playable map collision layouts remain distinct")
	game.rooms.matching = true;reveal.begin(false);reveal.advance(.5)
	check(reveal.target == -1 and reveal.state == "searching" and reveal.visible,"Searching never invents a final map before the room resolves")
	game.start_fps_arena(2)
	check(reveal.target == 2 and ui.modal,"Actual arena entry resolves the reel and blocks stray player input")
	for frame in range(100):
		if not reveal.visible:break
		reveal.advance(.1)
	check(reveal.last_committed == game.fps_arena.map_id,"Room reveal agrees with the received arena")
	game.rooms.matching = false
	game.rooms.operation = "health";reveal.begin(false);reveal.advance(.75)
	check(reveal.state == "searching","Manual host creation waits for pending directory health instead of falsely failing")
	game.rooms.operation = "";reveal.advance(.1)
	check(reveal.state == "error" and reveal.target == -1,"Completed failed room creation does not invent a map")
	reveal.cancel()
	reveal.begin(false);reveal.cancel();reveal.resolve(1)
	check(not reveal.visible and reveal.target == -1,"Cancel rejects a stale completion")
	reveal.begin(false);reveal.fail("Offline")
	check(reveal.state == "error" and reveal.target == -1 and reveal.visible,"Failed matchmaking shows an error instead of a false winner")
	reveal.cancel()
	game.interface_motion = false;ui.training_map = 3;ui.begin_training_map()
	check(reveal.state == "locked" and reveal.current == 3,"Motion-off mode shows the truthful final cover without cycling")
	reveal.advance(.21)
	check(game.fps_arena.map_id == 3 and not reveal.visible,"Motion-off mode still enters the correct map")
	game.net.leave();game.queue_free();game = null;await create_timer(.35).timeout
	if not failed:print("NULRYTH_MAP_ART_REVEAL_PASS real textures, card touch, four arenas, authority landing, bounded reel, cancel/error and motion-off")
	quit(1 if failed else 0)
