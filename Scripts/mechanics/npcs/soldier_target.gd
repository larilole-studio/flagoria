class_name SoldierTarget
extends RefCounted
## Nearest hostile unit inside a soldier’s sight radius.


static func pick(soldier: Soldier, mobs: Array, players: Array, sight: float) -> Object:
	var best: Object = null
	var best_d := sight
	for node in mobs:
		if not node is Mob:
			continue
		var mob := node as Mob
		if mob is Soldier and mob.owner_peer == soldier.owner_peer:
			continue
		if mob.state == Mob.State.DYING or mob.is_queued_for_deletion():
			continue
		var d := soldier.global_position.distance_to(mob.global_position)
		if d <= best_d:
			best_d = d
			best = mob
	for node in players:
		if not node is CharacterBody2D:
			continue
		var player := node as CharacterBody2D
		if str(player.name) == str(soldier.owner_peer):
			continue
		if not Mob.is_alive(player):
			continue
		var d := soldier.global_position.distance_to(player.global_position)
		if d <= best_d:
			best_d = d
			best = player
	return best
