class_name RaidStep
extends RefCounted
## How a raiding mob walks and strikes (#529). Mob.think calls step.
## No can_stand_at and no wander leash: a raid has to leave home ground.
## No pathfinder. A free-form wall of the target city within RAID_REACH is
## struck once per RAID_HIT_INTERVAL. Otherwise step on the larger axis when
## that cell is walkable and not a free-form wall. Both axes blocked by a
## free-form wall: damage the primary one. A structure wall on the way: stop,
## and do not pass it to host_damage_wall.


static func step(mob: Mob, delta: float) -> void:
	if mob._world == null or mob._raid_cell == Mob.RAID_NONE:
		return
	var strike := _strike_cell(mob)
	if strike != Mob.RAID_NONE:
		mob.state = Mob.State.IDLE
		mob.direction = Vector2.ZERO
		mob.facing = MobCatalog.facing_for(_cell_centre(mob, strike) - mob.position)
		mob._raid_cool -= delta
		if mob._raid_cool <= 0.0:
			mob._raid_cool = Mob.RAID_HIT_INTERVAL
			_strike_wall(mob, strike)
		return
	var here := mob._world.local_to_map(mob._world.to_local(mob.global_position))
	if here == mob._raid_cell:
		mob.state = Mob.State.IDLE
		mob.direction = Vector2.ZERO
		return
	var next := _step_cell(mob, here)
	if next == here:
		mob.state = Mob.State.IDLE
		mob.direction = Vector2.ZERO
		return
	var dest := _cell_centre(mob, next)
	var to := dest - mob.position
	if to.length() <= 0.5:
		mob.position = dest
		return
	var speed := float(MobCatalog.stat(mob.mob_type, "chase_speed"))
	var motion := to.normalized() * speed * delta
	if motion.length() > to.length():
		motion = to
	mob.position += motion
	mob.facing = MobCatalog.facing_for(motion)
	mob.state = Mob.State.WALK


static func _strike_cell(mob: Mob) -> Vector2i:
	var city := _nearest_city_wall(mob, Mob.RAID_REACH)
	if city != Mob.RAID_NONE:
		return city
	var here := mob._world.local_to_map(mob._world.to_local(mob.global_position))
	var axes := _axes(mob, here)
	if axes.size() < 2:
		return Mob.RAID_NONE
	var primary := here + axes[0]
	var secondary := here + axes[1]
	if mob._world.has_wall(primary) and mob._world.has_wall(secondary):
		return primary
	return Mob.RAID_NONE


static func _step_cell(mob: Mob, here: Vector2i) -> Vector2i:
	for axis in _axes(mob, here):
		var cell := here + axis
		if _kind(mob, cell) == "open":
			return cell
	return here


static func _axes(mob: Mob, here: Vector2i) -> Array[Vector2i]:
	var dx := mob._raid_cell.x - here.x
	var dy := mob._raid_cell.y - here.y
	var horizontal := Vector2i(signi(dx), 0)
	var vertical := Vector2i(0, signi(dy))
	var out: Array[Vector2i] = []
	if absi(dx) >= absi(dy):
		if dx != 0:
			out.append(horizontal)
		if dy != 0:
			out.append(vertical)
	else:
		if dy != 0:
			out.append(vertical)
		if dx != 0:
			out.append(horizontal)
	return out


static func _nearest_city_wall(mob: Mob, reach: float) -> Vector2i:
	var cities := mob.get_node_or_null("../../Cities") as Cities
	if cities == null or not cities.cities.has(mob._raid_id):
		return Mob.RAID_NONE
	var walls: Dictionary = cities.cities[mob._raid_id]["walls"]
	var best := Mob.RAID_NONE
	var best_d := reach
	var found := false
	for cell: Vector2i in walls:
		if not mob._world.has_wall(cell):
			continue
		var dist := mob.global_position.distance_to(
			mob._world.to_global(mob._world.map_to_local(cell))
		)
		if dist > reach:
			continue
		if (
			not found
			or dist < best_d
			or (is_equal_approx(dist, best_d) and _cell_before(cell, best))
		):
			found = true
			best = cell
			best_d = dist
	return best


static func _kind(mob: Mob, cell: Vector2i) -> String:
	if mob._world.has_wall(cell):
		return "free"
	if _structure_wall(mob, cell):
		return "structure"
	var ground: Vector2i = mob._world.predict_cell(cell)[0]
	if mob._world.ground_is_walkable(ground):
		return "open"
	return "blocked"


static func _structure_wall(mob: Mob, cell: Vector2i) -> bool:
	## Castle stone and other structure WALL_* / PALISADE_* cells. Tower rings
	## are not walls for this step.
	if not mob._world._structures.has_cell(cell):
		return false
	var atlas: Vector2i = mob._world._structures.object_at(cell)
	if atlas == mob._world.NO_PLANT:
		return false
	var tile_name := WallBuilder._atlas_wall_name(atlas)
	return tile_name.begins_with("WALL_") or tile_name.begins_with("PALISADE_")


static func _strike_wall(mob: Mob, cell: Vector2i) -> void:
	if mob._world == null or not mob._world.has_wall(cell):
		return
	var requests := mob.get_node_or_null("../../StructureRequests") as StructureRequests
	if requests == null:
		return
	mob._raid_strikes.append(cell)
	var peer := mob.multiplayer.multiplayer_peer
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		requests.host_damage_wall(cell)
		return
	## Offline scene (a unit test, or a host that has not opened a peer yet):
	## the same hp change host_damage_wall applies, without an RPC.
	var left: int = mob._world._walls.damage(cell)
	if left == 0:
		var gone: Array[Vector2i] = [cell]
		mob._world._walls.erase_cells(gone)
	var cities := mob.get_node_or_null("../../Cities") as Cities
	if cities != null:
		cities.tick()


static func _cell_centre(mob: Mob, cell: Vector2i) -> Vector2:
	var global_pos := mob._world.to_global(mob._world.map_to_local(cell))
	if mob.get_parent() == null:
		return global_pos
	return mob.get_parent().to_local(global_pos)


static func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
