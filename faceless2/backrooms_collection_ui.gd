extends RefCounted
static func build(ui: Control) -> void:
	ui._page(ui.localized("S1 / COLLECTION","S1 / 收藏"),"collection")
	var banner: Panel = ui._card(ui.panels,Rect2(72,216,1454,250),Color(.04,.04,.04))
	preload("backrooms_map_catalog.gd").illustration(banner,"relic_banner",Rect2(1,1,1452,248))
	ui._label(banner,ui.localized("SIGNAL TOKENS","信号徽记"),Vector2(26,34),600,22)
	ui._label(banner,str(ui.game.season.tokens),Vector2(26,79),550,54)
	ui._label(banner,ui.localized("YOUR SEASON ARCHIVE","你的赛季收藏"),Vector2(28,188),650,18,ui.MUTED)
	var preview: Panel = ui._card(ui.panels,Rect2(72,488,350,326),Color(.06,.06,.06))
	ui._label(preview,ui.localized("PLAYER / MODEL PREVIEW","玩家 / 模型预览"),Vector2(18,12),314,16,ui.MUTED).size.y = 28
	preload("backrooms_season_ui.gd").avatar(ui,Rect2(96,526,302,270))
	ui._card(ui.panels,Rect2(450,488,1076,326),Color(.055,.055,.055))
	ui._label(ui.panels,ui.localized("EARNED BADGES & TITLES","已获得的徽章与称号"),Vector2(476,506),970,22).size.y = 38
	var scroll := ScrollContainer.new();scroll.position = Vector2(476,554);scroll.size = Vector2(1016,176);ui.panels.add_child(scroll)
	var list := VBoxContainer.new();list.custom_minimum_size.x = 980;list.add_theme_constant_override("separation",8);scroll.add_child(list)
	if ui.game.season.collection.is_empty():
		var empty := Label.new();empty.text = ui.localized("Your collection starts with the S1 manual.\nReach levels and claim FREE rewards.","从 S1 手册开始你的收藏。\n提升等级并领取免费奖励。");empty.add_theme_font_size_override("font_size",22);list.add_child(empty)
	else:
		for entry in ui.game.season.collection:
			var label := Label.new();label.text = "◇   "+str(entry);label.custom_minimum_size = Vector2(960,46);label.add_theme_font_size_override("font_size",22);list.add_child(label)
	ui._button(ui.panels,ui.localized("OPEN S1 MANUAL   →","打开 S1 手册   →"),Rect2(1100,746,400,52),ui.open_season)
