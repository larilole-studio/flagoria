extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 4

const BuildDrag := preload("res://.cursor/skills/verify-flagoria/bin/build_drag.gd")
const BUILDINGS := "CanvasLayer1/BuildingsButton"
const SAWMILL_BUTTON := "CanvasLayer1/BuildPicker/SawmillButton"
const MENU_ROWS := MENU_PANEL + "/Panel/Margin/VBox"
const TREE_WARNING := "not adjacent to a tree"


func run() -> void:
	if not await start_game():
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var hud: ResourceHud = current_scene.find_child("ResourceHud", true, false)
	var build := interaction.build
	var sites := _sites(map, interaction)
	for action in ["ui_down", "ui_right", "ui_up", "ui_left", "ui_left", "ui_down"]:
		if not sites.is_empty():
			break
		await _walk(action)
		sites = _sites(map, interaction)
	if sites.is_empty():
		printerr("place sawmill: no reachable tree edge and corner sites")
		done(false)
		return

	step("open Buildings and select Sawmill")
	await click(BUILDINGS)
	await snapshot("sawmill-picker")
	await click(SAWMILL_BUTTON)
	var center := root.get_visible_rect().get_center()
	var tile_size := Vector2(map.tile_set.tile_size) * map.global_scale * root.get_camera_2d().zoom
	if (
		build.tool != BuildPlacement.Tool.SAWMILL
		or build.cells.size() != 6
		or build.cost_viewport.distance_to(center) > tile_size.length() * 0.5
	):
		printerr("place sawmill: preview did not start at the center cell")
		done(false)
		return

	var before: int = map.placed_structures().size()
	step("refuse an edge site without stone")
	var underfunded := [false]
	await _drag(
		map,
		interaction,
		sites.good,
		func() -> void:
			underfunded[0] = build.reasons == ["not enough stone"]
			if not underfunded[0]:
				printerr(
					"underfunded target ", sites.good, " preview ", build.cells, " ", build.reasons
				)
	)
	if (
		not underfunded[0]
		or map.placed_structures().size() != before
		or hud.stone_label.text != "0"
	):
		printerr("place sawmill: underfunded preview or refusal failed")
		done(false)
		return

	step("fill resources through the game menu")
	await click(MENU_BUTTON)
	await click(MENU_ROWS + "/ResourceGrants/MaxResources")
	await click(MENU_ROWS + "/Resume")

	step("refuse the corner site")
	var refused := [false]
	await _drag(
		map,
		interaction,
		sites.diagonal,
		func() -> void:
			refused[0] = build.reasons == [TREE_WARNING] and not build.cell_ok.has(true)
			await snapshot("sawmill-adjacency-refused")
	)
	if not refused[0] or map.placed_structures().size() != before or hud.stone_label.text != "999":
		printerr("place sawmill: diagonal preview or refusal failed")
		done(false)
		return

	step("place beside the tree")
	var first: Vector2i = sites.good
	var priced := [false]
	await _drag(
		map,
		interaction,
		first,
		func() -> void:
			priced[0] = (
				build.price == Vector2i(0, 15)
				and build.reasons.is_empty()
				and not build.cell_ok.has(false)
			)
			await snapshot("sawmill-ready-preview")
	)
	await snapshot("sawmill-placed")
	if not priced[0] or not _placed(map, hud, first, "984"):
		printerr("place sawmill: valid preview, owner or charge failed")
		done(false)
		return

	done(await _place_on_other_ground(map, interaction, hud, first))


func _place_on_other_ground(
	map: TileMap, interaction: Interaction, hud: ResourceHud, first: Vector2i
) -> bool:
	step("place on different generated ground")
	var first_ground: Vector2i = map.get_cell_atlas_coords(0, first)
	var second: Variant = _site_on_other_ground(map, interaction, first_ground)
	for action in ["ui_down", "ui_right", "ui_up", "ui_left", "ui_left", "ui_down"]:
		if second != null:
			break
		await _walk(action)
		second = _site_on_other_ground(map, interaction, first_ground)
	if second == null:
		printerr("place sawmill: no reachable site on a different ground tile")
		return false
	await _drag(map, interaction, second)
	await snapshot("sawmill-placed-other-ground")
	return _placed(map, hud, second, "969")


func _sites(map: TileMap, interaction: Interaction) -> Dictionary:
	var placer := ConstructionPlacer.new(map)
	for good in _nearby_cells(map, interaction):
		var tree := good + Vector2i.DOWN
		if (
			not map.has_tree(tree)
			or not placer.can_place_geometry(BuildCosts.SAWMILL, [good]).is_empty()
		):
			continue
		for offset in [Vector2i.LEFT, Vector2i.RIGHT]:
			var diagonal: Vector2i = good + offset
			if (
				interaction.in_reach(diagonal)
				and placer.can_place_geometry(BuildCosts.SAWMILL, [diagonal]) == [TREE_WARNING]
			):
				return {"good": good, "diagonal": diagonal}
	return {}


func _site_on_other_ground(
	map: TileMap, interaction: Interaction, first_ground: Vector2i
) -> Variant:
	var placer := ConstructionPlacer.new(map)
	for cell in _nearby_cells(map, interaction):
		if (
			map.get_cell_atlas_coords(0, cell) != first_ground
			and map.has_tree(cell + Vector2i.DOWN)
			and placer.can_place_geometry(BuildCosts.SAWMILL, [cell]).is_empty()
		):
			return cell
	return null


func _walk(action: String) -> void:
	await hold(action, 40)
	var player := hero() as CharacterBody2D
	await wait_until(func() -> bool: return player.velocity == Vector2.ZERO, 2.0)
	await physics_frame
	await process_frame


func _nearby_cells(map: TileMap, interaction: Interaction) -> Array[Vector2i]:
	var origin := _center_cell(map, interaction)
	var cells: Array[Vector2i] = []
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var cell := origin + Vector2i(dx, dy)
			if interaction.in_reach(cell):
				cells.append(cell)
	return cells


func _center_cell(map: TileMap, interaction: Interaction) -> Vector2i:
	return map.local_to_map(
		map.to_local(interaction.to_world(root.get_visible_rect().get_center()))
	)


func _placed(map: TileMap, hud: ResourceHud, anchor: Vector2i, stone: String) -> bool:
	var placement: Dictionary = map.structure_placement_at(anchor)
	return (
		placement.get("name") == "sawmill"
		and placement.get("owner") == get_multiplayer().get_unique_id()
		and map.has_tree(anchor + Vector2i.DOWN)
		and hud.label.text == "999"
		and hud.stone_label.text == stone
	)


func _drag(map: TileMap, interaction: Interaction, target: Vector2i, inspect := Callable()) -> void:
	var center := root.get_visible_rect().get_center()
	var start := root.get_final_transform() * (center + Vector2(-60, -64))
	var origin := _center_cell(map, interaction)
	if interaction.build.has_pointer_origin():
		origin = map.local_to_map(
			map.to_local(interaction.to_world(interaction.build.cost_viewport))
		)
	var offset := (
		to_window(map, map.map_to_local(target)) - to_window(map, map.map_to_local(origin))
	)
	await BuildDrag.drag_touch(self, start, start + offset, inspect)
