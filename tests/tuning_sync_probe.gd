extends "res://tests/helpers/probe_base.gd"

const CASTLE := &"building.castle_wood"
const MINE := &"building.mine_wood"
const TIMEOUT_MS := 8000


func _run() -> void:
	var hosting := has_option("--host")
	var main := await open_game(hosting)
	if main == null:
		quit(1)
		return
	install_round_trip(main)
	var passed := await _host(main) if hosting else await _join(main)
	write_result({"done": true, "passed": passed, "errors": _errors.snapshot()})
	if hosting:
		await wait_for_state(
			func() -> bool: return FileAccess.file_exists(probe_out + ".stop"), TIMEOUT_MS
		)
	quit(0 if passed else 1)


func _host(main: Node) -> bool:
	var grants := main.get_node("AdminResourceGrants")
	var inventory: Inventory = grants.inventory
	grants.set_script(GrantPolicy)
	grants.inventory = inventory
	var params := MapGenParams.make_defaults()
	params.altitude_seed = 11
	params.moisture_seed = 12
	params.temperature_seed = 13
	params.items_seed = 14
	params.biome_seed = 15
	if host_game(main, params) != OK:
		return false
	Tuning.set_value(CASTLE, 39)
	host_listening()
	var client_out := probe_out.get_base_dir().path_join("p1.json")
	if not await wait_for_state(
		func() -> bool: return HostListen.read_probe_result(client_out).has("joined"), TIMEOUT_MS
	):
		return false
	Tuning.set_value(CASTLE, 40)
	if not await wait_for_state(func() -> bool: return grants.denied_peer != 0, TIMEOUT_MS):
		return false
	return (
		grants.denied_peer in main.multiplayer.get_peers()
		and BuildCosts.cost(BuildCosts.MINE) == 15
		and BuildCosts.cost(BuildCosts.CASTLE) == 35
	)


func _join(main: Node) -> bool:
	# A snapshot replaces local overrides even when the host has no override for a key.
	Tuning.set_value(MINE, 23)
	var spawn_cost := [Vector2i.ZERO]
	main.get_node("World").child_entered_tree.connect(
		func(child: Node) -> void:
			if (
				child is CharacterBody2D
				and str(child.name) == str(main.multiplayer.get_unique_id())
			):
				spawn_cost[0] = Vector2i(
					BuildCosts.cost(BuildCosts.CASTLE), BuildCosts.cost(BuildCosts.MINE)
				)
	)
	await join_game(main)
	if not await wait_for_state(func() -> bool: return local_player(main) != null, TIMEOUT_MS):
		return false
	if spawn_cost[0] != Vector2i(39, 15):
		printerr("tuning_sync_probe: first build costs were ", spawn_cost[0], ", expected (39, 15)")
		return false
	write_result({"joined": true})
	if not await wait_for_state(
		func() -> bool: return BuildCosts.cost(BuildCosts.CASTLE) == 40, TIMEOUT_MS
	):
		return false
	return await _request_edits(main)


func _request_edits(main: Node) -> bool:
	var sync := main.get_node("TuningSync")
	sync.set_value(MINE, 101)
	if BuildCosts.cost(BuildCosts.MINE) != 15 or not await wait_for_round_trip(main):
		return false
	if BuildCosts.cost(BuildCosts.MINE) != 100:
		return false
	sync.reset(MINE)
	if not await wait_for_round_trip(main) or BuildCosts.cost(BuildCosts.MINE) != 15:
		return false
	sync.reset_all()
	if not await wait_for_round_trip(main) or BuildCosts.cost(BuildCosts.CASTLE) != 35:
		return false
	sync.set_value(MINE, 16)
	return await wait_for_round_trip(main) and BuildCosts.cost(BuildCosts.MINE) == 15


class GrantPolicy:
	extends AdminResourceGrants

	var requests := 0
	var denied_peer := 0

	func is_admin(peer_id: int) -> bool:
		if peer_id == 1:
			return true
		requests += 1
		if requests <= 3:
			return true
		denied_peer = peer_id
		return false
