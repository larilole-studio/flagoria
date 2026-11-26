class_name ButtonVariantTheme
extends Theme
## Builds each material from its resource palette and the existing pixel metrics.

const BASE := preload("res://art/ui/main_menu_theme.tres")
const INK := Color("2a2238")
const PAPER := Color("e7d7b1")
const GOLD := Color("f2b632")
const FOCUS := Color(1, 0.882, 0.553)
const STATES := [&"normal", &"hover", &"pressed", &"disabled"]

@export var palette: Dictionary[String, Color]:
	set(value):
		palette = value
		if not palette.is_empty():
			_build()


func map_palette() -> Dictionary:
	return {
		"face": palette["normal"],
		"edge": palette["edge"],
		"highlight": palette["highlight"],
		"shade": palette["pressed"],
		"bevel": palette["edge"],
		"ink": palette["ink"],
	}


func _build() -> void:
	default_font = BASE.default_font
	default_font_size = BASE.default_font_size
	merge_with(BASE)
	var edge := palette["edge"]
	var ink := palette["ink"]
	var accent := palette["highlight"]
	var backdrop := palette["backdrop"]
	var trim: Color = palette.get("trim", accent)

	for state in STATES:
		var face := palette[String(state)]
		var label := palette["disabled_ink"] if state == &"disabled" else ink
		var highlight := trim
		if state == &"hover" and trim != edge:
			highlight = FOCUS
		elif state in [&"pressed", &"disabled"]:
			highlight = edge
		_install_face(&"Button", state, face, edge, highlight, label)
		_install_face(&"KeyCap", state, face, edge, highlight, label)
		_install_face(&"KeyCapOK", state, GOLD, INK, FOCUS, INK)
		_install_face(&"KeyCapDelete", state, INK, edge, accent, PAPER)

	for type in [&"Button", &"KeyCap", &"KeyCapOK", &"KeyCapDelete"]:
		set_color(&"font_focus_color", type, ink)
		set_constant(&"outline_size", type, 0)
	for type in [&"KeyCapOK", &"KeyCapDelete"]:
		set_color(&"font_focus_color", type, INK if type == &"KeyCapOK" else PAPER)
	set_stylebox(&"focus", &"KeyCap", get_stylebox(&"focus", &"Button"))
	set_color(&"font_color", &"TitleLabel", accent)
	set_color(&"font_outline_color", &"TitleLabel", INK)
	set_color(&"font_shadow_color", &"TitleLabel", INK)

	var field := _flat_from(&"normal", &"LineEdit", INK, accent)
	set_stylebox(&"normal", &"LineEdit", field)
	set_stylebox(&"read_only", &"LineEdit", field)
	set_color(&"font_placeholder_color", &"LineEdit", PAPER)
	set_color(&"font_color_selected", &"LineEdit", INK)
	set_color(&"selection_color", &"LineEdit", accent)
	set_stylebox(&"slider", &"HSlider", _flat_from(&"slider", &"HSlider", INK, INK))
	set_stylebox(
		&"grabber_area", &"HSlider", _flat_from(&"grabber_area", &"HSlider", palette["normal"], INK)
	)
	set_stylebox(
		&"grabber_area_highlight",
		&"HSlider",
		_flat_from(&"grabber_area_highlight", &"HSlider", accent, INK)
	)

	var panel := StyleBoxFlat.new()
	panel.bg_color = backdrop
	panel.anti_aliasing = false
	set_stylebox(&"panel", &"PanelContainer", panel)
	set_stylebox(&"panel", &"KeyboardPanel", _flat_from(&"panel", &"KeyboardPanel", backdrop, edge))


func _flat_from(item: StringName, type: StringName, face: Color, edge: Color) -> StyleBoxFlat:
	var box := BASE.get_stylebox(item, type).duplicate() as StyleBoxFlat
	box.bg_color = face
	box.border_color = edge
	return box


func _install_face(
	type: StringName, state: StringName, face: Color, edge: Color, highlight: Color, ink: Color
) -> void:
	var metrics_type := &"Button" if type == &"Button" else &"KeyCap"
	var metrics_state := &"normal" if state == &"disabled" else state
	var box: StyleBox = _flat_from(metrics_state, metrics_type, face, edge)
	if highlight != edge:
		box = _pixel_trim(box, face, edge, highlight)
	set_stylebox(state, type, box)
	var text_item := &"font_color" if state == &"normal" else StringName("font_%s_color" % state)
	set_color(text_item, type, ink)
	if state == &"pressed":
		set_stylebox(&"hover_pressed", type, box)
		set_color(&"font_hover_pressed_color", type, ink)


func _pixel_trim(metrics: StyleBox, face: Color, edge: Color, highlight: Color) -> StyleBoxTexture:
	# Nine-sliced strips preserve the one-pixel material highlight at any width.
	var image := Image.create_empty(5, 7, false, Image.FORMAT_RGBA8)
	image.fill(edge)
	image.fill_rect(Rect2i(1, 1, 3, 3), face)
	image.fill_rect(Rect2i(2, 1, 1, 1), highlight)
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(image)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, metrics.get_margin(side))
		box.set_texture_margin(side, 3 if side == SIDE_BOTTOM else 2)
	return box
