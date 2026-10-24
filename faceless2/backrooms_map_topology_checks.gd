extends SceneTree
# Sample actual physics rather than hashing names/materials. Identical ground
# layouts with renamed nodes or different rooftop decorations must fail.
var game: Node3D
var failed := false
const NX := 33
const NZ := 45
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:failed = true;push_error("FAIL: "+message)
func point(cell: Vector2i) -> Vector3:return Vector3(-32+cell.x*2,.12,-44+cell.y*2)
func run() -> void:
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.ui.intro_timer.stop();game.net.leave();game.set_process(false);game.player.set_physics_process(false)
	var masks: Array[Dictionary] = []
	var rows: Array = []
	for id in range(6):
		game.fps_arena.activate(id);await physics_frame;await physics_frame
		var free := {};var blocked := {}
		for x in range(NX):
			for z in range(NZ):
				var cell := Vector2i(x,z)
				if game.net.movement_path_clear(point(cell),point(cell)):free[cell] = true
				else:blocked[cell] = true
		masks.append(blocked)
		check(blocked.size() > 70,"Each map has substantive physical cover")
		var start := Vector2i(16,22)
		check(free.has(start),"The central crossing is clear")
		var visited := {};visited[start] = true;var queue: Array[Vector2i] = [start];var head := 0
		while head < queue.size():
			var cell: Vector2i = queue[head];head += 1
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = cell+offset
				if free.has(next) and not visited.has(next) and game.net.movement_path_clear(point(cell),point(next)):
					visited[next] = true;queue.append(next)
		for seat in range(1,7):
			var spawn: Vector3 = game.fps_arena.spawn_for(seat);var reachable := false
			check(game.net.movement_path_clear(spawn,spawn),"Every actual spawn has capsule clearance")
			for cell: Vector2i in visited:
				if point(cell).distance_to(spawn) < 3 and game.net.movement_path_clear(point(cell),spawn):reachable = true;break
			check(reachable,"Every spawn connects to the central play space")
		for destination in [Vector3(0,.12,-44),Vector3(0,.12,44)]:
			var reachable := false
			for cell: Vector2i in visited:
				if point(cell).distance_to(destination) < 3 and game.net.movement_path_clear(point(cell),destination):reachable = true;break
			check(reachable,"Both ends remain reachable through real routes")
		var crate_positions := {};var count := 0
		for body in game.fps_arena.map_roots[id].get_children():
			if body is StaticBody3D and "Crate" in str(body.name):
				var key: String = str(body.global_position)
				check(not crate_positions.has(key),"No exact duplicate crate placement")
				crate_positions[key] = true;count += 1
		check(count <= 18,"Curated crate budget prevents repeated rows of props")
		rows.append({"map":id,"blocked_cells":blocked.size(),"reachable_cells":visited.size(),"crates":count})
	for a in range(6):
		for b in range(a+1,6):
			var intersection := 0
			for cell in masks[a]:
				if masks[b].has(cell):intersection += 1
			var union_size: int = masks[a].size()+masks[b].size()-intersection
			var difference: float = 1-float(intersection)/maxi(1,union_size)
			check(difference >= .18,"Ground collision layouts differ materially, independent of node names")
			print("MAP_GROUND_DIFFERENCE ",a,"/",b," ",difference)
	print("MAP_TOPOLOGY_METRICS ",JSON.stringify(rows))
	game.queue_free();game = null;await create_timer(.35).timeout
	if not failed:print("NULRYTH_SIX_MAP_TOPOLOGY_PASS real capsule occupancy, pairwise differences, spawn/route connectivity and curated props")
	quit(1 if failed else 0)
