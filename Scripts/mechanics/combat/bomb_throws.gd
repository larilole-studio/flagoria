class_name BombThrows
extends Node2D
## The host advances each throw through flight, fuse and blast. Peers animate
## the flight locally and switch sprites on the host's reliable phase RPCs.

enum Phase { FLIGHT, FUSE, BLAST }

const ORIGIN_LIMIT := 24.0
const BURST_SECONDS := 0.28
const POT_IDLE := preload("res://art/items/bomb/pot_idle.png")
const POT_FUSE := preload("res://art/items/bomb/pot_fuse.png")
const POT_SIZE := Vector2(16, 16)
const WorldMap := preload("res://Scripts/world/TileMap.gd")


class Pot:
	var sender_id: int
	var origin: Vector2
	var end: Vector2
	var travel: float
	var fuse: float
	var radius: float
	var damage: int
	var phase := Phase.FLIGHT
	var phase_started := 0

	func age_at(now: int) -> float:
		return (now - phase_started) * 0.001


var _pots: Dictionary[int, Pot] = {}
var _cooldown_until: Dictionary[int, int] = {}
var _next_id := 0

@onready var _map: WorldMap = $"../worldMap"
@onready var _structures: StructureRequests = $"../StructureRequests"


func send_throw(origin: Vector2, direction: Vector2) -> void:
	if multiplayer.is_server():
		resolve(multiplayer.get_unique_id(), origin, direction)
	elif Interaction.multiplayer_on(multiplayer):
		request_throw.rpc_id(1, origin, direction)


@rpc("any_peer", "call_remote", "reliable")
func request_throw(origin: Vector2, direction: Vector2) -> void:
	resolve(multiplayer.get_remote_sender_id(), origin, direction)


func resolve(sender_id: int, origin: Vector2, direction: Vector2) -> bool:
	if not multiplayer.is_server():
		return false
	var body := get_node_or_null("../" + str(sender_id)) as CharacterBody2D
	var health := body.get_node_or_null("Health") as PlayerHealth if body != null else null
	if health == null or health.is_dead():
		return false
	var now := Time.get_ticks_msec()
	var length_squared := direction.length_squared()
	if (
		now < _cooldown_until.get(sender_id, 0)
		or not origin.is_finite()
		or origin.distance_to(body.global_position) > ORIGIN_LIMIT
		or not is_finite(length_squared)
		or length_squared <= 0.0000001
	):
		return false
	var start := body.global_position + AttackAim.ORIGIN
	var end := BombShot.landing(start, direction, Tuning.value(&"bomb.max_range"))
	if not _valid_landing(end):
		return false
	_cooldown_until[sender_id] = now + roundi(Tuning.value(&"bomb.cooldown_seconds") * 1000.0)
	_next_id += 1
	show_throw.rpc(_next_id, start, end, BombShot.travel_seconds(start.distance_to(end)))
	var pot := _pots[_next_id]
	pot.sender_id = sender_id
	pot.fuse = Tuning.value(&"bomb.fuse_seconds")
	pot.radius = Tuning.value(&"bomb.blast_radius")
	pot.damage = int(Tuning.value(&"bomb.damage"))
	return true


func has_phase(phase: Phase) -> bool:
	for pot in _pots.values():
		if pot.phase == phase:
			return true
	return false


@rpc("authority", "call_local", "reliable")
func show_throw(id: int, origin: Vector2, end: Vector2, travel: float) -> void:
	var pot := Pot.new()
	pot.origin = origin
	pot.end = end
	pot.travel = travel
	pot.phase_started = Time.get_ticks_msec()
	_pots[id] = pot


@rpc("authority", "call_local", "reliable")
func show_landing(id: int) -> void:
	if _pots.has(id):
		_pots[id].phase = Phase.FUSE
		_pots[id].phase_started = Time.get_ticks_msec()


@rpc("authority", "call_local", "reliable")
func show_blast(id: int, radius: float) -> void:
	if _pots.has(id):
		_pots[id].phase = Phase.BLAST
		_pots[id].phase_started = Time.get_ticks_msec()
		_pots[id].radius = radius


func _process(_delta: float) -> void:
	if _pots.is_empty():
		return
	var now := Time.get_ticks_msec()
	var host := multiplayer.is_server()
	for id in _pots.keys():
		var pot := _pots[id]
		var age: float = pot.age_at(now)
		match pot.phase:
			Phase.FLIGHT:
				if host and pot.sender_id > 0 and age >= pot.travel:
					show_landing.rpc(id)
			Phase.FUSE:
				if host and pot.sender_id > 0 and age >= pot.fuse:
					_blast(pot)
					show_blast.rpc(id, pot.radius)
			Phase.BLAST:
				if age >= BURST_SECONDS:
					_pots.erase(id)
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec()
	for pot in _pots.values():
		var point := to_local(pot.end)
		var age: float = pot.age_at(now)
		match pot.phase:
			Phase.FLIGHT:
				point = to_local(BombShot.arc_point(pot.origin, pot.end, age / pot.travel))
				draw_texture_rect(POT_IDLE, Rect2(point - POT_SIZE / 2.0, POT_SIZE), false)
			Phase.FUSE:
				draw_texture_rect(POT_FUSE, Rect2(point - POT_SIZE / 2.0, POT_SIZE), false)
			Phase.BLAST:
				_draw_burst(point, pot.radius, clampf(age / BURST_SECONDS, 0.0, 1.0))


func _draw_burst(center: Vector2, radius: float, t: float) -> void:
	var spread := BombShot.radii(radius) * lerpf(0.2, 0.85, t)
	for i in 12:
		var point := center + Vector2.from_angle(TAU * i / 12.0) * spread
		var color := Color(1.0, 0.52 if i % 2 == 0 else 0.82, 0.16, 1.0 - t)
		draw_rect(Rect2(point.round() - Vector2.ONE * 2.0, Vector2(4, 4)), color)
	draw_circle(center, lerpf(8.0, 2.0, t), Color(1.0, 0.84, 0.34, 1.0 - t))


func _valid_landing(point: Vector2) -> bool:
	if not point.is_finite():
		return false
	var extent := _map.archipelago_world_extent
	if _map.archipelago_spacing <= 0 or extent <= 0:
		return true
	var cell := _map.local_to_map(_map.to_local(point))
	return absi(cell.x) <= extent and absi(cell.y) <= extent


func _blast(pot: Pot) -> void:
	for player in get_parent().get_children():
		if not player is CharacterBody2D or str(player.name) == str(pot.sender_id):
			continue
		var health := player.get_node_or_null("Health") as PlayerHealth
		if health != null and BombShot.contains(pot.end, pot.radius, player.global_position):
			health.take_damage(pot.damage)
	for container in [$"../Mobs", $"../Soldiers"]:
		for mob in container.get_children():
			if mob is Mob and BombShot.contains(pot.end, pot.radius, mob.global_position):
				mob.take_hit(pot.sender_id, pot.damage)
	_blast_cells(pot)


func _blast_cells(pot: Pot) -> void:
	var radii := BombShot.radii(pot.radius)
	var first := _map.local_to_map(_map.to_local(pot.end - radii))
	var last := _map.local_to_map(_map.to_local(pot.end + radii))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var center := _map.to_global(_map.map_to_local(cell))
			if not BombShot.contains(pot.end, pot.radius, center):
				continue
			_structures.host_blast_structure(cell, pot.sender_id)
			for hit in range(mini(pot.damage, _map.wall_hp(cell))):
				_structures.host_damage_wall(cell)
