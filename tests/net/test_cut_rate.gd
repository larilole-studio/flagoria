extends "res://tests/helpers/test_helpers.gd"
## The host's cut request limit (#355): request_cut beyond a peer's
## CutRateLimit bucket is dropped, a drag-sized burst and nonstop dragging
## while walking at top speed all go through, and each peer has its own
## bucket. In-process, with a MultiplayerAPI stand-in that records RPCs and
## sets the sender, so no network peer is opened.

const Batch := preload("res://tests/net/test_regrow_batch.gd")
const LIMIT_PATH := "res://Scripts/mechanics/interact/cut_rate_limit.gd"
const EMPTY := Vector2i(100000, 100000)  ## a cell with no plant and out of reach

const RATE_ROWS := {
	"test_cut_rate_burst_dropped": {"peer": 2, "refill": true, "drag": false},
	"test_cut_rate_per_peer": {"peer": 3, "refill": false, "drag": false},
	"test_cut_rate_drag_burst": {"peer": 2, "refill": false, "drag": true},
}


class FakeApi:
	extends Batch.FakeApi

	func _get_peer_ids() -> PackedInt32Array:
		return PackedInt32Array([2, 3])


func _limit_script() -> GDScript:
	return load(LIMIT_PATH) if ResourceLoader.exists(LIMIT_PATH) else null


func _host_scene(api: FakeApi) -> Dictionary:
	## A host main scene with the stand-in, on the first of a few seeds with
	## two plants near the origin, and a cutter node for peers 2 and 3 on
	## them. The limit's clock is pinned at `now[0]` s, when there is a limit.
	var scene = open_rpc_test_scene(api)
	var world = scene.get_node("World/worldMap")
	var cells: Array[Vector2i] = []
	for s in [11, 42, 7, 1, 99]:
		world.apply_map_params(_spawn_params(s, 0.0))
		world.generate_chunk(Vector2(0, 0))
		cells.clear()
		var used: Array = world.get_used_cells(1)
		used.sort()
		for cell in used:
			if cells.size() < 2 and world.choppable(cell) != null:
				cells.append(cell)
		if cells.size() == 2:
			break
	var interaction = scene.get_node("World/Interaction")
	var now := [0.0]
	var limit = interaction.get("cut_limit")
	if limit != null:
		limit.clock = func() -> float: return now[0]
	for i in cells.size():
		var cutter := Node2D.new()
		cutter.name = str(i + 2)
		scene.get_node("World").add_child(cutter)
		cutter.global_position = interaction.cell_center(cells[i])
	return {"scene": scene, "world": world, "interaction": interaction, "cells": cells, "now": now}


func _cut_by(api: FakeApi, s: Dictionary, peer: int, cell: Vector2i) -> bool:
	## `peer` asks the host to cut `cell`; true when the plant was cut and
	## the peer was sent its yields.
	api.sent.clear()
	api.sender = peer
	s["interaction"].request_cut(cell)
	var yields := api.sent.filter(
		func(r: Array) -> bool: return r[0] == peer and str(r[1]) == "receive_yields"
	)
	return s["world"].choppable(cell) == null and yields.size() == 1


func _spam(api: FakeApi, s: Dictionary, peer: int, count: int) -> void:
	api.sender = peer
	for i in count:
		s["interaction"].request_cut(EMPTY)


func _test_cut_rate_burst_dropped() -> int:
	return await _run_rate_row("test_cut_rate_burst_dropped")


func _test_cut_rate_per_peer() -> int:
	return await _run_rate_row("test_cut_rate_per_peer")


func _test_cut_rate_drag_burst() -> int:
	return await _run_rate_row("test_cut_rate_drag_burst")


func _run_rate_row(label: String) -> int:
	print("-- " + label)
	var row: Dictionary = RATE_ROWS[label]
	var script := _limit_script()
	if row["drag"] and script == null:
		printerr("FAIL %s: no %s" % [label, LIMIT_PATH])
		return 1
	var burst := int(script.BURST) if script else 162
	var spam := int(script.DRAG_CELLS) - 1 if row["drag"] else burst
	var api := FakeApi.new()
	var session := _host_scene(api)
	var cells: Array[Vector2i] = session["cells"]
	var peer: int = row["peer"]
	var fail := 0
	if cells.size() < (1 if row["drag"] else 2):
		printerr("FAIL %s: too few plants near the origin" % label)
		fail = 1
	else:
		var cell := cells[peer - 2]
		_spam(api, session, 2, spam)
		if row["refill"]:
			if _cut_by(api, session, peer, cell) or session["world"].choppable(cell) == null:
				printerr(
					(
						"FAIL %s: after %d requests, peer %d's next request cut %s"
						% [label, spam, peer, cell]
					)
				)
				fail += 1
			if script:
				session["now"][0] += 1.0 / script.RATE
		if not _cut_by(api, session, peer, cell):
			printerr(
				(
					"FAIL %s: peer %d could not cut %s after peer 2 sent %d requests"
					% [label, peer, cell, spam]
				)
			)
			fail += 1
	await close_rpc_test_scene(session["scene"])
	if fail == 0:
		var detail := ""
		if row["refill"]:
			detail = " (%d requests, then 1 dropped)" % burst
		elif row["drag"]:
			detail = " (%d requests)" % script.DRAG_CELLS
		print("PASS " + label + detail)
	return fail


func _in_reach(pos: Vector2, tile: float, reach: float) -> Dictionary:
	## Every cell whose centre is within `reach` of `pos`, on `tile` px cells.
	var out := {}
	var lo := Vector2i(floori((pos.x - reach) / tile), floori((pos.y - reach) / tile))
	var hi := Vector2i(floori((pos.x + reach) / tile), floori((pos.y + reach) / tile))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if pos.distance_to((Vector2(x, y) + Vector2(0.5, 0.5)) * tile) <= reach:
				out[Vector2i(x, y)] = true
	return out


func _test_cut_rate_numbers() -> int:
	## The limit's figures match the game: TILE is the tile set's cell size,
	## DRAG_CELLS is the most cell centres within Interaction.REACH of a point
	## (recounted over 1/4 px offsets), and a player dragging every frame
	## while walking 10 s at top speed (straight and diagonal) through a
	## plant on every cell is never refused.
	print("-- test_cut_rate_numbers")
	var script := _limit_script()
	if script == null:
		printerr("FAIL cut_rate_numbers: no %s" % LIMIT_PATH)
		return 1
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	var tiles: TileSet = scene.get_node("World/worldMap").tile_set
	scene.free()
	var tile := float(script.TILE)
	if Vector2(tiles.tile_size) != Vector2(tile, tile):
		printerr(
			"FAIL cut_rate_numbers: tiles are %s px, the limit assumes %s" % [tiles.tile_size, tile]
		)
		fail += 1
	var most := 0
	for a in 64:
		for b in 64:
			most = maxi(
				most, _in_reach(Vector2(a, b) * tile / 64.0, tile, Interaction.REACH).size()
			)
	if most != script.DRAG_CELLS:
		printerr(
			(
				"FAIL cut_rate_numbers: at most %d cells are in reach, DRAG_CELLS is %d"
				% [most, script.DRAG_CELLS]
			)
		)
		fail += 1
	var speed := 130.0
	for dir in [Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2(2, 1).normalized()]:
		var limit = script.new()
		var now := [0.0]
		limit.clock = func() -> float: return now[0]
		var asked := {}
		var refused := 0
		var start := Vector2(3.0, 5.0)
		for frame in 601:
			now[0] = frame / 60.0
			for cell in _in_reach(start + dir * speed * now[0], tile, Interaction.REACH):
				if not asked.has(cell):
					asked[cell] = true
					refused += int(not limit.allow(2))
		if refused > 0:
			printerr(
				(
					"FAIL cut_rate_numbers: walking %s at %d px/s, %d of %d requests were refused"
					% [dir, speed, refused, asked.size()]
				)
			)
			fail += 1
	if fail == 0:
		print(
			(
				"PASS test_cut_rate_numbers (%d cells in reach, burst %d, %.1f/s)"
				% [most, script.BURST, script.RATE]
			)
		)
	return fail
