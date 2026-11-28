class_name RoundHudStyle
extends RefCounted
## Disc textures and typography for the in-game HUD.

const HUD := "res://art/ui/hud_e4/"
const DENSITY := 4
const FILTER := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
const HIT := 32.0
const SIZE := 24.0
const RUN_HIT := 36.0
const RUN_SIZE := 32.0
const MENU_HIT := 32.0
const MENU_ART := 24.0

const _FONT_PATH := "res://art/ui/fonts/LilitaOne-Regular.ttf"
const _PLUM := Color("#3B1748")
const _WHEEL: PackedStringArray = ["wheel_sword", "wheel_bomb", "wheel_chop"]
static var _textures: Dictionary[String, Texture2D] = {}
static var _labels: Dictionary[int, LabelSettings] = {}


static func texture_directory() -> String:
	return HUD


static func button_filter() -> CanvasItem.TextureFilter:
	return FILTER


static func texture(sprite: String) -> Texture2D:
	var path := HUD + sprite + ".png"
	if not _textures.has(path):
		var image := (load(path) as Texture2D).get_image()
		if not image.has_mipmaps():
			image.generate_mipmaps()
		var art := ImageTexture.create_from_image(image)
		art.set_size_override(image.get_size() / DENSITY)
		_textures[path] = art
	return _textures[path]


static func apply_label(label: Label, size_px: int) -> void:
	if not _labels.has(size_px):
		var settings := LabelSettings.new()
		settings.font = load(_FONT_PATH) as FontFile
		settings.font_size = size_px
		settings.font_color = Color.WHITE
		settings.outline_size = 2
		settings.outline_color = _PLUM
		settings.shadow_color = _PLUM
		settings.shadow_size = 2
		settings.shadow_offset = Vector2(0, 1)
		_labels[size_px] = settings
	label.label_settings = _labels[size_px]
	label.texture_filter = FILTER


static func apply_joystick(stick: Node2D) -> void:
	stick.texture_filter = button_filter()
	stick.border_disabled = texture("joystick_base_disabled")
	stick.stick_active = texture("joystick_knob_active")
	stick.stick_disabled = texture("joystick_knob_disabled")
	stick.border = texture("joystick_base_normal")
	stick.stick = texture("joystick_knob_normal")


static func apply_attack(button: TouchScreenButton) -> void:
	button.texture_filter = button_filter()
	button.texture_idle = texture("attack_idle")
	button.texture_down = texture("attack_pressed")
	button.texture_aim = texture("attack_aim")
	button.texture_disabled = texture("attack_disabled")
	button.show_touch_state(AttackAim.TOUCH_IDLE)


static func apply(button: Button, hit: float = HIT, art: float = SIZE) -> void:
	apply_disc(button, "map", hit, art, true)


static func apply_build(button: Button, hit: float = HIT, art: float = SIZE) -> void:
	apply_disc(button, "build", hit, art, true)


static func apply_menu(button: Button, hit: float = MENU_HIT, art: float = MENU_ART) -> void:
	apply_disc(button, "menu", hit, art)


static func apply_run(button: Button, hit: float = RUN_HIT, art: float = RUN_SIZE) -> void:
	apply_disc(button, "run", hit, art)


static func apply_wheel(button: Button, tool: int, hit: float = HIT, art: float = SIZE) -> void:
	apply_disc(button, _WHEEL[tool] if tool < _WHEEL.size() else "wheel_command", hit, art, true)


static func apply_disc(
	button: Button,
	prefix: String,
	hit: float = HIT,
	art: float = SIZE,
	has_selected_states := false
) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.icon = null
	button.text = ""
	button.texture_filter = button_filter()
	var normal := _box(prefix + "_normal", hit, art)
	var pressed := _box(prefix + "_pressed", hit, art)
	var disabled := _box(prefix + "_disabled", hit, art)
	var boxes := {"normal": normal, "pressed": pressed, "disabled": disabled}
	if has_selected_states:
		boxes["selected"] = _box(prefix + "_selected", hit, art)
		boxes["selected_pressed"] = _box(prefix + "_selected_pressed", hit, art)
		if not button.has_meta(&"hud_e4_boxes"):
			button.toggled.connect(func(_on: bool) -> void: refresh_toggle(button))
	button.set_meta(&"hud_e4_boxes", boxes)
	refresh_toggle(button)
	button.custom_minimum_size = Vector2(hit, hit)
	button.reset_size()


static func refresh_toggle(button: Button, highlighted := false) -> void:
	if not button.has_meta(&"hud_e4_boxes"):
		return
	var boxes: Dictionary = button.get_meta(&"hud_e4_boxes")
	var selected := (button.button_pressed or highlighted) and boxes.has("selected")
	var face: StyleBoxTexture = boxes["selected" if selected else "normal"]
	button.add_theme_stylebox_override("normal", face)
	button.add_theme_stylebox_override("hover", face)
	button.add_theme_stylebox_override(
		"pressed", face if selected and button.toggle_mode else boxes["pressed"]
	)
	button.add_theme_stylebox_override(
		"hover_pressed", boxes["selected_pressed" if selected else "pressed"]
	)
	button.add_theme_stylebox_override("disabled", boxes["disabled"])


static func _box(sprite: String, hit: float, art: float) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = (
		_command_texture(sprite) if sprite.begins_with("wheel_command_") else texture(sprite)
	)
	box.set_expand_margin_all((art - hit) * 0.5)
	return box


static func _command_texture(sprite: String) -> Texture2D:
	if _textures.has(sprite):
		return _textures[sprite]
	var face := "#adb88d" if "selected" in sprite else "#86996e"
	if sprite.ends_with("pressed"):
		face = "#72865c"
	var svg := (
		"""<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24">
	<circle cx="12" cy="12" r="11" fill="#403b33"/>
	<circle cx="12" cy="11.5" r="9.5" fill="%s" stroke="#cdd0ac" stroke-width=".6"/>
	<path d="M8 17.5v-12m.5 1h7l-1.8 2 1.8 2h-7" fill="#f3e7c7"
	stroke="#403b33" stroke-width="1.1" stroke-linejoin="round" stroke-linecap="round"/>
	<path d="M6.5 17.5h7" stroke="#403b33" stroke-width="1.1" stroke-linecap="round"/>
	</svg>"""
		% face
	)
	var image := Image.new()
	image.load_svg_from_string(svg)
	image.generate_mipmaps()
	var icon := ImageTexture.create_from_image(image)
	_textures[sprite] = icon
	return icon
