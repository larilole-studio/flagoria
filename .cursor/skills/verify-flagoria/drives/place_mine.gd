extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 4

const BuildDrag := preload("res://.cursor/skills/verify-flagoria/bin/build_drag.gd")
const BUILDINGS := "CanvasLayer1/BuildingsButton"
const MINE_BUTTON := "CanvasLayer1/BuildPicker/MineButton"
const MENU_ROWS := MENU_PANEL + "/Panel/Margin/VBox"
const ROCK_WARNING := "not adjacent to a rock"


func run() -> void:
	if not await start_game():
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var inventory: Inventory = current_scene.get_node(INVENTORY)
	var hud: ResourceHud = current_scene.find_child("ResourceHud", true, false)
	var build := interaction.build
	var center := root.get_visible_rect().get_center()
	var origin := map.local_to_map(map.to_local(interaction.to_world(center)))
	var sites := _sites(map, interaction, origin)
	if sites.is_empty():
		printerr("place mine: no reachable clear mine and diagonal sites near %s" % origin)
		done(false)
		return

	step("open Buildings and select Mine")
	await click(BUILDINGS)
	await snapshot("mine-picker")
	await click(MINE_BUTTON)
	var center_cell := interaction.get_canvas_transform() * interaction.cell_center(origin)
	if (
		build.tool != BuildPlacement.Tool.MINE
		or build.cells.size() != 9
		or not build.cost_viewport.is_equal_approx(center_cell)
	):
		printerr("place mine: preview did not start at the center cell")
		done(false)
		return

	var before: int = map.placed_structures().size()
	step("refuse the adjacent site without wood")
	var underfunded := [false]
	await _drag(
		map,
		center,
		origin,
		sites.good,
		func() -> void: underfunded[0] = build.reasons == ["not enough wood"]
	)
	if not underfunded[0] or map.placed_structures().size() != before or hud.label.text != "0":
		printerr("place mine: underfunded preview or refusal failed")
		done(false)
		return

	step("grant wood through the game menu")
	await click(MENU_BUTTON)
	await click(MENU_ROWS + "/ResourceGrants/AddWood")
	await click(MENU_ROWS + "/Resume")

	step("refuse a clear mine site when the rock only touches a corner")
	var refused := [false]
	await _drag(
		map,
		center,
		origin,
		sites.diagonal,
		func() -> void:
			refused[0] = build.reasons == [ROCK_WARNING] and not build.cell_ok.has(true)
			await snapshot("mine-adjacency-refused")
	)
	if not refused[0] or map.placed_structures().size() != before or hud.label.text != "100":
		printerr("place mine: diagonal preview or refusal failed")
		done(false)
		return

	step("place beside the rock")
	var priced := [false]
	await _drag(
		map,
		center,
		origin,
		sites.good,
		func() -> void:
			priced[0] = (
				build.cost == 15 and build.reasons.is_empty() and not build.cell_ok.has(false)
			)
			await snapshot("mine-ready-preview")
	)
	var mine: Dictionary = map.structure_placement_at(sites.good)
	var placed: bool = (
		priced[0]
		and mine.get("name") == "mine"
		and mine.get("owner") == get_multiplayer().get_unique_id()
		and map.placed_structures().size() == before + 1
		and map.has_live_rock(sites.good + Vector2i.DOWN)
		and inventory.count_of(Inventory.WOOD) == 85
		and inventory.count_of(Inventory.STONE) == 0
		and hud.label.text == "85"
	)
	if not placed:
		printerr("place mine: valid preview, owner or charge failed")
	await snapshot("mine-placed")
	done(placed)


func _sites(map: TileMap, interaction: Interaction, origin: Vector2i) -> Dictionary:
	var placer := ConstructionPlacer.new(map)
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var good := origin + Vector2i(dx, dy)
			if (
				not interaction.in_reach(good)
				or not map.has_live_rock(good + Vector2i.DOWN)
				or not placer.can_place_geometry(BuildCosts.MINE, [good]).is_empty()
			):
				continue
			for side in [Vector2i.LEFT, Vector2i.RIGHT]:
				var diagonal: Vector2i = good + side
				if (
					interaction.in_reach(diagonal)
					and placer.can_place_geometry(BuildCosts.MINE, [diagonal]) == [ROCK_WARNING]
				):
					return {"good": good, "diagonal": diagonal}
	return {}


func _drag(
	map: TileMap, center: Vector2, origin: Vector2i, target: Vector2i, inspect: Callable
) -> void:
	var start := root.get_final_transform() * (center + Vector2(-60, -64))
	var offset := (
		to_window(map, map.map_to_local(target)) - to_window(map, map.map_to_local(origin))
	)
	await BuildDrag.drag_touch(self, start, start + offset, inspect)
