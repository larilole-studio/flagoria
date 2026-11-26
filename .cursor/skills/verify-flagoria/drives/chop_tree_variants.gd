## fixture
## launch: --seed 49
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## Paint a regular tree and a continental birch near the spawn, then chop with an aimed attack.


func run() -> void:
	if not await start_game():
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	await toggle_mode()
	step("paint tree variants")
	var origin := map.local_to_map(map.to_local(hero().global_position))
	var regular := origin + Vector2i(-1, -1)
	var birch := origin + Vector2i(1, -1)
	paint_pair(map, origin, regular, birch)
	await snapshot("before")
	if not await chop_and_capture(map, interaction, regular, "regular"):
		done(false)
		return
	done(await chop_and_capture(map, interaction, birch, "birch"))


func paint_pair(map: TileMap, origin: Vector2i, regular: Vector2i, birch: Vector2i) -> void:
	var params := MapGenParams.new()
	params.altitude_seed = 2
	params.moisture_seed = 7
	params.temperature_seed = 12
	params.items_seed = 17
	params.biome_seed = 31
	params.biome_frequency = 0.003
	params.spawn_biome = BiomeCatalog.CONTINENTAL
	map.apply_map_params(params)
	map.set_process(false)
	for y in range(-4, 5):
		for x in range(-4, 5):
			var cell := origin + Vector2i(x, y)
			map.set_cell(0, cell, TileCatalog.SOURCE_ID, TileCatalog.GRASS_A)
			map.erase_cell(1, cell)
			map.erase_cell(map.GROUND_DECOR_LAYER, cell)
	map.set_cell(1, regular, TileCatalog.SOURCE_ID, TileCatalog.TREE)
	map.set_cell(1, birch, TileCatalog.SOURCE_ID, TileCatalog.TREE_BIRCH_BOTTOM)
	map.set_cell(1, birch + Vector2i.UP, TileCatalog.SOURCE_ID, TileCatalog.TREE_BIRCH_TOP)


func chop_and_capture(
	map: TileMap, interaction: Interaction, cell: Vector2i, label: String
) -> bool:
	step("chop " + label)
	await aim_chop(map, cell)
	if not await wait_until(
		func() -> bool: return map.get_cell_alternative_tile(1, cell) == ChopAction.HIDDEN_ALT, 2.0
	):
		printerr("chop tree variants: no hit sheet on " + label)
		return false
	await snapshot(label + "-hit")
	if not await wait_until(
		func() -> bool:
			return map.get_cell_atlas_coords(map.GROUND_DECOR_LAYER, cell) == TileCatalog.STUMP,
		2.0
	):
		printerr("chop tree variants: no stump on " + label)
		return false
	await snapshot(label + "-fall")
	return await wait_until(func() -> bool: return not interaction.chopping(), 2.0)


func aim_chop(map: TileMap, cell: Vector2i) -> void:
	var button: CanvasItem = current_scene.get_node("CanvasLayer1/TouchScreenButton")
	var start := to_window(button, button._shape_center())
	var player := hero()
	var toward := map.to_global(map.map_to_local(cell)) - player.global_position
	var beyond := player.global_position + toward + toward.normalized() * 8.0
	var offset := to_window(player, player.to_local(beyond)) - to_window(player, Vector2.ZERO)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = start
	Input.parse_input_event(press)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.position = start + offset
	drag.relative = offset
	Input.parse_input_event(drag)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.position = drag.position
	Input.parse_input_event(release)
