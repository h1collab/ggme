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
var last_kill_serial := 0
var feed_seconds := 0.0
func icon_file(key: String) -> String:
	var file := "res://ui/hud/"+key+".svg"
	return file if ResourceLoader.exists(file) else "res://faceless2/hud_icons/"+key+".svg"
func icon(parent: Control, key: String, at: Vector2, extent: Vector2) -> void:
	var picture := TextureRect.new()
	picture.texture = load(icon_file(key))
	picture.position = at
	picture.size = extent
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
func card(rect: Rect2) -> Panel:
	var panel: Panel = ui._card(self,rect,Color(.014,.022,.030,.60))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel
func build(owner_ui: Control) -> void:
	ui = owner_ui
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1600,900)
	var left := card(Rect2(26,24,535,136))
	icon(left,"map",Vector2(16,18),Vector2(34,34))
	map_text = ui._label(left,"",Vector2(62,16),455,23)
	icon(left,"people",Vector2(16,70),Vector2(32,32))
	room_text = ui._label(left,"",Vector2(62,72),455,20)
	var right := card(Rect2(1030,110,522,64))
	icon(right,"score",Vector2(16,14),Vector2(30,30))
	score_text = ui._label(right,"",Vector2(60,17),450,20)
	feed = ui._label(self,"",Vector2(1050,190),480,20)
	feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feed.size.y = 140
	health_card = card(Rect2(26,790,262,76))
	icon(health_card,"health",Vector2(18,21),Vector2(34,34))
	health_text = ui._label(health_card,"",Vector2(68,12),180,34)
	ammo_card = card(Rect2(1260,744,292,122))
	icon(ammo_card,"weapon",Vector2(18,9),Vector2(77,42))
	icon(ammo_card,"bullet",Vector2(252,19),Vector2(20,28))
	ammo_text = ui._label(ammo_card,"",Vector2(108,10),139,34)
	ammo_hint = ui._label(ammo_card,"",Vector2(18,65),254,19)
	reload_bar = ProgressBar.new()
	reload_bar.position = Vector2(18,105)
	reload_bar.size = Vector2(256,5)
	reload_bar.show_percentage = false
	reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_card.add_child(reload_bar)
func refresh(delta: float) -> void:
	var game: Node = ui.game
	var fps: Node3D = game.fps
	visible = fps.active and not ui.modal
	if not visible: return
	var mobile: bool = ui.touch_controls_enabled()
	health_card.position.y = 557 if mobile else 790
	ammo_card.position.y = 510 if mobile else 744
	map_text.text = game.fps_arena.map_title(game.language == "zh")
	var count: int = fps.health_by_peer.size()
	var cap: int = game.net.max_crew
	room_text.text = ui.localized("LOCAL TRAINING","本地训练") if game.net.mode == "solo" else "%s  ·  %d/%d" % [game.rooms.room_code,count,cap]
	if game.net.mode != "solo" and not fps.match_can_fire(): room_text.text += "  ·  "+ui.localized("WAITING FOR P2","等待第 2 人")
	var id: int = game.multiplayer.get_unique_id() if game.net.mode != "solo" else 1
	score_text.text = ui.localized("KILLS %d  ·  PLAYERS %d","击倒 %d  ·  玩家 %d") % [int(fps.scores.get(id,0)),count]
	health_text.text = str(fps.health)
	health_text.modulate = Color(1,.37,.29) if fps.health <= 25 else Color.WHITE
	ammo_text.text = "%d / %d" % [fps.magazine,fps.reserve]
	ammo_text.modulate = Color(1,.68,.33) if fps.magazine <= 5 else Color.WHITE
	reload_bar.visible = fps.reload_time > 0
	reload_bar.value = 100.0*(1.0-clampf(fps.reload_time/fps.RELOAD_SECONDS,0,1))
	if fps.reload_time > 0: ammo_hint.text = ui.localized("RELOADING %.1fs","装弹中 %.1f 秒") % fps.reload_time
	elif fps.magazine == 0: ammo_hint.text = ui.localized("RELOAD / R","请装弹") if fps.reserve > 0 else ui.localized("NO AMMO","弹药耗尽")
	elif fps.magazine <= 5: ammo_hint.text = ui.localized("LOW AMMO","弹匣将空")
	else: ammo_hint.text = ui.localized("BLASTER  ·  %d ROUND MAG","枪械  ·  弹匣容量 %d") % fps.MAGAZINE_CAPACITY
	if not fps.kill_events.is_empty():
		var newest: int = int(fps.kill_events.back().get("serial",0))
		if newest < last_kill_serial: last_kill_serial = 0
		if newest > last_kill_serial:
			last_kill_serial = newest
			feed_seconds = 8.0
			var lines: PackedStringArray = []
			for event in fps.kill_events: lines.append("P%d   ›   P%d" % [int(event.killer),int(event.victim)])
			feed.text = "\n".join(lines)
	else:
		last_kill_serial = 0
		feed.text = ""
	feed_seconds = maxf(0,feed_seconds-delta)
	feed.visible = feed_seconds > 0 and not feed.text.is_empty()
