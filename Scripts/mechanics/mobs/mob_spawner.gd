class_name MobSpawner
extends Node2D
## Places a few mobs on each island near the player spawn, the same for a given
## map seed. The server decides; its MultiplayerSpawner sends each mob's
## spawn data to every peer, including peers that join later.
##
## An island is a 4-connected group of clear ground cells (walkable, no tree,
## bush or stones) inside a SCAN_RADIUS box around the spawn. Terrain comes from
## TileMap.predict_cell, so no tiles are generated and the map is unchanged.
##
## Once a living player has been in the world for AMBIENT_DELAY_MS, the server
## adds and removes mobs around each player (`plan_tick`). Those nodes go
## through the same MultiplayerSpawner, so peers and late joiners see the
## spawn and the free. Ambient mobs are not saved.

const MOB_SCENE_PATH := "res://Mobs/mob.tscn"

const SCAN_RADIUS := 40  ## cells each side of the spawn cell
const MIN_ISLAND_CELLS := 40  ## smaller islands get no mobs
const CELLS_PER_MOB := 300  ## rate: one mob per this many island cells...
const MAX_PER_ISLAND := 3  ## rate: ...up to this many
const MAX_MOBS := 10  ## rate
const SAFE_RADIUS := 6  ## cells: no mob starts this close to the player spawn
const MIN_GAP := 4  ## cells between two mobs' start cells
const MIN_BEACH_CELLS := 12  ## sand cells an island needs for a crab
## Chebyshev cells. Ambient mobs spawn in the ring (min, max] around a player,
## never inside any player's min, and an unpinned mob past the despawn radius
## of every player is removed. Chasing mobs stay.
const SPAWN_MIN_RADIUS := 12
const SPAWN_MAX_RADIUS := 40
const DESPAWN_RADIUS := 64
const PER_PLAYER_CAP := 10  ## rate: ambient cap for one living player
const GLOBAL_CAP := 30  ## rate: ambient cap for the whole world
const PER_CHUNK_CAP := 1  ## ambient mobs kept in one chunk
const AMBIENT_DELAY_MS := 45000  ## first tick, and the gap before the next
const CHUNK := 32  ## cells on a side, the grid generate_chunk draws
## Constants marked "rate" are the 1x day density. `rate` (the host's
## GameSettings.mob_rate) divides CELLS_PER_MOB and multiplies both caps.
## PER_PLAYER_CAP scales like per_island (ceili) and GLOBAL_CAP like total
## (roundi). The day/night scale does the same again: 1 by day, 2 at night.
## See ambient_caps. A surplus over the day cap leaves only past
## DESPAWN_RADIUS, on a later tick, so nothing vanishes on screen.

const GRASS := [TileCatalog.GRASS_A, TileCatalog.GRASS_B, TileCatalog.GRASS_C, TileCatalog.GRASS_D]

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

## The band probe sets this to 0 and calls run_ambient_tick itself. The
## automatic gap between ticks stays AMBIENT_DELAY_MS either way.
var ambient_delay_ms := AMBIENT_DELAY_MS
var _player_since := -1
var _last_ambient_ms := -1
var _ambient_tick := 0


func _ready() -> void:
	spawner.spawn_function = _make_mob


static func is_home_cell(world: TileMap, cell: Vector2i, home: int) -> bool:
	## Clear ground of the mob's home kind: sand for HOME_SAND, grass otherwise.
	if not world.predicted_clear(cell):
		return false
	var ground: Vector2i = world.predict_cell(cell)[0]
	if home == MobCatalog.HOME_SAND:
		return ground == TileCatalog.SAND
	return GRASS.has(ground)


static func caps(rate: float) -> Dictionary:
	## Density and caps for a spawn rate: {cells_per_mob, per_island, total}.
	return {
		"cells_per_mob": maxi(1, roundi(CELLS_PER_MOB / rate)),
		"per_island": maxi(1, ceili(MAX_PER_ISLAND * rate)),
		"total": maxi(1, roundi(MAX_MOBS * rate)),
	}


static func ambient_caps(rate: float, scale := 1.0) -> Dictionary:
	## Ambient caps at a spawn rate and clock scale: {per_player, total}.
	## `scale` 1 is the day hold (and the cycle switched off). Callers that
	## omit it keep today's caps.
	var density := rate * scale
	return {
		"per_player": maxi(1, ceili(PER_PLAYER_CAP * density)),
		"total": maxi(1, roundi(GLOBAL_CAP * density)),
	}


static func ambient_scale() -> float:
	## The shared clock, read the same way on the host and on a joiner.
	## Only the host applies it, and only inside a tick, not every frame.
	## Look the node up by name so this file does not name the autoload
	## at compile time (a --script entry can compile this before autoloads).
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1.0
	var clock := tree.root.get_node_or_null("DayNight")
	if clock == null or not clock.has_method("spawn_scale"):
		return 1.0
	return float(clock.call("spawn_scale"))


static func home_kind(world: TileMap, cell: Vector2i) -> int:
	## HOME_SAND, HOME_GRASS, or -1 when the cell is not home ground.
	if not world.predicted_clear(cell):
		return -1
	var ground: Vector2i = world.predict_cell(cell)[0]
	if ground == TileCatalog.SAND:
		return MobCatalog.HOME_SAND
	if GRASS.has(ground):
		return MobCatalog.HOME_GRASS
	return -1


static func plan_tick(world: TileMap, player_cells: Array, existing: Array, seed_value: int, tick: int, rate: float, scale := 1.0) -> Dictionary:
	## {spawn: [{name, type, cell}], despawn: [name]} for one ambient tick.
	## Pure: the same arguments return the same dictionary. No spawn and no
	## despawn when `player_cells` is empty, so an opening wave with nobody
	## in the world is left alone. A spawn cell is home ground, farther than
	## SPAWN_MIN_RADIUS from every player, and within SPAWN_MAX_RADIUS of at
	## least one. Each eligible chunk contributes its lowest-_rank cell.
	## Names are mob_a_%d. Despawn is only an unpinned mob past
	## DESPAWN_RADIUS from every player. A lower scale (dawn, or the cycle
	## off) does not remove a mob still inside that radius.
	var spawn: Array = []
	var despawn: Array = []
	if player_cells.is_empty():
		return {"spawn": spawn, "despawn": despawn}
	var cap := ambient_caps(rate, scale)
	var staying: Array = []
	for item in existing:
		var cell: Vector2i = item["cell"]
		if _beyond_everyone(cell, player_cells, DESPAWN_RADIUS) and not bool(item.get("pinned", false)):
			despawn.append(str(item["name"]))
		else:
			staying.append(item)
	var per: Array[int] = []
	per.resize(player_cells.size())
	var global := staying.size()
	var in_chunk := {}
	for item in staying:
		var cell: Vector2i = item["cell"]
		var owner := _nearest_player(cell, player_cells)
		if _chebyshev(cell, player_cells[owner]) <= SPAWN_MAX_RADIUS:
			per[owner] += 1
		var key := _chunk_of(cell)
		in_chunk[key] = int(in_chunk.get(key, 0)) + 1
	var best := {}
	for origin in player_cells:
		var at: Vector2i = origin
		for x in range(-SPAWN_MAX_RADIUS, SPAWN_MAX_RADIUS + 1):
			for y in range(-SPAWN_MAX_RADIUS, SPAWN_MAX_RADIUS + 1):
				var dist := maxi(absi(x), absi(y))
				if dist <= SPAWN_MIN_RADIUS or dist > SPAWN_MAX_RADIUS:
					continue
				var cell := at + Vector2i(x, y)
				if not _beyond_everyone(cell, player_cells, SPAWN_MIN_RADIUS):
					continue
				var home := home_kind(world, cell)
				if home < 0:
					continue
				var chunk := _chunk_of(cell)
				if int(in_chunk.get(chunk, 0)) >= PER_CHUNK_CAP:
					continue
				var rank := _rank(cell, seed_value)
				var prev: Dictionary = best.get(chunk, {})
				if prev.is_empty() or rank < int(prev["rank"]) or (rank == int(prev["rank"]) and _cell_before(cell, prev["cell"])):
					best[chunk] = {"cell": cell, "rank": rank, "home": home}
	var offers: Array = best.values()
	offers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["rank"]) != int(b["rank"]):
			return int(a["rank"]) < int(b["rank"])
		return _cell_before(a["cell"], b["cell"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(seed_value, tick, 0))
	var next_i := _next_ambient_index(existing)
	for offer in offers:
		var roll := rng.randi()
		if global >= int(cap["total"]):
			break
		var cell: Vector2i = offer["cell"]
		var owner := _nearest_player(cell, player_cells)
		if per[owner] >= int(cap["per_player"]):
			continue
		spawn.append({
			"name": "mob_a_%d" % next_i,
			"type": _type_for(int(offer["home"]), roll),
			"cell": cell,
		})
		next_i += 1
		per[owner] += 1
		global += 1
	return {"spawn": spawn, "despawn": despawn}


static func plan(world: TileMap, origin: Vector2i, seed_value: int, rate := 1.0) -> Array:
	## [{type, cell}] for this map, largest island first. Same inputs,
	## same plan.
	var cap := caps(rate)
	var max_mobs: int = cap["total"]
	var clear := {}
	for x in range(-SCAN_RADIUS, SCAN_RADIUS + 1):
		for y in range(-SCAN_RADIUS, SCAN_RADIUS + 1):
			var c := origin + Vector2i(x, y)
			if world.predicted_clear(c):
				clear[c] = true
	var islands := _islands(clear)
	islands.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())

	var out: Array = []
	var taken: Array[Vector2i] = []
	for island in islands:
		if island.size() < MIN_ISLAND_CELLS or out.size() >= max_mobs:
			break
		var want := clampi(island.size() / int(cap["cells_per_mob"]), 1, cap["per_island"])
		var order: Array = island.filter(func(c: Vector2i) -> bool:
			return maxi(absi(c.x - origin.x), absi(c.y - origin.y)) > SAFE_RADIUS)
		order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return _rank(a, seed_value) < _rank(b, seed_value))
		var sand: Array = order.filter(func(c: Vector2i) -> bool: return is_home_cell(world, c, MobCatalog.HOME_SAND))
		var grass: Array = order.filter(func(c: Vector2i) -> bool: return is_home_cell(world, c, MobCatalog.HOME_GRASS))
		for slot in want:
			if out.size() >= max_mobs:
				break
			var type := MobCatalog.CRAB
			var pool := sand
			if slot > 0 or sand.size() < MIN_BEACH_CELLS:
				pool = grass
				type = MobCatalog.SLIME if (_rank(island[0], seed_value) + slot) % 2 == 0 else MobCatalog.PIGLET
			var cell = _first_free(pool, taken)
			if cell == null:
				continue
			taken.append(cell)
			out.append({"type": type, "cell": cell})
	return out


static func _islands(clear: Dictionary) -> Array:
	## 4-connected groups of `clear` cells, in scan order.
	var seen := {}
	var out: Array = []
	for start in clear.keys():
		if seen.has(start):
			continue
		seen[start] = true
		var group: Array[Vector2i] = [start]
		var head := 0
		while head < group.size():
			var cur: Vector2i = group[head]
			head += 1
			for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var n: Vector2i = cur + d
				if clear.has(n) and not seen.has(n):
					seen[n] = true
					group.append(n)
		out.append(group)
	return out


static func _rank(cell: Vector2i, seed_value: int) -> int:
	return hash(Vector3i(cell.x, cell.y, seed_value)) & 0x7FFFFFFF


static func _chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(CHUNK)), floori(float(cell.y) / float(CHUNK)))


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _beyond_everyone(cell: Vector2i, players: Array, radius: int) -> bool:
	for p in players:
		if _chebyshev(cell, p) <= radius:
			return false
	return true


static func _nearest_player(cell: Vector2i, players: Array) -> int:
	var best := 0
	var best_d := 0x7FFFFFFF
	for i in players.size():
		var d := _chebyshev(cell, players[i])
		if d < best_d:
			best_d = d
			best = i
	return best


static func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y


static func _next_ambient_index(existing: Array) -> int:
	var n := 0
	for item in existing:
		var mob_name := str(item.get("name", ""))
		if not mob_name.begins_with("mob_a_"):
			continue
		var tail := mob_name.trim_prefix("mob_a_")
		if tail.is_valid_int():
			n = maxi(n, tail.to_int() + 1)
	return n


static func _type_for(home: int, roll: int) -> String:
	if home == MobCatalog.HOME_SAND:
		return MobCatalog.CRAB
	return MobCatalog.SLIME if roll % 2 == 0 else MobCatalog.PIGLET


static func _first_free(pool: Array, taken: Array[Vector2i]) -> Variant:
	for c in pool:
		var ok := true
		for t in taken:
			if maxi(absi(c.x - t.x), absi(c.y - t.y)) < MIN_GAP:
				ok = false
				break
		if ok:
			return c
	return null


func opening_roster(world: TileMap, origin: Vector2i, seed_value: int, rate: float) -> bool:
	## True when every planned mob is still here and no player body exists
	## yet. A later castle may clear trees and change the plan; a death or
	## a player already in the world means this set must stay.
	if mobs().size() != plan(world, origin, seed_value, rate).size():
		return false
	var parent := world.get_parent()
	if parent == null:
		return false
	for child in parent.get_children():
		if child is CharacterBody2D:
			return false
	return true


func spawn_for_world(world: TileMap, origin: Vector2i, seed_value: int, rate := 1.0, reset_credits := true) -> int:
	## Server only: replace any mobs with this map's plan at `rate`. Returns
	## the count. Clients get the server's mobs and never plan their own.
	## `reset_credits` false skips the kill-credit packet. The caller uses
	## that only for an opening set that has not paid anyone.
	if not multiplayer.is_server():
		return 0
	# These mob ids are about to be used again. Drop kill credits first, or
	# the new mob_0 could not pay.
	if reset_credits:
		var points := get_node_or_null("../../Points") as Points
		if points:
			points.clear_kill_credits()
	clear_mobs()
	var plans := plan(world, origin, seed_value, rate)
	for i in plans.size():
		var p: Dictionary = plans[i]
		spawner.spawn({
			"name": "mob_%d" % i,
			"type": p["type"],
			"pos": world.map_to_local(p["cell"]),
			"seed": hash(Vector2i(seed_value, i)),
		})
	return plans.size()


func clear_mobs() -> void:
	for child in get_children():
		if child is Mob:
			remove_child(child)
			child.queue_free()


func mobs() -> Array:
	return get_children().filter(func(n: Node) -> bool: return n is Mob)


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now := Time.get_ticks_msec()
	if _living_player_cells().is_empty():
		# Nobody to spawn around. Do not despawn the opening wave.
		_player_since = -1
		return
	if _player_since < 0:
		_player_since = now
	if now - _player_since < ambient_delay_ms:
		return
	if _last_ambient_ms >= 0 and now - _last_ambient_ms < AMBIENT_DELAY_MS:
		return
	run_ambient_tick()


func run_ambient_tick() -> Dictionary:
	## Server only: apply one plan_tick. Despawn is queue_free while the mob
	## is still a child, so the MultiplayerSpawner replicates the free.
	var empty := {"spawn": [], "despawn": []}
	if not multiplayer.is_server():
		return empty
	var world := _world()
	if world == null:
		return empty
	var players := _living_player_cells()
	if players.is_empty():
		return empty
	if _player_since < 0:
		_player_since = Time.get_ticks_msec()
	_last_ambient_ms = Time.get_ticks_msec()
	var plan := plan_tick(world, players, _existing_for_plan(world), _map_seed(), _ambient_tick, _rate(), ambient_scale())
	_ambient_tick += 1
	for mob_name in plan["despawn"]:
		var node := get_node_or_null(str(mob_name))
		if node is Mob and not (node as Mob).is_queued_for_deletion():
			node.queue_free()
	for item in plan["spawn"]:
		var cell: Vector2i = item["cell"]
		var index := int(str(item["name"]).trim_prefix("mob_a_"))
		spawner.spawn({
			"name": item["name"],
			"type": item["type"],
			"pos": world.map_to_local(cell),
			"seed": hash(Vector2i(_map_seed(), index)),
		})
	return plan


func _world() -> TileMap:
	return get_node_or_null("../worldMap") as TileMap


func _map_seed() -> int:
	var main := get_node_or_null("../..")
	if main != null and main.get("world_params") is MapGenParams:
		return (main.world_params as MapGenParams).altitude_seed
	return 0


func _rate() -> float:
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return 1.0
	return float(settings.mob_rate)


func _living_player_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var world := _world()
	var root := get_parent()
	if world == null or root == null:
		return out
	for child in root.get_children():
		if child is CharacterBody2D and Mob.is_alive(child):
			out.append(world.local_to_map(child.position))
	return out


func _existing_for_plan(world: TileMap) -> Array:
	var out: Array = []
	for m in mobs():
		if (m as Mob).is_queued_for_deletion():
			continue
		out.append({
			"name": str(m.name),
			"cell": world.local_to_map(m.position),
			"pinned": (m as Mob).pinned(),
		})
	return out


func _make_mob(data: Dictionary) -> Node:
	var mob: Mob = load(MOB_SCENE_PATH).instantiate()
	mob.name = data["name"]
	mob.setup(data["type"], data["pos"], data["seed"])
	return mob
