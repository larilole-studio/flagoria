extends "res://tests/helpers/test_helpers.gd"

const TREE_WARNING := "not adjacent to a tree"
const ANCHOR := Vector2i(19, -59)
const UNPAINTED_ANCHOR := Vector2i(31, -60)


func _test_place_sawmill() -> int:
	print("-- test_place_sawmill")
	var scene := mount_main_scene()
	var world: TileMap = scene.get_node("World/worldMap")
	var inventory: Inventory = scene.get_node("Inventory")
	world.apply_map_params(_spawn_params(11, 0.003))
	var placer := ConstructionPlacer.new(world)
	var fail := 0
	if (
		world.is_drawn(UNPAINTED_ANCHOR + Vector2i.DOWN)
		or not placer.can_place_geometry(BuildCosts.SAWMILL, [UNPAINTED_ANCHOR]).is_empty()
	):
		printerr("FAIL place_sawmill: unpainted live tree site was refused")
		fail += 1
	world.generate_chunk(world.map_to_local(ANCHOR))
	inventory.add(Inventory.STONE, 15)
	inventory.add(Inventory.WOOD, 4)
	var anchor: Array[Vector2i] = [ANCHOR]
	var edge := ANCHOR + Vector2i.DOWN
	for fixture in [
		[edge, Vector2i(-1, -1)],
		[edge + Vector2i.LEFT, TileCatalog.TREE],
		[edge, TileCatalog.BUSH],
		[ANCHOR, TileCatalog.TREE],
	]:
		var cell: Vector2i = fixture[0]
		if fixture[1] != Vector2i(-1, -1):
			world.set_cell(1, cell, TileCatalog.SOURCE_ID, fixture[1])
		if not _sawmill_refuses(placer, inventory, anchor):
			printerr("FAIL place_sawmill: non-adjacent fixture qualified: ", fixture)
			fail += 1
		world.erase_cell(1, cell)

	world.set_cell(1, edge, TileCatalog.SOURCE_ID, TileCatalog.TREE)
	if (
		not world.has_tree(edge)
		or not placer.can_place(BuildCosts.SAWMILL, anchor, inventory).is_empty()
		or world.cut_choppable(edge) == null
		or world.has_tree(edge)
		or not _sawmill_refuses(placer, inventory, anchor)
		or not world.placed_structures().is_empty()
	):
		printerr("FAIL place_sawmill: live tree or chopped stump geometry")
		fail += 1

	world.set_cell(1, edge, TileCatalog.SOURCE_ID, TileCatalog.PINE)
	inventory.spend(Inventory.STONE, 1)
	if (
		not world.has_tree(edge)
		or placer.can_place(BuildCosts.SAWMILL, anchor, inventory) != ["not enough stone"]
		or placer.place(BuildCosts.SAWMILL, anchor, inventory)
		or BuildCosts.balance(inventory) != Vector2i(4, 14)
	):
		printerr("FAIL place_sawmill: underfunded placement")
		fail += 1
	inventory.add(Inventory.STONE, 1)
	if (
		placer.footprint_of(BuildCosts.SAWMILL, ANCHOR).size() != 6
		or not placer.place(BuildCosts.SAWMILL, anchor, inventory)
		or BuildCosts.balance(inventory) != Vector2i(4, 0)
		or world.structure_placement_at(ANCHOR).get("owner") != 1
		or not world.has_tree(edge)
	):
		printerr("FAIL place_sawmill: valid pine site, owner, footprint or charge")
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_place_sawmill")
	return fail


func _sawmill_refuses(
	placer: ConstructionPlacer, inventory: Inventory, anchor: Array[Vector2i]
) -> bool:
	return (
		placer.can_place(BuildCosts.SAWMILL, anchor, inventory) == [TREE_WARNING]
		and not placer.place(BuildCosts.SAWMILL, anchor, inventory)
		and BuildCosts.balance(inventory) == Vector2i(4, 15)
	)
