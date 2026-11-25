class_name ConstructionRemover
extends RefCounted
## Resolve a tapped cell to one construction and share the rules between preview and host.

const WorldMap := preload("res://Scripts/world/TileMap.gd")

var _map: WorldMap


func _init(map: WorldMap) -> void:
	_map = map


func target_at(cell: Vector2i, peer_id: int) -> Dictionary:
	var placement := _map.structure_placement_at(cell)
	var kind: StringName = &""
	var reason := ""
	var cells: Array[Vector2i] = []
	if not placement.is_empty():
		cells = placement["cells"]
		var name: String = placement["name"]
		for candidate: StringName in BuildCosts.NAMED_STRUCTURES:
			if BuildCosts.NAMED_STRUCTURES[candidate] == name:
				kind = candidate
				break
		if placement.get("start_castle", false):
			reason = "start castle"
		elif int(placement["owner"]) <= 0 or placement["owner"] != peer_id:
			reason = "not yours"
	elif _map.has_wall(cell):
		kind = BuildCosts.WALL_BLOCK
		cells = [cell]
	elif _map.has_bridge(cell):
		kind = BuildCosts.PLANK
		cells = [cell]
	if kind == &"" and reason == "":
		reason = "nothing here"
	return {
		"kind": kind,
		"cells": cells,
		"reason": reason,
		"refund": BuildCosts.refund(kind, 1) if reason == "" else 0,
		"id": placement.get("id", 0),
		"anchor": placement.get("anchor", cell),
	}


func remove(cell: Vector2i, peer_id: int, inventory: Inventory = null) -> Dictionary:
	## The caller checks the requesting body's reach. Empty means no write or refund.
	if not _map.multiplayer.is_server():
		return {}
	var target := target_at(cell, peer_id)
	if target["reason"] != "":
		return {}
	var removed := false
	match target["kind"]:
		BuildCosts.WALL_BLOCK:
			removed = _map.erase_wall_cells([cell])
		BuildCosts.PLANK:
			removed = _map.erase_bridge_cells([cell])
		_:
			removed = _map.remove_structure(target["id"])
	if not removed:
		return {}
	if inventory != null and target["refund"] > 0:
		inventory.add(Inventory.WOOD, target["refund"])
	return target
