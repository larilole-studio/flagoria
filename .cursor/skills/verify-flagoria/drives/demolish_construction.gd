## fixture
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Seed the wood balance, then use the real picker and touch input throughout.

const BuildDrag := preload("res://.cursor/skills/verify-flagoria/bin/build_drag.gd")

const BUILDINGS := "CanvasLayer1/BuildingsButton"
const TOWER_BUTTON := "CanvasLayer1/BuildPicker/TowerButton"
const DEMOLISH_BUTTON := "CanvasLayer1/BuildPicker/DemolishButton"


func run() -> void:
	if not await start_game():
		return
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var inventory: Inventory = current_scene.get_node(INVENTORY)
	inventory.add(Inventory.WOOD, 10)
	var initial := inventory.count_of(Inventory.WOOD)
	await toggle_mode()
	var anchor: Variant = await tower_anchor(map, interaction)
	if anchor == null:
		printerr("demolish: no reachable tower anchor by the starting castle")
		done(false)
		return
	step("place tower through the picker")
	await click(BUILDINGS)
	await click(TOWER_BUTTON)
	var center := root.get_visible_rect().get_center()
	var start_cell := map.local_to_map(map.to_local(interaction.to_world(center)))
	var target := to_window(map, map.map_to_local(anchor))
	var origin := to_window(map, map.map_to_local(start_cell))
	var finger := root.get_final_transform() * (center + Vector2(0, -64))
	await BuildDrag.drag_touch(self, finger, finger + target - origin)
	if not _has_tower(map) or inventory.count_of(Inventory.WOOD) != initial - 10:
		printerr("demolish: the Tower tool did not place a tower")
		done(false)
		return
	step("open picker and preview demolition")
	await click(BUILDINGS)
	var button: Button = current_scene.get_node(DEMOLISH_BUTTON)
	if not button.is_visible_in_tree():
		done(false)
		return
	await snapshot("demolish-picker")
	await click(DEMOLISH_BUTTON)
	var preview := [false]
	await tap_cell(
		anchor,
		func() -> void:
			preview[0] = (
				interaction.build.tool == BuildPlacement.Tool.DEMOLISH
				and interaction.build.cells.has(anchor)
				and not interaction.build.cell_ok.has(true)
				and interaction.build.cost == 5
				and interaction.build.reasons.is_empty()
				and _has_tower(map)
			)
			await snapshot("demolish-before")
	)
	step("check the removal and wood refund")
	await snapshot("demolish-after")
	done(preview[0] and not _has_tower(map) and inventory.count_of(Inventory.WOOD) == initial - 5)


func tower_anchor(map: TileMap, interaction: Interaction) -> Variant:
	## Nearest clear tower spot, then stand the hero beside it.
	var placer := ConstructionPlacer.new(map)
	var origin := map.local_to_map(map.to_local(hero().global_position))
	for r in range(2, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := origin + Vector2i(dx, dy)
				if not placer.can_place_geometry(BuildCosts.TOWER, [cell]).is_empty():
					continue
				hero().global_position = map.to_global(map.map_to_local(cell + Vector2i(0, 3)))
				for _i in 8:
					await process_frame
				if interaction.in_reach(cell):
					return cell
	return null


func _has_tower(map: TileMap) -> bool:
	for placement in map.placed_structures().values():
		if placement["name"] == BuildCosts.NAMED_STRUCTURES[BuildCosts.TOWER]:
			return true
	return false
