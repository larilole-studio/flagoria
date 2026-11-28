class_name SoldierSaves
extends RefCounted
## Save and restore trained soldiers (#553).


static func capture_world(save: WorldSave, game: Node) -> void:
	save.soldiers = capture(game)
	var requests := game.get_node_or_null("World/Soldiers") as SoldierRequests
	if requests != null and requests.multiplayer.is_server():
		save.soldier_training = requests.capture_training()


static func restore_world(save: WorldSave, requests: SoldierRequests) -> int:
	var restored := restore(save.soldiers, requests)
	requests.restore_training(save.soldier_training)
	return restored


static func capture(game: Node) -> Array:
	var soldiers := game.get_node_or_null("World/Soldiers") as SoldierRequests
	if soldiers == null:
		return []
	var out: Array = []
	for child in soldiers.get_children():
		if child is Soldier and child.state != Soldier.State.DYING:
			var s := child as Soldier
			(
				out
				. append(
					{
						"name": str(s.name),
						"pos": [s.position.x, s.position.y],
						"owner": s.owner_peer,
						"order": s.order,
						"hp": s.hp,
						"barracks_anchor": [s.barracks_anchor.x, s.barracks_anchor.y],
						"seed": s.spawn_seed,
					}
				)
			)
	return out


static func restore(rows: Array, soldiers: SoldierRequests) -> int:
	if rows.is_empty() or soldiers == null:
		return 0
	var world := soldiers.get_parent().get_node_or_null("worldMap") as TileMap
	if world == null:
		return 0
	var count := 0
	for row in rows:
		if not row is Dictionary:
			continue
		if not _barracks_exists(world, row):
			continue
		soldiers.spawn_saved(row)
		count += 1
	return count


static func _barracks_exists(world: TileMap, row: Dictionary) -> bool:
	var anchor_arr: Array = row.get("barracks_anchor", [0, 0])
	var anchor := Vector2i(int(anchor_arr[0]), int(anchor_arr[1]))
	var owner := int(row.get("owner", 0))
	for entry in world.placed_structures().values():
		if (
			str(entry.get("name")) == "barracks"
			and int(entry.get("owner")) == owner
			and entry.get("anchor", Vector2i.ZERO) == anchor
		):
			return true
	return false
