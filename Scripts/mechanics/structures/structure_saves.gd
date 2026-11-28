class_name StructureSaves
extends RefCounted
## Placed structures and free-form walls in world saves (world.structures,
## #42; docs/world-saves.md). A placement is an entry on its anchor cell
## ({"structure", "owner", "order"}), a free-form wall an entry on its cell
## ({"wall": "palisade"}). Tower ownership is the placement's owner, so flag
## colours and cities (rebuilt from the towers and walls) come back with them.
## Host alone: a joining peer gets the restored list with the map (#278).

const _WorldMap := preload("res://Scripts/world/TileMap.gd")

const PALISADE := "palisade"


static func to_changes(map: _WorldMap) -> Dictionary[String, Dictionary]:
	## The map's placements and free-form walls as world.structures entries.
	var out: Dictionary[String, Dictionary] = {}
	var order := 0
	for entry in map.structures_for_sync(true):
		var cell_data := {"structure": entry[0], "owner": entry[1], "order": order}
		if entry.size() >= 4 and int(entry[3]) != 0:
			cell_data["rotation"] = int(entry[3])
		if entry.size() >= 7:
			cell_data["hp"] = entry[6]
		if entry[0] == BuildCosts.NAMED_STRUCTURES[BuildCosts.CASTLE]:
			cell_data["start_castle"] = entry[5]
		if entry[0] == MineProduction.STRUCTURE_NAME:
			cell_data["production_elapsed"] = map.mine_production.elapsed(entry[4])
		elif entry[0] == SawmillProduction.STRUCTURE_NAME:
			cell_data["production_elapsed"] = map.sawmill_production.elapsed(entry[4])
		_put(out, entry[2], cell_data)
		order += 1
	for cell: Vector2i in map._walls._wall_cells:
		var entry := {"wall": PALISADE}
		var left: int = map._walls.hp(cell)
		if left < WallBuilder.MAX_HP:
			entry["hp"] = left
		_put(out, cell, entry)
	return out


static func restore(changes: Dictionary, map: _WorldMap) -> int:
	## Put back the placements, then the free-form walls (so they join the
	## structure walls), from to_changes entries. Call it after the params are
	## applied, before any chunk is drawn. A placement naming no shipped
	## structure, a wall on a cell that no longer generates land, and bad keys
	## are dropped; other entries are left alone. Returns placements + walls.
	var cities := map.get_parent().get_node_or_null("Cities") as Cities
	if cities != null and not changes.is_empty():
		cities.on_world_cleared()
	var placed := []
	var walls: Array[Vector2i] = []
	var hp_by_cell: Dictionary = {}
	for chunk in changes:
		for key in changes[chunk]:
			var entry = changes[chunk][key]
			var cell = WorldSave.parse_cell(str(key))
			if cell == null or not entry is Dictionary:
				continue
			if (
				entry.get("structure") is String
				and StructurePlacer.load_named(entry["structure"]) != null
			):
				var turns := int(entry.get("rotation", 0))
				placed.append(
					[
						int(entry.get("order", 0)),
						entry["structure"],
						int(entry.get("owner", 0)),
						cell,
						turns,
						entry.get("start_castle"),
						entry.get("production_elapsed"),
						entry.get("hp")
					]
				)
			elif (
				entry.get("wall") == PALISADE and map.ground_is_walkable(map.predict_cell(cell)[0])
			):
				walls.append(cell)
				if entry.has("hp"):
					hp_by_cell[cell] = int(entry["hp"])
	placed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var list := []
	var castle_owners := {}
	for p: Array in placed:
		var starting := false
		if p[1] == BuildCosts.NAMED_STRUCTURES[BuildCosts.CASTLE]:
			# Older saves recorded the starting castle as the owner's first castle.
			starting = bool(p[5]) if p[5] != null else not castle_owners.has(p[2])
			castle_owners[p[2]] = true
		list.append([p[1], p[2], p[3], p[4], 0, starting, p[7]])
	var count: int = map.replace_structures(list) if not list.is_empty() else 0
	for p: Array in placed:
		if p[1] == MineProduction.STRUCTURE_NAME:
			var mine := map.structure_placement_at(p[3])
			map.mine_production.restore_elapsed(mine["id"], p[6])
		elif p[1] == SawmillProduction.STRUCTURE_NAME:
			var sawmill := map.structure_placement_at(p[3])
			if sawmill.get("name") == p[1] and sawmill.get("anchor") == p[3]:
				map.sawmill_production.restore_elapsed(sawmill["id"], p[6])
	if not walls.is_empty() and map.place_wall_cells(walls):
		for cell: Vector2i in walls:
			if hp_by_cell.has(cell):
				map._walls.set_hp(cell, int(hp_by_cell[cell]))
		count += walls.size()
	if count > 0 and cities != null:
		cities.refresh_after_structure_restore()
	return count


static func adopt_start_castle(map: _WorldMap, owner: int) -> bool:
	## When a restored save already holds peer `owner`'s castle, make its gate
	## front the spawn (as place_start_castle does) and return true, so no
	## second castle is placed on a loaded world.
	var placements := map.placed_structures()
	var ids := placements.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = placements[id]
		if p.get("start_castle", false) and p["owner"] == owner:
			map._castle_front = p["anchor"] + StartCastle.GATE_FRONT
			map.spawn_point = map._castle_front
			return true
	return false


static func _put(out: Dictionary, cell: Vector2i, entry: Dictionary) -> void:
	var chunk := WorldSave.chunk_key(cell)
	if not out.has(chunk):
		out[chunk] = {}
	out[chunk][WorldSave.cell_key(cell)] = entry
