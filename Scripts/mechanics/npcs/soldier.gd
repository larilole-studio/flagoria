class_name Soldier
extends Mob
## A trained unit that follows or holds, engaging nearby enemies on the host.

const SOLDIER_SCENE := "res://Mobs/soldier.tscn"
const BUILDING_REACH := 17.0
const SCAN_INTERVAL := 0.2
const RETURN_STOP := 1.0
const COUNT_FONT := preload("res://art/ui/fonts/LilitaOne-Regular.ttf")
const COUNT_INK := Color("#3d3a5c")
const COUNT_TEXT := Color("#ffe680")

@export var owner_peer: int = 0
@export var order: String = "follow"
@export var move_target := Vector2.ZERO
@export var barracks_anchor: Vector2i = Vector2i.ZERO

var member_anchors: Array[Vector2i] = []
var spawn_seed := 0

var _blocked_seconds := 0.0
var _hold_pos := Vector2.ZERO
var _strike_cd := 0.0
var _hurt_cd := 0.0
var _scan_cd := 0.0
var _engaged := false
var _unit_target: Node2D
var _building_target := {}


func setup_soldier(data: Dictionary) -> void:
	spawn_seed = int(data.get("seed", 0))
	setup(String(data.get("type", MobCatalog.SOLDIER)), data["pos"], spawn_seed)
	owner_peer = int(data.get("owner", 0))
	order = str(data.get("order", "follow"))
	move_target = data.get("move_target", Vector2.ZERO)
	member_anchors = read_members(data)
	barracks_anchor = member_anchors[0]
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
			"members": row.get("members", []),
			"hp": int(row.get("hp", MobCatalog.stat(MobCatalog.SOLDIER, "hp"))),
		}
	)


static func read_members(data: Dictionary) -> Array[Vector2i]:
	var members: Array[Vector2i] = []
	var source: Variant = data.get("members", [])
	if source is Array and source.size() in [SoldierFormations.SQUAD, SoldierFormations.COMPANY]:
		for anchor in source:
			if anchor is Vector2i or (anchor is Array and anchor.size() == 2):
				members.append(Vector2i(int(anchor[0]), int(anchor[1])))
		if members.size() == source.size():
			return members
	var anchor: Variant = data.get("barracks_anchor", Vector2i.ZERO)
	return [Vector2i(int(anchor[0]), int(anchor[1]))]


func member_count() -> int:
	return maxi(1, member_anchors.size())


func can_group() -> bool:
	return is_owned_alive(owner_peer) and state == State.IDLE and order != "move" and not _engaged


func strike_damage() -> int:
	return ceili(float(member_count()) / SoldierFormations.SQUAD)


func _process(delta: float) -> void:
	super._process(delta)
	if member_count() > 1:
		sprite.hide()
		queue_redraw()


func _draw() -> void:
	var count := member_count()
	if count == 1 or puff.visible or sprite.texture == null:
		return
	var frame_size := sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
	var frame := Rect2(Vector2(sprite.frame_coords) * frame_size, frame_size)
	var company := count == SoldierFormations.COMPANY
	var columns := 5 if company else 3
	var spacing := 8 if company else 9
	for member in count:
		var rank := member / columns
		var in_rank := mini(columns, count - rank * columns)
		var x := (member % columns) * spacing - (in_rank - 1) * spacing * 0.5
		var y := (rank - (count - 1) / columns) * 5
		var at := Vector2(x - frame_size.x * 0.5, y - frame_size.y)
		draw_texture_rect_region(sprite.texture, Rect2(at, frame_size), frame)
	var label := str(count)
	var width := ceili(COUNT_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x)
	draw_rect(Rect2(-ceilf(width * 0.5) - 2, 1, width + 4, 10), COUNT_INK)
	draw_string(
		COUNT_FONT,
		Vector2(-floorf(width * 0.5), 9),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		COUNT_TEXT
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
	_engaged = _engage(delta)
	if not _engaged:
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
		return mob.take_hit(owner_peer, strike_damage())
	var health := _unit_target.get_node_or_null("Health") as PlayerHealth
	return health != null and health.take_damage(strike_damage())


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
	if _strike_cd <= 0.0 and health.host_damage(id, strike_damage(), owner_peer):
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
