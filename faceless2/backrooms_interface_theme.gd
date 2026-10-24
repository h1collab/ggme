extends RefCounted
# FACELESS / MONO: shared grayscale contrast for menus and combat controls.
const INK := Color("080808")
const SURFACE := Color("161616")
const BLUE := Color("333333")
const CYAN := Color("eeeeee")
const GOLD := Color("ffffff")
const WHITE := Color.WHITE
const LOCKED := Color("aaaaaa")
static func plate(color: Color = SURFACE, edge: Color = Color(.3,.3,.3)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = edge
	box.set_border_width_all(1)
	box.border_width_left = 1
	box.set_corner_radius_all(0)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box
static func install(target: Theme) -> void:
	for kind in ["Button","OptionButton","CheckBox","CheckButton","MenuButton","LineEdit","SpinBox","Label","PopupMenu","TabContainer","Tree","ItemList"]:
		for key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_selected_color"]:
			target.set_color(key,kind,WHITE)
		target.set_color("font_disabled_color",kind,LOCKED)
		target.set_color("font_uneditable_color",kind,CYAN)
		target.set_color("font_placeholder_color",kind,CYAN)
		if kind == "Label": continue # Text stays unboxed; cards own their backgrounds.
		for state in ["normal","panel","read_only"]: target.set_stylebox(state,kind,plate())
		for state in ["hover","hover_pressed"]: target.set_stylebox(state,kind,plate(BLUE,CYAN))
		target.set_stylebox("pressed",kind,plate(Color("444444"),GOLD))
		target.set_stylebox("disabled",kind,plate(INK,Color("444444")))
		var focus := plate(Color(0,0,0,0),GOLD)
		focus.set_border_width_all(2)
		target.set_stylebox("focus",kind,focus)
	target.set_color("caret_color","LineEdit",GOLD)
	target.set_color("selection_color","LineEdit",BLUE)
	for kind in ["HSlider","VSlider","HScrollBar","VScrollBar"]:
		for key in ["slider","scroll"]: target.set_stylebox(key,kind,plate(INK,BLUE))
		for key in ["grabber_area","grabber_area_highlight","grabber","grabber_highlight"]: target.set_stylebox(key,kind,plate(CYAN,CYAN))

	# Original vector marks replace built-in check/dropdown/slider textures.
	var chevron := vector_icon('<path d="M5 8 L12 15 L19 8"/>')
	var checked := vector_icon('<rect x="3" y="3" width="18" height="18"/><path d="M6 12 L10 16 L18 7"/>')
	var unchecked := vector_icon('<rect x="3" y="3" width="18" height="18"/>')
	var diamond := vector_icon('<path d="M12 2 L22 12 L12 22 L2 12 Z"/>')
	target.set_icon("updown","SpinBox",vector_icon('<path d="M6 8 L12 3 L18 8 M6 16 L12 21 L18 16"/>'))
	for kind in ["OptionButton","MenuButton"]: target.set_icon("arrow",kind,chevron)
	for kind in ["CheckBox","CheckButton"]:
		for key in ["checked","checked_disabled","radio_checked","radio_checked_disabled"]: target.set_icon(key,kind,checked)
		for key in ["unchecked","unchecked_disabled","radio_unchecked","radio_unchecked_disabled"]: target.set_icon(key,kind,unchecked)
	for kind in ["HSlider","VSlider"]:
		for key in ["grabber","grabber_highlight","grabber_disabled"]: target.set_icon(key,kind,diamond)
static func vector_icon(paths: String) -> Texture2D:
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#eeeeee" stroke-width="2" stroke-linecap="square">'+paths+'</g></svg>')
	return ImageTexture.create_from_image(image)
