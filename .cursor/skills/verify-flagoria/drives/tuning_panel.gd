extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11

const BuildDrag := preload("res://.cursor/skills/verify-flagoria/bin/build_drag.gd")
const MENU_ROWS := MENU_PANEL + "/Panel/Margin/VBox"
const TUNING_BUTTON := MENU_ROWS + "/ResourceGrants/Tuning"
const CONTENT := "CanvasLayer1/InGameMenu/TuningPanel/Margin/Content"
const TABS := CONTENT + "/Body/Categories/"
const SCROLL := CONTENT + "/Body/Scroll"
const ROWS := SCROLL + "/Rows"
const HEADER := CONTENT + "/Header"
const CONFIRM_RESET := CONTENT + "/ConfirmReset"
const CASTLE_WOOD := ROWS + "/building_castle_wood"
const PLANK_WOOD := ROWS + "/building_plank_wood"
const MINE_WOOD := ROWS + "/building_mine_wood"
const RESET := "/ResetSlot/Reset"
const WINDOW_SIZE := Vector2i(2400, 1080)
const ROW_COUNTS := {
	"Buildingcosts": 12,
	"Mine": 2,
	"Sawmill": 2,
	"Handmining": 2,
	"Chopping": 6,
	"Soldiers": 5,
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
	await _touch(HEADER + "/Close")
	if not current_scene.get_node(TUNING_BUTTON).is_visible_in_tree():
		_fail("Close did not return to Menu")
		return
	await _touch(MENU_ROWS + "/Resume")
	await click("CanvasLayer1/BuildingsButton")
	await click("CanvasLayer1/BuildPicker/CastleButton")
	if not await _show_preview(BuildCosts.CASTLE, Vector2i(36, 15), "castle-build-preview"):
		_fail("no reachable castle preview showing 36 wood and 15 stone")
		return
	if not await _reload_with_mine_price() or not await _reset_prices():
		return
	done(true)


func _reload_with_mine_price() -> bool:
	step("set Mine wood to 20, save, and load from Worlds")
	await _touch(MENU_BUTTON)
	await _touch(TUNING_BUTTON)
	await _reveal_mine_row()
	for i in 5:
		await _touch(MINE_WOOD + "/Increase")
	if not _shows_value(MINE_WOOD, "20"):
		return _fail("Mine wood did not reach 20")
	await _touch(HEADER + "/Close")
	await _touch(SAVE_BUTTON)
	await _touch(MENU_ROWS + "/MainMenu")
	if not await wait_until(menu_root_visible, 10.0):
		return _fail("Main menu did not reopen")
	await click(WORLDS_BUTTON)
	var list: ItemList = current_scene.get_node(WORLDS_VIEW + "/Body/Scroll/List")
	if list.item_count != 1:
		return _fail("expected one saved world")
	await _touch_at(to_window(list, list.get_item_rect(0).get_center()))
	await click(WORLDS_VIEW + "/Body/Actions/Load")
	if not await wait_until(func() -> bool: return hero() != null, 10.0):
		return _fail("saved world did not load")
	await grant_resources()
	await click("CanvasLayer1/BuildingsButton")
	await click("CanvasLayer1/BuildPicker/MineButton")
	return (
		await _show_preview(BuildCosts.MINE, Vector2i(20, 0), "mine-build-preview-20")
		or _fail("no reachable mine preview showing 20 wood after loading")
	)


func _reset_prices() -> bool:
	step("reset the Mine wood row")
	await _touch(MENU_BUTTON)
	await _touch(TUNING_BUTTON)
	await _reveal_mine_row()
	var reset: Button = current_scene.get_node(MINE_WOOD + RESET)
	if not (
		_shows_value(MINE_WOOD, "20")
		and reset.is_visible_in_tree()
		and reset.text == "Reset to 15"
		and _check_touch_targets(MINE_WOOD + "/ResetSlot")
	):
		return _fail("Mine wood reset did not show its default or meet the touch target")
	await snapshot("mine-wood-reset")
	await _touch(MINE_WOOD + RESET)
	if not _shows_value(MINE_WOOD, "15") or reset.is_visible_in_tree():
		return _fail("row reset did not restore Mine wood and hide its reset control")
	await _touch(MINE_WOOD + "/Increase")
	await _touch(TABS + "Mine")
	await _touch(ROWS + "/mine_cycle_seconds/Increase")
	if not _shows_value(ROWS + "/mine_cycle_seconds", "60.5"):
		return _fail("Mine cycle did not change before Reset all")
	await _touch(TABS + "Buildingcosts")
	await _reveal_mine_row()
	return await _confirm_reset_all()


func _confirm_reset_all() -> bool:
	step("cancel Reset all, then open it again and confirm")
	if not _check_touch_targets(HEADER):
		return _fail("undersized Tuning header button")
	await _touch(HEADER + "/ResetAll")
	if not _check_touch_targets(CONFIRM_RESET):
		return _fail("undersized reset confirmation button")
	await snapshot("reset-all-confirm")
	await _touch(CONFIRM_RESET + "/CancelReset")
	if not _shows_value(MINE_WOOD, "16"):
		return _fail("cancel changed Mine wood")
	await _touch(HEADER + "/ResetAll")
	await _touch(CONFIRM_RESET + "/ApplyReset")
	if not (
		_shows_value(MINE_WOOD, "15")
		and _shows_value(CASTLE_WOOD, "35")
		and _shows_value(PLANK_WOOD, "1")
		and not current_scene.get_node(MINE_WOOD + RESET).is_visible_in_tree()
	):
		return _fail("Reset all did not restore the building costs")
	await snapshot("reset-all-result")
	await _touch(TABS + "Mine")
	return (
		_shows_value(ROWS + "/mine_cycle_seconds", "60")
		or _fail("Reset all did not restore the Mine tab")
	)


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


func _reveal_mine_row() -> void:
	var scroll: ScrollContainer = current_scene.get_node(SCROLL)
	var bar := scroll.get_v_scroll_bar()
	var start := to_window(bar, bar.size * Vector2(0.5, 0.2))
	var end := to_window(bar, bar.size * Vector2(0.5, 0.31))
	for at in [start, end]:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		Input.parse_input_event(motion)
		await process_frame
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = at == start
		button.position = at
		button.global_position = at
		Input.parse_input_event(button)
		await process_frame
		await process_frame


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
	await _touch_at(to_window(control, control.size / 2.0))


func _touch_at(at: Vector2) -> void:
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
		var size := to_window(child, child.size) - to_window(child, Vector2.ZERO)
		if (
			child.size.y < menu_button.size.y
			or (root.size == WINDOW_SIZE and minf(size.x, size.y) < 48)
		):
			printerr("tuning: ", child.name, " is only ", size, " screen px")
			return false
	return true


func _show_preview(
	kind: StringName,
	price: Vector2i,
	screen: String,
	walk := ["", "ui_up", "ui_right", "ui_up", "ui_right", "ui_down"]
) -> bool:
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var placer := ConstructionPlacer.new(map)
	for action in walk:
		if not action.is_empty():
			await hold(action, 30)
		var center := root.get_visible_rect().get_center()
		var origin := map.local_to_map(map.to_local(interaction.to_world(center)))
		for dx in [4, 5, 3, -4, -5, -3, 0, 2, -2]:
			for dy in [0, -3, 3, -4, 4, -5, 5, -2, 2]:
				var cell := origin + Vector2i(dx, dy)
				if (
					interaction.in_reach(cell)
					and placer.can_place_geometry(kind, [cell]).is_empty()
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
							shown[0] = interaction.build.price == price
							if shown[0]:
								await snapshot(screen)
					)
					if shown[0]:
						return true
	return false
