class_name RangedShot
extends RefCounted
## One bow shot as a pure segment (#362). No randomness and no scene tree:
## the host calls fly, then applies at most one hit.

const SPEED := 180.0
const RANGE := 120.0
const STEP := 1.0 / 60.0
const DAMAGE := 1
const COOLDOWN := 1.0  ## matches PlayerHealth.invulnerable_time


static func fly(
	map: Node, origin: Vector2, direction: Vector2, mobs: Array, players: Array, shooter: Node
) -> Dictionary:
	## Walk origin along direction at SPEED, sampling every STEP, and stop
	## at RANGE. A blocked AttackAim.clear_shot between two samples is
	## terrain. Otherwise the first mob contact box or player box on the
	## segment wins. The shooter and dead players are skipped.
	if not _finite(direction) or direction.length_squared() <= 0.0000001:
		return {"kind": "bad", "end": origin, "target": null}
	var dir := direction.normalized()
	var space := _space(map)
	var exclude := _bodies(players, shooter)
	var step_px := SPEED * STEP
	var traveled := 0.0
	var prev := origin
	while traveled < RANGE - 0.001:
		var next_dist := minf(traveled + step_px, RANGE)
		var point := origin + dir * next_dist
		if not AttackAim.clear_shot(space, prev, point, exclude):
			return {"kind": "terrain", "end": prev, "target": null}
		var hit := _along(prev, point, mobs, players, shooter)
		if not hit.is_empty():
			return hit
		prev = point
		traveled = next_dist
	return {"kind": "miss", "end": origin + dir * RANGE, "target": null}


static func apply(hit: Dictionary, sender_id: int) -> bool:
	## One Mob.take_hit or one PlayerHealth.take_damage. False when the
	## target is already hurt or invulnerable, or the segment hit nothing.
	var target: Variant = hit.get("target")
	if hit.get("kind") == "mob" and is_instance_valid(target) and target is Mob:
		return (target as Mob).take_hit(sender_id)
	if hit.get("kind") == "player" and is_instance_valid(target) and target is Node:
		var health := (target as Node).get_node_or_null("Health") as PlayerHealth
		if health == null:
			return false
		return health.take_damage(DAMAGE)
	return false


static func _space(map: Node) -> PhysicsDirectSpaceState2D:
	var body := map as Node2D
	if body == null or not body.is_inside_tree():
		return null
	var world := body.get_world_2d()
	if world == null:
		return null
	return world.direct_space_state


static func _bodies(players: Array, shooter: Node) -> Array:
	## Player bodies sit on the terrain physics layer. They are not cover.
	var exclude: Array = []
	for player in players:
		if is_instance_valid(player) and player is CollisionObject2D:
			exclude.append((player as CollisionObject2D).get_rid())
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		var rid: RID = (shooter as CollisionObject2D).get_rid()
		if not exclude.has(rid):
			exclude.append(rid)
	return exclude


static func _along(
	a: Vector2, b: Vector2, mobs: Array, players: Array, shooter: Node
) -> Dictionary:
	var best_t := 2.0
	var best := {}
	var delta := b - a
	for mob in mobs:
		if not is_instance_valid(mob) or not (mob is Mob):
			continue
		var t := _segment_t(a, b, (mob as Mob).contact_box())
		if t >= 0.0 and t < best_t:
			best_t = t
			best = {"kind": "mob", "target": mob, "end": a + delta * t}
	for player in players:
		if not is_instance_valid(player) or player == shooter or not (player is Node2D):
			continue
		if not Mob.is_alive(player):
			continue
		var t := _segment_t(a, b, Mob.player_box(player as Node2D))
		if t >= 0.0 and t < best_t:
			best_t = t
			best = {"kind": "player", "target": player, "end": a + delta * t}
	return best


static func _segment_t(a: Vector2, b: Vector2, rect: Rect2) -> float:
	## Earliest t in [0, 1] where the segment touches rect, or -1.
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return -1.0
	var delta := b - a
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		var origin: float = a.x if axis == 0 else a.y
		var step: float = delta.x if axis == 0 else delta.y
		var lo: float = rect.position.x if axis == 0 else rect.position.y
		var hi: float = rect.end.x if axis == 0 else rect.end.y
		if absf(step) <= 0.0000001:
			if origin < lo or origin > hi:
				return -1.0
			continue
		var inv := 1.0 / step
		var ta := (lo - origin) * inv
		var tb := (hi - origin) * inv
		if ta > tb:
			var swap := ta
			ta = tb
			tb = swap
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return -1.0
	return t0


static func _finite(v: Vector2) -> bool:
	return not is_nan(v.x) and not is_nan(v.y) and not is_inf(v.x) and not is_inf(v.y)
