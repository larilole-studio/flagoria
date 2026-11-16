class_name RaidDirector
extends Node
## Host-only raid clock (#529). While GameSettings.raids_enabled is on, every
## raid_interval_s a group of idle mobs is sent at one target: the nearest
## player-owned city inside the radius, or else the nearest owned tower.
## The origin is the cell of the living mob with the lowest name. The seed
## and the tick pick who joins; they do not pick the target. Raids start off.
## Turning them off clears every raid cell and the accumulator.
## Clients do not run this. The host moves the bodies, and wall hp and
## capture already replicate.

const RAID_NONE := Vector2i(1 << 20, 0)

var _accum := 0.0
var _tick := 0


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		advance(delta)


func advance(delta: float) -> void:
	## Server clock. Tests and the raid probe call this with a large delta
	## instead of waiting out the interval. A non-server call does nothing.
	if not multiplayer.is_server():
		return
	var settings := _settings()
	if settings == null or not settings.raids_enabled:
		_clear()
		return
	if delta <= 0.0:
		return
	_accum += delta
	var interval := float(settings.raid_interval_s)
	if interval <= 0.0:
		return
	var fired := 0
	while _accum >= interval and fired < 8:
		_accum -= interval
		_launch()
		fired += 1


func choose_target(origin: Vector2i) -> Dictionary:
	## {id, cell} of the raid target, or {} when nothing in range qualifies.
	## A player-owned city (owner greater than 0) wins over any tower. Ties
	## go to the smaller placement id. Distance is Chebyshev cells.
	var settings := _settings()
	var map := _map()
	if settings == null or map == null:
		return {}
	var radius := int(settings.raid_radius_cells)
	var city := _nearest(origin, radius, _city_ids(), map)
	if not city.is_empty():
		return city
	return _nearest(origin, radius, _tower_ids(map), map)


func _launch() -> void:
	var tick := _tick
	_tick += 1
	var mobs := _living()
	if mobs.is_empty():
		return
	var target := choose_target(_origin(mobs))
	if target.is_empty():
		return
	var settings := _settings()
	for mob in _pick(_eligible(mobs), int(settings.raid_group), _map_seed(), tick):
		mob.assign_raid(target["cell"], int(target["id"]))


func _clear() -> void:
	_accum = 0.0
	var node := get_node_or_null("../Mobs")
	if node == null:
		return
	for child in node.get_children():
		if child is Mob:
			(child as Mob).clear_raid()


func _living() -> Array[Mob]:
	var out: Array[Mob] = []
	var node := get_node_or_null("../Mobs")
	if node == null:
		return out
	for child in node.get_children():
		if child is Mob and not (child as Mob).is_queued_for_deletion() \
				and (child as Mob).state != Mob.State.DYING:
			out.append(child)
	return out


func _origin(mobs: Array[Mob]) -> Vector2i:
	var best: Mob = mobs[0]
	for mob in mobs:
		if str(mob.name) < str(best.name):
			best = mob
	var map := _map()
	if map == null:
		return RAID_NONE
	return map.local_to_map(map.to_local(best.global_position))


func _eligible(mobs: Array[Mob]) -> Array[Mob]:
	## Idle and wandering mobs that are not already raiding. A chase, a hurt
	## window and death stay out; the chase wins until the mob is calm.
	var out: Array[Mob] = []
	for mob in mobs:
		if mob.state == Mob.State.CHASE or mob.state == Mob.State.HURT or mob.state == Mob.State.DYING:
			continue
		if mob._raid_cell != Mob.RAID_NONE:
			continue
		out.append(mob)
	out.sort_custom(func(a: Mob, b: Mob) -> bool: return str(a.name) < str(b.name))
	return out


func _pick(pool: Array[Mob], count: int, seed_value: int, tick: int) -> Array[Mob]:
	var bag: Array[Mob] = pool.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(seed_value, tick, 17))
	for i in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Mob = bag[i]
		bag[i] = bag[j]
		bag[j] = swap
	var chosen: Array[Mob] = []
	var n := mini(count, bag.size())
	for i in n:
		chosen.append(bag[i])
	return chosen


func _city_ids() -> Array[int]:
	var out: Array[int] = []
	var cities := get_node_or_null("../Cities") as Cities
	if cities == null:
		return out
	for id in cities.cities.keys():
		if cities.owner_of(int(id)) > 0:
			out.append(int(id))
	return out


func _tower_ids(map: TileMap) -> Array[int]:
	var out: Array[int] = []
	for id in map._structures.towers().keys():
		if map._structures.owner_of(int(id)) > 0:
			out.append(int(id))
	return out


func _nearest(origin: Vector2i, radius: int, ids: Array[int], map: TileMap) -> Dictionary:
	var best_id := 0
	var best_d := radius + 1
	var best_cell := RAID_NONE
	var found := false
	for id in ids:
		var cell := _flag_cell(map, id)
		if cell == RAID_NONE:
			continue
		var dist := maxi(absi(cell.x - origin.x), absi(cell.y - origin.y))
		if dist > radius:
			continue
		if not found or dist < best_d or (dist == best_d and id < best_id):
			found = true
			best_d = dist
			best_id = id
			best_cell = cell
	if not found:
		return {}
	return {"id": best_id, "cell": best_cell}


func _flag_cell(map: TileMap, id: int) -> Vector2i:
	var flags: Array = map._structures.towers().get(id, [])
	if not flags.is_empty() and flags[0] is Vector2i:
		return flags[0]
	var placed: Dictionary = map._structures.placements()
	if placed.has(id):
		return placed[id]["anchor"]
	return RAID_NONE


func _settings() -> Node:
	return get_node_or_null("/root/GameSettings")


func _map() -> TileMap:
	return get_node_or_null("../worldMap") as TileMap


func _map_seed() -> int:
	var main := get_node_or_null("../..")
	if main != null and main.get("world_params") is MapGenParams:
		return (main.world_params as MapGenParams).altitude_seed
	return 0
