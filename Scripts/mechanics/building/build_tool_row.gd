class_name BuildToolRow
extends RefCounted
## Build picker tools: icons, tips, footprint kinds and picker buttons (#556).

## Nothing stays hidden once its request exists. Plank (#297), Tower (#497)
## and Wall (#498) stay visible. An empty list hides nothing.
const MP_HIDDEN: Array = []

const FOOTPRINT_KIND := {
	BuildPlacement.Tool.TOWER: BuildCosts.TOWER,
	BuildPlacement.Tool.CASTLE: BuildCosts.CASTLE,
	BuildPlacement.Tool.GUARD: BuildCosts.GUARD_POST,
	BuildPlacement.Tool.BARRACKS: BuildCosts.BARRACKS,
	BuildPlacement.Tool.MINE: BuildCosts.MINE,
}
const TOOL_TIPS := {
	BuildPlacement.Tool.CUT: "Cut",
	BuildPlacement.Tool.PLANK: "Plank",
	BuildPlacement.Tool.TOWER: "Tower",
	BuildPlacement.Tool.CASTLE: "Castle",
	BuildPlacement.Tool.GUARD: "Guard post",
	BuildPlacement.Tool.BARRACKS: "Barracks",
	BuildPlacement.Tool.MINE: "Mine",
	BuildPlacement.Tool.WALL: "Wall",
	BuildPlacement.Tool.DEMOLISH: "Demolish",
}
const BUTTON_NAMES := {
	BuildPlacement.Tool.PLANK: "PlankButton",
	BuildPlacement.Tool.TOWER: "TowerButton",
	BuildPlacement.Tool.CASTLE: "CastleButton",
	BuildPlacement.Tool.GUARD: "GuardButton",
	BuildPlacement.Tool.BARRACKS: "BarracksButton",
	BuildPlacement.Tool.MINE: "MineButton",
	BuildPlacement.Tool.WALL: "WallButton",
	BuildPlacement.Tool.DEMOLISH: "DemolishButton",
}


static func picker_tools() -> Array:
	return [
		BuildPlacement.Tool.PLANK,
		BuildPlacement.Tool.WALL,
		BuildPlacement.Tool.TOWER,
		BuildPlacement.Tool.CASTLE,
		BuildPlacement.Tool.GUARD,
		BuildPlacement.Tool.BARRACKS,
		BuildPlacement.Tool.MINE,
		BuildPlacement.Tool.DEMOLISH,
	]


static func tip(tool: BuildPlacement.Tool) -> String:
	return TOOL_TIPS[tool] as String


static func button_name(tool: BuildPlacement.Tool) -> String:
	return BUTTON_NAMES[tool] as String


static func footprint_kind(tool: BuildPlacement.Tool) -> StringName:
	return FOOTPRINT_KIND.get(tool, &"")


static func is_footprint(tool: BuildPlacement.Tool) -> bool:
	return FOOTPRINT_KIND.has(tool)


static func tracks_pointer(tool: BuildPlacement.Tool) -> bool:
	return tool != BuildPlacement.Tool.CUT


static func populate_picker(
	picker: Control, theme: Theme, buttons: Dictionary, on_select: Callable
) -> void:
	for child in picker.get_children():
		child.queue_free()
	buttons.clear()
	var tools := picker_tools()
	for i in tools.size():
		var t: BuildPlacement.Tool = tools[i]
		var button := Button.new()
		button.name = button_name(t)
		button.set_meta(&"picker_slot", i)
		button.toggle_mode = true
		button.theme = theme
		var caption := "Guard" if t == BuildPlacement.Tool.GUARD else tip(t)
		var kind := footprint_kind(t)
		if BuildCosts.STONE.has(kind):
			var amount := BuildCosts.price(kind)
			var quote := BuildCosts.label(amount)
			caption += "\n%d wood\n%d stone" % [amount.x, amount.y]
			button.tooltip_text = tip(t) + " — " + quote
		else:
			button.tooltip_text = tip(t)
		var sprite := "guard" if t == BuildPlacement.Tool.GUARD else tip(t).to_lower()
		RoundHudStyle.apply_disc(
			button, "pick_" + sprite, RoundHudStyle.HIT, RoundHudStyle.SIZE, true
		)
		var captured: BuildPlacement.Tool = t
		button.pressed.connect(func() -> void: on_select.call(captured))
		_add_picker_label(button, caption, 8 if BuildCosts.STONE.has(kind) else 10)
		picker.add_child(button)
		buttons[t] = button
	picker.reset_size()


static func _add_picker_label(button: Button, caption: String, font_size: int) -> void:
	var label := Label.new()
	label.name = "Caption"
	RoundHudStyle.apply_label(label, font_size)
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)


static func snap_run(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	## Contiguous horizontal or vertical cells from `from_cell` to `to_cell`,
	## snapping to the dominant axis (ties go horizontal).
	var delta := to_cell - from_cell
	var horizontal := absi(delta.x) >= absi(delta.y)
	var end := Vector2i(to_cell.x, from_cell.y) if horizontal else Vector2i(from_cell.x, to_cell.y)
	var step := Vector2i(
		0 if end.x == from_cell.x else (1 if end.x > from_cell.x else -1),
		0 if end.y == from_cell.y else (1 if end.y > from_cell.y else -1),
	)
	var out: Array[Vector2i] = [from_cell]
	var cur := from_cell
	while cur != end:
		cur += step
		out.append(cur)
	return out


static func wall_segment(
	tip: Vector2i, has_tip: bool, from_cell: Vector2i, to_cell: Vector2i
) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not has_tip:
		if from_cell == to_cell:
			return [to_cell]
		return snap_run(from_cell, to_cell)
	var delta := to_cell - tip
	if delta == Vector2i.ZERO:
		return empty
	var neighbours := {
		tip + Vector2i.LEFT: true,
		tip + Vector2i.RIGHT: true,
		tip + Vector2i.UP: true,
		tip + Vector2i.DOWN: true,
	}
	if from_cell == to_cell:
		if not neighbours.has(to_cell):
			return empty
		return [to_cell]
	var horizontal := absi(delta.x) >= absi(delta.y)
	if horizontal and delta.x == 0:
		return empty
	if not horizontal and delta.y == 0:
		return empty
	var step := Vector2i(
		(1 if delta.x > 0 else -1) if horizontal else 0,
		0 if horizontal else (1 if delta.y > 0 else -1),
	)
	var start := tip + step
	var end := Vector2i(to_cell.x, tip.y) if horizontal else Vector2i(tip.x, to_cell.y)
	if start == tip:
		return empty
	return snap_run(start, end)
