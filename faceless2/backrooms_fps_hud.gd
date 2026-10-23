extends Control
# Original repository-native SVG symbols, bound exclusively to real combat state.
var ui: Control
var map_text: Label
var room_text: Label
var score_text: Label
var feed: Label
var timer_card: Panel
var timer_text: Label
var health_bar: ProgressBar
var weapon_buttons: Array[Button] = []
var shoulder_button: Button
var view_button: Button
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
var result_panel: Panel
var result_text: Label
var ready_button: Button
var cached_touch_mode := -1
var weapon_signature := ""
var static_layout_updates := 0
var weapon_presentation_updates := 0
var health_fill: StyleBoxFlat
var stamina_fill: StyleBoxFlat
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
	var panel: Panel = ui._card(self,rect,Color(.025,.025,.025,.72))
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(.025,.025,.025,.72)
	panel.add_theme_stylebox_override("panel",skin)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel
func build(owner_ui: Control) -> void:
	ui = owner_ui
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1600,900)
	var left := card(Rect2(32,24,340,100))
	map_text = ui._label(left,"",Vector2(14,8),312,20)
	room_text = ui._label(left,"",Vector2(14,38),312,14,Color(.7,.7,.7))
	score_text = ui._label(left,"",Vector2(14,66),312,16)
	map_text.size.y = 26
	room_text.size.y = 22
	score_text.size.y = 24
	result_panel = card(Rect2(420,200,760,460))
	result_panel.add_theme_stylebox_override("panel",ui._style(Color(.012,.018,.024,.88)))
	result_text = ui._label(result_panel,"",Vector2(24,24),712,23)
	result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_text.size.y = 350
	ready_button = ui._button(result_panel,"",Rect2(250,380,260,58),func(): ui.game.net.request_fps_ready(),true)
	result_panel.visible = false
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
	health_card = card(Rect2(32,798,196,66))
	icon(health_card,"health",Vector2(12,8),Vector2(22,22))
	health_text = ui._label(health_card,"",Vector2(44,0),140,30)
	ammo_card = card(Rect2(1360,798,208,66))
	icon(ammo_card,"weapon",Vector2(12,8),Vector2(36,18))
	ammo_text = ui._label(ammo_card,"",Vector2(60,0),140,28)
	ammo_hint = ui._label(ammo_card,"",Vector2(12,36),184,14)
	reload_bar = ProgressBar.new()
	reload_bar.position = Vector2(12,58)
	reload_bar.size = Vector2(184,2)
	reload_bar.show_percentage = false
	_style_bar(reload_bar)
	reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_card.add_child(reload_bar)
	stamina_bar = ProgressBar.new()
	stamina_bar.position = Vector2(12,54)
	stamina_bar.size = Vector2(172,2)
	stamina_bar.show_percentage = false
	_style_bar(stamina_bar)
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_card.add_child(stamina_bar)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(12,42)
	health_bar.size = Vector2(172,4)
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_bar(health_bar,4.0)
	health_card.add_child(health_bar)
	timer_card = card(Rect2(690,24,220,44))
	timer_text = ui._label(timer_card,"",Vector2(8,7),204,20)
	timer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_button = ui._button(self,"",Rect2(1090,30,140,48),func(): ui.game.player.set_third_person(not ui.game.player.third_person),true)
	shoulder_button = ui._button(self,ui.localized("SHOULDER / Q","换肩 / Q"),Rect2(1242,30,166,48),func(): ui.game.player.shoulder *= -1.0,true)
	for index in range(4):
		var selected := index
		var button: Button = ui._button(self,"",Rect2(544+index*130,822,120,44),func(): ui.game.fps.select_weapon(selected),true)
		button.add_theme_font_size_override("font_size",15)
		weapon_buttons.append(button)
	health_fill = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	stamina_fill = stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	score_toggle = Button.new()
	score_toggle.position = left.position+Vector2(0,60)
	score_toggle.size = Vector2(340,40)
	score_toggle.flat = true
	score_toggle.tooltip_text = ui.localized("Scoreboard / TAB","计分板 / TAB")
	add_child(score_toggle)
	score_toggle.pressed.connect(func(): scoreboard_open = not scoreboard_open)
	scoreboard = card(Rect2(490,220,620,350))
	scoreboard_text = ui._label(scoreboard,"",Vector2(28,20),560,25)
	scoreboard_text.size.y = 320
	scoreboard.visible = false
func refresh(delta: float) -> void:
	shoulder_button.visible = ui.game.player.third_person
	var game: Node = ui.game
	var fps: Node3D = game.fps
	visible = fps.active and not ui.modal
	if not visible:
		scoreboard_open = false
		return
	result_panel.visible = fps.round_over and game.net.mode != "solo"
	if result_panel.visible:
		var winners: PackedStringArray = []
		for seat in fps.round_winner_seats: winners.append("P%d" % seat)
		var title: String = ui.localized("DRAW","平局") if winners.size() != 1 else ui.localized("WINNER %s","获胜者 %s") % winners[0]
		result_text.text = title+"\n"+ui.localized("NEXT ROUND IN %ds · READY %d/%d","%d 秒后下一局 · 已准备 %d/%d") % [ceili(fps.round_break),fps.round_ready.size(),fps.health_by_peer.size()]+"\n\n"+ranking_text()
		var own: int = game.multiplayer.get_unique_id()
		ready_button.text = ui.localized("READY","已准备") if fps.round_ready.has(own) else ui.localized("READY / ENTER","准备再战 / 回车")
		ready_button.disabled = fps.round_ready.has(own)
	timer_card.visible = game.net.mode != "solo"
	var mobile: bool = ui.touch_controls_enabled()
	stamina_bar.value = game.player.stamina
	stamina_fill.bg_color = ui.SignalTheme.GOLD if game.player.stamina < 20 else ui.SignalTheme.BLUE
	scoreboard.visible = scoreboard_open or Input.is_physical_key_pressed(KEY_TAB)
	if scoreboard.visible:
		scoreboard_text.text = ranking_text()
	queue_redraw()
	if cached_touch_mode != int(mobile):
		cached_touch_mode = int(mobile)
		static_layout_updates += 1
		health_card.position.y = 558 if mobile else 798
		ammo_card.position.y = 553 if mobile else 798
		for button in weapon_buttons: button.position.y = 822
	health_bar.value = fps.health
	health_fill.bg_color = Color(.6,.6,.6) if fps.health <= 25 else ui.SignalTheme.CYAN
	view_button.text = ui.localized("FIRST / V","第一人称 / V") if game.player.third_person else ui.localized("THIRD / V","第三人称 / V")
	var signature := "%s:%d:%s:%s" % [game.language,fps.selected_weapon,fps.round_over,fps.reload_time > 0]
	if weapon_signature != signature:
		weapon_signature = signature
		weapon_presentation_updates += 1
		for index in range(weapon_buttons.size()):
			var button := weapon_buttons[index]
			var entry: Dictionary = fps.Arsenal.spec(index)
			button.text = "%d  %s" % [index+1,str(entry.zh) if game.language == "zh" else str(entry.label)]
			button.modulate = Color.WHITE
			button.set_selection(index == fps.selected_weapon)
			button.disabled = fps.round_over or fps.reload_time > 0
			button.visible = not fps.round_over
	timer_text.text = ui.localized("LOCAL TRAINING","本地训练") if game.net.mode == "solo" else ui.localized("%02d:%02d · FIRST TO %d","%02d:%02d · %d 杀获胜") % [ceili(fps.round_remaining)/60,ceili(fps.round_remaining)%60,fps.SCORE_LIMIT]
	if game.net.mode != "solo" and not fps.round_over and fps.health_by_peer.size() < 2: timer_text.text = ui.localized("WAITING FOR PLAYER 2","等待第 2 位玩家")
	map_text.text = game.fps_arena.map_title(game.language == "zh")
	var count: int = fps.health_by_peer.size()
	var cap: int = game.net.max_crew
	room_text.text = ui.localized("LOCAL TRAINING","本地训练") if game.net.mode == "solo" else "%s  ·  %d/%d" % [game.rooms.room_code,count,cap]
	if game.net.mode != "solo":
		if fps.round_over: room_text.text = ui.localized("ROUND %d COMPLETE","第 %d 局结束") % fps.round_id
		elif count < 2: room_text.text = "%s · " % game.rooms.room_code+ui.localized("WAITING P2","等待第 2 人")
		else:
			var seconds: int = ceili(fps.round_remaining)
			room_text.text += " · %02d:%02d" % [seconds/60,seconds%60]
	var id: int = game.multiplayer.get_unique_id() if game.net.mode != "solo" else 1
	score_text.text = ui.localized("K %d   /   D %d","击杀 %d   /   死亡 %d") % [int(fps.scores.get(id,0)),int(fps.deaths.get(id,0))]
	if fps.training_enabled: score_text.text = "%02ds  ·  %d HIT  ·  %d%%" % [ceili(fps.training_time),fps.training_hits,fps.training_accuracy()]
	elif fps.training_finished: score_text.text = ui.localized("RESULT %d  ·  BEST %d","成绩 %d  ·  纪录 %d") % [fps.training_hits,fps.training_best]
	health_text.text = str(fps.health)
	health_text.modulate = Color(.75,.75,.75) if fps.health <= 25 else Color.WHITE
	ammo_text.text = "— / ∞" if fps.selected_weapon == 3 else "%d / %d" % [fps.magazine,fps.reserve]
	ammo_text.modulate = Color(.75,.75,.75) if (fps.selected_weapon != 3 and fps.magazine <= maxi(1,ceili(float(fps.weapon_spec().capacity)*.2))) else Color.WHITE
	reload_bar.visible = fps.reload_time > 0
	reload_bar.value = 100.0*(1.0-clampf(fps.reload_time/maxf(.01,float(fps.weapon_spec().reload)),0,1))
	if fps.reload_time > 0: ammo_hint.text = ui.localized("RELOADING %.1fs","装弹中 %.1f 秒") % fps.reload_time
	elif fps.selected_weapon == 3: ammo_hint.text = ui.localized("KNIFE · 2m · MELEE","战术刀 · 2米 · 近战")
	elif fps.magazine == 0: ammo_hint.text = ui.localized("RELOAD / R","请装弹") if fps.reserve > 0 else ui.localized("NO AMMO","弹药耗尽")
	elif (fps.selected_weapon != 3 and fps.magazine <= maxi(1,ceili(float(fps.weapon_spec().capacity)*.2))): ammo_hint.text = ui.localized("LOW AMMO","弹匣将空")
	else: ammo_hint.text = str(fps.weapon_spec().zh) if game.language == "zh" else str(fps.weapon_spec().label)
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

func ranking_text() -> String:
	var game: Node = ui.game
	var fps: Node3D = game.fps
	var rows: PackedStringArray = [ui.localized("RANK   PLAYER     K / D      SCORE","排名   玩家      击杀 / 死亡    得分"),""]
	var ids: Array = fps.health_by_peer.keys()
	ids.sort_custom(func(a: int,b: int):
		if int(fps.scores.get(a,0)) != int(fps.scores.get(b,0)): return int(fps.scores.get(a,0)) > int(fps.scores.get(b,0))
		if int(fps.deaths.get(a,0)) != int(fps.deaths.get(b,0)): return int(fps.deaths.get(a,0)) < int(fps.deaths.get(b,0))
		return int(game.net.seats.get(a,1)) < int(game.net.seats.get(b,1)))
	for index in range(ids.size()):
		var peer_id: int = int(ids[index])
		rows.append("%d.     P%d        %d / %d        %d" % [index+1,int(game.net.seats.get(peer_id,1)),int(fps.scores.get(peer_id,0)),int(fps.deaths.get(peer_id,0)),int(fps.scores.get(peer_id,0))*100])
	return "\n".join(rows)

func _style_bar(bar: ProgressBar, height: float = 2.0) -> void:
	bar.add_theme_font_size_override("font_size",1)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("3a3a3a")
	var fill := StyleBoxFlat.new()
	fill.bg_color = ui.SignalTheme.CYAN
	bar.add_theme_stylebox_override("background",back)
	bar.add_theme_stylebox_override("fill",fill)
	# Initial Control.size was clamped by the default 28px theme minimum.
	bar.set_deferred("size",Vector2(bar.size.x,height))

func _draw() -> void:
	if not is_instance_valid(ui) or not is_instance_valid(ui.game.fps): return
	var fps: Node3D = ui.game.fps
	if not fps.active or ui.modal: return
	var center := Vector2(800,450)
	if fps.selected_weapon == 2 and fps.aiming and not ui.game.player.third_person:
		draw_arc(center,800,0,TAU,128,Color(.006,.009,.012,.97),900,true)
		draw_arc(center,350,0,TAU,128,ui.SignalTheme.CYAN,2,true)
		draw_line(center+Vector2(-350,0),center+Vector2(350,0),Color(.015,.018,.02),1.5,true)
		draw_line(center+Vector2(0,-350),center+Vector2(0,350),Color(.015,.018,.02),1.5,true)
		for step in range(1,6):
			draw_line(center+Vector2(-5,step*30),center+Vector2(5,step*30),Color(.015,.018,.02),1,true)
		draw_circle(center,2,Color.WHITE)
	if not fps.aiming or ui.game.player.third_person:
		var motion: float = Vector2(ui.game.player.velocity.x,ui.game.player.velocity.z).length()
		var gap: float = 5.0+motion*.65+fps.visual_recoil*10
		for axis in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			draw_line(center+axis*(gap-1),center+axis*(gap+7),Color.BLACK,3.5,true)
			draw_line(center+axis*gap,center+axis*(gap+6),Color.WHITE,1.5,true)
	if fps.hit_feedback_time > 0:
		for axis in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
			draw_line(center+axis*7,center+axis*13,Color.WHITE,2,true)
	if fps.damage_feedback_time > 0:
		var alpha: float = .22*fps.damage_feedback_time/.35
		for inset in range(0,30,5):
			draw_rect(Rect2(inset,inset,1600-inset*2,900-inset*2),Color(1,1,1,alpha*(1-float(inset)/30)),false,5)
