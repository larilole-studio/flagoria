class_name Soldier
extends Mob
## A trained unit that follows or holds, engaging nearby enemies on the host.

const SOLDIER_SCENE := "res://Mobs/soldier.tscn"
const BUILDING_REACH := 17.0
const SCAN_INTERVAL := 0.2
const RETURN_STOP := 1.0

@export var owner_peer: int = 0
@export var order: String = "follow"
@export var move_target := Vector2.ZERO
@export var barracks_anchor: Vector2i = Vector2i.ZERO

var spawn_seed := 0

var _hold_pos := Vector2.ZERO
var _blocked_seconds := 0.0
var _strike_cd := 0.0
var _hurt_cd := 0.0
var _scan_cd := 0.0
var _unit_target: Node2D
var _building_target := {}


func setup_soldier(data: Dictionary) -> void:
	spawn_seed = int(data.get("seed", 0))
	setup(String(data.get("type", MobCatalog.SOLDIER)), data["pos"], spawn_seed)
	owner_peer = int(data.get("owner", 0))
	order = str(data.get("order", "follow"))
	barracks_anchor = data.get("barracks_anchor", Vector2i.ZERO)
	if data.has("hp"):
		hp = int(data["hp"])
	_hold_pos = position


func setup_from_save(row: Dictionary) -> void:
	var pos_arr: Array = row.get("pos", [0.0, 0.0])
	var anchor_arr: Array = row.get("barracks_anchor", [0, 0])
	setup_soldier(
		{
			"type": MobCatalog.SOLDIER,
			"pos": Vector2(float(pos_arr[0]), float(pos_arr[1])),
			"seed": int(row.get("seed", 0)),
			"owner": int(row.get("owner", 0)),
			"order": str(row.get("order", "follow")),
			"barracks_anchor": Vector2i(int(anchor_arr[0]), int(anchor_arr[1])),
			"hp": int(row.get("hp", MobCatalog.stat(MobCatalog.SOLDIER, "hp"))),
		}
	)


func think(delta: float) -> void:
	if _world == null:
		_world = get_node_or_null("../../worldMap") as TileMap
	_timer -= delta
	_strike_cd = maxf(0.0, _strike_cd - delta)
	_hurt_cd = maxf(0.0, _hurt_cd - delta)
	if state == State.DYING:
		if _timer <= 0.0:
			queue_free()
		return
	_check_swords()
	if state == State.DYING:
		return
	if state == State.HURT:
		if _timer <= 0.0:
			_start_idle()
		return
	_scan_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = SCAN_INTERVAL
		_scan_targets()
	if not _engage(delta):
		_step_move(delta)


func take_hit(by_peer: int = 0, damage: int = 1) -> bool:
	if by_peer == owner_peer and owner_peer != 0:
		return false
	return super.take_hit(by_peer, damage)


func _step_move(delta: float) -> void:
	if order == "hold":
		_walk_toward(_hold_pos, delta, RETURN_STOP)
		return
	if order == "move":
		_step_command(delta)
		return
	var owner := get_node_or_null("../../" + str(owner_peer)) as Node2D
	if owner == null or not is_alive(owner):
		direction = Vector2.ZERO
		state = State.IDLE
		return
	_walk_toward(owner.global_position, delta, SoldierStats.FOLLOW_STOP)
	_hold_pos = global_position


func _walk_toward(goal: Vector2, delta: float, stop: float) -> void:
	var offset := goal - global_position
	var distance := offset.length()
	if distance <= stop:
		direction = Vector2.ZERO
		state = State.IDLE
		return
	direction = offset / distance
	facing = MobCatalog.facing_for(offset)
	state = State.WALK
	var travel := minf(distance, Tuning.value(&"soldiers.walk_speed") * delta)
	var motion := direction * travel
	if not step(motion, false) and not step(Vector2(motion.x, 0), false):
		step(Vector2(0, motion.y), false)


func _step_command(delta: float) -> void:
	var to := move_target - global_position
	if to.length() <= 0.5:
		set_order("hold")
		state = State.IDLE
		return
	_walk_toward(move_target, delta, 0.0)
	# Sliding counts only while it makes progress toward the target.
	if to.length() - global_position.distance_to(move_target) > 0.001:
		_blocked_seconds = 0.0
	else:
		_blocked_seconds += delta
		if _blocked_seconds >= Tuning.value(&"command.blocked_seconds"):
			set_order("hold")
			state = State.IDLE


func _scan_targets() -> void:
	var world := get_node_or_null("../..")
	if world == null:
		return
	var mobs := world.get_node_or_null("Mobs") as MobSpawner
	var units: Array = get_parent().get_children()
	if mobs != null:
		units.append_array(mobs.mobs())
	var sight := Tuning.value(&"soldiers.sight_range")
	_unit_target = SoldierTarget.pick(self, units, players(), sight)
	var health := world.get_node_or_null("BuildingHealth") as BuildingHealth
	_building_target = {}
	if health != null:
		var reach := sight
		if is_instance_valid(_unit_target):
			reach = global_position.distance_to(_unit_target.global_position)
		_building_target = health.nearest_enemy(global_position, reach, owner_peer)


func _engage(delta: float) -> bool:
	if not _building_target.is_empty():
		return _engage_building(delta)
	if not is_instance_valid(_unit_target) or _unit_target.is_queued_for_deletion():
		return false
	var mob := _unit_target as Mob
	if (mob != null and mob.state == State.DYING) or (mob == null and not is_alive(_unit_target)):
		return false
	var target_position := _unit_target.global_position
	if global_position.distance_to(target_position) > Tuning.value(&"soldiers.sight_range"):
		return false
	var target_box := mob.contact_box() if mob != null else player_box(_unit_target)
	if not contact_box().intersects(target_box):
		_walk_toward(target_position, delta, 0.0)
		return true
	_face_target(target_position)
	if _strike_cd <= 0.0 and _hit_unit(mob):
		_strike_cd = SoldierStats.HIT_EVERY
	if mob != null and not mob is Soldier and mob.state != State.DYING and _hurt_cd <= 0.0:
		if take_hit():
			_hurt_cd = SoldierStats.HIT_EVERY
	return true


func _hit_unit(mob: Mob) -> bool:
	if mob != null:
		return mob.take_hit(owner_peer)
	var health := _unit_target.get_node_or_null("Health") as PlayerHealth
	return health != null and health.take_damage(1)


func _engage_building(delta: float) -> bool:
	var health := get_node_or_null("../../BuildingHealth") as BuildingHealth
	var id: int = _building_target["id"]
	if health == null or health.hp(id) <= 0:
		_building_target = {}
		return false
	var target_position: Vector2 = _building_target["position"]
	if global_position.distance_to(target_position) > BUILDING_REACH:
		_walk_toward(target_position, delta, BUILDING_REACH)
		return true
	_face_target(target_position)
	if _strike_cd <= 0.0 and health.host_damage(id, 1, owner_peer):
		_strike_cd = SoldierStats.HIT_EVERY
	return true


func _face_target(at: Vector2) -> void:
	var offset := at - global_position
	if not offset.is_zero_approx():
		facing = MobCatalog.facing_for(offset)
	direction = Vector2.ZERO
	state = State.IDLE


func is_owned_alive(peer_id: int) -> bool:
	return (
		owner_peer == peer_id and hp > 0 and state != State.DYING and not is_queued_for_deletion()
	)


func move_to(destination: Vector2) -> void:
	move_target = destination
	_blocked_seconds = 0.0
	set_order("move")


func set_order(next: String) -> void:
	order = next
	if order == "hold":
		_hold_pos = global_position


func step(motion: Vector2, _leash: bool = true) -> bool:
	var to := global_position + motion
	if motion == Vector2.ZERO or not can_stand_at(to):
		return false
	global_position = to
	return true


func can_stand_at(pos: Vector2) -> bool:
	if _world == null:
		return false
	var half: Vector2 = MobCatalog.stat(mob_type, "body") * 0.5
	for corner in 4:
		var cell := _feet_cell(pos, half, corner)
		if not _world.predicted_clear(cell) or _world.has_wall(cell):
			return false
	return true
