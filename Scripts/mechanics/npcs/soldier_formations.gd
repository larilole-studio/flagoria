class_name SoldierFormations
extends RefCounted
## Replace nearby idle soldiers with one replicated formation. Split pooled HP
## into the largest surviving formations after each lost member.

const SQUAD := 5
const COMPANY := 20
const GROUP_RADIUS := 32.0
const SPLIT_OFFSETS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(-12, 0),
	Vector2(12, 0),
	Vector2(0, -12),
	Vector2(0, 12),
	Vector2(-12, -12),
	Vector2(12, -12),
	Vector2(-12, 12),
	Vector2(12, 12)
]

var _next_formation := 0


func refresh(requests: SoldierRequests) -> void:
	if not requests.multiplayer.is_server():
		return
	for soldier: Soldier in requests.soldiers():
		if not soldier.is_owned_alive(soldier.owner_peer) or soldier.member_count() == 1:
			continue
		var survivors := ceili(float(soldier.hp) / single_hp())
		if survivors < soldier.member_count():
			_split(requests, soldier, survivors)
	_merge(requests, SQUAD, COMPANY)
	_merge(requests, 1, SQUAD)


static func single_hp() -> int:
	return MobCatalog.stat(MobCatalog.SOLDIER, "hp")


func _merge(requests: SoldierRequests, size: int, result_size: int) -> void:
	var pool: Array[Soldier] = []
	for soldier: Soldier in requests.soldiers():
		if soldier.member_count() == size and soldier.can_group():
			pool.append(soldier)
	if pool.size() < result_size / size:
		return
	for lead: Soldier in pool:
		var group: Array[Soldier] = []
		var anchors: Array[Vector2i] = []
		var total_hp := 0
		for soldier: Soldier in pool:
			if soldier.owner_peer != lead.owner_peer or soldier.order != lead.order:
				continue
			if soldier.position.distance_squared_to(lead.position) > GROUP_RADIUS * GROUP_RADIUS:
				continue
			group.append(soldier)
			anchors.append_array(soldier.member_anchors)
			total_hp += soldier.hp
			if anchors.size() == result_size:
				break
		if anchors.size() != result_size or total_hp <= (result_size - 1) * single_hp():
			continue
		var row := _formation(lead, anchors, lead.position, total_hp)
		if _replace(requests, group, [row]):
			return


func _split(requests: SoldierRequests, soldier: Soldier, survivors: int) -> void:
	var rows: Array[Dictionary] = []
	var offsets := SPLIT_OFFSETS.filter(
		func(offset: Vector2) -> bool: return soldier.can_stand_at(soldier.position + offset)
	)
	var hp := soldier.hp
	var first := 0
	while first < survivors:
		var members := SQUAD if survivors - first >= SQUAD else 1
		var part_hp := mini(hp, members * single_hp())
		var chosen := Vector2.ZERO
		if not offsets.is_empty():
			chosen = offsets[mini(rows.size(), offsets.size() - 1)]
		var anchors := soldier.member_anchors.slice(first, first + members)
		rows.append(_formation(soldier, anchors, soldier.position + chosen, part_hp))
		hp -= part_hp
		first += members
	_replace(requests, [soldier], rows)


func _replace(requests: SoldierRequests, troops: Array[Soldier], rows: Array[Dictionary]) -> bool:
	var replacements: Array[Soldier] = []
	for row in rows:
		var next_name := "formation_%d" % _next_formation
		while requests.has_node(next_name):
			_next_formation += 1
			next_name = "formation_%d" % _next_formation
		_next_formation += 1
		row["name"] = next_name
		var replacement := requests.spawn_saved(row)
		if replacement == null:
			for spawned in replacements:
				spawned.queue_free()
			return false
		replacements.append(replacement)
	for soldier in troops:
		soldier.queue_free()
	return true


static func _formation(
	source: Soldier, anchors: Array[Vector2i], at: Vector2, hp: int
) -> Dictionary:
	return {
		"pos": at,
		"owner": source.owner_peer,
		"order": source.order,
		"move_target": source.move_target,
		"seed": source.spawn_seed,
		"barracks_anchor": anchors[0],
		"members": anchors,
		"hp": hp,
	}
