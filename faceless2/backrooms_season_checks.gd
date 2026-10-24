extends SceneTree
var failed := false
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failed = true; push_error("FAIL: "+label)
func key(code: int, held: bool) -> void:
	var event := InputEventKey.new();event.physical_keycode = code;event.pressed = held
	Input.parse_input_event(event)
func run() -> void:
	var profile = preload("backrooms_season.gd").new()
	profile.profile_path = "user://qa_s1_manual.cfg"
	check(profile.level() == 1,"Fresh S1 starts level one")
	for tier in range(1,46):
		check(not profile.reward(tier).is_empty() and not profile.reward(tier,true).is_empty(),"Both reward tracks define every tier through 45")
	check(profile.claim(1) == "CLAIMED" and profile.tokens == 55,"Actual free claim adds cosmetic tokens")
	check(profile.claim(1) == "CLAIMED" and profile.tokens == 55,"Duplicate claim is idempotent")
	check(profile.claim(2) == "LEVEL_LOCKED" and profile.claim(1,true) == "PAID_LOCKED","Future and unowned paid rewards cannot be claimed")
	profile.begin_session()
	check(profile.record_round(1,false) and not profile.record_round(1,true) and profile.xp == 100,"Round reward cannot be applied twice")
	profile.add_xp(100000)
	check(profile.level() == 45 and profile.xp == 4400,"XP is capped at the level-45 boundary")
	check(profile.claim(45) == "CLAIMED" and profile.collection.has("S1 SURVIVOR"),"Final-tier title enters the real collection")
	var loaded = preload("backrooms_season.gd").new();loaded.profile_path = profile.profile_path;loaded.load_profile()
	check(loaded.level() == 45 and loaded.tokens == 55 and loaded.claimed.has(45),"Progress and collection survive reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile.profile_path))
	var game = load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop();game.net.leave();game.start_fps_arena(0)
	game.season.profile_path = "user://qa_s1_runtime.cfg"
	var wall := StaticBody3D.new();var shape := CollisionShape3D.new();shape.shape = BoxShape3D.new();shape.shape.size = Vector3(.2,3,16);wall.add_child(shape);wall.position = Vector3(2,1.5,0);game.add_child(wall)
	game.player.reset_to(Vector3(1.53,.12,5));game.player.yaw = 0;game.player.rotation.y = 0
	for frame in range(12): await physics_frame
	check(game.player.wall_tangent(game.player.position,Vector3.RIGHT) == Vector3.ZERO,"Straight wall pressure cannot boost")
	check(game.player.wall_tangent(Vector3(-1,.12,0),Vector3(1,0,-1)) == Vector3.ZERO,"Open ground cannot boost")
	key(KEY_W,true);key(KEY_D,true)
	await create_timer(.65).timeout
	check(game.player.wall_glide_active and absf(game.player.velocity.z) > 7.4,"Real diagonal wall contact accelerates CharacterBody along the wall")
	check(Vector2(game.player.velocity.x,game.player.velocity.z).length() <= 8.05,"Wall glide respects the hard speed cap")
	check(game.net.host_wall_glide(game.player.position,game.player.position+Vector3(0,0,-.3)),"Host independently finds the real wall")
	check(not game.net.host_wall_glide(Vector3(-1,.12,0),Vector3(-1,.12,-.3)),"Host denies open-ground boost eligibility")
	key(KEY_W,false);key(KEY_D,false)
	await create_timer(.5).timeout
	check(game.player.wall_glide == 0.0 and game.player.velocity.length() < .3,"Releasing movement clears boost and stops")
	wall.queue_free()
	game.player.set_physics_process(false)
	for seat in range(1,7):
		var actor := preload("backrooms_combat_actor.gd").new();game.add_child(actor);actor.configure(seat)
		actor.update_combat(6.2,false,0,0,.016)
		check(actor.current_clip.ends_with("Run_Carry") and actor.animation.speed_scale < 1.2,"Run gait matches actual sprint speed")
		actor.update_combat(6.2,true,0,0,.016,0,5.0)
		var rise: float = actor.animation.current_animation_position
		actor.update_combat(6.2,true,0,0,.016,0,-4.0)
		check(actor.current_clip.ends_with("Jump") and actor.animation.current_animation_position > rise and actor.animation.speed_scale == 0,"Jump follows rise/fall without looping")
		check(actor.hand_contact_error() < .003,"Jump preserves the real hand grip")
		actor.update_combat(6.2,false,0,0,.016)
		check(actor.current_clip.ends_with("Run_Carry") and actor.animation.speed_scale > .8,"Landing resumes the running animation")
		actor.queue_free()
	game.ui.season_page = 8;game.ui.open_season()
	check(game.ui.panel_kind == "season" and game.ui.panels.find_children("*","Button",true,false).size() >= 13,"Last manual page renders both tracks through tier45")
	game.net.leave();game.queue_free();game = null
	for frame in range(10): await process_frame
	if not failed: print("FPS_S1_MOVEMENT_PASS wall geometry/speed cap, host eligibility, all six run/jump rigs, 45-tier claims/save/paid locks")
	quit(1 if failed else 0)
