class_name BuildingMerge
extends RefCounted
## Re-solve adjacent building footprints so they share a wall (#27).

const MERGE_SOLVE_ATTEMPTS := 8


static func find_merge_neighbour(records: Array, record: Dictionary, before: int = -1) -> int:
	## Lowest-index record that shares a full edge with record, only indices < before.
	var limit := before if before >= 0 else records.size()
	var found := -1
	for i in limit:
		if shares_full_edge(records[i], record):
			found = i
			break
	return found


static func rectangles_overlap(a: Dictionary, b: Dictionary) -> bool:
	var ax := int(a.get("x", 0))
	var ay := int(a.get("y", 0))
	var aw := int(a.get("width", 0))
	var ah := int(a.get("height", 0))
	var bx := int(b.get("x", 0))
	var by := int(b.get("y", 0))
	var bw := int(b.get("width", 0))
	var bh := int(b.get("height", 0))
	if ax + aw <= bx or bx + bw <= ax or ay + ah <= by or by + bh <= ay:
		return false
	var ox := mini(ax + aw, bx + bw) - maxi(ax, bx)
	var oy := mini(ay + ah, by + bh) - maxi(ay, by)
	return ox > 0 and oy > 0


static func shares_full_edge(a: Dictionary, b: Dictionary) -> bool:
	if rectangles_overlap(a, b):
		return false
	var ax := int(a.get("x", 0))
	var ay := int(a.get("y", 0))
	var aw := int(a.get("width", 0))
	var ah := int(a.get("height", 0))
	var bx := int(b.get("x", 0))
	var by := int(b.get("y", 0))
	var bw := int(b.get("width", 0))
	var bh := int(b.get("height", 0))
	if ax + aw == bx and ay == by and ah == bh:
		return true
	if bx + bw == ax and ay == by and ah == bh:
		return true
	if ay + ah == by and ax == bx and aw == bw:
		return true
	if by + bh == ay and ax == bx and aw == bw:
		return true
	return false


static func touches_without_full_edge(records: Array, record: Dictionary) -> bool:
	for existing in records:
		if rectangles_overlap(existing, record):
			return true
		var ax := int(existing.get("x", 0))
		var ay := int(existing.get("y", 0))
		var aw := int(existing.get("width", 0))
		var ah := int(existing.get("height", 0))
		var bx := int(record.get("x", 0))
		var by := int(record.get("y", 0))
		var bw := int(record.get("width", 0))
		var bh := int(record.get("height", 0))
		if ax + aw < bx or bx + bw < ax or ay + ah < by or by + bh < ay:
			continue
		if not shares_full_edge(existing, record):
			return true
	return false


static func merge_seed(earlier: Dictionary, later: Dictionary) -> int:
	return (
		GeneratedBuildings.mix_seed(int(earlier.get("seed", 0)), int(earlier.get("style", 0)))
		^ GeneratedBuildings.mix_seed(int(later.get("seed", 0)), int(later.get("style", 0)))
	)


static func merge_grids(
	earlier: Dictionary,
	earlier_grid: Array,
	later: Dictionary,
	later_grid: Array,
	pieces: Array = [],
) -> Dictionary:
	if earlier_grid.is_empty() or later_grid.is_empty():
		return {"ok": false}
	if not shares_full_edge(earlier, later):
		return {"ok": false}
	if pieces.is_empty():
		for piece: BuildingBlockPiece in BuildingBlockCatalog.all():
			pieces.append(piece)
	var cx := mini(int(earlier.get("x", 0)), int(later.get("x", 0)))
	var cy := mini(int(earlier.get("y", 0)), int(later.get("y", 0)))
	var cw := (
		maxi(
			int(earlier.get("x", 0)) + int(earlier.get("width", 0)),
			int(later.get("x", 0)) + int(later.get("width", 0)),
		)
		- cx
	)
	var ch := (
		maxi(
			int(earlier.get("y", 0)) + int(earlier.get("height", 0)),
			int(later.get("y", 0)) + int(later.get("height", 0)),
		)
		- cy
	)
	var ex := int(earlier.get("x", 0)) - cx
	var ey := int(earlier.get("y", 0)) - cy
	var lx := int(later.get("x", 0)) - cx
	var ly := int(later.get("y", 0)) - cy
	var ew := int(earlier.get("width", 0))
	var eh := int(earlier.get("height", 0))
	var lw := int(later.get("width", 0))
	var lh := int(later.get("height", 0))
	var combined := _stitch(earlier_grid, later_grid, ex, ey, lx, ly, cw, ch, ew, eh, lw, lh)
	var seam := _seam_cells(lx, ly, lw, lh, ex, ey, ew, eh)
	seam.merge(_seam_cells_earlier(ex, ey, ew, eh, lx, ly, lw, lh))
	var allowed := _cell_allowed(combined, seam, cw, ch)
	var solve := WfcSolver.solve(
		cw, ch, pieces, merge_seed(earlier, later), MERGE_SOLVE_ATTEMPTS, allowed
	)
	if solve.get("ok", false):
		var err := WfcBuildingConstraints.validate_all(solve.grid)
		if err == "":
			return {
				"ok": true,
				"earlier_grid": _extract(solve.grid, ex, ey, ew, eh),
				"later_grid": _extract(solve.grid, lx, ly, lw, lh),
			}
	var stitched := _stitch_fallback(combined, seam, cw, ch, merge_seed(earlier, later))
	var err2 := WfcBuildingConstraints.validate_all(stitched)
	if err2 != "":
		return {"ok": false, "error": err2}
	return {
		"ok": true,
		"earlier_grid": _extract(stitched, ex, ey, ew, eh),
		"later_grid": _extract(stitched, lx, ly, lw, lh),
	}


static func _stitch(
	earlier_grid: Array,
	later_grid: Array,
	ex: int,
	ey: int,
	lx: int,
	ly: int,
	cw: int,
	ch: int,
	ew: int,
	eh: int,
	lw: int,
	lh: int,
) -> Array:
	var combined: Array = []
	for y in ch:
		var row: Array = []
		for x in cw:
			row.append("")
		combined.append(row)
	for y in eh:
		for x in ew:
			combined[ey + y][ex + x] = str(earlier_grid[y][x])
	for y in lh:
		for x in lw:
			combined[ly + y][lx + x] = str(later_grid[y][x])
	return combined


static func _seam_cells(
	lx: int, ly: int, lw: int, lh: int, ex: int, ey: int, ew: int, eh: int
) -> Dictionary:
	var seam := {}
	for y in lh:
		for x in lw:
			var wx := lx + x
			var wy := ly + y
			for step: Vector2i in WfcSolver.STEPS:
				var nx := wx + step.x
				var ny := wy + step.y
				var ix := nx - ex
				var iy := ny - ey
				if ix >= 0 and iy >= 0 and ix < ew and iy < eh:
					seam[Vector2i(wx, wy)] = true
					break
	return seam


static func _seam_cells_earlier(
	ex: int, ey: int, ew: int, eh: int, lx: int, ly: int, lw: int, lh: int
) -> Dictionary:
	var seam := {}
	for y in eh:
		for x in ew:
			var wx := ex + x
			var wy := ey + y
			for step: Vector2i in WfcSolver.STEPS:
				var nx := wx + step.x
				var ny := wy + step.y
				var ix := nx - lx
				var iy := ny - ly
				if ix >= 0 and iy >= 0 and ix < lw and iy < lh:
					seam[Vector2i(wx, wy)] = true
					break
	return seam


static func _cell_allowed(combined: Array, seam: Dictionary, cw: int, ch: int) -> Array:
	var allowed: Array = []
	var flex := Vector2i(-1, -1)
	for y in ch:
		var row: Array = []
		for x in cw:
			var cell := Vector2i(x, y)
			var fixed := str(combined[y][x])
			if not seam.has(cell):
				if not WfcBuildingConstraints.is_ring_cell(x, y, cw, ch):
					fixed = "floor"
				row.append([fixed])
			elif not WfcBuildingConstraints.is_ring_cell(x, y, cw, ch):
				row.append(["floor"])
			elif WfcBuildingConstraints.is_north_roof_strip(x, y, cw, ch):
				row.append(["roof_fill"])
			elif _is_combined_corner(x, y, cw, ch):
				row.append(["wall_corner"])
			elif flex.x < 0:
				flex = cell
				row.append(["floor", "door"])
			else:
				row.append(WfcBuildingConstraints.RING_PIECE_IDS.duplicate())
		allowed.append(row)
	return allowed


static func _is_combined_corner(x: int, y: int, cw: int, ch: int) -> bool:
	return (x == 0 or x == cw - 1) and (y == 0 or y == ch - 1)


static func _stitch_fallback(
	combined: Array, seam: Dictionary, cw: int, ch: int, seed: int
) -> Array:
	var out: Array = []
	for y in ch:
		var row: Array = combined[y].duplicate()
		for x in cw:
			var cell := Vector2i(x, y)
			if seam.has(cell):
				if WfcBuildingConstraints.is_north_roof_strip(x, y, cw, ch):
					row[x] = "roof_fill"
				elif not WfcBuildingConstraints.is_ring_cell(x, y, cw, ch):
					row[x] = "floor"
		out.append(row)
	var doors: Array[Vector2i] = []
	for y in ch:
		for x in cw:
			if out[y][x] == "door" and WfcBuildingConstraints.is_ring_cell(x, y, cw, ch):
				doors.append(Vector2i(x, y))
	while doors.size() > 1:
		var drop: Vector2i = doors.pop_back()
		out[drop.y][drop.x] = "wall_straight"
	if doors.is_empty():
		var pick := WfcBuildingConstraints.door_cell_for_seed(cw, ch, seed)
		out[pick.y][pick.x] = "door"
	return out


static func _extract(combined: Array, ox: int, oy: int, w: int, h: int) -> Array:
	var out: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append(str(combined[oy + y][ox + x]))
		out.append(row)
	return out
