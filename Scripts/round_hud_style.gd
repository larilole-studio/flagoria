class_name RoundHudStyle
extends RefCounted
## Texture-backed Castle Stone HUD controls (Direction C, #480, #492).

const HUD := "res://art/ui/hud_c/"

## Tap target and drawn art sizes (art px).
const HIT := 32.0
const SIZE := 24.0
const RUN_HIT := 36.0
const RUN_SIZE := 32.0
const MENU_HIT := 32.0
const MENU_ART := 24.0

const SKY_DEEP := Color(0.29, 0.56, 0.84, 1.0)

const _MODE := {
	Interaction.Mode.COMBAT: {
		"normal": HUD + "ui_disc_mode_attack_normal.png",
		"pressed": HUD + "ui_disc_mode_attack_pressed.png",
		"disabled": HUD + "ui_disc_mode_attack_disabled.png",
		"selected": HUD + "ui_disc_mode_attack_selected.png",
		"selected_pressed": HUD + "ui_disc_mode_attack_selected_pressed.png",
	},
	Interaction.Mode.INTERACT: {
		"normal": HUD + "ui_disc_mode_interact_normal.png",
		"pressed": HUD + "ui_disc_mode_interact_pressed.png",
		"disabled": HUD + "ui_disc_mode_interact_disabled.png",
		"selected": HUD + "ui_disc_mode_interact_selected.png",
		"selected_pressed": HUD + "ui_disc_mode_interact_selected_pressed.png",
	},
}



static func apply(button: Button, hit: float = HIT, art: float = SIZE, _icon_px: int = 0) -> void:
	## Round 24 px utility disc; `art` and `hit` follow Customize HUD scale.
	_apply_kit(button, _kit("ui_disc_map"), hit, art)


static func apply_build(button: Button, hit: float = HIT, art: float = SIZE) -> void:
	_apply_kit(button, _kit("ui_disc_build"), hit, art)


static func apply_scores(button: Button, hit: float = HIT, art: float = SIZE) -> void:
	_apply_kit(button, _kit("ui_disc_scores", true), hit, art, true)


static func apply_menu(button: Button, hit: float = MENU_HIT, art: float = MENU_ART) -> void:
	_apply_kit(button, _kit("ui_menu"), hit, art)


static func apply_run(button: Button, hit: float = RUN_HIT, art: float = RUN_SIZE) -> void:
	_apply_kit(button, _kit("ui_disc_run"), hit, art)


static func apply_mode(button: Button, mode: int, hit: float = HIT, art: float = SIZE) -> void:
	var kit: Dictionary = _MODE[mode]
	_bind_toggle_art(button, kit, hit, art)
	button.set_meta(&"hud_c_always_selected", true)
	_sync_toggle_styles(button)


static func apply_weapon(button: Button, bow_equipped: bool, hit: float = RUN_HIT, art: float = RUN_SIZE) -> void:
	_bind_toggle_art(button, _kit("ui_disc_weapon_bow" if bow_equipped else "ui_disc_weapon_sword", true), hit, art)
	button.set_meta(&"hud_c_always_selected", true)
	_sync_toggle_styles(button)


static func refresh_toggle(button: Button) -> void:
	if button.has_meta(&"hud_c_kit"):
		_sync_toggle_styles(button)


static func _apply_kit(
		button: Button,
		kit: Dictionary,
		hit: float,
		art: float,
		toggle := false,
) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.icon = null
	button.text = ""
	button.expand_icon = false
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.remove_theme_constant_override("icon_max_width")
	button.set_meta(&"hud_c_kit", kit.duplicate())
	button.set_meta(&"hud_c_hit", hit)
	button.set_meta(&"hud_c_art", art)
	button.set_meta(&"hud_c_toggle", toggle)
	if toggle:
		_wire_toggle(button)
		_sync_toggle_styles(button)
	else:
		for state in ["normal", "hover", "hover_pressed", "pressed", "disabled", "focus"]:
			var key := "disabled" if state == "disabled" else ("pressed" if state in ["pressed", "hover_pressed"] else "normal")
			button.add_theme_stylebox_override(state, _pick_box(kit, hit, art, key))
		button.add_theme_stylebox_override("hover", button.get_theme_stylebox("normal"))
	button.custom_minimum_size = Vector2(hit, hit)
	button.reset_size()


static func _bind_toggle_art(button: Button, kit: Dictionary, hit: float, art: float) -> void:
	_apply_kit(button, kit, hit, art, true)


static func _wire_toggle(button: Button) -> void:
	if button.has_meta(&"hud_c_wired"):
		return
	button.set_meta(&"hud_c_wired", true)
	button.button_down.connect(func() -> void: _sync_toggle_styles(button))
	button.button_up.connect(func() -> void: _sync_toggle_styles(button))
	button.toggled.connect(func(_on: bool) -> void: _sync_toggle_styles(button))


static func _sync_toggle_styles(button: Button) -> void:
	if not button.has_meta(&"hud_c_kit"):
		return
	var kit: Dictionary = button.get_meta(&"hud_c_kit")
	var hit: float = button.get_meta(&"hud_c_hit")
	var art: float = button.get_meta(&"hud_c_art")
	if button.disabled:
		var dim := _pick_box(kit, hit, art, "disabled")
		button.add_theme_stylebox_override("normal", dim)
		button.add_theme_stylebox_override("pressed", dim)
		button.add_theme_stylebox_override("hover_pressed", dim)
		return
	var always: bool = button.get_meta(&"hud_c_always_selected") if button.has_meta(&"hud_c_always_selected") else false
	var on := button.button_pressed or always
	if on and kit.has("selected"):
		button.add_theme_stylebox_override("normal", _pick_box(kit, hit, art, "selected"))
		button.add_theme_stylebox_override("pressed", _pick_box(kit, hit, art, "selected"))
		var active := "selected_pressed" if kit.has("selected_pressed") else "selected"
		button.add_theme_stylebox_override("hover_pressed", _pick_box(kit, hit, art, active))
	else:
		button.add_theme_stylebox_override("normal", _pick_box(kit, hit, art, "normal"))
		button.add_theme_stylebox_override("pressed", _pick_box(kit, hit, art, "pressed"))
		button.add_theme_stylebox_override("hover_pressed", _pick_box(kit, hit, art, "pressed"))
	button.add_theme_stylebox_override("hover", button.get_theme_stylebox("normal"))
	button.add_theme_stylebox_override("disabled", _pick_box(kit, hit, art, "disabled"))


static func _pick_box(kit: Dictionary, hit: float, art: float, key: String) -> StyleBoxTexture:
	return _texture_box(str(kit.get(key, kit["normal"])), hit, art)


static func _texture_box(path: String, hit: float, art: float) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(path) as Texture2D
	var inset := (hit - art) * 0.5
	box.set_expand_margin_all(-inset)
	box.texture_margin_left = 0
	box.texture_margin_top = 0
	box.texture_margin_right = 0
	box.texture_margin_bottom = 0
	return box


static func _kit(prefix: String, with_selected := false) -> Dictionary:
	var out := {
		"normal": HUD + prefix + "_normal.png",
		"pressed": HUD + prefix + "_pressed.png",
		"disabled": HUD + prefix + "_disabled.png",
	}
	if with_selected:
		out["selected"] = HUD + prefix + "_selected.png"
		out["selected_pressed"] = HUD + prefix + "_selected_pressed.png"
	return out


static func status_plate_style() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(HUD + "ui_status_plate.png") as Texture2D
	box.texture_margin_left = 6
	box.texture_margin_top = 6
	box.texture_margin_right = 6
	box.texture_margin_bottom = 6
	return box