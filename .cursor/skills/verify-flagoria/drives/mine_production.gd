extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 4

const BuildDrag := preload("res://.cursor/skills/verify-flagoria/bin/build_drag.gd")
const WorldChunks := preload("res://Scripts/world/world_chunks.gd")
const BUILDINGS := "CanvasLayer1/BuildingsButton"
const MINE_BUTTON := "CanvasLayer1/BuildPicker/MineButton"
const MENU_ROWS := MENU_PANEL + "/Panel/Margin/VBox"


func run() -> void:
	if not await start_game():
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var inventory: Inventory = current_scene.get_node(INVENTORY)
	var hud: ResourceHud = current_scene.find_child("ResourceHud", true, false)
	var center := root.get_visible_rect().get_center()
	var origin := map.local_to_map(map.to_local(interaction.to_world(center)))
	var target: Variant = _find_site(map, interaction, origin)
	if target == null:
		printerr("mine production: no reachable mine site")
		done(false)
		return

	step("grant wood and place a mine through Buildings")
	await click(MENU_BUTTON)
	await click(MENU_ROWS + "/ResourceGrants/AddWood")
	await click(MENU_ROWS + "/Resume")
	await click(BUILDINGS)
	await click(MINE_BUTTON)
	var start := root.get_final_transform() * (center + Vector2(-60, -64))
	var offset := (
		to_window(map, map.map_to_local(target)) - to_window(map, map.map_to_local(origin))
	)
	await BuildDrag.drag_touch(self, start, start + offset, func() -> void: pass)
	var mine: Dictionary = map.structure_placement_at(target)
	if (
		mine.get("name") != "mine"
		or mine.get("owner") != get_multiplayer().get_unique_id()
		or not map.mine_production.is_producing(mine["id"])
		or not _shows_stone(inventory, hud, 0)
	):
		printerr("mine production: placed mine or starting stone HUD is missing")
		done(false)
		return

	step("snapshot the placed mine with zero stone")
	await snapshot("before-cycle")
	step("advance the host world clock by one minute")
	WorldChunks.refresh(map, 60.0)
	var credited := _shows_stone(inventory, hud, 1)
	await snapshot("after-cycle")
	if not credited:
		printerr("mine production: expected one stone in the inventory and HUD")
	done(credited)


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


func _shows_stone(inventory: Inventory, hud: ResourceHud, count: int) -> bool:
	return (
		inventory.count_of(Inventory.STONE) == count
		and hud.stone_label.is_visible_in_tree()
		and hud.stone_label.text == str(count)
	)
