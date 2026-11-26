extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 4

const BuildDrag := preload("res://.cursor/skills/verify-flagoria/bin/build_drag.gd")
const BUILDINGS := "CanvasLayer1/BuildingsButton"
const MINE_BUTTON := "CanvasLayer1/BuildPicker/MineButton"
const MENU_ROWS := MENU_PANEL + "/Panel/Margin/VBox"
const WORLD_LIST := WORLDS_VIEW + "/Body/Scroll/List"


func run() -> void:
	if not await start_game():
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var center := root.get_visible_rect().get_center()
	var origin := map.local_to_map(map.to_local(interaction.to_world(center)))
	var site: Variant = _find_site(map, interaction, origin)
	if site == null:
		printerr("mine cart: no reachable site")
		done(false)
		return

	step("grant wood, open the picker, and place beside a rock")
	await click(MENU_BUTTON)
	await click(MENU_ROWS + "/ResourceGrants/AddWood")
	await click(MENU_ROWS + "/Resume")
	await click(BUILDINGS)
	await snapshot("picker")
	await click(MINE_BUTTON)
	var start := root.get_final_transform() * (center + Vector2(-60, -64))
	var offset := to_window(map, map.map_to_local(site)) - to_window(map, map.map_to_local(origin))
	await BuildDrag.drag_touch(
		self, start, start + offset, func() -> void: await snapshot("preview")
	)
	var cart := _cart_at(map, site)
	if cart == null or not cart.is_playing():
		printerr("mine cart: placement did not start the loop")
		done(false)
		return

	for moment in [[7, "outbound"], [12, "parked"], [18, "inbound"]]:
		step("capture %s at frame %d" % [moment[1], moment[0]])
		if not await _capture_frame(cart, moment[0], moment[1]):
			done(false)
			return

	step("save and reload from Worlds")
	if not await _reload():
		done(false)
		return
	map = current_scene.get_node(WORLD_MAP)
	cart = _cart_at(map, site)
	done(cart != null and await _capture_frame(cart, 9, "reloaded"))


func _find_site(map: TileMap, interaction: Interaction, origin: Vector2i) -> Variant:
	var placer := ConstructionPlacer.new(map)
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var cell := origin + Vector2i(dx, dy)
			if (
				interaction.in_reach(cell)
				and map.has_live_rock(cell + Vector2i.DOWN)
				and placer.can_place_geometry(BuildCosts.MINE, [cell]).is_empty()
			):
				return cell
	return null


func _cart_at(map: TileMap, site: Vector2i) -> AnimatedSprite2D:
	var mine: Dictionary = map.structure_placement_at(site)
	return map.get_node_or_null("MineCart_%d" % mine.get("id", 0)) as AnimatedSprite2D


func _capture_frame(cart: AnimatedSprite2D, frame: int, label: String) -> bool:
	if not await wait_until(func() -> bool: return cart.is_playing() and cart.frame == frame, 6.0):
		printerr("mine cart: did not reach frame %d" % frame)
		return false
	await snapshot(label)
	return true


func _reload() -> bool:
	if not await menu_save():
		return false
	await click(MENU_ROWS + "/MainMenu")
	if not await wait_until(menu_root_visible, 10.0):
		return false
	await click(WORLDS_BUTTON)
	var list: ItemList = current_scene.get_node(WORLD_LIST)
	if list.item_count != 1:
		printerr("mine cart: expected one saved world")
		return false
	var at := to_window(list, list.get_item_rect(0).get_center())
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await click(WORLDS_VIEW + "/Body/Actions/Load")
	return await wait_until(func() -> bool: return hero() != null, 10.0)
