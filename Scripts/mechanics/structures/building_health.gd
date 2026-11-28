class_name BuildingHealth
extends Node2D
## Host combat API for named placements. HP travels with placement snapshots
## and saves. Live damage arrives on the same reliable channel as removal.

signal building_damaged(placement_id: int, owner: int, hp: int)
signal building_zeroed(placement_id: int)

const WorldMap := preload("res://Scripts/world/TileMap.gd")
const CRACK := Color("#2a2238")
const BAR_SIZE := Vector2(24, 3)
const NEUTRAL := Color("#b2adb7")

@onready var _map: WorldMap = $"../worldMap"
@onready var _requests: StructureRequests = $"../StructureRequests"


func _ready() -> void:
	_map._structures.health_display_changed.connect(queue_redraw)
	_map.ground_changed.connect(func(_bounds: Rect2i) -> void: queue_redraw())
	Tuning.events.changed.connect(_on_tuning_changed)


func hp(placement_id: int) -> int:
	var entry := _map._structures.placement_details(placement_id)
	return _remaining_hp(entry)


func max_hp(placement_id: int) -> int:
	var entry := _map._structures.placement_details(placement_id)
	return 0 if entry.is_empty() else Tuning.building_max_hp(entry["name"])


func placement_at(world_position: Vector2) -> int:
	return _map._structures.placement_at(_map.local_to_map(_map.to_local(world_position)))


func nearest_in_arc(origin: Vector2, angle: float, reach: float, arc: float) -> int:
	var radius := Vector2.ONE * reach
	var first := _map.local_to_map(_map.to_local(origin - radius))
	var last := _map.local_to_map(_map.to_local(origin + radius))
	var best := 0
	var best_distance := reach
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var id := _map._structures.placement_at(cell)
			if id == 0:
				continue
			var offset := _map.to_global(_map.map_to_local(cell)) - origin
			var distance := offset.length()
			if (
				distance > 0.001
				and distance <= best_distance
				and absf(angle_difference(angle, offset.angle())) <= arc * 0.5
			):
				best = id
				best_distance = distance
	return best


func nearest_enemy(origin: Vector2, reach: float, attacker_side: int) -> Dictionary:
	var radius := Vector2.ONE * reach
	var first := _map.local_to_map(_map.to_local(origin - radius))
	var last := _map.local_to_map(_map.to_local(origin + radius))
	var best := {}
	var best_distance := reach * reach
	var eligible := {}
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var id := _map._structures.placement_at(cell)
			if id == 0:
				continue
			if not eligible.has(id):
				var entry := _map._structures.placement_details(id)
				var owner: int = entry.get("owner", StructurePlacer.OWNER_NEUTRAL)
				eligible[id] = (
					owner != attacker_side
					and owner != StructurePlacer.OWNER_NEUTRAL
					and _remaining_hp(entry) > 0
				)
			if not eligible[id]:
				continue
			var at := _map.to_global(_map.map_to_local(cell))
			var distance := origin.distance_squared_to(at)
			if distance <= best_distance:
				best_distance = distance
				best = {"id": id, "position": at}
	return best


func host_damage(placement_id: int, amount: int, attacker_side: int) -> bool:
	if not multiplayer.is_server() or amount <= 0:
		return false
	var entry := _map._structures.placement_details(placement_id)
	var before := _remaining_hp(entry)
	if before <= 0 or entry["owner"] == attacker_side:
		return false
	var remaining := maxi(0, before - amount)
	if not multiplayer.get_peers().is_empty():
		receive_damage.rpc(placement_id, remaining)
	_apply_damage(placement_id, remaining, entry["owner"])
	if remaining == 0 and _map.remove_structure(placement_id):
		_requests.publish_structure_removed(placement_id)
	return true


@rpc("authority", "call_remote", "reliable")
func receive_damage(placement_id: int, remaining: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var entry := _map._structures.placement_details(placement_id)
	if not entry.is_empty():
		_apply_damage(placement_id, remaining, entry["owner"])


func _apply_damage(placement_id: int, remaining: int, owner: int) -> void:
	_map._structures.set_building_hp(placement_id, remaining)
	building_damaged.emit(placement_id, owner, remaining)
	if remaining == 0:
		building_zeroed.emit(placement_id)


func _remaining_hp(entry: Dictionary) -> int:
	if entry.is_empty():
		return 0
	var maximum := Tuning.building_max_hp(entry["name"])
	return clampi(entry.get("hp", maximum), 0, maximum)


func _on_tuning_changed(key: StringName) -> void:
	if key.begins_with("building_hp."):
		queue_redraw()


func _draw() -> void:
	var placements := _map.placed_structures()
	for id: int in placements:
		var placement: Dictionary = placements[id]
		if not placement.has("hp") or not _map.is_drawn(placement["anchor"]):
			continue
		var entry := _map._structures.placement_details(id)
		var fraction := float(_remaining_hp(entry)) / Tuning.building_max_hp(entry["name"])
		if fraction < 1.0:
			_draw_damage(entry, fraction)


func _draw_damage(entry: Dictionary, fraction: float) -> void:
	var anchor: Vector2i = entry["anchor"]
	var bounds := Rect2i(anchor, Vector2i.ONE)
	var cells: Array[Vector2i] = entry["cells"]
	for cell in cells:
		bounds = bounds.merge(Rect2i(cell, Vector2i.ONE))
		var offset := cell - anchor
		# Leave the anchor's facing marker clear on larger footprints.
		var cracked := cells.size() <= 2 or (cell != anchor and (offset.x + offset.y) % 2 == 0)
		if fraction <= 0.5 and cracked and _map.get_cell_source_id(1, cell) != -1:
			_draw_crack(_centre(cell), fraction <= 0.25, offset.x < 0)
	var top := _centre(bounds.position) + _centre(Vector2i(bounds.end.x - 1, bounds.position.y))
	var at := top / 2.0 - Vector2(BAR_SIZE.x / 2.0, 15.0)
	var owner: int = entry["owner"]
	var colour: Color = TowerCapture.BAR_COLOURS.get(owner, TowerCapture.BAR_OTHER)
	if owner == StructurePlacer.OWNER_NEUTRAL:
		colour = NEUTRAL
	draw_rect(Rect2(at - Vector2.ONE, BAR_SIZE + Vector2(2, 2)), TowerCapture.BAR_BACK)
	draw_rect(Rect2(at, Vector2(BAR_SIZE.x * fraction, BAR_SIZE.y)), colour)


func _draw_crack(at: Vector2, heavy: bool, lean_left: bool) -> void:
	var width := 2.0 if heavy else 1.0
	var slant := -1.0 if lean_left else 1.0
	var joint := at + Vector2(slant, 1)
	draw_line(at + Vector2(-3 * slant, -5), joint, CRACK, width)
	draw_line(joint, at + Vector2(-slant, 3), CRACK, width)
	draw_line(at + Vector2(-slant, 3), at + Vector2(2 * slant, 6), CRACK, width)
	if heavy:
		draw_line(joint, at + Vector2(5 * slant, -1), CRACK, 1.0)


func _centre(cell: Vector2i) -> Vector2:
	return to_local(_map.to_global(_map.map_to_local(cell)))
