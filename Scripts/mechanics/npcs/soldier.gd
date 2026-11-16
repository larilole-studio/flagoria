class_name Soldier
extends Mob
## A trained unit that follows its owner or holds position (#553), and fights
## nearby mobs on the host (#554).

const SOLDIER_SCENE := "res://Mobs/soldier.tscn"

@export var owner_peer: int = 0
@export var order: String = "follow"
@export var barracks_anchor: Vector2i = Vector2i.ZERO

var _hold_pos := Vector2.ZERO
var spawn_seed := 0
var _strike_cd := 0.0
var _hurt_cd := 0.0


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
	setup_soldier({
		"type": MobCatalog.SOLDIER,
		"pos": Vector2(float(pos_arr[0]), float(pos_arr[1])),
		"seed": int(row.get("seed", 0)),
		"owner": int(row.get("owner", 0)),
		"order": str(row.get("order", "follow")),
		"barracks_anchor": Vector2i(int(anchor_arr[0]), int(anchor_arr[1])),
		"hp": int(row.get("hp", MobCatalog.stat(MobCatalog.SOLDIER, "hp"))),
	})


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
	_step_move(delta)
	_fight_mobs()


func take_hit(by_peer: int = 0) -> bool:
	if by_peer == owner_peer and owner_peer != 0:
		return false
	return super.take_hit(by_peer)


func _step_move(delta: float) -> void:
	if order == "hold":
		global_position = _hold_pos
		direction = Vector2.ZERO
		state = State.IDLE
		return
	var owner := get_node_or_null("../../" + str(owner_peer)) as Node2D
	if owner == null or not is_alive(owner):
		direction = Vector2.ZERO
		state = State.IDLE
		return
	var to := owner.global_position - global_position
	if to.length() <= SoldierStats.FOLLOW_STOP:
		direction = Vector2.ZERO
		state = State.IDLE
		return
	var motion := to.normalized() * SoldierStats.WALK_SPEED * delta
	facing = MobCatalog.facing_for(to)
	state = State.WALK
	if not step(motion, false) and not step(Vector2(motion.x, 0), false):
		step(Vector2(0, motion.y), false)
	_hold_pos = global_position


func _fight_mobs() -> void:
	var mob_root := get_node_or_null("../../Mobs")
	if mob_root == null or not mob_root.has_method("mobs"):
		return
	var target: Mob = null
	var best_d := SoldierStats.ATTACK_RANGE
	for node in mob_root.mobs():
		if not node is Mob:
			continue
		var mob := node as Mob
		if mob.state == State.DYING or mob.is_queued_for_deletion():
			continue
		var d := position.distance_to(mob.position)
		if d <= best_d:
			best_d = d
			target = mob
	if target == null:
		return
	var my_box := contact_box()
	var their_box := target.contact_box()
	if my_box.intersects(their_box) and _strike_cd <= 0.0:
		if target.take_hit(owner_peer):
			_strike_cd = SoldierStats.HIT_EVERY
	if their_box.intersects(my_box) and _hurt_cd <= 0.0:
		if take_hit(0):
			_hurt_cd = SoldierStats.HIT_EVERY


func set_order(next: String) -> void:
	order = next
	if order == "hold":
		_hold_pos = global_position


func step(motion: Vector2, leash: bool = true) -> bool:
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