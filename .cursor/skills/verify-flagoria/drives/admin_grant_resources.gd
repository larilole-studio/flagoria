extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11

const BuildDrag := preload("res://.cursor/skills/verify-flagoria/bin/build_drag.gd")
const MENU_ROWS := MENU_PANEL + "/Panel/Margin/VBox"
const BUILDINGS := "CanvasLayer1/BuildingsButton"
const TOWER := "CanvasLayer1/BuildPicker/TowerButton"


func run() -> void:
	if not await start_game():
		return
	var inventory: Inventory = current_scene.get_node(INVENTORY)
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var hud: ResourceHud = current_scene.find_child("ResourceHud", true, false)
	step("starting wood")
	if hud.label.text != "0":
		printerr("admin grants: expected an empty starting wood counter")
		done(false)
		return
	await snapshot("starting-wood")

	await click(BUILDINGS)
	await click(TOWER)
	var center := root.get_visible_rect().get_center()
	var origin: Vector2i
	var anchor: Vector2i
	for attempt in 6:
		if attempt > 0:
			await hold("ui_right", 20)
		origin = map.local_to_map(map.to_local(interaction.to_world(center)))
		anchor = _tower_anchor(map, interaction, origin)
		if anchor != origin:
			break
	if anchor == origin:
		printerr("admin grants: no reachable tower site")
		done(false)
		return
	var placements: int = map.placed_structures().size()
	var refused := [false]
	await _drag_tower(
		map,
		center,
		origin,
		anchor,
		func() -> void:
			refused[0] = interaction.build.reasons == [ConstructionPlacer.NOT_ENOUGH_WOOD]
	)
	if not refused[0] or map.placed_structures().size() != placements:
		printerr("admin grants: tower did not refuse placement for lack of wood")
		done(false)
		return

	step("grant wood from Menu")
	await click(MENU_BUTTON)
	var panel: Control = current_scene.get_node(MENU_PANEL + "/Panel")
	if (
		not panel.is_visible_in_tree()
		or not root.get_visible_rect().encloses(panel.get_global_rect())
	):
		printerr(
			(
				"admin grants: menu panel %s does not fit viewport %s"
				% [panel.get_global_rect(), root.get_visible_rect()]
			)
		)
		done(false)
		return
	await snapshot("grant-buttons")
	await click(MENU_ROWS + "/ResourceGrants/AddWood")
	await click(MENU_ROWS + "/Resume")
	if hud.label.text != "100":
		printerr("admin grants: HUD did not show the grant")
		done(false)
		return
	await snapshot("wood-after-grant")

	step("place the same tower")
	await _drag_tower(map, center, origin, anchor)
	var placed: bool = (
		map.placed_structures().size() == placements + 1
		and not map.structure_placement_at(anchor).is_empty()
		and inventory.count_of(Inventory.WOOD) == 90
		and hud.label.text == "90"
	)
	if placed:
		await snapshot("tower-placed")
	else:
		printerr("admin grants: tower placement or its wood charge failed")
	done(placed)


func _tower_anchor(map: TileMap, interaction: Interaction, origin: Vector2i) -> Vector2i:
	var placer := ConstructionPlacer.new(map)
	for dx in [3, 4, 5, 2, 1, 0, -1, -2, -3, -4, -5]:
		for dy in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5]:
			var cell := origin + Vector2i(dx, dy)
			if (
				cell != origin
				and interaction.in_reach(cell)
				and placer.can_place_geometry(BuildCosts.TOWER, [cell]).is_empty()
			):
				return cell
	return origin


func _drag_tower(
	map: TileMap, center: Vector2, origin: Vector2i, anchor: Vector2i, inspect := Callable()
) -> void:
	var start := root.get_final_transform() * (center + Vector2(-60, -64))
	var delta := to_window(map, map.map_to_local(anchor)) - to_window(map, map.map_to_local(origin))
	await BuildDrag.drag_touch(self, start, start + delta, inspect)
