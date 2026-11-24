extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## A palisade city, then one raid strike that cracks a straight wall (#529).

const HERO_GAP := 12


func run() -> void:
	step("raid-city-intact")
	if not await start_game():
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	if not await wait_until(func() -> bool: return map.spawn_point != Vector2i.ZERO, 10.0):
		printerr("mob raid: spawn never set")
		done(false)
		return
	if not await wait_until(func() -> bool: return not _living_mobs().is_empty(), 10.0):
		printerr("mob raid: no mobs")
		done(false)
		return
	var city := _place_city(map)
	if city.is_empty():
		printerr("mob raid: no palisade ring away from the hero")
		done(false)
		return
	var mob := _raider(map, city["stand"])
	if mob == null:
		printerr("mob raid: no raider")
		done(false)
		return
	var settings = root.get_node("GameSettings")
	settings.set_raids_enabled(true, false)
	settings.set_raid_group(8, false)
	settings.set_raid_radius_cells(96, false)
	settings.set_raid_interval_s(45, false)
	var director: RaidDirector = current_scene.get_node("World/RaidDirector")
	director.advance(settings.raid_interval_s)
	if mob._raid_cell == Mob.RAID_NONE:
		printerr("mob raid: director did not assign %s" % mob.name)
		done(false)
		return
	mob._raid_cool = 30.0
	await _look(map, city["wall"])
	for _i in 8:
		await process_frame
	if map._walls.hp(city["wall"]) != WallBuilder.MAX_HP:
		printerr("mob raid: wall already at %d before the strike" % map._walls.hp(city["wall"]))
		done(false)
		return
	await snapshot("raid-city-intact")
	step("raid-wall-cracked")
	mob._raid_cool = 0.0
	var cracked := await wait_until(
		func() -> bool: return map._walls.hp(city["wall"]) == WallBuilder.MAX_HP - 1, 5.0
	)
	await _look(map, city["wall"])
	await snapshot("raid-wall-cracked")
	if not cracked:
		printerr("mob raid: hp stayed %d" % map._walls.hp(city["wall"]))
		done(false)
		return
	done(true)


func _place_city(map: TileMap) -> Dictionary:
	var tower: Structure = StructurePlacer.load_named("tower_wood")
	var hero_cell := map.local_to_map(map.to_local(hero().global_position))
	for radius in range(HERO_GAP, 48):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var origin := hero_cell + Vector2i(x, y)
				if not _ensure_rect(map, origin, Vector2i(7, 7)):
					continue
				if not map.can_place_structure(tower, origin + Vector2i(3, 4)).is_empty():
					continue
				var id: int = map.place_structure(tower, origin + Vector2i(3, 4), 1)
				if id <= 0:
					continue
				var ring := _perimeter(origin, origin + Vector2i(6, 6))
				if not map.place_wall_cells(ring):
					continue
				var cities: Cities = current_scene.get_node("World/Cities")
				cities.rebuild()
				if not cities.cities.has(id):
					continue
				var spot := _straight(map, origin, ring)
				if spot.is_empty():
					continue
				spot["id"] = id
				return spot
	return {}


func _straight(map: TileMap, origin: Vector2i, ring: Array[Vector2i]) -> Dictionary:
	var centre := origin + Vector2i(3, 3)
	for cell in ring:
		var at: Vector2i = cell
		var piece := WallBuilder._atlas_wall_name(map._walls.piece(at))
		if not (piece.ends_with("_H") or piece.ends_with("_V")):
			continue
		var away := at - centre
		var step := Vector2i(signi(away.x), signi(away.y))
		if step == Vector2i.ZERO or (step.x != 0 and step.y != 0):
			continue
		var stand := at + step
		_ensure_cell(map, stand)
		if map.has_wall(stand) or map._structures.has_cell(stand):
			continue
		var ground: Vector2i = map.predict_cell(stand)[0]
		if not map.ground_is_walkable(ground):
			continue
		return {"wall": at, "stand": stand}
	return {}


func _raider(map: TileMap, stand: Vector2i) -> Mob:
	var best: Mob = null
	for mob in _living_mobs():
		if best == null or str(mob.name) < str(best.name):
			best = mob
	if best == null:
		return null
	for mob in _living_mobs():
		if mob != best:
			mob.state = Mob.State.CHASE
	best.global_position = map.to_global(map.map_to_local(stand))
	best.state = Mob.State.IDLE
	best._calm = 0.0
	best.update_chart_visibility()
	return best


func _living_mobs() -> Array[Mob]:
	var out: Array[Mob] = []
	var node := current_scene.get_node("World/Mobs")
	for child in node.get_children():
		if child is Mob and not (child as Mob).is_queued_for_deletion():
			out.append(child)
	return out


func _ensure_rect(map: TileMap, origin: Vector2i, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			var cell := origin + Vector2i(x, y)
			_ensure_cell(map, cell)
			if map.has_wall(cell) or map._structures.has_cell(cell):
				return false
			if map.get_cell_source_id(0, cell) == -1 or not map.predicted_clear(cell):
				return false
	return true


func _ensure_cell(map: TileMap, cell: Vector2i) -> void:
	if map.get_cell_source_id(0, cell) == -1:
		map.generate_chunk(map.map_to_local(cell))


func _perimeter(lo: Vector2i, hi: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(lo.x, hi.x + 1):
		out.append(Vector2i(x, lo.y))
		out.append(Vector2i(x, hi.y))
	for y in range(lo.y + 1, hi.y):
		out.append(Vector2i(lo.x, y))
		out.append(Vector2i(hi.x, y))
	return out


func _look(map: TileMap, cell: Vector2i) -> void:
	var cam: Camera2D = hero().get_node("Camera2D")
	cam.zoom = Vector2(4, 4)
	cam.global_position = map.to_global(map.map_to_local(cell))
