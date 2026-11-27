class_name SawmillProduction
extends RefCounted
## A host game-time cycle for each sawmill placement.

const WORLD_MAP := preload("res://Scripts/world/TileMap.gd")
const STRUCTURE_NAME := BuildCosts.NAMED_STRUCTURES[BuildCosts.SAWMILL]

var _map: WORLD_MAP
var _elapsed: Dictionary[int, float] = {}


func _init(map: WORLD_MAP) -> void:
	_map = map


func register_sawmill(id: int) -> void:
	_elapsed[id] = 0.0


func remove_sawmill(id: int) -> void:
	_elapsed.erase(id)


func clear() -> void:
	_elapsed.clear()


func elapsed(id: int) -> float:
	return _elapsed.get(id, 0.0)


func restore_elapsed(id: int, saved: Variant) -> void:
	# A fresh placement already starts at zero, including legacy saves.
	if _elapsed.has(id) and (saved is int or saved is float):
		var seconds := float(saved)
		if seconds >= 0.0 and seconds < Tuning.value(&"sawmill.cycle_seconds"):
			_elapsed[id] = seconds


func is_producing(id: int) -> bool:
	## A placed sawmill can deliver to its owner. Replicas can query this too.
	return _elapsed.has(id) and _owner_connected(_map._structures.owner_of(id))


func advance(seconds: float) -> void:
	## Advance from the host's world clock. Undeliverable cycles are skipped.
	if _elapsed.is_empty() or seconds <= 0.0 or not _map.is_inside_tree():
		return
	var api := _map.multiplayer
	if not api.has_multiplayer_peer() or not api.is_server():
		return
	var cycle := Tuning.value(&"sawmill.cycle_seconds")
	var wood_per_cycle := int(Tuning.value(&"sawmill.wood_per_cycle"))
	for id in _elapsed:
		var total := _elapsed[id] + seconds
		if total < cycle:
			_elapsed[id] = total
			continue
		var wood := floori(total / cycle) * wood_per_cycle
		_elapsed[id] = fmod(total, cycle)
		_deliver(_map._structures.owner_of(id), wood)


func _owner_connected(owner: int) -> bool:
	if owner <= 0 or not _map.is_inside_tree():
		return false
	var api := _map.multiplayer
	var peer := api.multiplayer_peer
	return (
		peer != null
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
		and (owner == api.get_unique_id() or owner in api.get_peers())
	)


func _deliver(owner: int, wood: int) -> void:
	if not _owner_connected(owner):
		return
	var requests := _map.get_node_or_null("../StructureRequests") as StructureRequests
	if requests == null:
		return
	if owner == _map.multiplayer.get_unique_id():
		if requests.inventory != null:
			requests.inventory.add(Inventory.WOOD, wood)
	else:
		requests.receive_sawmill_wood.rpc_id(owner, wood)
