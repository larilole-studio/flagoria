extends "res://tests/net/test_wall_sync.gd"
## One hit shows 2 HP on both peers, then the wall disappears for all peers.


func _test_wall_break_two_players() -> int:
	return await run_wall_row(
		"test_wall_break_two_players", "break", _both_hp2, _same_walls, _await_break
	)


func _await_break(read: Callable) -> bool:
	if await wait_until(_broke.bind(read), 25000):
		return true
	printerr("FAIL wall_break_two_players: break host %s client %s" % [read.call(0), read.call(1)])
	return false


func _same_walls(peer: Dictionary, host: Dictionary) -> bool:
	return peer.get("walls", {}) == host.get("walls", {})


func _broke(read: Callable) -> bool:
	var client: Dictionary = read.call(1)
	if not client.get("break_done", false):
		return false
	var target: String = client["target"]
	return not read.call(0).get("walls", {}).has(target) and not client.get("walls", {}).has(target)


func _both_hp2(read: Callable) -> bool:
	return read.call(0).get("saw_hp2", false) and read.call(1).get("saw_hp2", false)
