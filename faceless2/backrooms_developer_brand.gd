extends RefCounted
# Reuse the repository's original ZOrix mark; grayscale is display-only.
static func logo(parent: Node, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.name = "ZOrixLogo"
	image.position = rect.position
	image.size = rect.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://ui/team_logo.jpg" if ResourceLoader.exists("res://ui/team_logo.jpg") else "res://faceless2/branding/team_logo.jpg"
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = Rect2(290,298,766,766)
	image.texture = atlas
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){ vec4 c=texture(TEXTURE,UV); float y=dot(c.rgb,vec3(0.299,0.587,0.114)); COLOR=vec4(vec3(y),c.a)*tint; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	image.material = material
	parent.add_child(image)
	return image
static func badge(parent: Node, at: Vector2, extent: float = 36.0) -> void:
	logo(parent,Rect2(at,Vector2.ONE*extent))
	var label := Label.new()
	label.name = "DeveloperCredit"
	label.text = "Developed by ZOrix"
	label.position = at+Vector2(extent+14,5)
	label.size = Vector2(360,30)
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color(.7,.7,.7))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
