class_name Inventory
extends Node
## Resources the local player has gathered or spent. Each peer has its own
## inventory, and PlayerSave stores its wood and stone balances.

signal changed(resource: StringName, count: int)

const WOOD := &"wood"
const STONE := &"stone"

## Keep issued and processed charges separate so requests cannot reuse a balance
## while an earlier host charge is still in flight.
var processed_charges := Vector2i.ZERO
var _issued_charges: Dictionary[int, Vector2i] = {}
var _counts := {}


func _ready() -> void:
	multiplayer.peer_disconnected.connect(
		func(peer_id: int) -> void: _issued_charges.erase(peer_id)
	)
	multiplayer.connected_to_server.connect(func() -> void: processed_charges = Vector2i.ZERO)


func record_charge(peer_id: int, amount: Vector2i) -> void:
	_issued_charges[peer_id] = issued_charges(peer_id) + amount


func issued_charges(peer_id: int) -> Vector2i:
	return _issued_charges.get(peer_id, Vector2i.ZERO)


func add(resource: StringName, amount := 1) -> int:
	## Add `amount` of `resource` and return the new count.
	var count: int = _counts.get(resource, 0) + amount
	_counts[resource] = count
	changed.emit(resource, count)
	return count


func count_of(resource: StringName) -> int:
	return _counts.get(resource, 0)


func spend(resource: StringName, amount: int) -> bool:
	## Take `amount` of `resource` and emit `changed`. False, and nothing
	## taken or emitted, when the count is below `amount` or `amount` is
	## negative. Spending 0 always succeeds.
	var count := count_of(resource)
	if amount < 0 or count < amount:
		return false
	_counts[resource] = count - amount
	changed.emit(resource, count - amount)
	return true
