extends RefCounted
const Catalog = preload("backrooms_map_catalog.gd")
static func build(ui: Control) -> void:
	ui.game.fps_arena.build()
	ui._page(ui.localized("MAP ARCHIVE / SIX ARENAS","地图档案 / 六座战场"),"maps")
	ui._label(ui.panels,ui.localized("ILLUSTRATION + ACTUAL GROUND PLAN / SELECT A TRAINING MAP","封面 + 实际路线 / 选择训练地图"),Vector2(76,185),1400,17,ui.MUTED).size.y = 30
	for id in range(Catalog.COUNT):
		var x: float = 72+(id%3)*488
		var y: float = 228+(id/3)*276
		var panel: Panel = ui._card(ui.panels,Rect2(x,y,468,258),Color(.065,.065,.065))
		panel.name = "MapCard%d" % id
		Catalog.image(panel,id,Rect2(10,10,304,152))
		var plan := preload("backrooms_map_plan.gd").new()
		plan.arena = ui.game.fps_arena;plan.map_id = id;plan.position = Vector2(330,10);plan.size = Vector2(128,152);panel.add_child(plan)
		ui._label(panel,"0%d / %s" % [id+1,Catalog.title(id,ui.game.language == "zh")],Vector2(14,174),302,21).size.y = 32
		ui._label(panel,Catalog.DETAILS_ZH[id] if ui.game.language == "zh" else Catalog.DETAILS[id],Vector2(14,216),302,14,ui.MUTED).size.y = 30
		var select: Button = ui._button(panel,ui.localized("SELECTED","已选择") if id == ui.training_map else ui.localized("SELECT","选择"),Rect2(330,176,128,62),func():ui.training_map = id;ui.open_maps())
		select.name = "Select";select.add_theme_font_size_override("font_size",17);select.size = Vector2(128,62);select.set_selection(id == ui.training_map)
	ui._button(ui.panels,ui.localized("TRAIN SELECTED MAP   →","进入所选训练地图   →"),Rect2(72,784,560,56),ui.begin_training_map)
	ui._button(ui.panels,ui.localized("FIND A MATCH   →","开始匹配   →"),Rect2(1066,784,460,56),func():ui.open_lobby();ui._quick_match())
	ui._label(ui.panels,ui.localized("White blocks: actual obstacles. Dots: spawn seats. Online matches use the host/server map.","白块为实际障碍，圆点为出生位；在线对局使用房主或服务器确定的地图。"),Vector2(76,858),1450,15,ui.MUTED).size.y = 28
