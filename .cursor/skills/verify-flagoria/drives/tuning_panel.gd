extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11

const BuildDrag := preload("res://.cursor/skills/verify-flagoria/bin/build_drag.gd")
const MENU_ROWS := MENU_PANEL + "/Panel/Margin/VBox"
const TUNING_BUTTON := MENU_ROWS + "/ResourceGrants/Tuning"
const CONTENT := "CanvasLayer1/InGameMenu/TuningPanel/Margin/Content"
const TABS := CONTENT + "/Body/Categories/"
const SCROLL := CONTENT + "/Body/Scroll"
const ROWS := SCROLL + "/Rows"
const CASTLE_WOOD := ROWS + "/building_castle_wood"
const PLANK_WOOD := ROWS + "/building_plank_wood"
const WINDOW_SIZE := Vector2i(2400, 1080)
const ROW_COUNTS := {
	"Buildingcosts": 11,
	"Mine": 2,
	"Handmining": 2,
	"Chopping": 6,
	"Soldiers": 2,
	"Movement": 2,
	"Visuals": 3,
}


func run() -> void:
	if DisplayServer.get_name() != "headless":
		root.size = WINDOW_SIZE
	if not await start_game():
		return

	if (
		not await _edit_building_costs()
		or not await _scroll_costs()
		or not await _visit_categories()
	):
		return

	step("return to Menu and preview a castle")
	await _touch(CONTENT + "/Header/Close")
	if not current_scene.get_node(TUNING_BUTTON).is_visible_in_tree():
		_fail("Close did not return to Menu")
		return
	await _touch(MENU_ROWS + "/Resume")
	await click("CanvasLayer1/BuildingsButton")
	await click("CanvasLayer1/BuildPicker/CastleButton")
	if not await _show_castle_preview():
		_fail("no reachable castle preview showing 36 wood and 15 stone")
		return
	done(true)


func _edit_building_costs() -> bool:
	step("open Tuning on Building costs")
	await _touch(MENU_BUTTON)
	if not current_scene.get_node(TUNING_BUTTON).is_visible_in_tree():
		return _fail("Menu touch did not show Tuning")
	await _touch(TUNING_BUTTON)
	if not _shows_value(CASTLE_WOOD, "35") or not _check_touch_targets(TABS):
		_fail("Building costs or its category tabs are missing")
		return false
	await snapshot("building-costs")

	step("increase Castle wood from 35 to 36")
	await _touch(CASTLE_WOOD + "/Increase")
	if not _shows_value(CASTLE_WOOD, "36"):
		_fail("Castle wood did not update to 36")
		return false
	await snapshot("castle-wood-36")

	step("decrease Plank wood to its minimum and tap again")
	await _touch(PLANK_WOOD + "/Decrease")
	if not _shows_value(PLANK_WOOD, "0"):
		_fail("Plank wood did not reach zero")
		return false
	await _touch(PLANK_WOOD + "/Decrease")
	if not _shows_value(PLANK_WOOD, "0"):
		_fail("Plank wood went below zero")
		return false
	return true


func _scroll_costs() -> bool:
	step("drag to scroll Building costs")
	var scroll: ScrollContainer = current_scene.get_node(SCROLL)
	var plus: Button = current_scene.get_node(CASTLE_WOOD + "/Increase")
	var start := to_window(plus, plus.size / 2.0)
	var end := (
		start
		- Vector2(0, (to_window(scroll, scroll.size) - to_window(scroll, Vector2.ZERO)).y * 0.4)
	)
	await BuildDrag.drag_touch(self, start, end)
	return (
		(scroll.scroll_vertical > 0 and _shows_value(CASTLE_WOOD, "36"))
		or _fail("a drag from the stepper should scroll without changing Castle wood")
	)


func _visit_categories() -> bool:
	step("visit every category and review Visuals")
	for tab: String in ROW_COUNTS:
		await _touch(TABS + tab)
		var rows := current_scene.get_node(ROWS)
		if rows.get_child_count() != ROW_COUNTS[tab]:
			_fail("unexpected row count for " + tab)
			return false
		for row in rows.get_children():
			if not _check_touch_targets(str(current_scene.get_path_to(row))):
				_fail("undersized stepper in " + tab)
				return false
	await snapshot("visuals")
	return true


func _touch(path: String) -> void:
	var control: Control = current_scene.get_node(path)
	var at := to_window(control, control.size / 2.0)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _shows_value(row: String, expected: String) -> bool:
	var value := current_scene.get_node_or_null(row + "/Value") as Label
	return value != null and value.is_visible_in_tree() and value.text == expected


func _check_touch_targets(parent: String) -> bool:
	var menu_button: Button = current_scene.get_node(MENU_ROWS + "/Resume")
	for child in current_scene.get_node(parent).get_children():
		if not child is Button:
			continue
		var height := (
			to_window(child, Vector2(0, child.size.y)).y - to_window(child, Vector2.ZERO).y
		)
		if child.size.y < menu_button.size.y or (root.size == WINDOW_SIZE and height < 48):
			printerr("tuning: ", child.name, " is only ", height, " screen px tall")
			return false
	return true


func _show_castle_preview() -> bool:
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var placer := ConstructionPlacer.new(map)
	for action in ["", "ui_up", "ui_right", "ui_up", "ui_right", "ui_down"]:
		if not action.is_empty():
			await hold(action, 30)
		var center := root.get_visible_rect().get_center()
		var origin := map.local_to_map(map.to_local(interaction.to_world(center)))
		for dx in [4, 5, 3, -4, -5, -3, 0, 2, -2]:
			for dy in [0, -3, 3, -4, 4, -5, 5, -2, 2]:
				var cell := origin + Vector2i(dx, dy)
				if (
					interaction.in_reach(cell)
					and placer.can_place_geometry(BuildCosts.CASTLE, [cell]).is_empty()
				):
					var finger := root.get_final_transform() * (center + Vector2(-60, -64))
					var delta := (
						to_window(map, map.map_to_local(cell))
						- to_window(map, map.map_to_local(origin))
					)
					var shown := [false]
					await BuildDrag.drag_touch(
						self,
						finger,
						finger + delta,
						func() -> void:
							shown[0] = interaction.build.price == Vector2i(36, 15)
							if shown[0]:
								await snapshot("castle-build-preview")
					)
					if shown[0]:
						return true
	return false
