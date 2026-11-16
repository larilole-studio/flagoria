class_name BuildToolRow
extends RefCounted
## Buildings-column tools: icons, tips, footprint kinds and picker buttons (#556).

const COLUMN_ICON := 12
## Nothing stays hidden once its request exists. Plank (#297), Tower (#497)
## and Wall (#498) stay visible. An empty list hides nothing.
const MP_HIDDEN: Array = []

const TOOL_ICONS := {
	BuildPlacement.Tool.CUT: preload("res://art/ui/ui_tool_cut.png"),
	BuildPlacement.Tool.PLANK: preload("res://art/ui/ui_tool_plank.png"),
	BuildPlacement.Tool.TOWER: preload("res://art/ui/ui_tool_tower.png"),
	BuildPlacement.Tool.CASTLE: preload("res://art/ui/ui_tool_castle.png"),
	BuildPlacement.Tool.GUARD: preload("res://art/ui/ui_tool_guard.png"),
	BuildPlacement.Tool.BARRACKS: preload("res://art/ui/ui_tool_guard.png"),
	BuildPlacement.Tool.WALL: preload("res://art/ui/ui_tool_wall.png"),
}
const FOOTPRINT_KIND := {
	BuildPlacement.Tool.TOWER: BuildCosts.TOWER,
	BuildPlacement.Tool.CASTLE: BuildCosts.CASTLE,
	BuildPlacement.Tool.GUARD: BuildCosts.GUARD_POST,
	BuildPlacement.Tool.BARRACKS: BuildCosts.BARRACKS,
}
const TOOL_TIPS := {
	BuildPlacement.Tool.CUT: "Cut",
	BuildPlacement.Tool.PLANK: "Plank",
	BuildPlacement.Tool.TOWER: "Tower",
	BuildPlacement.Tool.CASTLE: "Castle",
	BuildPlacement.Tool.GUARD: "Guard post",
	BuildPlacement.Tool.BARRACKS: "Barracks",
	BuildPlacement.Tool.WALL: "Wall",
}
const BUTTON_NAMES := {
	BuildPlacement.Tool.PLANK: "PlankButton",
	BuildPlacement.Tool.TOWER: "TowerButton",
	BuildPlacement.Tool.CASTLE: "CastleButton",
	BuildPlacement.Tool.GUARD: "GuardButton",
	BuildPlacement.Tool.BARRACKS: "BarracksButton",
	BuildPlacement.Tool.WALL: "WallButton",
}


static func column_tools() -> Array:
	return [
		BuildPlacement.Tool.PLANK, BuildPlacement.Tool.TOWER, BuildPlacement.Tool.CASTLE,
		BuildPlacement.Tool.GUARD, BuildPlacement.Tool.BARRACKS, BuildPlacement.Tool.WALL,
	]


static func icon(tool: BuildPlacement.Tool) -> Texture2D:
	return TOOL_ICONS[tool] as Texture2D


static func tip(tool: BuildPlacement.Tool) -> String:
	return TOOL_TIPS[tool] as String


static func button_name(tool: BuildPlacement.Tool) -> String:
	return BUTTON_NAMES[tool] as String


static func footprint_kind(tool: BuildPlacement.Tool) -> StringName:
	return FOOTPRINT_KIND.get(tool, &"")


static func is_footprint(tool: BuildPlacement.Tool) -> bool:
	return FOOTPRINT_KIND.has(tool)


static func tracks_pointer(tool: BuildPlacement.Tool) -> bool:
	if tool == BuildPlacement.Tool.CUT:
		return false
	return tool == BuildPlacement.Tool.PLANK or tool == BuildPlacement.Tool.WALL or is_footprint(tool)


static func populate_picker(
		picker: Control,
		theme: Theme,
		buttons: Dictionary,
		on_select: Callable) -> void:
	for child in picker.get_children():
		child.queue_free()
	buttons.clear()
	for t in column_tools():
		var button := Button.new()
		button.name = button_name(t)
		button.toggle_mode = true
		button.theme = theme
		button.icon = icon(t)
		button.tooltip_text = tip(t)
		RoundHudStyle.apply(button, RoundHudStyle.HIT, RoundHudStyle.SIZE, COLUMN_ICON)
		var captured: BuildPlacement.Tool = t
		button.pressed.connect(func() -> void: on_select.call(captured))
		picker.add_child(button)
		buttons[t] = button
	picker.reset_size()


static func wall_segment(tip: Vector2i, has_tip: bool, from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not has_tip:
		if from_cell == to_cell:
			return [to_cell]
		return BuildPlacement.snap_run(from_cell, to_cell)
	var delta := to_cell - tip
	if delta == Vector2i.ZERO:
		return empty
	var neighbours := {
		tip + Vector2i.LEFT: true, tip + Vector2i.RIGHT: true,
		tip + Vector2i.UP: true, tip + Vector2i.DOWN: true,
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
	return BuildPlacement.snap_run(start, end)