extends SceneTree
# Native viewport capture diagnostics ONLY, run in the authorized Linux/xvfb CI.
# Scene-only measurements on this machine are not Android/device FPS evidence.
var game: Node3D
var output_dir := ""
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	output_dir = OS.get_environment("F2_BENCHMARK_DIR")
	if output_dir.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native benchmark requires the authorized desktop workflow")
		quit(2); return
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(960,540)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.intro_timer.stop()
	game.net.leave()
	game.set_quality(1)
	game.set_process(false)
	game.ui.visible = false
	var rows: Array[Dictionary] = []
	for map_id in range(4):
		game.start_fps_arena(map_id)
		game.player.set_physics_process(false)
		game.fps.set_process(false)
		game.fps.weapon_pivot.visible = false
		game.fps_arena.set_process(false)
		game.fps_arena.local_shadow.visible = false
		game.player.camera.global_position = Vector3(0,4.8,24)
		game.player.camera.look_at(Vector3(0,1.3,-6))
		for i in range(16): await frame()
		if OS.get_environment("F2_BENCHMARK_LABEL") == "optimized":
			var stats: Array = [game.fps_arena.floor_batch,game.fps_arena.batch_stats[map_id]]
			for stat in stats:
				for batch in stat.batches:
					var sources: Array = batch.get_meta("authored_sources")
					for index in range(sources.size()):
						var actual: Transform3D = batch.global_transform*batch.multimesh.get_instance_transform(index)
						if not actual.is_equal_approx((sources[index].source as Node3D).global_transform):
							push_error("Native renderer batch transform differs from authored source")
							quit(1); return
		var frame_ms: Array[float] = []
		var draw_calls: Array[int] = []
		var primitives: Array[int] = []
		for i in range(32):
			var begin := Time.get_ticks_usec()
			await frame()
			frame_ms.append(float(Time.get_ticks_usec()-begin)/1000.0)
			draw_calls.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
			primitives.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
		frame_ms.sort(); draw_calls.sort(); primitives.sort()
		var row := {"map_id":map_id,"median_frame_ms":frame_ms[16],"p95_frame_ms":frame_ms[30],"median_visible_draw_calls":draw_calls[16],"median_visible_primitives":primitives[16]}
		rows.append(row)
		var captured := root.get_texture().get_image()
		captured.save_png(output_dir.path_join("map%d.png" % map_id))
		if OS.get_environment("F2_BENCHMARK_LABEL") == "optimized":
			# Compare actual pixels to the same scene without batching. World
			# transform parity alone misses lighting/normal/projection regressions.
			var stats: Array = [game.fps_arena.floor_batch,game.fps_arena.batch_stats[map_id]]
			for stat in stats:
				for batch in stat.batches: batch.visible = false
				for source in stat.sources: source.visible = true
			for i in range(4): await frame()
			root.get_texture().get_image().save_png(output_dir.path_join("map%d-unbatched.png" % map_id))
			for stat in stats:
				for source in stat.sources: source.visible = false
				for batch in stat.batches: batch.visible = true
		print("FPS_NATIVE_RENDER_SAMPLE ",JSON.stringify(row))
	if OS.get_environment("F2_BENCHMARK_LABEL") == "optimized": print("FPS_NATIVE_BATCH_GPU_PARITY_PASS")
	var report := {"source_sha":OS.get_environment("F2_BENCHMARK_SHA"),"label":OS.get_environment("F2_BENCHMARK_LABEL"),"resolution":"960x540","quality":1,"mode":"scene-only fixed camera; no HUD/viewmodel", "device":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"note":"CI machine only; not Android FPS", "maps":rows}
	var file := FileAccess.open(output_dir.path_join("benchmark.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	game.net.leave(); game.queue_free()
	game = null
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec() < drain: await process_frame
	print("FPS_NATIVE_BENCHMARK_CAPTURE_PASS")
	quit(0)
