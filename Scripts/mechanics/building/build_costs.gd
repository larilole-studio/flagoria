class_name BuildCosts
extends RefCounted
## Shared wood and stone prices, affordability and construction transactions.

const PLANK := &"plank"
const WALL_BLOCK := &"wall_block"
const TOWER := &"tower"
const CASTLE := &"castle"
const GUARD_POST := &"guard_post"
const BARRACKS := &"barracks"
const MINE := &"mine"
const START_CASTLE := &"start_castle"

## Requestable named structures take one anchor cell.
const NAMED_STRUCTURES := {
	TOWER: "tower_wood",
	CASTLE: "castle",
	GUARD_POST: "guard_post",
	BARRACKS: "barracks",
	MINE: "mine",
}

const CITY_KINDS := {
	CASTLE: true,
	GUARD_POST: true,
}

## Kind -> wood for one unit: a plank is one bridge cell, a wall block one
## wall cell, a tower one tower, a castle one extra castle (#527). The
## starting castle each player gets is free.
const WOOD := {
	PLANK: 1,
	WALL_BLOCK: 2,
	TOWER: 10,
	CASTLE: 35,
	GUARD_POST: 14,
	BARRACKS: 20,
	MINE: 15,
	START_CASTLE: 0,
}
const STONE := {CASTLE: 15, GUARD_POST: 6, BARRACKS: 10}
## Share of a build’s cost given back when Demolish removes it.
const REFUND_SHARE := 0.5

const NOT_ENOUGH_WOOD := "not enough wood"
const NOT_ENOUGH_STONE := "not enough stone"
const NOT_ENOUGH_WOOD_AND_STONE := "not enough wood and stone"
const MULTIPLAYER_ON := "multiplayer on"
const UNKNOWN_KIND := "unknown kind"
const NOT_PLACED := "not placed"
## Spend refused after the refusal check (for example a stub inventory).
## Nothing is written (#380 item 3: charge before write, so a failed spend
## cannot leave tiles in place).
const SPEND_FAILED := "spend failed"

## Kinds that stay host-alone. Towers (#497), castles (#527) and walls (#498)
## are requested on StructureRequests. The starting castle is still placed by
## the host alone.
const HOST_ALONE := {
	START_CASTLE: true,
}


static func is_requestable(kind: StringName) -> bool:
	return kind == WALL_BLOCK or NAMED_STRUCTURES.has(kind)


static func cost(kind: StringName, units := 1) -> int:
	## Wood for `units` of `kind`; -1 for a kind not in WOOD.
	return WOOD[kind] * units if WOOD.has(kind) else -1


static func price(kind: StringName, units := 1) -> Vector2i:
	## x is wood and y is stone.
	return Vector2i(cost(kind, units), int(STONE.get(kind, 0)) * units)


static func refund(kind: StringName, units := 1) -> Vector2i:
	if not WOOD.has(kind):
		return Vector2i.ZERO
	var amount := price(kind, units)
	return Vector2i(floori(amount.x * REFUND_SHARE), floori(amount.y * REFUND_SHARE))


static func label(amount: Vector2i, prefix := "") -> String:
	var wood := "%s%d wood" % [prefix, amount.x]
	if amount.y == 0:
		return wood
	return "%s + %d stone" % [wood, amount.y]


static func balance(inventory: Inventory) -> Vector2i:
	return Vector2i(inventory.count_of(Inventory.WOOD), inventory.count_of(Inventory.STONE))


static func shortage(available: Vector2i, amount: Vector2i) -> String:
	if available.x < amount.x:
		return NOT_ENOUGH_WOOD_AND_STONE if available.y < amount.y else NOT_ENOUGH_WOOD
	return NOT_ENOUGH_STONE if available.y < amount.y else ""


static func credit(inventory: Inventory, amount: Vector2i) -> void:
	if amount.x > 0:
		inventory.add(Inventory.WOOD, amount.x)
	if amount.y > 0:
		inventory.add(Inventory.STONE, amount.y)


static func charge(inventory: Inventory, amount: Vector2i) -> bool:
	if amount.x < 0 or amount.y < 0 or not shortage(balance(inventory), amount).is_empty():
		return false
	if amount.x > 0 and not inventory.spend(Inventory.WOOD, amount.x):
		return false
	if amount.y > 0 and not inventory.spend(Inventory.STONE, amount.y):
		credit(inventory, Vector2i(amount.x, 0))
		return false
	return true


static func refusal(inventory: Inventory, kind: StringName, units := 1) -> String:
	if not WOOD.has(kind):
		return UNKNOWN_KIND
	if HOST_ALONE.has(kind) and Interaction.multiplayer_on(inventory.multiplayer):
		return MULTIPLAYER_ON
	return shortage(balance(inventory), price(kind, units))


static func buy(inventory: Inventory, kind: StringName, units: int, place: Callable) -> String:
	## Charge before writing and put both resources back if the writer refuses.
	var why := refusal(inventory, kind, units)
	if why != "":
		return why
	var amount := price(kind, units)
	if not charge(inventory, amount):
		return SPEND_FAILED
	var placed: Variant = place.call()
	if (placed is bool and placed) or (placed is int and placed > 0):
		return ""
	credit(inventory, amount)
	return NOT_PLACED
