class_name HudToolRow
extends Node
## Direction C touch HUD: top-right column, status plate, tool wheel (#480, #492, #574).
##
## Map and Buildings stack in the top-right column. Customize HUD can move every
## control including the wheel (#575). Layout runs on viewport and visibility
## changes, not every frame. A headless dedicated host builds no wheel.

const ToolWheelScript := preload("res://Scripts/tool_wheel.gd")

const CANVAS_SIZE := Vector2(480, 270)
const GAP := 4.0
const WHEEL_GAP := 2.0
const SIDE := 12.0
const LAYOUT := {
	"menu": Vector2(444, 12),
	"map": Vector2(444, 52),
	"build": Vector2(444, 88),
	"scores": Vector2(116, 12),
	"attack": Vector2(428, 218),
	"run": Vector2(390, 222),
	"joystick": Vector2(77, 201),
}

const HIT_INSET := {
	"menu": Vector2(4, 4),
	"map": Vector2(4, 4),
	"build": Vector2(4, 4),
	"scores": Vector2(4, 4),
	"run": Vector2(2, 2),
}


func _ready() -> void:
	if ToolWheelScript.headless_host():
		set_process(false)
		call_deferred("_bind_relayout")
		return
	call_deferred("_add_wheel")
	call_deferred("_bind_relayout")


func _add_wheel() -> void:
	var layer := get_parent()
	if layer == null or layer.get_node_or_null("ToolWheel") != null:
		return
	var wheel := ToolWheelScript.new()
	wheel.name = "ToolWheel"
	layer.add_child(wheel)
	_layout()


func _bind_relayout() -> void:
	var layer := get_parent()
	if layer == null:
		return
	_layout()
	for node_name in ["BuildingsButton", "MinimapButton"]:
		var btn := layer.get_node_or_null(node_name) as BaseButton
		if btn != null and not btn.toggled.is_connected(_on_relayout):
			btn.toggled.connect(_on_relayout)
	var picker := layer.get_node_or_null("BuildPicker") as CanvasItem
	if picker != null and not picker.visibility_changed.is_connected(_on_relayout):
		picker.visibility_changed.connect(_on_relayout)
	for node_name in ["MinimapPanel", "ScoreboardPanel"]:
		var panel := layer.get_node_or_null(node_name) as CanvasItem
		if panel != null and not panel.visibility_changed.is_connected(_on_relayout):
			panel.visibility_changed.connect(_on_relayout)
	if not get_viewport().size_changed.is_connected(_on_relayout):
		get_viewport().size_changed.connect(_on_relayout)


func _on_relayout(_on: Variant = null) -> void:
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
	_place_tool(layer)
	_place_buildings(layer)
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
	var map_button := layer.get_node_or_null("MinimapButton") as Button
	var buildings := layer.get_node_or_null("BuildingsButton") as Button
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


static func hud_child(layer: Node, node_name: String) -> Node:
	return status_node(layer, node_name)


static func status_node(layer: Node, node_name: String) -> Node:
	var node := layer.get_node_or_null(node_name)
	if node != null:
		return node
	var plate := layer.get_node_or_null("StatusPlate") as StatusPlateHud
	if plate != null:
		return plate.get_node_or_null(node_name)
	return null


func _place_status(layer: Node) -> void:
	var plate := layer.get_node_or_null("StatusPlate") as StatusPlateHud
	var hearts := status_node(layer, "HeartsHud") as Control
	var score := status_node(layer, "ScoreHud") as Label
	var wood := status_node(layer, "ResourceHud") as ResourceHud
	var scores := layer.get_node_or_null("ScoreboardToggle") as Button
	if plate != null and hearts != null and score != null and wood != null:
		var on_plate := hearts.get_parent() == plate and score.get_parent() == plate and wood.get_parent() == plate
		if not on_plate:
			plate.bind_nodes(hearts, score, wood)
	if scores != null:
		_pin(scores)
		RoundHudStyle.apply_scores(scores)
		_set_art(scores, "scores")
		scores.z_index = 2


func _place_combat(layer: Node) -> void:
	var run := layer.get_node_or_null("RunButton") as Button
	if run != null:
		_pin(run)
		RoundHudStyle.apply_run(run)
		_set_art(run, "run")
		run.z_index = 2


func _place_attack(layer: Node) -> void:
	var attack := layer.get_node_or_null("TouchScreenButton") as TouchScreenButton
	if attack == null:
		return
	attack.position = LAYOUT["attack"] + _edge_offset()
	attack.scale = Vector2.ONE
	if attack.shape is CircleShape2D:
		(attack.shape as CircleShape2D).radius = 24.0


func _place_joystick(layer: Node) -> void:
	var stick := layer.get_node_or_null("player_joystick") as Node2D
	if stick != null:
		stick.position = Vector2(LAYOUT["joystick"]) + Vector2(0, _edge_offset().y)
		stick.scale = Vector2.ONE


func _place_buildings(layer: Node, custom := false) -> void:
	var buildings := layer.get_node_or_null("BuildingsButton") as Control
	var picker := layer.get_node_or_null("BuildPicker") as Control
	if buildings == null or picker == null:
		return
	var buttons: Array[Control] = []
	for child in picker.get_children():
		if child is Control and child.visible and not child.is_queued_for_deletion():
			buttons.append(child)
	if buttons.is_empty():
		return
	_pin(picker)
	picker.position = Vector2.ZERO
	picker.z_index = 2
	var hit := RoundHudStyle.HIT
	var step := int(hit + GAP)
	var view := get_viewport().get_visible_rect()
	var right := floori(view.end.x - GAP - hit)
	# Keep the picker in the upper HUD, clear of the default thumb controls.
	var bottom := floori(minf(view.end.y, LAYOUT["attack"].y - 4.0) - GAP - hit)
	var left_of_buildings := floori(buildings.position.x - GAP - hit)
	var top := clampi(roundi(buildings.position.y), int(GAP), bottom)
	var blocked := _picker_obstacles(layer, custom)
	var next := 0
	# Start alongside Buildings, then wrap left. Use the rest of the upper
	# HUD if a custom layout puts Buildings against the left or bottom edge.
	var columns := range(left_of_buildings, int(GAP) - 1, -step)
	columns.append_array(range(right, maxi(left_of_buildings + 1, int(GAP) - 1), -step))
	var row_bands := [range(top, bottom + 1, step), range(top - step, int(GAP) - 1, -step)]
	for rows in row_bands:
		for x in columns:
			for y in rows:
				var button := buttons[next]
				var rect := Rect2(Vector2(x, y), _size_of(button))
				if not view.encloses(rect) or blocked.any(func(other: Rect2) -> bool: return rect.intersects(other)):
					continue
				_pin(button)
				button.position = rect.position
				button.z_index = 3
				blocked.append(rect.grow(GAP))
				next += 1
				if next == buttons.size():
					return


func _picker_obstacles(layer: Node, custom: bool) -> Array[Rect2]:
	var blocked: Array[Rect2] = []
	var layout := get_node("/root/HudLayout")
	for id in layout.IDS:
		var control := layer.get_node_or_null(NodePath(layout.PATHS[id])) as CanvasItem
		if control == null or not control.is_visible_in_tree():
			continue
		var rect: Rect2 = layout.control_hit_rect(id, layer)
		if control is TouchScreenButton and control.shape != null:
			var shape_rect: Rect2 = control.shape.get_rect()
			if control.shape_centered and control.texture_normal != null:
				shape_rect.position += control.texture_normal.get_size() * 0.5
			rect = rect.merge(control.global_transform * shape_rect)
		if rect.has_area():
			blocked.append(rect)
	var paths := ["InGameMenu/MenuButton", "StatusPlate", "ScoreboardPanel"]
	if custom:
		paths.append("MinimapPanel")
	for path in paths:
		var control := layer.get_node_or_null(path) as Control
		if control != null and control.visible:
			blocked.append(control.get_global_rect())
	return blocked


func _place_panel(layer: Node, avoid_picker := true) -> void:
	var panel := layer.get_node_or_null("MinimapPanel") as Control
	if panel == null or panel.size.x <= 0.0:
		return
	var view := get_viewport().get_visible_rect().size
	var width := panel.size.x * panel.scale.x
	var height := panel.size.y * panel.scale.y
	var arc_left := view.x
	for node_name in ["MinimapButton", "BuildingsButton"]:
		arc_left = minf(arc_left, _left_of(layer.get_node_or_null(node_name) as Control))
	var picker := layer.get_node_or_null("BuildPicker") as Control
	if avoid_picker and picker != null:
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
	for node_name in ["StatusPlate", "ScoreboardToggle"]:
		var control := layer.get_node_or_null(node_name) as Control
		if control != null and control.visible and panel.get_global_rect().intersects(control.get_global_rect()):
			var dropped := ceilf(control.get_global_rect().end.y + GAP)
			if dropped + height <= limit:
				panel.position.y = dropped


func _place_tool(layer: Node) -> void:
	var layout := get_node_or_null("/root/HudLayout")
	if layout != null and not layout.get_entry("wheel").is_empty():
		return
	var wheel := layer.get_node_or_null("ToolWheel")
	if wheel == null or not wheel.has_method("place_button"):
		return
	var button := wheel.get_node_or_null("ToolButton") as Control
	var run := layer.get_node_or_null("RunButton") as Control
	if button == null or run == null:
		return
	_pin(button)
	var disc := button as Button
	if disc != null and absf(disc.size.x - RoundHudStyle.HIT) > 0.5:
		RoundHudStyle.apply(disc)
	var run_size := _size_of(run)
	var button_size := _size_of(button)
	var x := run.position.x - WHEEL_GAP - button_size.x
	var y := run.position.y + (run_size.y - button_size.y) * 0.5
	if x < SIDE:
		x = run.position.x
		y = run.position.y - WHEEL_GAP - button_size.y
	wheel.place_button(Vector2(roundf(x), roundf(y)))
	button.z_index = 4


func _set_art(control: Control, id: String) -> void:
	if not LAYOUT.has(id):
		return
	var inset: Vector2 = HIT_INSET.get(id, Vector2.ZERO)
	control.position = LAYOUT[id] - inset
	if id != "scores":
		var offset := _edge_offset()
		control.position.x += offset.x
		if id == "run":
			control.position.y += offset.y


func _edge_offset() -> Vector2:
	return (get_viewport().get_visible_rect().size - CANVAS_SIZE).max(Vector2.ZERO)


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


func place_custom_popups(layer: Node) -> void:
	_place_tool(layer)
	_place_panel(layer, false)
	_place_buildings(layer, true)


func _pin(control: Control) -> void:
	if control.has_meta(&"hud_pinned"):
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.set_meta(&"hud_pinned", true)