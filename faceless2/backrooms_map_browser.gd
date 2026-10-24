extends RefCounted
const Catalog = preload("backrooms_map_catalog.gd")
static func build(ui: Control) -> void:
	ui._page(ui.localized("MAP ARCHIVE / FOUR ALLEYS","地图档案 / 四座小巷"),"maps")
	ui._label(ui.panels,ui.localized("SELECT YOUR TRAINING GROUND","选择你的训练地图"),Vector2(76,190),1400,19,ui.MUTED)
	for id in range(4):
		var panel: Panel = ui._card(ui.panels,Rect2(72+id*368,246,350,410),Color(.065,.065,.065))
		panel.name = "MapCard%d" % id
		Catalog.image(panel,id,Rect2(10,10,330,204))
		ui._label(panel,"0%d / %s" % [id+1,Catalog.title(id,ui.game.language == "zh")],Vector2(16,231),318,23).size.y = 44
		ui._label(panel,Catalog.DETAILS_ZH[id] if ui.game.language == "zh" else Catalog.DETAILS[id],Vector2(16,282),318,18,ui.MUTED).size.y = 50
		var select: Button = ui._button(panel,ui.localized("SELECTED","已选择") if id == ui.training_map else ui.localized("SELECT","选择"),Rect2(16,348,318,46),func():ui.training_map = id;ui.open_maps())
		select.name = "Select";select.set_selection(id == ui.training_map)
	ui._button(ui.panels,ui.localized("TRAIN SELECTED MAP   →","进入所选训练地图   →"),Rect2(72,724,560,78),ui.begin_training_map)
	ui._button(ui.panels,ui.localized("FIND A MATCH   →","开始匹配   →"),Rect2(1066,724,460,78),func():ui.open_lobby();ui._quick_match())
	ui._label(ui.panels,ui.localized("Training uses your selection. Online matches reveal the actual host/server map.","训练使用所选地图；在线匹配会揭示房主或服务器实际确定的地图。"),Vector2(76,841),1450,17,ui.MUTED)
