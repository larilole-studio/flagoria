class_name SoldierTarget
extends RefCounted
## Nearest mob or enemy player inside attack range for a soldier (#555).


static func pick(soldier: Soldier, owner_body: Node2D, mobs: Array, players: Array) -> Object:
	var best: Object = null
	var best_d := SoldierStats.ATTACK_RANGE
	for node in mobs:
		if not node is Mob:
			continue
		var mob := node as Mob
		if mob.state == Mob.State.DYING or mob.is_queued_for_deletion():
			continue
		var d := soldier.position.distance_to(mob.position)
		if d <= best_d:
			best_d = d
			best = mob
	for node in players:
		if not node is CharacterBody2D:
			continue
		var player := node as CharacterBody2D
		if player == owner_body:
			continue
		if not Mob.is_alive(player):
			continue
		var d := soldier.position.distance_to(player.position)
		if d <= best_d:
			best_d = d
			best = player
	return best