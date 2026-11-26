class_name ButtonStyle
extends RefCounted
## Session-wide button style for menu and parchment controls.

const SELECTED := "current"
const ENV := "FLAGORIA_BUTTON_STYLE"
const CURRENT := preload("res://art/ui/main_menu_theme.tres")
const VARIANTS := {
	"wood": "res://art/ui/themes/button_wood.tres",
	"parchment": "res://art/ui/themes/button_parchment.tres",
	"stone": "res://art/ui/themes/button_stone.tres",
	"pixel": "res://art/ui/themes/button_pixel.tres",
	"banner": "res://art/ui/themes/button_banner.tres",
}
const CURRENT_MAP := {
	"face": Color("e0a96b"),
	"edge": Color("74452a"),
	"highlight": Color("ffe680"),
	"shade": Color("b06f3c"),
	"ink": Color("2a2238"),
}


static func selected_theme() -> Theme:
	var style := OS.get_environment(ENV)
	if style.is_empty():
		style = SELECTED
	var path: String = VARIANTS.get(style, "")
	return CURRENT if path.is_empty() else load(path)


static func apply(control: Control) -> void:
	var theme := selected_theme()
	if theme != CURRENT:
		control.theme = theme


static func map_palette() -> Dictionary:
	var theme := selected_theme() as ButtonVariantTheme
	return theme.map_palette() if theme else CURRENT_MAP.duplicate()
