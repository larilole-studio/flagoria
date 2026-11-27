class_name Tuning
extends RefCounted
## In-memory gameplay tuning shared within the local game process.

const BUILDING := "Building costs"
const MINE := "Mine"
const SAWMILL := "Sawmill"
const HAND_MINING := "Hand mining"
const CHOPPING := "Chopping"
const SOLDIERS := "Soldiers"
const DEFAULT_TRAINING_WOOD := 8
const MOVEMENT := "Movement"
const VISUALS := "Visuals"

# Run doubles both caps. At this ceiling, even running stays within
# CutRateLimit's 2x headroom over the original keyboard walk speed.
const PLAYER_SPEED_LIMIT := 130

# GDScript signals belong to an instance. Keep one emitter for the static API.
static var events := ChangeEvents.new()
static var _entries: Dictionary[StringName, Dictionary] = {}
static var _overrides: Dictionary[StringName, float] = {}


static func _static_init() -> void:
	_add(&"building.plank_wood", BUILDING, "Plank wood", 1, 0, 100, 1)
	_add(&"building.wall_block_wood", BUILDING, "Palisade wall block wood", 2, 0, 100, 1)
	_add(&"building.tower_wood", BUILDING, "Wooden tower wood", 10, 0, 100, 1)
	_add(&"building.castle_wood", BUILDING, "Castle wood", 35, 0, 100, 1)
	_add(&"building.guard_post_wood", BUILDING, "Guard post wood", 14, 0, 100, 1)
	_add(&"building.barracks_wood", BUILDING, "Barracks wood", 20, 0, 100, 1)
	_add(&"building.mine_wood", BUILDING, "Mine wood", 15, 0, 100, 1)
	_add(&"building.castle_stone", BUILDING, "Castle stone", 15, 0, 100, 1)
	_add(&"building.guard_post_stone", BUILDING, "Guard post stone", 6, 0, 100, 1)
	_add(&"building.barracks_stone", BUILDING, "Barracks stone", 10, 0, 100, 1)
	_add(&"building.sawmill_stone", BUILDING, "Sawmill stone", 15, 0, 100, 1)
	_add(&"building.refund_share", BUILDING, "Demolish refund share", 0.5, 0, 1, 0.05, false)
	_add(&"mine.cycle_seconds", MINE, "Production cycle (s)", 60, 1, 600, 0.5, false)
	_add(&"mine.stone_per_cycle", MINE, "Stone per cycle", 1, 1, 100, 1)
	_add(&"sawmill.cycle_seconds", SAWMILL, "Production cycle (s)", 60, 1, 600, 0.5, false)
	_add(&"sawmill.wood_per_cycle", SAWMILL, "Wood per cycle", 1, 1, 100, 1)
	_add(&"hand_mining.rock_hits", HAND_MINING, "Hits per rock", 2, 1, 10, 1)
	_add(&"hand_mining.rock_stone", HAND_MINING, "Stone per rock", 2, 1, 100, 1)
	for id in ["tree", "pine", "bush"]:
		var plant := InteractableCatalog.by_id(id)
		var name := plant.id.capitalize()
		_add(_plant_key(plant, "hits"), CHOPPING, name + " hits", plant.hits, 1, 10, 1)
		_add(
			_plant_key(plant, "wood"), CHOPPING, name + " wood", plant.amount_of(&"wood"), 1, 100, 1
		)
	_add(&"soldiers.training_wood", SOLDIERS, "Training wood", DEFAULT_TRAINING_WOOD, 1, 100, 1)
	_add(&"soldiers.walk_speed", SOLDIERS, "Walk speed (px/s)", 48, 1, 120, 0.5, false)
	_add(
		&"movement.keyboard_speed", MOVEMENT, "Keyboard speed (px/s)", 130, 1, PLAYER_SPEED_LIMIT, 1
	)
	_add(
		&"movement.joystick_speed", MOVEMENT, "Joystick speed (px/s)", 60, 1, PLAYER_SPEED_LIMIT, 1
	)
	_add(&"visuals.cloud_far_speed", VISUALS, "Far cloud drift (px/s)", 0.5, 0.1, 5, 0.1, false)
	_add(&"visuals.cloud_near_speed", VISUALS, "Near cloud drift (px/s)", 1.0, 0.1, 5, 0.1, false)
	_add(&"visuals.mine_cart_fps", VISUALS, "Mine cart animation (fps)", 5, 1, 30, 0.5, false)


static func value(key: StringName) -> float:
	return _overrides.get(key, _entries[key]["default"])


static func set_value(key: StringName, v: float) -> void:
	if not _entries.has(key) or is_nan(v):
		return
	var entry := _entries[key]
	var minimum: float = entry["min"]
	var maximum: float = entry["max"]
	var bounded := clampf(v, minimum, maximum)
	var next := clampf(minimum + snappedf(bounded - minimum, entry["step"]), minimum, maximum)
	if is_equal_approx(next, entry["default"]):
		reset(key)
	elif not is_equal_approx(next, value(key)):
		_overrides[key] = next
		events.changed.emit(key)


static func reset(key: StringName) -> void:
	if _overrides.erase(key):
		events.changed.emit(key)


static func reset_all() -> void:
	var keys := _overrides.keys()
	_overrides.clear()
	for key in keys:
		events.changed.emit(key)


static func overrides_for_save() -> Dictionary:
	return _overrides.duplicate()


static func restore_overrides(overrides: Dictionary) -> void:
	for key in _entries:
		var raw: Variant = overrides.get(String(key))
		if (raw is int or raw is float) and is_finite(float(raw)):
			set_value(key, float(raw))
		else:
			reset(key)


static func step_value(key: StringName, delta: float) -> void:
	if _entries.has(key):
		set_value(key, value(key) + delta)


static func overrides() -> Dictionary:
	return _overrides.duplicate()


static func replace_overrides(snapshot: Dictionary) -> void:
	for key in _overrides.keys():
		if not snapshot.has(key):
			reset(key)
	for key in snapshot:
		set_value(key, snapshot[key])


static func entries_by_category() -> Dictionary:
	var groups := {}
	for entry in _entries.values():
		var category: String = entry["category"]
		if not groups.has(category):
			groups[category] = []
		groups[category].append(entry.duplicate())
	return groups


static func chop_hits(plant: InteractableType) -> int:
	var key := _plant_key(plant, "hits")
	return int(value(key)) if _entries.has(key) else plant.hits


static func chop_yields(plant: InteractableType) -> Dictionary[StringName, int]:
	var key := _plant_key(plant, "wood")
	var yields := plant.yields.duplicate()
	if _entries.has(key):
		yields[&"wood"] = int(value(key))
	return yields


static func _plant_key(plant: InteractableType, field: String) -> StringName:
	return StringName("chopping.%s_%s" % [plant.id, field])


static func _add(
	key: StringName,
	category: String,
	label: String,
	default: float,
	minimum: float,
	maximum: float,
	step: float,
	integer := true
) -> void:
	_entries[key] = {
		"key": key,
		"category": category,
		"label": label,
		"default": default,
		"min": minimum,
		"max": maximum,
		"step": step,
		"integer": integer,
	}


class ChangeEvents:
	extends RefCounted
	signal changed(key: StringName)
