extends Control
# Original repository-native SVG symbols, bound exclusively to real combat state.
var ui: Control
var map_text: Label
var room_text: Label
var score_text: Label
var feed: Label
var health_text: Label
var ammo_text: Label
var ammo_hint: Label
var health_card: Panel
var ammo_card: Panel
var reload_bar: ProgressBar
var stamina_bar: ProgressBar
var scoreboard: Panel
var scoreboard_text: Label
var scoreboard_open := false
var score_toggle: Button
var last_kill_serial := 0
var feed_seconds := 0.0
var kill_rows: Array[Dictionary] = []
func icon_file(key: String) -> String:
	var file := "res://ui/hud/"+key+".svg"
	return file if ResourceLoader.exists(file) else "res://faceless2/hud_icons/"+key+".svg"
func icon(parent: Control, key: String, at: Vector2, extent: Vector2) -> void:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = load(icon_file(key))
	picture.position = at
	picture.size = extent
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
func card(rect: Rect2) -> Panel:
	var panel: Panel = ui._card(self,rect,Color(.012,.018,.024,.20))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel
func build(owner_ui: Control) -> void:
	ui = owner_ui
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1600,900)
	var left := card(Rect2(26,24,370,78))
	icon(left,"map",Vector2(12,10),Vector2(25,25))
	map_text = ui._label(left,"",Vector2(48,8),310,17)
	icon(left,"people",Vector2(12,43),Vector2(23,23))
	room_text = ui._label(left,"",Vector2(48,44),310,14)
	var right := card(Rect2(1270,112,282,48))
	icon(right,"score",Vector2(12,10),Vector2(25,25))
	score_text = ui._label(right,"",Vector2(47,12),225,16)
	feed = ui._label(self,"",Vector2(1100,178),452,16)
	feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feed.size.y = 140
	for index in range(4):
		var row := card(Rect2(1240,178+index*27,312,24))
		var killer: Label = ui._label(row,"",Vector2(0,0),119,16)
		killer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		killer.size.y = 24
		icon(row,"weapon",Vector2(133,3),Vector2(32,18))
		var victim: Label = ui._label(row,"",Vector2(180,0),125,16)
		victim.size.y = 24
		row.visible = false
		kill_rows.append({"row":row,"killer":killer,"victim":victim})
	health_card = card(Rect2(28,817,205,56))
	icon(health_card,"health",Vector2(12,10),Vector2(26,26))
	health_text = ui._label(health_card,"",Vector2(50,4),130,28)
	ammo_card = card(Rect2(1324,786,228,88))
	icon(ammo_card,"weapon",Vector2(12,7),Vector2(68,25))
	icon(ammo_card,"bullet",Vector2(197,10),Vector2(14,21))
	ammo_text = ui._label(ammo_card,"",Vector2(85,3),109,28)
	ammo_hint = ui._label(ammo_card,"",Vector2(12,44),204,14)
	reload_bar = ProgressBar.new()
	reload_bar.position = Vector2(12,74)
	reload_bar.size = Vector2(204,3)
	reload_bar.show_percentage = false
	_style_bar(reload_bar)
	reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_card.add_child(reload_bar)
	stamina_bar = ProgressBar.new()
	stamina_bar.position = Vector2(12,45)
	stamina_bar.size = Vector2(180,3)
	stamina_bar.show_percentage = false
	_style_bar(stamina_bar)
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_card.add_child(stamina_bar)
	score_toggle = Button.new()
	score_toggle.position = right.position
	score_toggle.size = right.size
	score_toggle.flat = true
	score_toggle.tooltip_text = ui.localized("Scoreboard / TAB","计分板 / TAB")
	add_child(score_toggle)
	score_toggle.pressed.connect(func(): scoreboard_open = not scoreboard_open)
	scoreboard = card(Rect2(490,220,620,350))
	scoreboard_text = ui._label(scoreboard,"",Vector2(28,20),560,25)
	scoreboard_text.size.y = 320
	scoreboard.visible = false
func refresh(delta: float) -> void:
	var game: Node = ui.game
	var fps: Node3D = game.fps
	visible = fps.active and not ui.modal
	if not visible:
		scoreboard_open = false
		return
	var mobile: bool = ui.touch_controls_enabled()
	stamina_bar.value = game.player.stamina
	stamina_bar.modulate = Color(1,.64,.28) if game.player.stamina < 20 else Color(.55,.80,1)
	scoreboard.visible = scoreboard_open or Input.is_physical_key_pressed(KEY_TAB)
	if scoreboard.visible:
		var rows: PackedStringArray = [ui.localized("SCOREBOARD   ·   KILLS / HP","计分板   ·   击倒 / 生命"),""]
		var ids: Array = fps.health_by_peer.keys()
		ids.sort_custom(func(a: int,b: int): return int(fps.scores.get(a,0)) > int(fps.scores.get(b,0)))
		for peer_id in ids:
			var number: int = int(game.net.seats.get(peer_id,peer_id))
			rows.append("P%d   ·   %d / %d" % [number,int(fps.scores.get(peer_id,0)),int(fps.health_by_peer[peer_id])])
		scoreboard_text.text = "\n".join(rows)
	queue_redraw()
	health_card.position.y = 596 if mobile else 817
	ammo_card.position.y = 553 if mobile else 786
	map_text.text = game.fps_arena.map_title(game.language == "zh")
	var count: int = fps.health_by_peer.size()
	var cap: int = game.net.max_crew
	room_text.text = ui.localized("LOCAL TRAINING","本地训练") if game.net.mode == "solo" else "%s  ·  %d/%d" % [game.rooms.room_code,count,cap]
	if game.net.mode != "solo" and not fps.match_can_fire(): room_text.text += "  ·  "+ui.localized("WAITING FOR P2","等待第 2 人")
	var id: int = game.multiplayer.get_unique_id() if game.net.mode != "solo" else 1
	score_text.text = ui.localized("KILLS %d  ·  PLAYERS %d","击倒 %d  ·  玩家 %d") % [int(fps.scores.get(id,0)),count]
	if fps.training_enabled: score_text.text = ui.localized("DRILL HITS %d","训练命中 %d") % fps.training_hits
	health_text.text = str(fps.health)
	health_text.modulate = Color(1,.37,.29) if fps.health <= 25 else Color.WHITE
	ammo_text.text = "%d / %d" % [fps.magazine,fps.reserve]
	ammo_text.modulate = Color(1,.68,.33) if fps.magazine <= 5 else Color.WHITE
	reload_bar.visible = fps.reload_time > 0
	reload_bar.value = 100.0*(1.0-clampf(fps.reload_time/fps.RELOAD_SECONDS,0,1))
	if fps.reload_time > 0: ammo_hint.text = ui.localized("RELOADING %.1fs","装弹中 %.1f 秒") % fps.reload_time
	elif fps.magazine == 0: ammo_hint.text = ui.localized("RELOAD / R","请装弹") if fps.reserve > 0 else ui.localized("NO AMMO","弹药耗尽")
	elif fps.magazine <= 5: ammo_hint.text = ui.localized("LOW AMMO","弹匣将空")
	else: ammo_hint.text = "M4A1  ·  5.56  ·  AUTO"
	if not fps.kill_events.is_empty():
		var newest: int = int(fps.kill_events.back().get("serial",0))
		if newest < last_kill_serial: last_kill_serial = 0
		if newest > last_kill_serial:
			last_kill_serial = newest
			feed_seconds = 8.0
			var lines: PackedStringArray = []
			for event in fps.kill_events: lines.append("P%d   ▸   P%d" % [int(game.net.seats.get(event.killer,event.killer)),int(game.net.seats.get(event.victim,event.victim))])
			feed.text = "\n".join(lines)
	else:
		last_kill_serial = 0
		feed.text = ""
	feed_seconds = maxf(0,feed_seconds-delta)
	feed.visible = false
	for index in range(kill_rows.size()):
		var show_row: bool = feed_seconds > 0 and index < fps.kill_events.size()
		kill_rows[index].row.visible = show_row
		if show_row:
			var event: Dictionary = fps.kill_events[fps.kill_events.size()-1-index]
			kill_rows[index].killer.text = "P%d" % int(game.net.seats.get(event.killer,event.killer))
			kill_rows[index].victim.text = "P%d" % int(game.net.seats.get(event.victim,event.victim))

func _style_bar(bar: ProgressBar) -> void:
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1,1,1,.12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(.78,.87,.89,.8)
	bar.add_theme_stylebox_override("background",back)
	bar.add_theme_stylebox_override("fill",fill)

func _draw() -> void:
	if not is_instance_valid(ui) or not is_instance_valid(ui.game.fps): return
	var fps: Node3D = ui.game.fps
	if not fps.active or ui.modal: return
	var center := Vector2(800,450)
	if not fps.aiming:
		var motion: float = Vector2(ui.game.player.velocity.x,ui.game.player.velocity.z).length()
		var gap: float = 5.0+motion*.65+fps.visual_recoil*10
		for axis in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			draw_line(center+axis*gap,center+axis*(gap+6),Color(.88,.94,.96,.80),1.5,true)
	if fps.hit_feedback_time > 0:
		for axis in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
			draw_line(center+axis*7,center+axis*13,Color(1,.88,.55),2,true)
	if fps.damage_feedback_time > 0:
		var alpha: float = .22*fps.damage_feedback_time/.35
		for inset in range(0,30,5):
			draw_rect(Rect2(inset,inset,1600-inset*2,900-inset*2),Color(.86,.10,.06,alpha*(1-float(inset)/30)),false,5)
