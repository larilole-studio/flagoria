class_name TowerGuns
extends Node2D
## Player-owned flag towers shoot other players (#37). The host ticks.
## Neutral and mob owners do not. There is no projectile: a hit is
## PlayerHealth.take_damage, then a 0.2 s tracer. The owner is read live
## each tick, so a capture shoots for the new peer on the next tick.
## Cooldown is not saved and is not sent to a joiner. The tracer is cosmetic.
## Range, damage and cooldown come from the host's GameSettings.

const TRACER_TIME := 0.2
## A ray that starts on the flag hits the tower ring. Begin this far out,
## toward the target, so the shot can leave the ring.
const LOS_LEAD := 12.0
const TRACER_COLOR := Color(1.0, 0.92, 0.45, 0.95)
const TRACER_WIDTH := 2.0

## Placement id -> seconds left before that tower may shoot again.
var _cooldown: Dictionary = {}
var _tracers: Array[Dictionary] = []
@onready var _map: TileMap = get_node_or_null("../worldMap")


func _ready() -> void:
	z_index = 12


func _physics_process(delta: float) -> void:
	_fade(delta)
	if _serving():
		tick(delta)


func _serving() -> bool:
	return not (Interaction.multiplayer_on(multiplayer) and not multiplayer.is_server())


func tick(delta: float) -> void:
	## One server step. A client does nothing: damage arrives on the health RPC.
	if _map == null or _map._structures == null:
		return
	if Interaction.multiplayer_on(multiplayer) and not multiplayer.is_server():
		return
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return
	var reach: float = settings.tower_range
	var damage: int = int(settings.tower_damage)
	var wait: float = settings.tower_cooldown
	var placer: StructurePlacer = _map._structures
	var towers := placer.towers()
	var players := _living_players()
	var space := get_world_2d().direct_space_state if is_inside_tree() else null
	for id: int in towers:
		var left: float = float(_cooldown.get(id, 0.0)) - delta
		if left > 0.0:
			_cooldown[id] = left
			continue
		_cooldown.erase(id)
		var owner := placer.owner_of(id)
		if owner <= 0:
			continue
		var cells: Array = towers[id]
		if cells.is_empty():
			continue
		var centre := _centre(cells[0])
		var target := _nearest(centre, owner, reach, players)
		if target == null:
			continue
		var to: Vector2 = target.global_position
		var aim := to - centre
		if aim.length() <= LOS_LEAD or space == null:
			continue
		var from := centre + aim.normalized() * LOS_LEAD
		# The target's own body sits on the terrain layer. It is not cover:
		# the ray is the gap between the ring and that body.
		var self_rid := (target as CollisionObject2D).get_rid()
		if not AttackAim.clear_shot(space, from, to, [self_rid]):
			continue  # a blocked ray does not spend the cooldown
		var health := target.get_node_or_null("Health") as PlayerHealth
		if health == null or not health.take_damage(damage):
			continue
		_cooldown[id] = wait
		pulse.rpc(from, to)
	for id in _cooldown.keys():
		if not towers.has(id):
			_cooldown.erase(id)


func _living_players() -> Array:
	var out: Array = []
	var world := get_parent()
	if world == null:
		return out
	for node in world.get_children():
		if node is CharacterBody2D and Mob.is_alive(node) and str(node.name).is_valid_int():
			out.append(node)
	return out


func _nearest(centre: Vector2, owner: int, reach: float, players: Array) -> Node2D:
	## The closest living player other than `owner` within `reach` px.
	var best: Node2D = null
	var best_d := reach
	for node in players:
		if int(str(node.name)) == owner:
			continue
		var d: float = node.global_position.distance_to(centre)
		if d <= best_d:
			best = node
			best_d = d
	return best


func _centre(cell: Vector2i) -> Vector2:
	return _map.to_global(_map.map_to_local(cell))


func _fade(delta: float) -> void:
	if _tracers.is_empty():
		return
	var keep: Array[Dictionary] = []
	for t in _tracers:
		var left: float = float(t["left"]) - delta
		if left > 0.0:
			t["left"] = left
			keep.append(t)
	_tracers = keep
	queue_redraw()


@rpc("authority", "call_local", "reliable")
func pulse(from: Vector2, to: Vector2) -> void:
	## A line from the lead point to the target. Ignored unless the host sent it.
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	_tracers.append({"from": from, "to": to, "left": TRACER_TIME})
	queue_redraw()


func _draw() -> void:
	for t in _tracers:
		draw_line(to_local(t["from"]), to_local(t["to"]), TRACER_COLOR, TRACER_WIDTH)
