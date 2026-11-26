class_name ConstructionPlacer
extends RefCounted
## Shared construction placement (#296): one API for every buildable kind.
## The preview, local purchase and host-authoritative write share placement
## rules and costs. Interaction transports plank requests (#297);
## StructureRequests transports the other builds (#497, #498).

const _WorldMap := preload("res://Scripts/world/TileMap.gd")

const MAX_PLANK_RUN := 10

const TOO_LONG := "too long"
const WRONG_GROUND := "wrong ground"
const OCCUPIED := "occupied"
const NOT_ADJACENT := "not adjacent"
const NOT_ADJACENT_TO_ROCK := "not adjacent to a rock"
const NOT_STRAIGHT := "not straight"
const EMPTY_CELLS := "empty cells"
const NOT_ENOUGH_WOOD := BuildCosts.NOT_ENOUGH_WOOD
const MULTIPLAYER_ON := BuildCosts.MULTIPLAYER_ON
const UNKNOWN_KIND := BuildCosts.UNKNOWN_KIND

const TOWER_STRUCTURE := BuildCosts.NAMED_STRUCTURES[BuildCosts.TOWER]
const CASTLE_STRUCTURE := BuildCosts.NAMED_STRUCTURES[BuildCosts.CASTLE]
const GUARD_STRUCTURE := BuildCosts.NAMED_STRUCTURES[BuildCosts.GUARD_POST]
const BARRACKS_STRUCTURE := BuildCosts.NAMED_STRUCTURES[BuildCosts.BARRACKS]

const _REASON_ORDER := [
	EMPTY_CELLS,
	UNKNOWN_KIND,
	TOO_LONG,
	WRONG_GROUND,
	OCCUPIED,
	NOT_STRAIGHT,
	NOT_ADJACENT,
	NOT_ADJACENT_TO_ROCK,
	NOT_ENOUGH_WOOD,
	MULTIPLAYER_ON,
]

var _map: _WorldMap
var _named: Dictionary = {}  ## Kind -> parsed Structure, loaded once per placer.


func _init(map: _WorldMap) -> void:
	_map = map


func can_place(
	kind: StringName, cells: Array[Vector2i], inventory: Inventory, quarter_turns: int = 0
) -> Array[String]:
	## Why `kind` cannot go on `cells`; empty when it can. Each reason appears
	## once, in `_REASON_ORDER`. Affordability and multiplayer come from BuildCosts.
	## A tower takes exactly one cell (its anchor); a plank or wall run takes
	## every cell in `cells`.
	var reasons := can_place_geometry(kind, cells, quarter_turns)
	if not cells.is_empty() and _can_build(kind):
		var why := BuildCosts.refusal(inventory, kind, _units(kind, cells))
		if why != "":
			reasons.append(why)
	return reasons


func can_place_geometry(
	kind: StringName, cells: Array[Vector2i], quarter_turns: int = 0
) -> Array[String]:
	## Why `kind` cannot go on `cells` from the map alone (no resource or
	## multiplayer gate). Used for previews and host-authoritative writes.
	var found := {}
	if cells.is_empty():
		found[EMPTY_CELLS] = true
	if not _can_build(kind):
		found[UNKNOWN_KIND] = true
	elif kind == BuildCosts.PLANK:
		_check_plank(cells, found)
	elif kind == BuildCosts.WALL_BLOCK:
		_check_wall(cells, found)
	else:
		_check_named(kind, cells, found, quarter_turns)
	return _ordered(found)


func plank_ends(cells: Array[Vector2i]) -> Array[Vector2i]:
	## `[from, to]` for a straight contiguous run, or empty when bent.
	return _straight_ends(cells)


func cost(kind: StringName, cells: Array) -> int:
	## Wood for placing `kind` on `cells`; -1 for an unknown kind. A tower is
	## always one unit regardless of footprint size; a wall block is one unit per cell.
	return BuildCosts.cost(kind, _units(kind, cells))


func price(kind: StringName, cells: Array) -> Vector2i:
	return BuildCosts.price(kind, _units(kind, cells))


func place(
	kind: StringName, cells: Array[Vector2i], inventory: Inventory, quarter_turns: int = 0
) -> bool:
	## True when the purchase succeeds or a connected client submits a request.
	## A refused writer refunds the charge (#380).
	if not can_place(kind, cells, inventory, quarter_turns).is_empty():
		return false
	if kind != BuildCosts.PLANK and Interaction.multiplayer_on(_map.multiplayer):
		var requests := _map.get_node_or_null("../StructureRequests")
		return requests != null and requests.place(kind, cells, quarter_turns)
	var owner := (
		0
		if kind == BuildCosts.PLANK or kind == BuildCosts.WALL_BLOCK
		else inventory.multiplayer.get_unique_id()
	)
	return _purchase(kind, cells, inventory, owner, quarter_turns, false)


func place_for_peer(
	kind: StringName,
	cells: Array[Vector2i],
	owner: int,
	inventory: Inventory,
	quarter_turns: int = 0
) -> bool:
	## Host-only write after reach checks. Supply inventory for the host's own
	## purchase; a remote buyer is charged by the request handler after success.
	if not _map.multiplayer.is_server() or not _can_build(kind) or cells.is_empty():
		return false
	if (
		kind == BuildCosts.PLANK
		and inventory != null
		and not can_place(kind, cells, inventory).is_empty()
	):
		return false
	return _purchase(
		kind, cells, inventory, owner, quarter_turns, kind != BuildCosts.PLANK or inventory == null
	)


func apply_replica(
	structure_name: String,
	anchor: Vector2i,
	owner: int,
	quarter_turns: int,
	placement_id: int,
	start_castle: bool
) -> void:
	var turns := posmod(quarter_turns, 4)
	for entry in _map.placed_structures().values():
		if (
			str(entry["name"]) == structure_name
			and int(entry["owner"]) == owner
			and entry["anchor"] == anchor
			and int(entry.get("rotation", 0)) == turns
		):
			return
	var structure := StructurePlacer.load_named(structure_name)
	if structure != null:
		var id := _map._structures.place_from_host(
			structure, anchor, owner, quarter_turns, placement_id
		)
		if start_castle:
			_map._structures.mark_start_castle(id)


func _purchase(
	kind: StringName,
	cells: Array[Vector2i],
	inventory: Inventory,
	owner: int,
	turns: int,
	from_host: bool
) -> bool:
	var write := func() -> bool:
		if from_host and not can_place_geometry(kind, cells, turns).is_empty():
			return false
		match kind:
			BuildCosts.PLANK:
				var ends := _straight_ends(cells)
				return not ends.is_empty() and _map.build_bridge(ends[0], ends[1])
			BuildCosts.WALL_BLOCK:
				return _map.place_wall_cells(cells)
			_:
				var structure := _load_named(kind)
				if structure == null:
					return false
				if from_host:
					return _map._structures.place_from_host(structure, cells[0], owner, turns) > 0
				return _map.place_structure(structure, cells[0], owner, turns) > 0
	if inventory == null:
		return write.call()
	return BuildCosts.buy(inventory, kind, _units(kind, cells), write) == ""


static func named_structure_file(kind: StringName) -> String:
	## Structure text file for a one-cell footprint buildable kind.
	return BuildCosts.NAMED_STRUCTURES.get(kind, "")


static func _can_build(kind: StringName) -> bool:
	return kind == BuildCosts.PLANK or BuildCosts.is_requestable(kind)


func _load_named(kind: StringName) -> Structure:
	if not _named.has(kind):
		_named[kind] = StructurePlacer.load_named(named_structure_file(kind))
	return _named[kind]


func footprint_of(
	kind: StringName, anchor_cell: Vector2i, quarter_turns: int = 0
) -> Array[Vector2i]:
	## Map cells a named footprint structure would cover with its anchor on `anchor_cell`.
	var structure := _load_named(kind)
	if structure == null:
		return []
	structure = Structure.rotated(structure, quarter_turns)
	var out: Array[Vector2i] = []
	for cell: Vector2i in StructurePlacer.footprint(structure, anchor_cell):
		out.append(cell)
	return out


func tower_footprint(anchor_cell: Vector2i, quarter_turns: int = 0) -> Array[Vector2i]:
	return footprint_of(BuildCosts.TOWER, anchor_cell, quarter_turns)


func castle_footprint(anchor_cell: Vector2i, quarter_turns: int = 0) -> Array[Vector2i]:
	return footprint_of(BuildCosts.CASTLE, anchor_cell, quarter_turns)


func guard_footprint(anchor_cell: Vector2i, quarter_turns: int = 0) -> Array[Vector2i]:
	return footprint_of(BuildCosts.GUARD_POST, anchor_cell, quarter_turns)


func _units(kind: StringName, cells: Array) -> int:
	return 1 if BuildCosts.NAMED_STRUCTURES.has(kind) else cells.size()


func _check_wall(cells: Array[Vector2i], found: Dictionary) -> void:
	## Land only; refuse structures, existing walls, players, mobs, trees and
	## bushes. A multi-cell run must be one contiguous H/V segment (no gaps,
	## no bends). Every placement must 4-touch an existing wall, tower or
	## castle so the first block cannot float free (design decision for #276);
	## tip adjacency is still enforced by BuildPlacement before place.
	if cells.is_empty():
		return
	if cells.size() > 1 and _straight_ends(cells).is_empty():
		found[NOT_STRAIGHT] = true
	if not _run_touches_wall_or_structure(cells):
		found[NOT_ADJACENT] = true
	for cell in cells:
		if _map.has_wall(cell) or _map._structures.has_cell(cell):
			found[OCCUPIED] = true
			continue
		var p: Array = _map.predict_cell(cell)
		if not _map.ground_is_walkable(p[0]) or _map.has_bridge(cell):
			found[WRONG_GROUND] = true
			continue
		if (
			p[1] == TileCatalog.TREE
			or p[1] == TileCatalog.TREE_BUSHY
			or p[1] == TileCatalog.PINE
			or p[1] == TileCatalog.TREE_BIRCH_BOTTOM
			or p[1] == TileCatalog.TREE_BIRCH_TOP
			or p[1] == TileCatalog.BUSH
		):
			found[OCCUPIED] = true
		elif _map.player_on_cell(cell) or _map.mob_on_cell(cell):
			found[OCCUPIED] = true


func _check_plank(cells: Array[Vector2i], found: Dictionary) -> void:
	## Water only; an existing plank, wall or structure cell, or a player or
	## mob overlapping a cell, is occupied (#380 item 2).
	if cells.is_empty():
		return
	if cells.size() > MAX_PLANK_RUN:
		found[TOO_LONG] = true
	for cell in cells:
		if _map.has_bridge(cell) or _map.has_wall(cell) or _map._structures.has_cell(cell):
			found[OCCUPIED] = true
		elif _map.predict_cell(cell)[0] != TileCatalog.WATER:
			found[WRONG_GROUND] = true
		elif _map.player_on_cell(cell) or _map.mob_on_cell(cell):
			found[OCCUPIED] = true
	if _straight_ends(cells).is_empty():
		found[NOT_STRAIGHT] = true
	elif not _run_touches_support(cells):
		found[NOT_ADJACENT] = true


func _check_named(
	kind: StringName, cells: Array[Vector2i], found: Dictionary, quarter_turns: int = 0
) -> void:
	## Anchor must be exactly one cell; StructurePlacer reasons map onto the
	## shared vocabulary (land only, no overlap with structures/players/mobs).
	if cells.size() != 1:
		found[EMPTY_CELLS] = true
		return
	var structure := _load_named(kind)
	if structure == null:
		found[UNKNOWN_KIND] = true
		return
	if kind == BuildCosts.MINE:
		_check_mine(structure, cells[0], found, quarter_turns)
	for reason in _map.can_place_structure(structure, cells[0], quarter_turns):
		if reason == StructurePlacer.MULTIPLAYER_ON:
			continue  # StructureRequests is the multiplayer gate (#497).
		if reason == StructurePlacer.WATER or reason == StructurePlacer.OUT_OF_MAP:
			found[WRONG_GROUND] = true
		elif (
			reason
			in [
				StructurePlacer.TREE,
				StructurePlacer.BUSH,
				StructurePlacer.OVERLAPS_STRUCTURE,
				StructurePlacer.OVERLAPS_PLAYER,
				StructurePlacer.OVERLAPS_MOB,
			]
		):
			found[OCCUPIED] = true


func _check_mine(
	structure: Structure, anchor: Vector2i, found: Dictionary, quarter_turns: int
) -> void:
	if not _neighbours(anchor).any(_map.has_live_rock):
		found[NOT_ADJACENT_TO_ROCK] = true
	var rotated := Structure.rotated(structure, quarter_turns)
	for cell: Vector2i in StructurePlacer.footprint(rotated, anchor):
		if _map.has_wall(cell):
			found[OCCUPIED] = true
			break


func _run_touches_wall_or_structure(cells: Array[Vector2i]) -> bool:
	## True when at least one cell in the run 4-touches an existing wall or
	## structure (tower / castle). Used so the first wall block cannot float.
	for cell in cells:
		for n in _neighbours(cell):
			if _map.has_wall(n) or _map._structures.has_cell(n):
				return true
	return false


func _run_touches_support(cells: Array[Vector2i]) -> bool:
	## True when at least one cell in the run touches land or an existing plank
	## (4-neighbour). A floating run over open water is refused (#296 update
	## 2026-11-02): no floating planks.
	for cell in cells:
		for n in _neighbours(cell):
			if _map.has_bridge(n) or _is_land(n):
				return true
	return false


func _is_land(cell: Vector2i) -> bool:
	## Walkable generated ground that is not already a plank.
	return not _map.has_bridge(cell) and _map.ground_is_walkable(_map.predict_cell(cell)[0])


func _straight_ends(cells: Array[Vector2i]) -> Array[Vector2i]:
	## `[from, to]` for one contiguous axis-aligned run, or empty when the
	## cells are bent, gapped or duplicated. One cell is a run of itself.
	if cells.is_empty():
		return []
	var seen := {}
	for c in cells:
		if seen.has(c):
			return []
		seen[c] = true
	if cells.size() == 1:
		return [cells[0], cells[0]]
	var xs := {}
	var ys := {}
	for c in cells:
		xs[c.x] = true
		ys[c.y] = true
	var horizontal := ys.size() == 1 and xs.size() == cells.size()
	var vertical := xs.size() == 1 and ys.size() == cells.size()
	if not horizontal and not vertical:
		return []
	var ordered: Array[Vector2i] = cells.duplicate()
	ordered.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x if horizontal else a.y < b.y
	)
	var step := Vector2i.RIGHT if horizontal else Vector2i.DOWN
	for i in range(1, ordered.size()):
		if ordered[i] != ordered[0] + step * i:
			return []
	return [ordered[0], ordered[ordered.size() - 1]]


static func _neighbours(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i.LEFT,
		cell + Vector2i.RIGHT,
		cell + Vector2i.UP,
		cell + Vector2i.DOWN,
	]


static func _ordered(found: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for reason in _REASON_ORDER:
		if found.has(reason):
			out.append(reason)
	return out
