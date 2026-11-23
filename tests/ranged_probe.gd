extends "res://tests/helpers/probe_base.gd"
## One peer of a bow-shot session, started by test_ranged_two_players.
##   -- --port=N --out=PATH --host --seed=11   listen host on seed 11
##   -- --port=N --out=PATH --seed=11          join localhost:N
## The host freezes mobs and stops health regen, picks two open cells, and
## writes them as "marks". While PATH.stand holds x,y this peer stands there.
## While PATH.fire changes, a client fires one bow shot at peer 1 (token
## "away" aims the other way). Every 100 ms it writes PATH. PATH.stop ends it.

var _id := 0
var _host := false
var _seed := 0
var _marks: Array = []
var _fired := ""


func _run() -> void:
	_seed = option("--seed").to_int()
	_host = has_option("--host")
	if _seed == 0:
		printerr("ranged_probe: needs --port, --out, --seed and the main scene")
		quit(1)
		return
	var main = await open_game(_host)
	if main == null:
		printerr("ranged_probe: needs --port, --out, --seed and the main scene")
		quit(1)
		return
	if _host:
		var params := MapGenParams.make_defaults()
		params.biome_frequency = 0.0
		params.altitude_seed = _seed
		params.moisture_seed = _seed
		params.temperature_seed = _seed
		params.items_seed = _seed
		params.biome_seed = _seed
		if host_game(main, params) == OK:
			_quiet_mobs(main)
			host_listening()
	else:
		await join_game(main)
	var world: Node = main.get_node("World")
	var deadline := Time.get_ticks_msec() + 90000
	while game_active(main, deadline):
		_note_self(world)
		if _host:
			_stop_regen(world)
			if _marks.is_empty() and main.world_params != null:
				_marks = _find_marks(main)
		_stand(world)
		_fire(main, world)
		if snapshot_due(main):
			_write(main, world)
		await process_frame
	finish(main, func() -> void: _write(main, world))


func _note_self(world: Node) -> void:
	for child in world.get_children():
		if child is CharacterBody2D and child.is_multiplayer_authority():
			_id = int(str(child.name))
			return
	if _id == 0:
		_id = world.get_tree().get_multiplayer().get_unique_id()


func _quiet_mobs(main: Node) -> void:
	var mobs := main.get_node_or_null("World/Mobs")
	if mobs == null:
		return
	for child in mobs.get_children():
		child.set_physics_process(false)


func _stop_regen(world: Node) -> void:
	for child in world.get_children():
		if child is CharacterBody2D:
			var timer := child.get_node_or_null("regen_timer") as Timer
			if timer:
				timer.stop()


func _stand(world: Node) -> void:
	if not FileAccess.file_exists(probe_out + ".stand"):
		return
	var text := FileAccess.get_file_as_string(probe_out + ".stand").strip_edges()
	var parts := text.split(",")
	if parts.size() != 2:
		return
	var me := world.get_node_or_null(str(_id)) as CharacterBody2D
	if me == null or not me.is_multiplayer_authority():
		return
	me.velocity = Vector2.ZERO
	me.position = Vector2(float(parts[0]), float(parts[1]))
	me.set_physics_process(false)


func _fire(main: Node, world: Node) -> void:
	if _host or not FileAccess.file_exists(probe_out + ".fire"):
		return
	var token := FileAccess.get_file_as_string(probe_out + ".fire").strip_edges()
	if token == "" or token == _fired:
		return
	_fired = token
	var me := world.get_node_or_null(str(_id)) as CharacterBody2D
	var target := world.get_node_or_null("1") as Node2D
	var wheel := main.get_node_or_null("CanvasLayer1/ToolWheel")
	if (
		me == null
		or target == null
		or wheel == null
		or not wheel.has_method("select")
		or not me.is_multiplayer_authority()
	):
		return
	wheel.select(ToolWheel.Tool.BOW)
	var toward := target.global_position - me.global_position
	var dir: Vector2 = toward if token != "away" else -toward
	if dir.length_squared() < 1.0:
		return
	me.attack_toward(AttackAim.direction_name(dir), dir.angle())


func _find_marks(main: Node) -> Array:
	## Two open cells four steps apart whose joining segment is clear of
	## terrain and of any mob closer than the far cell.
	var map: TileMap = main.get_node("World/worldMap")
	var world: Node = main.get_node("World")
	var host := world.get_node_or_null("1") as Node2D
	if host == null or map.get_world_2d() == null:
		return []
	var space := map.get_world_2d().direct_space_state
	var exclude: Array = []
	var mobs: Array = main.get_node("World/Mobs").mobs()
	for child in world.get_children():
		if child is CollisionObject2D:
			exclude.append((child as CollisionObject2D).get_rid())
	var origin := map.local_to_map(map.to_local(host.global_position))
	var steps: Array[Vector2i] = [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]
	for r in range(0, 28):
		for y in range(origin.y - r, origin.y + r + 1):
			for x in range(origin.x - r, origin.x + r + 1):
				if r > 0 and maxi(absi(x - origin.x), absi(y - origin.y)) != r:
					continue
				var cell := Vector2i(x, y)
				if not _open(map, cell):
					continue
				for step in steps:
					var other: Vector2i = cell + step
					if not _open(map, other):
						continue
					var here: Vector2 = map.to_global(map.map_to_local(cell))
					var there: Vector2 = map.to_global(map.map_to_local(other))
					var from: Vector2 = there + AttackAim.ORIGIN
					var aim := here + Vector2(0, -5)
					if not AttackAim.clear_shot(space, from, aim, exclude):
						continue
					var mob_hit: Dictionary = RangedShot.fly(
						map, from, here - there, mobs, [], null
					)
					if (
						mob_hit.get("kind") == "mob"
						and from.distance_to(mob_hit["end"]) < from.distance_to(here) - 6.0
					):
						continue
					return [[here.x, here.y], [there.x, there.y]]
	return []


func _open(map: TileMap, cell: Vector2i) -> bool:
	if map.get_cell_source_id(0, cell) == -1 or not map.is_walkable_land(cell):
		return false
	return map.get_cell_source_id(1, cell) == -1


func _write(main: Node, world: Node) -> void:
	var players := {}
	var shots := world.get_node_or_null("RangedShots") as RangedShots
	for child in world.get_children():
		if child is CharacterBody2D and child.get_node_or_null("Health") != null:
			var peer := int(str(child.name))
			players[str(peer)] = {
				"health": child.health.health,
				"pos": [child.position.x, child.position.y],
				"invulnerable": child.health.is_invulnerable(),
				"cooldown_until": shots.cooldown_until(peer) if shots != null else 0,
				"cooldown_ready": shots.cooldown_ready(peer) if shots != null else true,
			}
	var me := world.get_node_or_null(str(_id)) as CharacterBody2D
	var state := {
		"id": str(_id),
		"ready": main.world_params != null and me != null,
		"host": _host,
		"marks": _marks,
		"accepted": shots.accepted if shots != null else 0,
		"rejected": shots.rejected if shots != null else 0,
		"swinging": me.isAttacking if me != null else false,
		"players": players,
		"errors": _errors.snapshot(),
	}
	write_result(state)
