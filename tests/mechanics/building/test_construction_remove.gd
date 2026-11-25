extends "res://tests/helpers/test_helpers.gd"

const WorldMap := preload("res://Scripts/world/TileMap.gd")

const TOWER := Vector2i(-34, -35)
const WALL := Vector2i(-20, -28)
const PLANK := Vector2i(-29, -28)
const EXTRA_CASTLE := Vector2i(23, -30)


func _test_construction_remove() -> int:
	print("-- test_construction_remove")
	var scene := mount_seeded_tree_world(11, 0.0)
	var map := scene.get_node("World/worldMap") as WorldMap
	var inventory: Inventory = scene.get_node("Inventory")
	var remover := ConstructionRemover.new(map)
	var tower := StructurePlacer.load_named("tower_wood")
	var tap := TOWER + Vector2i.UP
	var original_ground: Vector2i = map.predict_cell(TOWER)[0]
	var fail := 0
	for owner in [2, StructurePlacer.OWNER_NEUTRAL, StructurePlacer.OWNER_MOBS, 1]:
		map.replace_structures([["tower_wood", owner, TOWER, 1]])
		var target := remover.target_at(tap, 1)
		if (
			owner != 1
			and (
				target["reason"] != "not yours" or not remover.remove(tap, 1, inventory).is_empty()
			)
		):
			printerr("FAIL construction_remove: removed tower owned by ", owner)
			fail += 1
	map.generate_chunk(map.map_to_local(TOWER))
	var tower_cells: Array = remover.target_at(tap, 1)["cells"]
	var registry: Node = map.get_parent().get_node(FootprintOrientation.LAYER_NAME)
	if (
		tower_cells.size() != 9
		or remover.remove(tap, 1, inventory).is_empty()
		or inventory.count_of(Inventory.WOOD) != 5
		or not map.placed_structures().is_empty()
		or not map.auto_structure_cells().is_empty()
		or map.get_cell_atlas_coords(0, TOWER) != original_ground
		or map.get_cell_source_id(1, tap) != -1
		or not map.can_place_structure(tower, TOWER, 1).is_empty()
	):
		printerr("FAIL construction_remove: tower footprint, flag or refund survived removal")
		fail += 1
	await process_frame
	if registry.get_child_count() != 0:
		printerr("FAIL construction_remove: tower facing marker survived")
		fail += 1
	if (
		not map.place_wall_cells([WALL, WALL + Vector2i.RIGHT])
		or not map.build_bridge(PLANK, PLANK + Vector2i.LEFT)
		or remover.remove(WALL, 2, inventory).is_empty()
		or remover.remove(PLANK, 2, inventory).is_empty()
		or not remover.remove(WALL, 2, inventory).is_empty()
		or map.has_wall(WALL)
		or map.has_bridge(PLANK)
		or inventory.count_of(Inventory.WOOD) != 6
	):
		printerr("FAIL construction_remove: wall/plank removal, repeat request or refund")
		fail += 1
	var start := Vector2i.MAX
	if not map.place_start_castle(1):
		printerr("FAIL construction_remove: could not place starting castle")
		fail += 1
	else:
		start = map.resolve_player_spawn() - StartCastle.GATE_FRONT
		if (
			remover.target_at(start, 1)["reason"] != "start castle"
			or not remover.remove(start, 1, inventory).is_empty()
		):
			printerr("FAIL construction_remove: starting castle was removable")
			fail += 1
	if (
		map.place_structure(StartCastle.structure(), EXTRA_CASTLE, 1, 1) <= 0
		or remover.target_at(EXTRA_CASTLE, 1)["reason"] != ""
	):
		printerr("FAIL construction_remove: extra castle was treated as a starting castle")
		fail += 1
	var structures := StructureSaves.to_changes(map)
	var bridges := BridgeBuilder.to_changes(map.bridges_for_sync())
	generate_seeded_chunk(map, 11, 0.0)
	StructureSaves.restore(structures, map)
	map.replace_bridges(BridgeBuilder.from_changes(bridges, map))
	if (
		not map.structure_placement_at(TOWER).is_empty()
		or map.has_wall(WALL)
		or map.has_bridge(PLANK)
		or not map.has_wall(WALL + Vector2i.RIGHT)
		or not map.has_bridge(PLANK + Vector2i.LEFT)
		or remover.target_at(start, 1)["reason"] != "start castle"
		or remover.target_at(EXTRA_CASTLE, 1)["reason"] != ""
	):
		printerr("FAIL construction_remove: saved changes did not preserve remaining cells")
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_construction_remove")
	return fail
