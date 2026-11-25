class_name BuildPlacement
extends RefCounted
## Tracks Buildings tools, placement previews, wall tips, and demolition taps.

enum Tool { CUT, PLANK, TOWER, CASTLE, GUARD, WALL, BARRACKS, DEMOLISH }

const PICKER_PATH := "/root/Flagoria/CanvasLayer1/BuildPicker"

const _FootprintOrientation := preload("res://Scripts/mechanics/building/footprint_orientation.gd")

var tool := Tool.CUT
var cells: Array[Vector2i] = []  ## snapped run or tower footprint under the finger
var cell_ok: Array[bool] = []  ## parallel to cells: green iff commit will place
var cost := 0
var reasons: Array[String] = []
var cost_viewport := Vector2.ZERO  ## where the cost label sits (finger)

var _interaction: Interaction
var _placer: ConstructionPlacer
var _remover: ConstructionRemover
var _picker: Control
var _buildings: Button
var _list_open := false
var _buttons: Dictionary = {}  ## Tool -> Button
var _snap_from := Vector2i.ZERO
var _snap_to := Vector2i.ZERO
var _snap_valid := false
var _snap_frame := 0
## Last placed wall cell while the Wall tool stays selected; cleared on leave.
var _wall_tip := Vector2i.ZERO
var _has_wall_tip := false
## Skip-cache extras: same drag cells can still go stale when wood, reach
## (player position) or the map change. Bumped on worldMap.ground_changed.
var _snap_wood := -1
var _snap_player_pos := Vector2(INF, INF)
var _snap_map_rev := -1
var _snap_rotation := -1
var _map_rev := 0
## Last multiplayer_on seen; Interaction polls and calls on_multiplayer_changed.
var _mp_was_on := false
var _rotate := BuildPlacementRotate.new()

var footprint_rotation: int:
	get:
		return _rotate.quarter_turns
	set(value):
		_rotate.quarter_turns = posmod(value, 4)


func setup(interaction: Interaction) -> void:
	_interaction = interaction
	_placer = ConstructionPlacer.new(interaction.world_map)
	_remover = ConstructionRemover.new(interaction.world_map)
	if interaction.world_map != null and interaction.world_map.has_signal("ground_changed"):
		interaction.world_map.ground_changed.connect(_on_ground_changed)
	_ensure_picker()
	set_tool(Tool.CUT)
	_mp_was_on = Interaction.multiplayer_on(interaction.multiplayer)
	_refresh_picker_visible()


static func is_footprint_tool(value: Tool) -> bool:
	return BuildToolRow.is_footprint(value)


func tracks_pointer() -> bool:
	return BuildToolRow.tracks_pointer(tool)


func set_tool(value: Tool) -> void:
	if tool == Tool.WALL and value != Tool.WALL:
		_has_wall_tip = false
	tool = value
	_rotate.reset()
	clear_preview()
	for t in _buttons:
		var button: Button = _buttons[t]
		button.set_pressed_no_signal(t == tool)
		RoundHudStyle.refresh_toggle(button)
	if value != Tool.CUT:
		_list_open = false
		if _buildings != null:
			_buildings.set_pressed_no_signal(false)
			RoundHudStyle.refresh_toggle(_buildings)
	_refresh_picker_visible()


func clear_preview() -> void:
	cells.clear()
	cell_ok.clear()
	cost = 0
	reasons.clear()
	cost_viewport = Vector2.ZERO
	_snap_valid = false
	_snap_wood = -1
	_snap_player_pos = Vector2(INF, INF)
	_snap_map_rev = -1
	_snap_rotation = -1
	_refresh_rotate_visible()


func rotate_footprint() -> void:
	## Turn the footprint preview 90° clockwise (#493).
	if not is_footprint_tool(tool):
		return
	_rotate.step_cw()
	_snap_valid = false
	if cost_viewport != Vector2.ZERO:
		var inventory := _inventory()
		if inventory != null:
			update_preview(cost_viewport, cost_viewport)


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


func update_preview(start_viewport: Vector2, end_viewport: Vector2) -> void:
	## Recompute the preview for the active tool. Plank: snapped run, green =
	## longest placeable prefix. Tower: footprint of the anchor under the
	## finger, all green iff commit will place, else all red. Skips work when
	## the snapped cells, wood count, player position and map revision are
	## unchanged (#383).
	if tool == Tool.CUT or _interaction == null or _interaction.player == null:
		clear_preview()
		return
	var inventory := _inventory()
	if inventory == null:
		clear_preview()
		return
	cost_viewport = end_viewport
	if tool == Tool.DEMOLISH:
		_update_demolish_preview(end_viewport)
		return
	if BuildToolRow.is_footprint(tool):
		_update_footprint_preview(end_viewport, inventory, BuildToolRow.footprint_kind(tool))
		return
	if tool == Tool.WALL:
		_update_wall_preview(start_viewport, end_viewport, inventory)
		return
	_update_plank_preview(start_viewport, end_viewport, inventory)


func longest_placeable(run: Array[Vector2i], inventory: Inventory) -> Array[Vector2i]:
	## Longest prefix of `run` ConstructionPlacer will accept (no gaps).
	for n in range(mini(run.size(), ConstructionPlacer.MAX_PLANK_RUN), 0, -1):
		var prefix: Array[Vector2i] = []
		for i in n:
			prefix.append(run[i])
		if _placer.can_place(BuildCosts.PLANK, prefix, inventory).is_empty():
			return prefix
	return []


func commit() -> bool:
	## Apply the current preview; false when no action is accepted.
	if tool == Tool.CUT or cells.is_empty():
		clear_preview()
		return false
	var inventory := _inventory()
	if inventory == null:
		clear_preview()
		return false
	var ok := false
	if tool == Tool.DEMOLISH and reasons.is_empty():
		var requests := _interaction.get_node_or_null("../StructureRequests") as StructureRequests
		ok = requests != null and requests.demolish(_cell_at(cost_viewport))
	elif BuildToolRow.is_footprint(tool):
		ok = _commit_footprint(inventory, BuildToolRow.footprint_kind(tool))
	elif tool == Tool.PLANK:
		ok = _commit_plank(inventory)
	elif tool == Tool.WALL:
		if "not adjacent" in reasons:
			clear_preview()
			return false
		ok = _commit_wall(inventory)
	clear_preview()
	return ok


func draw_preview(ci: Node2D) -> void:
	## Green/red cell tints, wood cost and refusal reason near the finger.
	## A wall gap / diagonal leaves cells empty but still shows the reason (#276).
	if tool == Tool.CUT or _interaction == null:
		return
	if cells.is_empty() and reasons.is_empty():
		return
	BuildPreview.draw_cells(ci, _interaction, cells, cell_ok)
	if is_footprint_tool(tool) and _snap_valid and cells.size() > 0:
		var mark: Vector2 = ci.to_local(_interaction.cell_center(_snap_from))
		_FootprintOrientation.draw_at(ci, mark, _rotate.quarter_turns)
	var label := ", ".join(PackedStringArray(reasons))
	if tool == Tool.DEMOLISH and reasons.is_empty():
		label = "+%d wood" % cost
	elif cost > 0:
		label = "%d wood" % cost if reasons.is_empty() else "%d wood — %s" % [cost, label]
	var label_at := _interaction.to_world(cost_viewport)
	if tool == Tool.DEMOLISH:
		label_at.y -= 18.0
	BuildPreview.draw_label(ci, label_at, label, not reasons.is_empty())


func on_mode_changed(mode: Interaction.Mode) -> void:
	if mode != Interaction.Mode.INTERACT:
		set_tool(Tool.CUT)
	else:
		_refresh_rotate_visible()
	_mp_was_on = Interaction.multiplayer_on(_interaction.multiplayer) if _interaction else false
	_refresh_picker_visible()


func on_multiplayer_changed(mp_on: bool) -> void:
	## Called from Interaction when multiplayer_on flips (peer joins while the
	## host is already in interact + Plank, etc.).
	if mp_on == _mp_was_on:
		return
	_mp_was_on = mp_on
	_refresh_picker_visible()


func _update_demolish_preview(viewport_pos: Vector2) -> void:
	var cell := _cell_at(viewport_pos)
	var target := _remover.target_at(cell, _interaction.multiplayer.get_unique_id())
	cells = target["cells"]
	cell_ok.clear()
	cell_ok.resize(cells.size())
	cell_ok.fill(false)
	reasons.clear()
	var why: String = target["reason"]
	if why == "" and not _interaction.in_reach(cell):
		why = "out of reach"
	if why != "":
		reasons.append(why)
	cost = target["refund"] if why == "" else 0


func _update_plank_preview(
	start_viewport: Vector2, end_viewport: Vector2, inventory: Inventory
) -> void:
	var from_cell := _cell_at(start_viewport)
	var to_cell := _cell_at(end_viewport)
	if _preview_inputs_unchanged(from_cell, to_cell, inventory):
		return
	_remember_preview_inputs(from_cell, to_cell, inventory)
	cells = snap_run(from_cell, to_cell)
	var anchored_run := _plank_run_from_reachable_start()
	var placeable := longest_placeable(anchored_run, inventory)
	var placeable_set := {}
	for cell in placeable:
		placeable_set[cell] = true
	cell_ok.clear()
	for cell in cells:
		cell_ok.append(placeable_set.has(cell))
	if placeable.is_empty():
		cost = 0
		reasons = (
			_placer.can_place(BuildCosts.PLANK, anchored_run, inventory)
			if not anchored_run.is_empty()
			else [ConstructionPlacer.EMPTY_CELLS]
		)
	else:
		cost = _placer.cost(BuildCosts.PLANK, placeable)
		reasons = []


func _update_footprint_preview(
	end_viewport: Vector2, inventory: Inventory, kind: StringName
) -> void:
	## Footprint of the anchor under the finger. All green and the kind's cost
	## when commit will place; all red with reasons otherwise.
	var anchor := _cell_at(end_viewport)
	if _preview_inputs_unchanged(anchor, anchor, inventory):
		return
	_remember_preview_inputs(anchor, anchor, inventory)
	cells = _placer.footprint_of(kind, anchor, _rotate.quarter_turns)
	cell_ok.clear()
	var one: Array[Vector2i] = [anchor]
	var placeable := false
	reasons.clear()
	if cells.is_empty():
		reasons.append(ConstructionPlacer.EMPTY_CELLS)
	elif not _interaction.in_reach(anchor):
		var why := _placer.can_place(kind, one, inventory, _rotate.quarter_turns)
		if why.is_empty():
			reasons.append("out of reach")
		else:
			reasons = why
	else:
		var why := _placer.can_place(kind, one, inventory, _rotate.quarter_turns)
		placeable = why.is_empty()
		if not placeable:
			reasons = why
	for _i in cells.size():
		cell_ok.append(placeable)
	cost = _placer.cost(kind, one) if placeable else 0
	_position_rotate_button(end_viewport)


func _plank_run_from_reachable_start() -> Array[Vector2i]:
	for i in cells.size():
		if _interaction.in_reach(cells[i]):
			return cells.slice(i)
	return []


func _commit_plank(inventory: Inventory) -> bool:
	var placeable := longest_placeable(_plank_run_from_reachable_start(), inventory)
	# Route through Interaction so multiplayer asks the host (#297). Offline
	# and host-alone still spend and write through ConstructionPlacer.place.
	return not placeable.is_empty() and _interaction.place_planks(placeable)


func _commit_footprint(inventory: Inventory, kind: StringName) -> bool:
	var anchor := _snap_from
	if not _interaction.in_reach(anchor):
		return false
	return _placer.place(kind, [anchor], inventory, _rotate.quarter_turns)


func _on_buildings_toggled(on: bool) -> void:
	if on and HudLayoutVisual.blocks_hud_actions():
		_buildings.set_pressed_no_signal(false)
		RoundHudStyle.refresh_toggle(_buildings)
		return
	_list_open = on
	_refresh_rotate_visible()
	_refresh_picker_visible()


func _ensure_picker() -> void:
	var hud := _interaction.get_node_or_null("/root/Flagoria/CanvasLayer1") as CanvasLayer
	if hud == null:
		return
	var theme: Theme = load("res://art/ui/main_menu_theme.tres")
	_buildings = hud.get_node_or_null("BuildingsButton") as Button
	if _buildings == null:
		_buildings = Button.new()
		_buildings.name = "BuildingsButton"
		_buildings.toggle_mode = true
		_buildings.theme = theme
		_buildings.tooltip_text = "Buildings"
		_buildings.icon = null
		RoundHudStyle.apply_build(_buildings)
		_buildings.toggled.connect(_on_buildings_toggled)
		hud.add_child(_buildings)
	_picker = hud.get_node_or_null("BuildPicker") as Control
	if _picker == null:
		_picker = Control.new()
		_picker.name = "BuildPicker"
		_picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(_picker)
	BuildToolRow.populate_picker(_picker, theme, _buttons, set_tool)
	_rotate.ensure(hud, theme)
	_rotate.connect_pressed(rotate_footprint)


func _refresh_picker_visible() -> void:
	if _picker == null or _interaction == null:
		return
	var mp := Interaction.multiplayer_on(_interaction.multiplayer)
	if mp and tool in BuildToolRow.MP_HIDDEN:
		set_tool(Tool.CUT)
		return
	for t in _buttons:
		var button: Button = _buttons[t]
		var available: bool = not (mp and t in BuildToolRow.MP_HIDDEN)
		button.set_meta(&"picker_available", available)
		if not _list_open or not available:
			button.hide()
	var hud := _picker.get_parent()
	var row := hud.get_node_or_null("HudToolRow") as HudToolRow
	if row != null:
		if _list_open:
			# Opening can precede the HUD’s deferred initial layout.
			row.relayout()
		else:
			row.place_build_picker(hud)


func wall_segment(
	tip: Vector2i, has_tip: bool, from_cell: Vector2i, to_cell: Vector2i
) -> Array[Vector2i]:
	return BuildToolRow.wall_segment(tip, has_tip, from_cell, to_cell)


func _update_wall_preview(
	start_viewport: Vector2, end_viewport: Vector2, inventory: Inventory
) -> void:
	var from_cell := _cell_at(start_viewport)
	var to_cell := _cell_at(end_viewport)
	if _preview_inputs_unchanged(from_cell, to_cell, inventory):
		return
	_remember_preview_inputs(from_cell, to_cell, inventory)
	var run := wall_segment(_wall_tip, _has_wall_tip, from_cell, to_cell)
	cells = run
	cell_ok.clear()
	reasons.clear()
	if run.is_empty():
		cost = 0
		reasons.clear()
		if _has_wall_tip:
			reasons.append("not adjacent")
			# Show the refused finger cell in red so the gap / diagonal is
			# visible even when wall_segment returns no cells.
			var refused: Array[Vector2i] = [to_cell]
			var refused_ok: Array[bool] = [false]
			cells = refused
			cell_ok = refused_ok
		else:
			reasons.append(ConstructionPlacer.EMPTY_CELLS)
		return
	var in_reach: Array[Vector2i] = []
	for cell in run:
		if _interaction.in_reach(cell):
			in_reach.append(cell)
	# Green == commit: whole in-reach prefix the placer accepts, else all red.
	var placeable: Array[Vector2i] = []
	if (
		not in_reach.is_empty()
		and _placer.can_place(BuildCosts.WALL_BLOCK, in_reach, inventory).is_empty()
	):
		placeable = in_reach
	var placeable_set := {}
	for cell in placeable:
		placeable_set[cell] = true
	for cell in cells:
		cell_ok.append(placeable_set.has(cell))
	if placeable.is_empty():
		cost = 0
		reasons.clear()
		if in_reach.is_empty():
			reasons.append(ConstructionPlacer.EMPTY_CELLS)
		else:
			reasons = _placer.can_place(BuildCosts.WALL_BLOCK, in_reach, inventory)
	else:
		cost = _placer.cost(BuildCosts.WALL_BLOCK, placeable)
		reasons.clear()


func _commit_wall(inventory: Inventory) -> bool:
	var in_reach: Array[Vector2i] = []
	for cell in cells:
		if _interaction.in_reach(cell):
			in_reach.append(cell)
	if in_reach.is_empty():
		return false
	if not _placer.can_place(BuildCosts.WALL_BLOCK, in_reach, inventory).is_empty():
		return false
	if not _placer.place(BuildCosts.WALL_BLOCK, in_reach, inventory):
		return false
	_wall_tip = in_reach[in_reach.size() - 1]
	_has_wall_tip = true
	return true


func _inventory() -> Inventory:
	return _interaction.get_node_or_null(Interaction.INVENTORY_PATH) as Inventory


func _cell_at(viewport_pos: Vector2) -> Vector2i:
	var world: Vector2 = _interaction.to_world(viewport_pos)
	return _interaction.world_map.local_to_map(_interaction.world_map.to_local(world))


func _on_ground_changed(_cells: Rect2i) -> void:
	_map_rev += 1


func _preview_inputs_unchanged(
	from_cell: Vector2i, to_cell: Vector2i, inventory: Inventory
) -> bool:
	if not _snap_valid or from_cell != _snap_from or to_cell != _snap_to:
		return false
	if _rotate.quarter_turns != _snap_rotation:
		return false
	if inventory.count_of(Inventory.WOOD) != _snap_wood:
		return false
	# Other actors can enter a footprint without changing any tiles.
	if Engine.get_process_frames() - _snap_frame >= _interaction.world_map.chunk_refresh_frames:
		return false
	if _map_rev != _snap_map_rev:
		return false
	var pos := _interaction.player.global_position if _interaction.player else Vector2(INF, INF)
	return pos == _snap_player_pos


func _remember_preview_inputs(from_cell: Vector2i, to_cell: Vector2i, inventory: Inventory) -> void:
	_snap_from = from_cell
	_snap_to = to_cell
	_snap_valid = true
	_snap_frame = Engine.get_process_frames()
	_snap_rotation = _rotate.quarter_turns
	_snap_wood = inventory.count_of(Inventory.WOOD)
	_snap_player_pos = (
		_interaction.player.global_position if _interaction.player else Vector2(INF, INF)
	)
	_snap_map_rev = _map_rev


func _refresh_rotate_visible() -> void:
	if _interaction == null:
		return
	var show := (
		not _list_open
		and _interaction.mode == Interaction.Mode.INTERACT
		and is_footprint_tool(tool)
		and not cells.is_empty()
	)
	_rotate.set_visible(show)


func _position_rotate_button(viewport_pos: Vector2) -> void:
	_refresh_rotate_visible()
	_rotate.position_at(viewport_pos)
