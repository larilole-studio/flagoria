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

const _WOOD_KEYS := {
	PLANK: &"building.plank_wood",
	WALL_BLOCK: &"building.wall_block_wood",
	TOWER: &"building.tower_wood",
	CASTLE: &"building.castle_wood",
	GUARD_POST: &"building.guard_post_wood",
	BARRACKS: &"building.barracks_wood",
	MINE: &"building.mine_wood",
}
const _STONE_KEYS := {
	CASTLE: &"building.castle_stone",
	GUARD_POST: &"building.guard_post_stone",
	BARRACKS: &"building.barracks_stone",
}

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


static func has_price(kind: StringName) -> bool:
	return kind == START_CASTLE or _WOOD_KEYS.has(kind)


static func has_stone_price(kind: StringName) -> bool:
	return _STONE_KEYS.has(kind)


static func cost(kind: StringName, units := 1) -> int:
	## Wood for `units` of `kind`; -1 for an unknown kind.
	if kind == START_CASTLE:
		return 0
	return int(Tuning.value(_WOOD_KEYS[kind])) * units if _WOOD_KEYS.has(kind) else -1


static func price(kind: StringName, units := 1) -> Vector2i:
	## x is wood and y is stone.
	var stone := int(Tuning.value(_STONE_KEYS[kind])) if has_stone_price(kind) else 0
	return Vector2i(cost(kind, units), stone * units)


static func refund(kind: StringName, units := 1) -> Vector2i:
	if not has_price(kind):
		return Vector2i.ZERO
	var amount := price(kind, units)
	var share := Tuning.value(&"building.refund_share")
	return Vector2i(floori(amount.x * share), floori(amount.y * share))


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
	if not has_price(kind):
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
