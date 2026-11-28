extends "res://tests/helpers/probe_base.gd"
## One peer of a barracks soldier sync session (#553). Modes place, move, watch.

var _place_error := ""
var _training_charge := Vector2i.ZERO
var _train_anchor := Vector2i.ZERO
var _saw_move := false
var _issued: Array = []


func _run() -> void:
	var save := option("--save")
	var host := has_option("--host")
	var mode := option("--mode", "watch")
	if host and save == "":
		printerr("soldier_sync_probe: needs --port, --out, --save with --host, and the main scene")
		quit(1)
		return
	var main = await open_game(host)
	if main == null:
		printerr("soldier_sync_probe: needs --port, --out, --save with --host, and the main scene")
		quit(1)
		return
	main.get_node("CanvasLayer2/MainMenu").hide()
	if host:
		var error := host_saved_game(main, save)
		if error != "":
			printerr("soldier_sync_probe: could not host %s: %s" % [save, error])
			quit(1)
			return
		host_listening()
	else:
		await join_game(main)
	var world = main.get_node("World/worldMap")
	var requests: SoldierRequests = main.get_node("World/Soldiers")
	var phase := "idle"
	var deadline := Time.get_ticks_msec() + 90000
	while game_active(main, deadline):
		if main.multiplayer == null:
			break
		var me: Node2D = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id()))
		var ready := main.world_params != null and me != null
		if not host and mode == "place" and phase == "idle" and ready:
			phase = "working"
			_place_error = await _do_place(main, world, me, requests)
			phase = "done"
		if ready and mode == "move" and phase == "idle":
			if host and main.multiplayer.get_peers().size() == 1:
				var client: int = main.multiplayer.get_peers()[0]
				_place_error = _spawn_move_fixture(world, requests, client)
				phase = "done"
			elif not host:
				var unit := requests.get_node_or_null("command_probe") as Soldier
				if unit != null:
					var target := unit.position + Vector2(64, 0)
					_issued = _coords(target)
					requests.request_move.rpc_id(1, PackedStringArray(["command_probe"]), target)
					phase = "done"
		if snapshot_due(main):
			_write(main, world, me, requests)
		await process_frame
	finish(main, func() -> void: _write(main, world, local_player(main), requests))


func _spawn_move_fixture(world: TileMap, requests: SoldierRequests, owner: int) -> String:
	var start: Variant = _search(
		world,
		func(cell: Vector2i) -> bool:
			for i in 5:
				if not world.predicted_clear(cell + Vector2i(i, 0)):
					return false
			return true
	)
	if start == null:
		return "no clear command lane"
	(
		requests
		. spawn_saved(
			{
				"name": "command_probe",
				"owner": owner,
				"order": "hold",
				"pos": world.to_global(world.map_to_local(start)),
				"seed": 11,
			}
		)
	)
	return ""


func _coords(pos: Vector2) -> Array:
	return [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01)]


func _command_snapshot(requests: SoldierRequests) -> Dictionary:
	var unit := requests.get_node_or_null("command_probe") as Soldier
	if unit == null:
		return {}
	_saw_move = _saw_move or unit.order == "move"
	return {
		"saw_move": _saw_move,
		"row":
		[unit.owner_peer, unit.order, _coords(unit.global_position), _coords(unit.move_target)],
	}


func _do_place(main, world, me: Node2D, requests: SoldierRequests) -> String:
	var interaction: Interaction = main.get_node("World/Interaction")
	var structure_requests = main.get_node("World/StructureRequests")
	var inventory: Inventory = main.get_node("Inventory")
	var land: Variant = _search(
		world, func(cell: Vector2i) -> bool: return _barracks_ok(world, cell, 0)
	)
	if land == null:
		return "no clear barracks anchor"
	var err := await _ready_to_build(main, me, interaction.cell_center(land) + Vector2(0, 48))
	if err != "":
		return err
	var one: Array[Vector2i] = [land]
	inventory.add(Inventory.WOOD, 20)
	inventory.add(Inventory.STONE, 10)
	if not structure_requests.place(BuildCosts.BARRACKS, one, 0):
		return "place was not sent"
	var builder: int = main.multiplayer.get_unique_id()
	if not await _until(func() -> bool: return _barracks_count(world, builder) >= 1, 8000):
		return "built barracks was not applied"
	err = await _ready_to_build(main, me, interaction.cell_center(land) + Vector2(0, 48))
	if err != "":
		return err
	inventory.add(Inventory.WOOD, 8)
	inventory.add(Inventory.STONE, 5)
	var before := BuildCosts.balance(inventory)
	requests.train(land)
	if not await _until(func() -> bool: return _soldier_rows(requests).size() >= 1, 15000):
		return "soldier did not spawn"
	_training_charge = before - BuildCosts.balance(inventory)
	if not main.multiplayer.is_server():
		requests.request_order.rpc_id(1)
	if not await _until(
		func() -> bool:
			var rows := _soldier_rows(requests)
			return not rows.is_empty() and str(rows[0][2]) == "hold",
		8000
	):
		return "hold order did not sync"
	return ""


func _ready_to_build(main, me: Node2D, where: Vector2) -> String:
	return await _wait_host_position(main, me, where, 5000)


func _wait_host_position(main, me: Node2D, where: Vector2, ms: int) -> String:
	var sync := me.get_node_or_null("MultiplayerSynchronizer")
	if sync is MultiplayerSynchronizer:
		(sync as MultiplayerSynchronizer).replication_interval = 0.0
	var peer_id := str(main.multiplayer.get_unique_id())
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		_pin(me, where)
		if _host_sees_position(peer_id, where, 4.0):
			return ""
		await process_frame
	return "host did not ack the player at %s" % where


func _pin(me: Node2D, where: Vector2) -> void:
	me.global_position = where
	if me is CharacterBody2D:
		(me as CharacterBody2D).velocity = Vector2.ZERO


func _host_sees_position(peer_id: String, where: Vector2, slack: float) -> bool:
	var path := probe_out.get_base_dir().path_join("p0.json")
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return false
	var pos = data.get("peers", {}).get(peer_id, null)
	if not pos is Array or pos.size() < 2:
		return false
	return Vector2(float(pos[0]), float(pos[1])).distance_to(where) <= slack


func _until(cond: Callable, ms: int) -> bool:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _barracks_count(world, owner: int) -> int:
	var n := 0
	for p in world.placed_structures().values():
		if str(p["name"]) == "barracks" and int(p["owner"]) == owner:
			n += 1
	return n


func _search(world, pred: Callable) -> Variant:
	var spawn: Vector2i = world.resolve_player_spawn()
	for r in range(0, 64):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := spawn + Vector2i(dx, dy)
				if pred.call(cell):
					return cell
	return null


func _barracks_ok(world, cell: Vector2i, turns: int) -> bool:
	var one: Array[Vector2i] = [cell]
	if not (
		ConstructionPlacer.new(world).can_place_geometry(BuildCosts.BARRACKS, one, turns).is_empty()
	):
		return false
	return true


func _peer_id(main) -> String:
	if main == null or main.multiplayer == null:
		return ""
	return str(main.multiplayer.get_unique_id())


func _soldier_rows(requests: SoldierRequests) -> Array:
	var rows: Array = []
	for child in requests.get_children():
		if child is Soldier and child.state != Soldier.State.DYING:
			rows.append([str(child.name), child.owner_peer, child.order])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return str(a) < str(b))
	return rows


func _write(main, world, me: Node2D, requests: SoldierRequests) -> void:
	if probe_out == "":
		return
	var peers := {}
	var world_root: Node = null
	if main != null:
		world_root = main.get_node_or_null("World")
	if world_root != null:
		for child in world_root.get_children():
			if child is CharacterBody2D and str(child.name).is_valid_int():
				peers[str(child.name)] = [child.global_position.x, child.global_position.y]
	write_result(
		{
			"id": _peer_id(main),
			"ready": main != null and main.world_params != null and me != null,
			"place_error": _place_error,
			"peers": peers,
			"soldiers": _soldier_rows(requests),
			"training_charge": [_training_charge.x, _training_charge.y],
			"issued": _issued,
			"command": _command_snapshot(requests) if requests != null else {},
			"pending_jobs": requests.pending_job_count() if requests != null else 0,
			"errors": _errors.snapshot(),
		}
	)
