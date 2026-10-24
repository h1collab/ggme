extends RefCounted
# Covers are illustrations; map IDs and names are also used by actual arenas.
const NAMES := ["NULL ALLEY","STATIC PASSAGE","FRACTURE ROW","ERROR CROSSING"]
const NAMES_ZH := ["空值小巷","杂讯窄街","断裂后巷","错误路口"]
const FILES := ["s1_keyart","static_passage","fracture_row","error_crossing"]
const DETAILS := ["VOID / CENTRAL ALLEY","SKYBRIDGES / STATIC","SPLIT SKYLINE / RIFT","GATEWAYS / CROSSROADS"]
const DETAILS_ZH := ["虚无 / 中央小巷","天桥 / 杂讯","断裂天际线 / 裂缝","门架 / 十字街口"]
static var cached: Dictionary = {}
static func title(id: int, chinese: bool = false) -> String:
	return NAMES_ZH[clampi(id,0,3)] if chinese else NAMES[clampi(id,0,3)]
static func texture(id: int) -> Texture2D:
	var key: String = FILES[clampi(id,0,3)]
	if not cached.has(key):
		var base := "res://ui/art/" if ResourceLoader.exists("res://ui/art/"+key+".webp") else "res://faceless2/ui_art/"
		cached[key] = load(base+key+".webp")
	return cached[key] as Texture2D
static func image(parent: Node, id: int, rect: Rect2, portrait: bool = false) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.position = rect.position;image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = texture(id)
	if portrait:
		var atlas := AtlasTexture.new();atlas.atlas = image.texture
		var extent: Vector2 = image.texture.get_size()
		atlas.region = Rect2(extent.x*.57,0,extent.x*.43,extent.y)
		image.texture = atlas
	parent.add_child(image)
	return image
