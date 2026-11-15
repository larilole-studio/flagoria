extends "res://tests/helpers/test_helpers.gd"
## Building neighbour merge and re-seal (#27).


const W := 6
const H := 5


func _test_building_merge() -> int:
	## Time cost: ~1 s in tools/verify.sh.
	print("-- test_building_merge")
	var fail := 0
	fail += _east_flush()
	fail += _overlap_unchanged()
	fail += _stagger_no_merge()
	fail += _remove_reseals()
	fail += _north_stack_roof()
	fail += _deterministic()
	if fail == 0:
		print("PASS test_building_merge")
	return fail


func _record(x: int, y: int, seed: int) -> Dictionary:
	return {"x": x, "y": y, "width": W, "height": H, "seed": seed, "style": 0}


func _grid(seed: int) -> Array:
	var solved := WfcBuildingConstraints.solve_building(W, H, seed)
	if not solved.ok:
		printerr("FAIL building_merge: seed %s solve %s" % [seed, solved.get("error", "")])
		return []
	return solved.grid


func _east_flush() -> int:
	var fail := 0
	var first := _record(0, 0, 1)
	var second := _record(W, 0, 2)
	var g1 := _grid(1)
	var g2 := _grid(2)
	if g1.is_empty() or g2.is_empty():
		return fail + 1
	var merged := BuildingMerge.merge_grids(first, g1, second, g2)
	if not merged.get("ok", false):
		printerr("FAIL building_merge: east flush merge")
		return fail + 1
	var cx := W
	var err := WfcBuildingConstraints.validate_all(_combined(merged, first, second))
	if err != "":
		printerr("FAIL building_merge: east validate %s" % err)
		fail += 1
	fail += _seam_pairs(first, second, merged.earlier_grid, merged.later_grid)
	return fail


func _combined(merged: Dictionary, _first: Dictionary, _second: Dictionary) -> Array:
	var combined: Array = []
	for y in H:
		combined.append(merged.earlier_grid[y] + merged.later_grid[y])
	return combined


func _seam_pairs(first: Dictionary, second: Dictionary, g1: Array, g2: Array) -> int:
	var fail := 0
	for y in range(1, H - 1):
		var left := str(g1[y][W - 1])
		var right := str(g2[y][0])
		var ring := WfcBuildingConstraints.RING_PIECE_IDS
		if left not in ring and left != "floor" and left != "door":
			printerr("FAIL building_merge: seam left %s,%s piece %s" % [W - 1, y, left])
			fail += 1
		if right != "floor" and right != "door":
			printerr("FAIL building_merge: seam right 0,%s piece %s" % [y, right])
			fail += 1
	return fail


func _overlap_unchanged() -> int:
	var first := _record(0, 0, 3)
	var second := _record(2, 0, 4)
	if not BuildingMerge.rectangles_overlap(first, second):
		printerr("FAIL building_merge: overlap fixture")
		return 1
	var g1 := _grid(3)
	var before := g1.duplicate(true)
	var merged := BuildingMerge.merge_grids(first, g1, second, _grid(4))
	if merged.get("ok", false):
		printerr("FAIL building_merge: overlap should not merge")
		return 1
	for y in H:
		if before[y] != g1[y]:
			printerr("FAIL building_merge: first grid changed on overlap attempt")
			return 1
	return 0


func _stagger_no_merge() -> int:
	var first := _record(0, 0, 5)
	var second := _record(W, 1, 6)
	if BuildingMerge.shares_full_edge(first, second):
		printerr("FAIL building_merge: stagger counted as full edge")
		return 1
	if not BuildingMerge.touches_without_full_edge([first], second):
		printerr("FAIL building_merge: stagger should touch without full edge")
		return 1
	return 0


func _remove_reseals() -> int:
	var first := _record(0, 0, 7)
	var second := _record(W, 0, 8)
	var merged := BuildingMerge.merge_grids(first, _grid(7), second, _grid(8))
	if not merged.get("ok", false):
		printerr("FAIL building_merge: remove prelude merge")
		return 1
	var solo := _grid(7)
	if WfcBuildingConstraints.validate_all(solo) != "":
		printerr("FAIL building_merge: solo ring invalid after removal replay")
		return 1
	var doors := 0
	for y in H:
		for x in W:
			if solo[y][x] == "door":
				doors += 1
	if doors != 1:
		printerr("FAIL building_merge: solo door count %s" % doors)
		return 1
	return 0


func _north_stack_roof() -> int:
	var north := _record(0, 0, 9)
	var south := _record(0, H, 10)
	if not BuildingMerge.shares_full_edge(north, south):
		printerr("FAIL building_merge: north stack not full edge")
		return 1
	var merged := BuildingMerge.merge_grids(north, _grid(9), south, _grid(10))
	if not merged.get("ok", false):
		printerr("FAIL building_merge: north stack merge")
		return 1
	var combined_h := H * 2
	var combined: Array = []
	for y in combined_h:
		var row: Array = []
		for x in W:
			if y < H:
				row.append(merged.earlier_grid[y][x])
			else:
				row.append(merged.later_grid[y - H][x])
		combined.append(row)
	var interior_row: String = str(combined[H][2])
	if interior_row != "floor":
		printerr("FAIL building_merge: south roof interior %s want floor" % interior_row)
		return 1
	if WfcBuildingConstraints.validate_all(combined) != "":
		printerr("FAIL building_merge: north stack validate")
		return 1
	return 0


func _deterministic() -> int:
	var first := _record(0, 0, 1)
	var second := _record(W, 0, 2)
	var a := BuildingMerge.merge_grids(first, _grid(1), second, _grid(2))
	var b := BuildingMerge.merge_grids(first, _grid(1), second, _grid(2))
	if not a.get("ok", false) or not b.get("ok", false):
		printerr("FAIL building_merge: deterministic solve failed")
		return 1
	if a.earlier_grid != b.earlier_grid or a.later_grid != b.later_grid:
		printerr("FAIL building_merge: merged grids differ on repeat")
		return 1
	return 0