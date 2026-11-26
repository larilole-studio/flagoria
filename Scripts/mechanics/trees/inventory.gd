class_name Inventory
extends Node
## Resources the local player has gathered or spent. Each peer has its own
## inventory, and PlayerSave stores its wood and stone balances.

signal changed(resource: StringName, count: int)

const WOOD := &"wood"
const STONE := &"stone"

var _counts := {}


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
