extends SceneTree
var game: Node3D
var failed := false
func check(value: bool, detail: String) -> void:
	if not value:
		failed = true
		push_error("FAIL: "+detail)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var begin := Time.get_ticks_usec()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop()
	game.net.leave()
	game.start_fps_arena(0)
	game.player.set_physics_process(false)
	var startup_us := Time.get_ticks_usec()-begin
	var actor: Node3D = game.fps_arena.local_shadow
	actor.update_combat(0,false,0,0,.016)
	begin = Time.get_ticks_usec()
	for i in range(5000): actor.update_combat(0,false,0,0,.016)
	var idle_us := Time.get_ticks_usec()-begin
	var source_surfaces := 0
	for mesh in game.fps_arena.find_children("*","MeshInstance3D",true,false):
		if mesh.skin == null: source_surfaces += mesh.mesh.get_surface_count()
	print("FPS_HEADLESS_CPU_SAMPLE ",JSON.stringify({"startup_us":startup_us,"idle_5000_updates_us":idle_us,"static_source_surfaces":source_surfaces}))
	if OS.get_environment("F2_PERF_REFERENCE") == "1":
		game.queue_free(); game = null; await drain_audio(); quit(0); return
	var stats: Array = [game.fps_arena.floor_batch]+game.fps_arena.batch_stats
	var replaced := 0
	var batches := 0
	for stat in stats:
		replaced += int(stat.source_count)
		batches += int(stat.batch_count)
		for batch in stat.batches:
			var members: Array = batch.get_meta("authored_sources")
			check(batch.multimesh.instance_count == members.size(),"Every authored instance retained")
			for index in range(members.size()):
				var source: MeshInstance3D = members[index].source
				# Dummy headless RenderingServer does not retain GPU getters.
				# Inspect the exact serialized buffer submitted to MultiMesh;
				# native screenshot/benchmark CI separately verifies actual rendering.
				var data: PackedFloat32Array = batch.get_meta("submitted_buffer")
				var at := index*12
				var local := Transform3D(Basis(Vector3(data[at],data[at+4],data[at+8]),Vector3(data[at+1],data[at+5],data[at+9]),Vector3(data[at+2],data[at+6],data[at+10])),Vector3(data[at+3],data[at+7],data[at+11]))
				var rendered: Transform3D = batch.global_transform*local
				check(rendered.is_equal_approx(source.global_transform),"Batch preserves actual world transform")
				# MultiMesh per-instance bases do not set the renderer's normal
				# correction flag. Exercise an oblique normal, not just positions.
				var probe := Vector3(.3,.8,.5).normalized()
				var expected_normal := (source.global_basis.inverse().transposed()*probe).normalized()
				var batch_normal: Vector3 = (batch.global_basis.inverse().transposed()*local.basis*probe).normalized()
				check(batch_normal.is_equal_approx(expected_normal),"Batch preserves inverse-transpose normals under non-uniform scale")
				check(not source.visible,"Source cannot be double rendered")
				check(batch.multimesh.mesh == source.mesh,"Exact original GLB vertex/index/UV/normal resource preserved")
				check(batch.material_override == source.material_override,"Original material preserved")
				var actual: AABB = local*source.mesh.get_aabb()
				check(batch.multimesh.custom_aabb.grow(.001).encloses(actual),"Cull box encloses every actual instance")
	check(replaced > 50 and batches < replaced*.7,"Spatial batches meaningfully reduce static submissions")
	check(game.environment.environment.sky.sky_material is ProceduralSkyMaterial,"Anime sky replaces photographic HDR panorama")
	for source_root in [game.fps_arena.floor_root]+game.fps_arena.map_roots:
		for mesh in source_root.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var finish := mesh.get_active_material(surface) as ShaderMaterial
				check(finish != null and finish.shader == game.fps_arena.AnimeFinish.Surface,"All FPS scenery uses the texture-free anime palette")
	var sky_id: int = game.environment.environment.sky.get_instance_id()
	for map_id in [1,2,3,0]:
		game.fps_arena.activate(map_id)
		check(game.environment.environment.sky.get_instance_id() == sky_id,"Map changes reuse the anime gradient sky")
	var budget := preload("backrooms_render_budget.gd").new()
	for preset in range(3):
		budget.configure(preset,Vector2i(3200,1440),true)
		check(budget.scale*budget.scale*3200*1440 <= float([600000,900000,1400000][preset])+1,"High DPI mobile pixel cap applies")
		var initial: float = budget.scale
		for i in range(70): budget.sample(.10)
		check(is_equal_approx(budget.scale,initial),"Startup spikes never trigger repeated buffer resize")
		for i in range(600): budget.sample(.04)
		check(is_equal_approx(budget.scale,budget.limits.x),"Sustained slow frames reach bounded low scale")
		var low: float = budget.scale
		for i in range(200): budget.sample(.01,true)
		check(is_equal_approx(budget.scale,low),"Menus do not adjust live 3D buffers")
		for i in range(6000): budget.sample(1.0/60.0)
		check(is_equal_approx(budget.scale,initial),"Sustained recovery restores preset without pumping")
		budget.configure(preset,Vector2i(3200,1440),false)
		check(budget.limits.x == budget.limits.y,"Desktop uses explicit selected quality")
	if not failed: print("FPS_STATIC_BATCH_PARITY_PASS ",replaced," original GLB instances into ",batches," bounded batches; geometry/material/world transforms/cull boxes preserved")
	if not failed: print("FPS_MOBILE_RENDER_BUDGET_PASS pixel caps, warmup, hysteresis, pause, overload/recovery")
	budget = null
	game.net.leave(); game.queue_free()
	game = null
	await drain_audio()
	if not failed: print("FPS_PERFORMANCE_CHECKS_PASS")
	quit(1 if failed else 0)

func drain_audio() -> void:
	var deadline := Time.get_ticks_msec()+250
	while Time.get_ticks_msec() < deadline: await process_frame
