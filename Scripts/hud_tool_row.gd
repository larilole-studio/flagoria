class_name HudToolRow
extends Node
## Default touch HUD placement for Direction C (#480, #492).

const GAP := 4.0
const SIDE := 12.0
const LAYOUT := {
	"menu": Vector2(444, 12),
	"mode": Vector2(444, 40),
	"map": Vector2(444, 68),
	"build": Vector2(444, 96),
	"scores": Vector2(116, 12),
	"attack": Vector2(428, 218),
	"run": Vector2(392, 222),
	"weapon": Vector2(406, 186),
	"joystick": Vector2(77, 201),
}

const HIT_INSET := {
	"menu": Vector2(4, 4),
	"mode": Vector2(4, 4),
	"map": Vector2(4, 4),
	"build": Vector2(4, 4),
	"scores": Vector2(4, 4),
	"run": Vector2(2, 2),
	"weapon": Vector2(2, 2),
}


func _process(_delta: float) -> void:
	_layout()


func restore_defaults(layer: Node) -> void:
	_restore_touch_defaults(layer)


func _layout() -> void:
	var layer := get_parent()
	if layer == null:
		return
	var layout := get_node_or_null("/root/HudLayout")
	if layout != null and layout.layout_active():
		layout.apply(layer)
		return
	_restore_touch_defaults(layer)


func _restore_touch_defaults(layer: Node) -> void:
	_place_menu(layer)
	_place_column(layer)
	_place_status(layer)
	_place_combat(layer)
	_place_attack(layer)
	_place_joystick(layer)
	_place_panel(layer)


func _place_menu(layer: Node) -> void:
	var menu := layer.get_node_or_null("InGameMenu") as Control
	if menu == null:
		return
	var button := menu.get_node_or_null("MenuButton") as Button
	if button == null:
		return
	_pin(button)
	RoundHudStyle.apply_menu(button)
	_set_art(button, "menu")
	button.z_index = 2


func _place_column(layer: Node) -> void:
	var mode := layer.get_node_or_null("ModeButton") as Button
	var map_button := layer.get_node_or_null("MinimapButton") as Button
	var buildings := layer.get_node_or_null("BuildingsButton") as Button
	if mode != null:
		_pin(mode)
		_set_art(mode, "mode")
		mode.z_index = 2
	if map_button != null:
		_pin(map_button)
		RoundHudStyle.apply(map_button)
		_set_art(map_button, "map")
		map_button.z_index = 2
	if buildings != null:
		_pin(buildings)
		RoundHudStyle.apply_build(buildings)
		_set_art(buildings, "build")
		buildings.z_index = 2
		_place_buildings(layer, buildings)


func _status_node(layer: Node, node_name: String) -> Node:
	var node := layer.get_node_or_null(node_name)
	if node != null:
		return node
	var plate := layer.get_node_or_null("StatusPlate") as StatusPlateHud
	if plate != null:
		return plate.get_node_or_null(node_name)
	return null


func _place_status(layer: Node) -> void:
	var plate := layer.get_node_or_null("StatusPlate") as StatusPlateHud
	var hearts := _status_node(layer, "HeartsHud") as Control
	var score := _status_node(layer, "ScoreHud") as Label
	var wood := _status_node(layer, "ResourceHud") as ResourceHud
	var scores := layer.get_node_or_null("ScoreboardToggle") as Button
	if plate != null and hearts != null and score != null and wood != null:
		plate.bind_nodes(hearts, score, wood)
	if scores != null:
		_pin(scores)
		RoundHudStyle.apply_scores(scores)
		_set_art(scores, "scores")
		scores.z_index = 2


func _place_combat(layer: Node) -> void:
	var run := layer.get_node_or_null("RunButton") as Button
	var weapon := layer.get_node_or_null("BowButton") as Button
	if run != null:
		_pin(run)
		RoundHudStyle.apply_run(run)
		_set_art(run, "run")
		run.z_index = 2
	if weapon != null:
		_pin(weapon)
		var bow := weapon.button_pressed
		RoundHudStyle.apply_weapon(weapon, bow)
		_set_art(weapon, "weapon")


func _place_attack(layer: Node) -> void:
	var attack := layer.get_node_or_null("TouchScreenButton") as TouchScreenButton
	if attack == null:
		return
	attack.position = LAYOUT["attack"]
	attack.scale = Vector2.ONE
	if attack.shape is CircleShape2D:
		(attack.shape as CircleShape2D).radius = 24.0


func _place_joystick(layer: Node) -> void:
	var stick := layer.get_node_or_null("player_joystick") as Node2D
	if stick != null:
		stick.position = LAYOUT["joystick"]
		stick.scale = Vector2.ONE


func _place_buildings(layer: Node, buildings: Control) -> void:
	var picker := layer.get_node_or_null("BuildPicker") as Control
	if picker == null:
		return
	_pin(picker)
	picker.position = Vector2.ZERO
	picker.z_index = 2
	var top := buildings.position.y + _size_of(buildings).y + GAP
	var x := buildings.position.x
	var y := top
	for child in picker.get_children():
		var button := child as Control
		if button == null or button.is_queued_for_deletion() or not button.visible:
			continue
		_pin(button)
		var size := _size_of(button)
		button.position = Vector2(roundf(x), roundf(y))
		button.z_index = 3
		y += size.y + GAP


func _place_panel(layer: Node) -> void:
	var panel := layer.get_node_or_null("MinimapPanel") as Control
	if panel == null or panel.size.x <= 0.0:
		return
	var view := layer.get_viewport().get_visible_rect().size
	var width := panel.size.x * panel.scale.x
	var height := panel.size.y * panel.scale.y
	var arc_left := view.x
	for node_name in ["ModeButton", "MinimapButton", "BuildingsButton"]:
		arc_left = minf(arc_left, _left_of(layer.get_node_or_null(node_name) as Control))
	var picker := layer.get_node_or_null("BuildPicker") as Control
	if picker != null:
		for child in picker.get_children():
			var column := child as Control
			if column != null and column.visible and not column.is_queued_for_deletion():
				arc_left = minf(arc_left, _left_of(column))
	var right := minf(view.x - MinimapPanel.MARGIN * panel.scale.x, arc_left - GAP)
	var y := maxf(MinimapPanel.TOP * panel.scale.y, SIDE + 24.0)
	var limit := view.y - SIDE
	var attack := layer.get_node_or_null("TouchScreenButton") as TouchScreenButton
	if attack != null and attack.texture_normal != null:
		limit = attack.position.y - GAP
	if y + height > limit:
		y = limit - height
	var x := right - width
	if x < SIDE:
		x = SIDE
	panel.position = Vector2(roundf(x), roundf(y))
	var plate := layer.get_node_or_null("StatusPlate") as Control
	if plate != null and plate.visible and panel.get_global_rect().intersects(plate.get_global_rect()):
		var dropped := plate.get_global_rect().end.y + GAP
		if dropped + height <= limit:
			panel.position.y = roundf(dropped)


func _set_art(control: Control, id: String) -> void:
	if not LAYOUT.has(id):
		return
	var inset: Vector2 = HIT_INSET.get(id, Vector2.ZERO)
	control.position = LAYOUT[id] - inset


func _size_of(control: Control) -> Vector2:
	var need := control.get_combined_minimum_size()
	return Vector2(maxf(control.size.x, need.x), maxf(control.size.y, need.y))


func _left_of(control: Control) -> float:
	if control == null:
		return INF
	var rect := control.get_global_rect()
	if rect.size.x <= 0.0:
		return INF
	return rect.position.x


func place_panel_only(layer: Node) -> void:
	_place_panel(layer)


func _pin(control: Control) -> void:
	if control.has_meta(&"hud_pinned"):
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.set_meta(&"hud_pinned", true)