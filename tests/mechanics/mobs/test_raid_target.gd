extends "res://tests/helpers/test_helpers.gd"
## Raid target, clock and palisade damage (#529). No ENet.
## Time cost: about 1 s inside tools/verify.sh. A standalone run is about 4 s.


const SEED := 11
## One cell of air between the tower ring and the palisade, so a side solves
## as PALISADE_H or PALISADE_V. A tight 5x5 touches the tower and becomes a T.
const RING := 7
const TOWER_AT := Vector2i(3, 4)
const CENTRE := Vector2i(3, 3)


func _test_raid_target() -> int:
	## Nearer city, radius cutoff, an owned tower when no city is in range,
	## neutral and mob owners ignored, raids off by default, the interval
	## assigns at most raid_group, a palisade ring loses hp, and a castle
	## auto-wall is not passed to host_damage_wall.
	print("-- test_raid_target")
	var fail := 0
	var game = root.get_node("GameSettings")
	var saved := {
		"path": game.save_path,
		"rate": game.mob_rate,
		"on": game.raids_enabled,
		"interval": game.raid_interval_s,
		"group": game.raid_group,
		"radius": game.raid_radius_cells,
	}
	fail += _settings(game)
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var cities: Cities = scene.get_node("World/Cities")
	var director: RaidDirector = scene.get_node("World/RaidDirector")
	var params := _spawn_params(SEED, 0.0)
	params.ensure_seeds()
	scene.world_params = params
	world.apply_map_params(params)
	for y in range(-2, 3):
		for x in range(-2, 3):
			world.generate_chunk(world.map_to_local(Vector2i(x * 32, y * 32)))
	var tower: Structure = StructurePlacer.load_named("tower_wood")
	var spots := _ring_spots(world, tower)
	if spots.size() < 2:
		printerr("FAIL raid_target: need two ring spots, found %d" % spots.size())
		fail += 1
	else:
		var pair := _ring_pair(spots)
		var near: Dictionary = _place_ring(world, cities, tower, pair[0], 1)
		var far: Dictionary = _place_ring(world, cities, tower, pair[1], 1)
		if near.is_empty() or far.is_empty():
			printerr("FAIL raid_target: ring place failed")
			fail += 1
		else:
			var extras := _place_extras(world, tower, near["flag"], far["flag"])
			if extras.is_empty():
				printerr("FAIL raid_target: could not place owned, neutral and mob towers")
				fail += 1
			else:
				fail += _targets(game, director, near, far, extras)
				fail += _clock_and_hp(game, director, world, cities, near)
				fail += _auto_wall(world, near)
	scene.queue_free()
	_restore(game, saved)
	if fail == 0:
		print("PASS test_raid_target")
	return fail


func _settings(game) -> int:
	var path := "user://test_raid_settings.cfg"
	var abs := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)
	game.save_path = path
	game.load_from_disk()
	var fail := 0
	if game.raids_enabled or game.raid_interval_s != game.RAID_INTERVAL_DEFAULT \
			or game.raid_group != game.RAID_GROUP_DEFAULT \
			or game.raid_radius_cells != game.RAID_RADIUS_DEFAULT:
		printerr("FAIL raid_target: defaults on=%s interval=%s group=%s radius=%s" % [
			game.raids_enabled, game.raid_interval_s, game.raid_group, game.raid_radius_cells])
		fail += 1
	game.set_raid_interval_s(1, false)
	game.set_raid_group(0, false)
	game.set_raid_radius_cells(1, false)
	if game.raid_interval_s != game.RAID_INTERVAL_MIN or game.raid_group != game.RAID_GROUP_MIN \
			or game.raid_radius_cells != game.RAID_RADIUS_MIN:
		printerr("FAIL raid_target: low clamp %s %s %s" % [
			game.raid_interval_s, game.raid_group, game.raid_radius_cells])
		fail += 1
	game.set_raid_interval_s(999, false)
	game.set_raid_group(99, false)
	game.set_raid_radius_cells(999, false)
	if game.raid_interval_s != game.RAID_INTERVAL_MAX or game.raid_group != game.RAID_GROUP_MAX \
			or game.raid_radius_cells != game.RAID_RADIUS_MAX:
		printerr("FAIL raid_target: high clamp %s %s %s" % [
			game.raid_interval_s, game.raid_group, game.raid_radius_cells])
		fail += 1
	game.set_raids_enabled(true, false)
	game.set_raid_interval_s(30, false)
	game.set_raid_group(4, false)
	game.set_raid_radius_cells(20, false)
	game.save_to_disk()
	game.raids_enabled = false
	game.raid_interval_s = 1.0
	game.load_from_disk()
	if not game.raids_enabled or game.raid_interval_s != 30.0 or game.raid_group != 4 \
			or game.raid_radius_cells != 20:
		printerr("FAIL raid_target: reload on=%s interval=%s group=%s radius=%s" % [
			game.raids_enabled, game.raid_interval_s, game.raid_group, game.raid_radius_cells])
		fail += 1
	game.set_raids_enabled(false, false)
	return fail


func _targets(game, director: RaidDirector, near: Dictionary, far: Dictionary, extras: Dictionary) -> int:
	var fail := 0
	var origin: Vector2i = extras["origin"]
	var d_near := _dist(origin, near["flag"])
	var d_far := _dist(origin, far["flag"])
	var d_tower := _dist(origin, extras["tower"])
	var d_neutral := _dist(origin, extras["neutral"])
	var d_mobs := _dist(origin, extras["mobs"])
	if not (d_near < d_far and d_far <= 96 and d_tower >= 17 and d_tower < d_near \
			and d_neutral < d_tower and d_mobs < d_tower):
		printerr("FAIL raid_target: distances near=%d far=%d tower=%d neutral=%d mobs=%d" % [
			d_near, d_far, d_tower, d_neutral, d_mobs])
		return 1
	# No city in range: the owned tower, not the closer neutral or mob tower.
	game.set_raid_radius_cells(d_tower, false)
	var tower_only: Dictionary = director.choose_target(origin)
	if int(tower_only.get("id", -1)) != int(extras["tower_id"]):
		printerr("FAIL raid_target: tower fallback %s want %s" % [tower_only, extras["tower_id"]])
		fail += 1
	# Cutoff: radius stops short of that tower. Ignored owners stay ignored.
	game.set_raid_radius_cells(d_tower - 1, false)
	if not director.choose_target(origin).is_empty():
		printerr("FAIL raid_target: radius cutoff still returned %s" % director.choose_target(origin))
		fail += 1
	# Both cities in range: the nearer one, not the closer tower.
	game.set_raid_radius_cells(d_far, false)
	var first: Dictionary = director.choose_target(origin)
	var second: Dictionary = director.choose_target(origin)
	if int(first.get("id", -1)) != int(near["id"]) or first != second:
		printerr("FAIL raid_target: nearer city %s then %s want %s" % [first, second, near["id"]])
		fail += 1
	var flipped: Vector2i = far["flag"]
	game.set_raid_radius_cells(maxi(_dist(flipped, near["flag"]), 16), false)
	var other: Dictionary = director.choose_target(flipped)
	if int(other.get("id", -1)) != int(far["id"]):
		printerr("FAIL raid_target: other city %s want %s" % [other, far["id"]])
		fail += 1
	return fail


func _clock_and_hp(game, director: RaidDirector, world, cities: Cities, near: Dictionary) -> int:
	var fail := 0
	var outside := _outside(world, near)
	if outside.is_empty():
		printerr("FAIL raid_target: no straight palisade to strike")
		return 1
	var stand: Vector2i = outside["stand"]
	var wall: Vector2i = outside["wall"]
	if world._walls.hp(wall) != WallBuilder.MAX_HP:
		printerr("FAIL raid_target: fresh wall hp %d" % world._walls.hp(wall))
		fail += 1
	var mobs: Array[Mob] = []
	for i in 6:
		mobs.append(_mob(world, "mob_%d" % i, stand))
	game.set_raids_enabled(false, false)
	game.set_raid_group(3, false)
	game.set_raid_interval_s(45, false)
	game.set_raid_radius_cells(96, false)
	mobs[0].assign_raid(near["flag"], int(near["id"]))
	director.advance(90.0)
	if mobs[0]._raid_cell != Mob.RAID_NONE or world._walls.hp(wall) != WallBuilder.MAX_HP:
		printerr("FAIL raid_target: raids off left cell %s hp %d" % [mobs[0]._raid_cell, world._walls.hp(wall)])
		fail += 1
	game.set_raids_enabled(true, false)
	director._accum = 0.0
	director._tick = 0
	director.advance(44.0)
	if _assigned(mobs) != 0:
		printerr("FAIL raid_target: early interval assigned %d" % _assigned(mobs))
		fail += 1
	director.advance(1.0)
	var names := _assigned_names(mobs)
	if names.size() != 3:
		printerr("FAIL raid_target: group assigned %s" % names)
		fail += 1
	for mob in mobs:
		mob.clear_raid()
	director._accum = 0.0
	director._tick = 0
	director.advance(45.0)
	if _assigned_names(mobs) != names:
		printerr("FAIL raid_target: retick assigned %s want %s" % [_assigned_names(mobs), names])
		fail += 1
	for mob in mobs:
		mob.clear_raid()
	var striker := mobs[0]
	striker.global_position = world.to_global(world.map_to_local(stand))
	striker._raid_strikes.clear()
	striker.assign_raid(near["flag"], int(near["id"]))
	striker._step_raid(1.0)
	if world._walls.hp(wall) != WallBuilder.MAX_HP - 1 or striker._raid_strikes != [wall]:
		printerr("FAIL raid_target: strike hp %d hits %s want %s" % [
			world._walls.hp(wall), striker._raid_strikes, wall])
		fail += 1
	cities.rebuild()
	return fail


func _auto_wall(world, near: Dictionary) -> int:
	if not world.place_start_castle(1):
		printerr("FAIL raid_target: no starting castle")
		return 1
	var wall := Vector2i.ZERO
	var found := false
	for cell: Vector2i in world._structures.auto_cells():
		if world.has_wall(cell):
			continue
		var tile_name := WallBuilder._atlas_wall_name(world._structures.object_at(cell))
		if not tile_name.begins_with("WALL_"):
			continue
		if _dist(cell, near["flag"]) <= 4:
			continue
		wall = cell
		found = true
		break
	if not found:
		printerr("FAIL raid_target: no castle auto-wall")
		return 1
	var stand := Vector2i.ZERO
	var step := Vector2i.ZERO
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var cell: Vector2i = wall + dir
		if world.has_wall(cell) or world._structures.has_cell(cell):
			continue
		var ground: Vector2i = world.predict_cell(cell)[0]
		if not world.ground_is_walkable(ground):
			continue
		stand = cell
		step = dir
		break
	if step == Vector2i.ZERO:
		printerr("FAIL raid_target: castle wall has no open side")
		return 1
	var mob := _mob(world, "mob_stone", stand)
	mob._raid_strikes.clear()
	mob.assign_raid(wall - step, -1)
	for _i in 6:
		mob._step_raid(0.25)
	if not mob._raid_strikes.is_empty() or world.local_to_map(world.to_local(mob.global_position)) == wall:
		printerr("FAIL raid_target: auto-wall strikes %s cell %s" % [
			mob._raid_strikes, world.local_to_map(world.to_local(mob.global_position))])
		return 1
	return 0


func _place_extras(world, tower: Structure, near_flag: Vector2i, far_flag: Vector2i) -> Dictionary:
	## One pass over anchors for each origin on the island. Ignored owners sit
	## closer than the owned tower; that tower sits closer than the near city.
	var anchors := _anchors(world, tower)
	var flags: Array[Vector2i] = []
	for anchor in anchors:
		flags.append(anchor + Vector2i(0, -1))
	var best := {}
	for i in flags.size():
		var origin: Vector2i = flags[i] + Vector2i(3, 0)
		var d_near := _dist(origin, near_flag)
		var d_far := _dist(origin, far_flag)
		if d_near < 18 or d_near > 90 or d_far <= d_near or d_far > 96:
			continue
		var ranked: Array[int] = []
		for j in flags.size():
			ranked.append(j)
		ranked.sort_custom(func(a: int, b: int) -> bool:
			var da := _dist(origin, flags[a])
			var db := _dist(origin, flags[b])
			if da != db:
				return da < db
			return a < b)
		var owned := -1
		for j in ranked:
			var dist := _dist(origin, flags[j])
			if dist >= 17 and dist < d_near and dist < 48:
				owned = j
				break
		if owned == -1:
			continue
		var owned_d := _dist(origin, flags[owned])
		var closer: Array[int] = []
		for j in ranked:
			if j == owned:
				break
			if _dist(origin, flags[j]) < owned_d:
				closer.append(j)
		if closer.size() < 2:
			continue
		var a := closer[0]
		var b := closer[1]
		if _foot_overlap(anchors[a], anchors[b]) or _foot_overlap(anchors[a], anchors[owned]) \
				or _foot_overlap(anchors[b], anchors[owned]):
			continue
		best = {"neutral": anchors[a], "owned": anchors[owned], "mobs": anchors[b], "origin": origin}
		break
	if best.is_empty():
		return {}
	var nid: int = world.place_structure(tower, best["neutral"], StructurePlacer.OWNER_NEUTRAL)
	var oid: int = world.place_structure(tower, best["owned"], 1)
	var mid: int = world.place_structure(tower, best["mobs"], StructurePlacer.OWNER_MOBS)
	if nid <= 0 or oid <= 0 or mid <= 0:
		return {}
	return {
		"origin": best["origin"],
		"neutral": world._structures.towers()[nid][0],
		"tower": world._structures.towers()[oid][0],
		"mobs": world._structures.towers()[mid][0],
		"tower_id": oid,
	}


func _foot_overlap(a: Vector2i, b: Vector2i) -> bool:
	for y in 3:
		for x in 3:
			var cell := a + Vector2i(x - 1, y - 2)
			for yb in 3:
				for xb in 3:
					if cell == b + Vector2i(xb - 1, yb - 2):
						return true
	return false


func _ring_spots(world, tower: Structure) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in world.get_used_cells(0):
		var origin: Vector2i = cell
		if _ring_fits(world, tower, origin):
			out.append(origin)
	return out


func _ring_pair(spots: Array[Vector2i]) -> Array[Vector2i]:
	var best: Array[Vector2i] = [spots[0], spots[1]]
	var best_d := -1
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			var dist := _dist(spots[i] + CENTRE, spots[j] + CENTRE)
			if dist > best_d and dist <= 90:
				best_d = dist
				best = [spots[i], spots[j]]
	return best


func _ring_fits(world, tower: Structure, origin: Vector2i) -> bool:
	if not _clear_rect(world, origin, Vector2i(RING, RING)):
		return false
	if not world.can_place_structure(tower, origin + TOWER_AT).is_empty():
		return false
	return _has_stand(world, origin)


func _has_stand(world, origin: Vector2i) -> bool:
	var hi := RING - 1
	var mid := RING >> 1
	for stand in [
		origin + Vector2i(mid, -1), origin + Vector2i(mid, hi + 1),
		origin + Vector2i(-1, mid), origin + Vector2i(hi + 1, mid),
	]:
		if world.get_cell_source_id(0, stand) == -1:
			continue
		if world.has_wall(stand) or world._structures.has_cell(stand):
			continue
		var ground: Vector2i = world.predict_cell(stand)[0]
		if world.ground_is_walkable(ground):
			return true
	return false


func _place_ring(world, cities: Cities, tower: Structure, origin: Vector2i, owner: int) -> Dictionary:
	var id: int = world.place_structure(tower, origin + TOWER_AT, owner)
	if id <= 0:
		return {}
	var ring := _perimeter(origin, origin + Vector2i(RING - 1, RING - 1))
	if not world.place_wall_cells(ring):
		return {}
	cities.rebuild()
	if not cities.cities.has(id):
		return {}
	return {
		"id": id,
		"origin": origin,
		"ring": ring,
		"flag": world._structures.towers()[id][0],
	}


func _anchors(world, tower: Structure) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in world.get_used_cells(0):
		var anchor: Vector2i = cell
		if world.can_place_structure(tower, anchor).is_empty():
			out.append(anchor)
	return out


func _outside(world, city: Dictionary) -> Dictionary:
	var centre: Vector2i = city["origin"] + CENTRE
	for cell in city["ring"]:
		var at: Vector2i = cell
		var piece := WallBuilder._atlas_wall_name(world._walls.piece(at))
		if not (piece.ends_with("_H") or piece.ends_with("_V")):
			continue
		var away := at - centre
		var step := Vector2i(signi(away.x), signi(away.y))
		if step == Vector2i.ZERO or (step.x != 0 and step.y != 0):
			continue
		var stand := at + step
		if world.has_wall(stand) or world._structures.has_cell(stand):
			continue
		var ground: Vector2i = world.predict_cell(stand)[0]
		if not world.ground_is_walkable(ground):
			continue
		return {"wall": at, "stand": stand}
	return {}


func _mob(world, mob_name: String, cell: Vector2i) -> Mob:
	var mob: Mob = load("res://Mobs/mob.tscn").instantiate()
	mob.name = mob_name
	var at: Vector2 = world.to_global(world.map_to_local(cell))
	mob.setup(MobCatalog.SLIME, at, 1)
	world.get_node("../Mobs").add_child(mob)
	mob.global_position = at
	mob.state = Mob.State.IDLE
	return mob


func _assigned(mobs: Array[Mob]) -> int:
	var n := 0
	for mob in mobs:
		if mob._raid_cell != Mob.RAID_NONE:
			n += 1
	return n


func _assigned_names(mobs: Array[Mob]) -> Array:
	var names := []
	for mob in mobs:
		if mob._raid_cell != Mob.RAID_NONE:
			names.append(str(mob.name))
	names.sort()
	return names


func _clear_rect(world, origin: Vector2i, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			var cell := origin + Vector2i(x, y)
			if world.has_wall(cell) or world._structures.has_cell(cell):
				return false
			if world.get_cell_source_id(0, cell) == -1 or not world.predicted_clear(cell):
				return false
	return true


func _perimeter(lo: Vector2i, hi: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(lo.x, hi.x + 1):
		out.append(Vector2i(x, lo.y))
		out.append(Vector2i(x, hi.y))
	for y in range(lo.y + 1, hi.y):
		out.append(Vector2i(lo.x, y))
		out.append(Vector2i(hi.x, y))
	return out


func _dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _restore(game, saved: Dictionary) -> void:
	game.save_path = saved["path"]
	game.set_mob_rate(saved["rate"], false)
	game.set_raid_interval_s(saved["interval"], false)
	game.set_raid_group(int(saved["group"]), false)
	game.set_raid_radius_cells(int(saved["radius"]), false)
	game.set_raids_enabled(bool(saved["on"]), false)
	var abs := ProjectSettings.globalize_path("user://test_raid_settings.cfg")
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)
