extends RefCounted
# Repository-native party lobby: central avatar, side navigation, bottom actions.
static func avatar(ui: Control, rect: Rect2) -> void:
	var holder := SubViewportContainer.new()
	holder.position = rect.position
	holder.size = rect.size
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.panels.add_child(holder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(rect.size)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	holder.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var actor := preload("backrooms_combat_actor.gd").new()
	world.add_child(actor)
	actor.configure(1)
	actor.rotation.y = PI-.3
	actor.update_combat(0,false,0,0,0)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,1.12,3.5)
	camera.look_at(Vector3(0,.95,0))
	camera.fov = 36
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30,-35,0)
	world.add_child(light)
	var ambient := WorldEnvironment.new()
	ambient.environment = Environment.new()
	ambient.environment.background_mode = Environment.BG_CLEAR_COLOR
	ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambient.environment.ambient_light_color = Color.WHITE
	ambient.environment.ambient_light_energy = .75
	world.add_child(ambient)
	ui.settle_avatar.call_deferred(viewport)
static func lobby(ui: Control) -> void:
	ui._signal_art()
	var season = ui.game.season
	ui._label(ui.panels,"NULRYTH",Vector2(58,34),260,32)
	preload("backrooms_developer_brand.gd").badge(ui.panels,Vector2(340,38),36)
	ui._label(ui.panels,"S1  /  FIRST SIGNAL",Vector2(1080,42),450,24)
	ui._label(ui.panels,ui.localized("PLAYER 01","玩家 01"),Vector2(62,136),340,30)
	ui._label(ui.panels,"LV.%02d   /   45" % season.level(),Vector2(62,184),320,22)
	ui._label(ui.panels,ui.localized("SEASON JOURNAL","赛季手册"),Vector2(62,256),320,18,ui.MUTED)
	ui._button(ui.panels,ui.localized("S1 MANUAL   →","S1 手册   →"),Rect2(62,292,300,78),ui.open_season)
	ui._button(ui.panels,ui.localized("COLLECTION","收藏"),Rect2(62,386,300,66),ui.open_collection)
	ui._button(ui.panels,ui.localized("CONTROLS","操作指南"),Rect2(62,470,300,66),ui.open_guide)
	ui._button(ui.panels,ui.localized("SETTINGS","设置"),Rect2(62,554,300,66),ui.open_settings)
	avatar(ui,Rect2(436,142,640,560))
	ui._label(ui.panels,ui.localized("YOUR NEXT ENCOUNTER","下一次交锋"),Vector2(1120,224),380,24)
	ui._label(ui.panels,ui.localized("4 ALLEYS\n6 PLAYERS\n2 TO START","4 张小巷地图\n6 人房间\n2 人开局"),Vector2(1120,284),390,22,ui.MUTED)
	ui._button(ui.panels,ui.localized("FREE / PAID\n45 LEVELS","免费 / 付费\n45 级奖励"),Rect2(1120,472,390,116),ui.open_season)
	ui._label(ui.panels,ui.localized("BLACK / WHITE / VOID","黑 / 白 / 虚无"),Vector2(590,688),560,20,ui.MUTED)
	ui._button(ui.panels,ui.localized("LOCAL TRAINING","本地训练"),Rect2(62,758,350,90),func(): ui.game.net.leave(); ui.game.start_fps_arena())
	ui._button(ui.panels,ui.localized("ROOMS","房间"),Rect2(432,758,300,90),ui.open_lobby)
	var play: Button = ui._button(ui.panels,ui.localized("FIND A MATCH   →","开始匹配   →"),Rect2(1060,748,450,100),func(): ui.open_lobby(); ui._quick_match())
	play.primary = true
static func manual(ui: Control, page: int) -> void:
	var season = ui.game.season
	ui._page(ui.localized("S1 / SEASON MANUAL","S1 / 赛季手册"),"season")
	ui._label(ui.panels,"FIRST SIGNAL",Vector2(76,190),600,20,ui.MUTED)
	ui._label(ui.panels,"LV.%02d / 45" % season.level(),Vector2(1036,188),260,24)
	var xp: Label = ui._label(ui.panels,"%d / 100 XP" % season.level_xp(),Vector2(1296,194),216,18,ui.MUTED)
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bar := ProgressBar.new();bar.position = Vector2(1036,232);bar.size = Vector2(476,4);bar.show_percentage = false;bar.value = season.level_xp()
	var back := StyleBoxFlat.new();back.bg_color = Color(.18,.18,.18)
	var fill := StyleBoxFlat.new();fill.bg_color = Color(.88,.88,.88)
	bar.add_theme_stylebox_override("background",back);bar.add_theme_stylebox_override("fill",fill);bar.add_theme_font_size_override("font_size",1)
	ui.panels.add_child(bar);bar.set_deferred("size",Vector2(476,4))
	ui._label(ui.panels,"FREE",Vector2(78,346),170,28)
	ui._label(ui.panels,ui.localized("EARN / CLAIM","升级 / 领取"),Vector2(78,390),170,16,ui.MUTED)
	ui._label(ui.panels,"PAID",Vector2(78,554),170,28)
	ui._label(ui.panels,ui.localized("PREVIEW","奖励预览"),Vector2(78,598),170,16,ui.MUTED)
	for column in range(5):
		var tier: int = page*5+column+1
		var x: float = 284+column*246
		var number: Label = ui._label(ui.panels,"%02d" % tier,Vector2(x+12,264),202,24)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for row in range(2):
			var paid := row == 1
			var y := 310.0+row*208
			var entry: Dictionary = season.reward(tier,paid)
			var status: String = season.state(tier,paid)
			var panel: Panel = ui._card(ui.panels,Rect2(x,y,226,186),Color(.065,.065,.065))
			panel.name = "Tier%02d%s" % [tier,"Paid" if paid else "Free"]
			var title: String = str(entry.zh) if ui.game.language == "zh" else str(entry.name)
			var name: Label = ui._label(panel,title,Vector2(12,22),202,17)
			name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;name.size.y = 44
			var detail: String = "× %d" % int(entry.amount) if entry.kind == "tokens" else ui.localized("BADGE" if entry.kind == "badge" else "TITLE","徽章" if entry.kind == "badge" else "称号")
			var quantity: Label = ui._label(panel,detail,Vector2(12,74),202,24,Color(.8,.8,.8))
			quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;quantity.size.y = 38
			var state_name: String = {"AVAILABLE":ui.localized("CLAIM","领取"),"CLAIMED":ui.localized("CLAIMED","已领取"),"LEVEL_LOCKED":"LV.%02d" % tier,"PAID_LOCKED":ui.localized("LOCKED","未解锁")}[status]
			var action: Button = ui._button(panel,state_name,Rect2(12,126,202,46),func():ui.claim_season(tier,paid))
			action.name = "Claim";action.add_theme_font_size_override("font_size",17)
			action.disabled = status != "AVAILABLE";action.set_selection(status == "AVAILABLE")
	ui._button(ui.panels,"←",Rect2(284,750,80,60),func():ui.season_page = maxi(0,page-1);ui.open_season())
	var range_text: Label = ui._label(ui.panels,"%02d — %02d / 45" % [page*5+1,page*5+5],Vector2(384,764),430,23)
	range_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui._button(ui.panels,"→",Rect2(826,750,80,60),func():ui.season_page = mini(8,page+1);ui.open_season())
	ui._label(ui.panels,ui.localized("PAID / PURCHASE NOT OPEN","PAID / 暂未开放购买"),Vector2(960,768),560,18,ui.MUTED)
	ui._label(ui.panels,ui.localized("Complete rounds or target drills for XP. Cosmetic rewards only.","完成对局或靶场挑战获取经验，奖励均为装饰。"),Vector2(78,841),1400,17,ui.MUTED)
