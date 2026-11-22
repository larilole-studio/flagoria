class_name HudToolRow
extends Node
## Map and Menu sit along the top edge. Attack mirrors the joystick, with Run
## and the tool wheel around it. Buildings sits beside that cluster and opens
## two rings over a dimmed playfield.
## Customize HUD can move these controls and the tool wheel. Layout follows
## viewport and visibility changes. A dedicated host builds no tool wheel.

const ToolWheelScript := preload("res://Scripts/ui/tool_wheel.gd")

const CANVAS_SIZE := Vector2(480, 270)
const GAP := 4.0
const WHEEL_GAP := 2.0
const SIDE := 12.0
const PICKER_RADII := [50.0, 90.0]
const PICKER_ANGLES := [[0.0, 50.0, 100.0], [0.0, 40.0, 80.0]]
const PICKER_SPACING := 40.0
const PLAYER_CLEARANCE := 70.0
const LAYOUT := {
	"menu": Vector2(444, 12),
	"map": Vector2(404, 12),
	"joystick": Vector2(77, 201),
}

var _picker_dimmer: ColorRect


func _ready() -> void:
	var stick := get_parent().get_node_or_null("player_joystick") as Node2D
	var attack := get_parent().get_node_or_null("TouchScreenButton") as TouchScreenButton
	if stick != null:
		RoundHudStyle.apply_joystick(stick)
	if attack != null:
		RoundHudStyle.apply_attack(attack)
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
	var layer := get_parent() as CanvasLayer
	if layer == null:
		return
	_layout()
	layer.visibility_changed.connect(relayout, CONNECT_DEFERRED)
	var scores := layer.get_node_or_null("ScoreboardPanel") as CanvasItem
	if scores != null and not scores.visibility_changed.is_connected(relayout):
		scores.visibility_changed.connect(relayout)
	if not get_viewport().size_changed.is_connected(relayout):
		get_viewport().size_changed.connect(relayout)


func relayout(_on: Variant = null) -> void:
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
	_place_map(layer)
	_place_status(layer)
	_place_joystick(layer)
	_place_attack(layer)
	_place_combat(layer)
	_place_tool(layer)
	place_build_picker(layer)


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


func _place_map(layer: Node) -> void:
	var map_button := layer.get_node_or_null("MapButton") as Button
	if map_button != null:
		_pin(map_button)
		RoundHudStyle.apply(map_button)
		_set_art(map_button, "map")
		map_button.z_index = 2


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
	if plate != null and hearts != null and score != null and wood != null:
		var on_plate := hearts.get_parent() == plate and score.get_parent() == plate and wood.get_parent() == plate
		if not on_plate:
			plate.bind_nodes(hearts, score, wood)


func _place_combat(layer: Node) -> void:
	var attack := layer.get_node_or_null("TouchScreenButton") as TouchScreenButton
	if attack == null or attack.texture_normal == null:
		return
	var rect := Rect2(attack.position, attack.texture_normal.get_size() * attack.scale)
	var run := layer.get_node_or_null("RunButton") as Button
	if run != null:
		_pin(run)
		RoundHudStyle.apply_run(run)
		run.position = Vector2(rect.position.x - _size_of(run).x - GAP - WHEEL_GAP,
				rect.get_center().y - _size_of(run).y + WHEEL_GAP)
		run.z_index = 2
	var buildings := layer.get_node_or_null("BuildingsButton") as Button
	if buildings != null:
		_pin(buildings)
		RoundHudStyle.apply_build(buildings)
		# Leave an inward path for both picker rings between the top row and Attack.
		buildings.position = rect.get_center() + Vector2(33.0, -52.5) - _size_of(buildings) * 0.5
		buildings.z_index = 2


static func attack_default_scale(attack: TouchScreenButton) -> float:
	var stick := attack.get_parent().get_node_or_null("player_joystick")
	if stick == null or stick.border == null or attack.texture_normal == null:
		return 1.0
	return stick.border.get_width() / float(attack.texture_normal.get_width())


func _place_attack(layer: Node) -> void:
	var attack := layer.get_node_or_null("TouchScreenButton") as TouchScreenButton
	var stick := layer.get_node_or_null("player_joystick") as Node2D
	if attack == null or attack.texture_normal == null or stick == null:
		return
	var view := get_viewport().get_visible_rect()
	var center := Vector2(2.0 * view.get_center().x - stick.position.x, stick.position.y)
	attack.scale = Vector2.ONE * attack_default_scale(attack)
	attack.position = center - attack.texture_normal.get_size() * attack.scale * 0.5
	if attack.shape is CircleShape2D:
		(attack.shape as CircleShape2D).radius = attack.texture_normal.get_width() * 0.5


func _place_joystick(layer: Node) -> void:
	var stick := layer.get_node_or_null("player_joystick") as Node2D
	if stick != null:
		stick.position = Vector2(LAYOUT["joystick"]) + Vector2(0, _edge_offset().y)
		stick.scale = Vector2.ONE


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or (event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT)) or not event.pressed:
		return
	var layer := get_parent()
	var picker := layer.get_node_or_null("BuildPicker") as Control
	var buildings := layer.get_node_or_null("BuildingsButton") as BaseButton
	if picker == null or buildings == null or not buildings.button_pressed or not picker.is_visible_in_tree():
		return
	var point: Vector2 = event.position
	if buildings.get_global_rect().has_point(point):
		return
	for child in picker.get_children():
		if child is Button and child.visible and child.get_global_rect().has_point(point):
			return
	get_viewport().set_input_as_handled()
	buildings.set_pressed(false)


func place_build_picker(layer: Node) -> void:
	var buildings := layer.get_node_or_null("BuildingsButton") as BaseButton
	var picker := layer.get_node_or_null("BuildPicker") as Control
	if _picker_dimmer != null:
		_picker_dimmer.hide()
	if buildings == null or picker == null or not buildings.button_pressed or HudLayoutVisual.blocks_hud_actions():
		return
	var buttons: Array[Button] = []
	for child in picker.get_children():
		if child is Button and child.get_meta(&"picker_available", true) and not child.is_queued_for_deletion():
			buttons.append(child)
	if buttons.is_empty():
		return
	var view := get_viewport().get_visible_rect()
	_show_picker_dimmer(layer, view)
	var origin := buildings.get_global_rect().get_center()
	var inward := 1.0 if origin.x < view.get_center().x else -1.0
	var blocked := _picker_obstacles(layer)
	var slots := _picker_slots(buttons, origin, inward, view, blocked)
	_pin(picker)
	picker.position = Vector2.ZERO
	picker.z_index = 2
	for button in buttons:
		var disc: Rect2 = slots[button][0]
		var caption: Rect2 = slots[button][1]
		var label := button.get_node("Caption") as Label
		_pin(button)
		button.position = disc.position
		button.z_index = 3
		label.visible = caption.has_area()
		if label.visible:
			label.position = caption.position - disc.position
		button.show()


func _show_picker_dimmer(layer: Node, view: Rect2) -> void:
	if _picker_dimmer == null:
		_picker_dimmer = ColorRect.new()
		_picker_dimmer.name = "BuildPickerDimmer"
		_picker_dimmer.color = Color(0, 0, 0, 0.45)
		_picker_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		_picker_dimmer.z_index = 1
		layer.add_child(_picker_dimmer)
		# GUI hit testing follows tree order, independently of draw order.
		layer.move_child(_picker_dimmer, 0)
	_picker_dimmer.position = view.position
	_picker_dimmer.size = view.size
	_picker_dimmer.show()


func _picker_slots(buttons: Array[Button], origin: Vector2, inward: float, view: Rect2,
		blocked: Array[Rect2]) -> Dictionary:
	var first_fit := {}
	var first_side := inward
	# Increase both radii proportionally, testing both sides at each size.
	var steps := ceili(view.size.length() - PICKER_RADII[0])
	for extra in range(maxi(0, steps) + 1):
		var scale_factor := 1.0 + extra / PICKER_RADII[0]
		for side: float in [inward, -inward]:
			var slots := _picker_candidate(buttons, origin, side, scale_factor, view, blocked)
			if slots.is_empty():
				continue
			if _picker_captions(slots, side, view, blocked, true):
				_picker_captions(slots, side, view, blocked)
				return slots
			if first_fit.is_empty():
				first_fit = slots
				first_side = side
	if first_fit.is_empty():
		first_fit = _picker_candidate(buttons, origin, inward, 1.0, view, blocked, true)
	_picker_captions(first_fit, first_side, view, blocked)
	return first_fit


func _picker_candidate(buttons: Array[Button], origin: Vector2, side: float, scale_factor: float,
		view: Rect2, blocked: Array[Rect2], clamp_to_view := false) -> Dictionary:
	var slots := {}
	var occupied := blocked.duplicate()
	for button in buttons:
		var index: int = button.get_meta(&"picker_slot")
		@warning_ignore("integer_division")
		var ring := index / 3
		var angle := deg_to_rad(PICKER_ANGLES[ring][index % 3])
		var offset := Vector2(side * sin(angle), -cos(angle)) * float(PICKER_RADII[ring]) * scale_factor
		var center := (origin + offset).round()
		var rect := Rect2(center - button.size * 0.5, button.size)
		if clamp_to_view:
			rect = HudLayoutVisual.nearest_clear_rect(rect, view, occupied)
		else:
			var nearest := view.get_center().clamp(rect.position, rect.end)
			if nearest.distance_to(view.get_center()) < PLAYER_CLEARANCE:
				return {}
			if not HudLayoutVisual.rect_clear(rect, view, occupied, PICKER_SPACING):
				return {}
		slots[button] = [rect]
		occupied.append(rect)
	return slots


func _picker_captions(slots: Dictionary, side: float, view: Rect2,
		blocked: Array[Rect2], reserve := false) -> bool:
	var occupied := blocked.duplicate()
	for slot: Array in slots.values():
		occupied.append(slot[0])
	var all_fit := true
	for button: Button in slots:
		var label := button.get_node("Caption") as Label
		var extent := label.get_minimum_size()
		if reserve:
			# Keep the search footprint of the original 10-unit theme captions.
			var font := label.get_theme_font("font")
			extent = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).ceil()
		var caption := _picker_caption(slots[button][0], extent, side, view, occupied)
		if not reserve:
			slots[button].append(caption)
		if caption.has_area():
			occupied.append(caption.grow(1.0))
		else:
			all_fit = false
	return all_fit


func _picker_caption(disc: Rect2, size: Vector2, side: float, view: Rect2,
		occupied: Array[Rect2]) -> Rect2:
	var center := disc.get_center()
	var distance := (disc.size + size) * 0.5 + Vector2.ONE * 2.0
	for direction: Vector2 in [Vector2.DOWN, Vector2(side, 0), Vector2.UP, Vector2(-side, 0)]:
		var base := center + direction * distance - size * 0.5
		var offsets := [0.0, -10.0, 10.0] if direction.x != 0.0 else [0.0]
		for offset: float in offsets:
			var rect := Rect2((base + Vector2(0, offset)).round(), size)
			# Reserve one pixel for the text outline on each side.
			if HudLayoutVisual.rect_clear(rect.grow(1.0), view, occupied):
				return rect
	return Rect2()


func _picker_obstacles(layer: Node, exclude: CanvasItem = null) -> Array[Rect2]:
	var blocked: Array[Rect2] = []
	var layout := get_node("/root/HudLayout")
	for id in layout.IDS:
		var control := layer.get_node_or_null(NodePath(layout.PATHS[id])) as CanvasItem
		if control == null or control == exclude or not control.is_visible_in_tree():
			continue
		var rect: Rect2 = layout.control_hit_rect(id, layer)
		if control is TouchScreenButton and control.shape != null:
			var shape_rect: Rect2 = control.shape.get_rect()
			if control.shape_centered and control.texture_normal != null:
				shape_rect.position += control.texture_normal.get_size() * 0.5
			rect = rect.merge(control.global_transform * shape_rect)
		if rect.has_area():
			blocked.append(rect)
	var paths := ["InGameMenu/MenuButton", "StatusPlate", "ScoreboardPanel", "FootprintRotateButton"]
	for path in paths:
		var control := layer.get_node_or_null(path) as Control
		if control != null and control.visible:
			blocked.append(control.get_global_rect())
	return blocked



func _place_tool(layer: Node, custom := false) -> void:
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
	if not custom:
		wheel.style_button(RoundHudStyle.HIT, RoundHudStyle.SIZE)
	var button_size := _size_of(button)
	var attack := layer.get_node_or_null("TouchScreenButton") as TouchScreenButton
	if not custom and attack != null and attack.texture_normal != null:
		var attack_size := attack.texture_normal.get_size() * attack.scale
		wheel.place_button(Vector2(attack.position.x - GAP - button_size.x,
				attack.position.y + attack_size.y * 0.5 + GAP + WHEEL_GAP))
	else:
		var x := run.position.x - WHEEL_GAP - button_size.x
		var y := run.position.y + (_size_of(run).y - button_size.y) * 0.5
		if x < SIDE:
			x = run.position.x
			y = run.position.y - WHEEL_GAP - button_size.y
		wheel.place_button(Vector2(roundf(x), roundf(y)))
	button.z_index = 4


func _set_art(control: Control, id: String) -> void:
	control.position = LAYOUT[id] - Vector2(4, 4)
	control.position.x += _edge_offset().x


func _edge_offset() -> Vector2:
	return (get_viewport().get_visible_rect().size - CANVAS_SIZE).max(Vector2.ZERO)


func _size_of(control: Control) -> Vector2:
	var need := control.get_combined_minimum_size()
	return Vector2(maxf(control.size.x, need.x), maxf(control.size.y, need.y))



func place_custom_popups(layer: Node) -> void:
	_place_tool(layer, true)
	var buildings := layer.get_node_or_null("BuildingsButton") as Button
	if buildings != null and not HudLayoutVisual.blocks_hud_actions():
		buildings.z_index = 2
		# Normalized positions can overlap when the saved layout is used at a new aspect ratio.
		var rect := buildings.get_global_rect()
		var view := get_viewport().get_visible_rect().grow(-SIDE)
		var clear_rect := HudLayoutVisual.nearest_clear_rect(rect, view, _picker_obstacles(layer, buildings))
		buildings.global_position = clear_rect.position
	place_build_picker(layer)


func _pin(control: Control) -> void:
	if control.has_meta(&"hud_pinned"):
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.set_meta(&"hud_pinned", true)
