extends "res://tests/helpers/test_helpers.gd"

const MINE := &"mine"
const ROCK_WARNING := "not adjacent to a rock"


func _test_place_mine() -> int:
	print("-- test_place_mine")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var map: TileMap = scene.get_node("World/worldMap")
	var inventory: Inventory = scene.get_node("Inventory")
	inventory.add(Inventory.WOOD, 15)
	inventory.add(Inventory.STONE, 4)
	var placer := ConstructionPlacer.new(map)
	var params := _spawn_params(11, 0.003)
	map.apply_map_params(params)
	var sites := _mine_sites(map)
	var fail := 0
	if sites.is_empty():
		printerr("FAIL place_mine: no fixture sites")
		fail = 1
	else:
		var good: Array[Vector2i] = [sites.good]
		var diagonal: Array[Vector2i] = [sites.diagonal]
		var rock: Array[Vector2i] = [sites.rock]
		if (
			placer.can_place(MINE, diagonal, inventory) != [ROCK_WARNING]
			or ROCK_WARNING not in placer.can_place(MINE, rock, inventory)
			or placer.place(MINE, diagonal, inventory)
			or inventory.count_of(Inventory.WOOD) != 15
		):
			printerr("FAIL place_mine: diagonal or anchor rock qualified")
			fail += 1
		if (
			not placer.can_place(MINE, good, inventory).is_empty()
			or not map.destroy_decor(sites.rock)
			or placer.can_place(MINE, good, inventory) != [ROCK_WARNING]
			or placer.place(MINE, good, inventory)
			or inventory.count_of(Inventory.WOOD) != 15
			or not map.placed_structures().is_empty()
		):
			printerr("FAIL place_mine: destroyed rock qualified")
			fail += 1

		map.apply_map_params(params)
		inventory.spend(Inventory.WOOD, 1)
		if (
			placer.can_place(MINE, good, inventory) != ["not enough wood"]
			or placer.place(MINE, good, inventory)
			or inventory.count_of(Inventory.WOOD) != 14
		):
			printerr("FAIL place_mine: underfunded placement")
			fail += 1
		inventory.add(Inventory.WOOD, 1)
		if (
			placer.footprint_of(MINE, sites.good).size() != 9
			or not placer.place(MINE, good, inventory)
			or inventory.count_of(Inventory.WOOD) != 0
			or inventory.count_of(Inventory.STONE) != 4
			or map.structure_placement_at(sites.good).get("owner") != 1
		):
			printerr("FAIL place_mine: valid placement or charge")
			fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_place_mine")
	return fail


func _mine_sites(map: TileMap) -> Dictionary:
	var rock := Vector2i(19, -58)
	var good := Vector2i(19, -59)
	var diagonal := Vector2i(18, -59)
	if not map.has_live_rock(rock):
		return {}
	return {"good": good, "diagonal": diagonal, "rock": rock}
