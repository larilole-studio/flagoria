class_name StructureRequests
extends Node
## Host-request pipeline for structures (#497, #498, #278). A client asks; the
## host checks reach and the solo footprint, writes, charges the placer, and
## tells peers. Clients may request named structures and free-form walls.
## A joining peer's starting castle is placed by the host and published here.
## Clients still cannot write: can_place reports multiplayer on for a raw
## structure place.

const _WorldMap := preload("res://Scripts/world/TileMap.gd")

@export var map: _WorldMap
@export var interaction: Interaction
@export var inventory: Inventory
@export var cities: Cities
@export var world: Node2D


func place(kind: StringName, cells: Array[Vector2i], quarter_turns: int = 0) -> bool:
	## Alone, ConstructionPlacer spends and writes. With peers, the host decides
	## and a client only sends the request. A connecting client sends nothing.
	if cells.is_empty():
		return false
	if not Interaction.multiplayer_on(multiplayer):
		if inventory == null:
			return false
		return ConstructionPlacer.new(map).place(kind, cells, inventory, quarter_turns)
	if not BuildCosts.is_requestable(kind):
		return false
	if multiplayer.is_server():
		return host_place(kind, cells, multiplayer.get_unique_id(), quarter_turns)
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	# Each peer owns its inventory. Include processed debits so the host can
	# subtract every charge it has issued, including ones still in transit.
	var reported := Vector2i.ZERO
	if BuildCosts.has_stone_price(kind) and inventory != null:
		reported = BuildCosts.balance(inventory) + inventory.processed_charges
	request_place.rpc_id(1, String(kind), cells, quarter_turns, reported)
	return true


func host_place(
	kind: StringName,
	cells: Array[Vector2i],
	peer_id: int,
	quarter_turns: int = 0,
	reported: Vector2i = Vector2i.ZERO
) -> bool:
	## Host accepts `peer_id`'s request, or places for itself. False charges nothing.
	if not multiplayer.is_server() or not BuildCosts.is_requestable(kind) or cells.is_empty():
		return false
	if BuildCosts.NAMED_STRUCTURES.has(kind) and cells.size() != 1:
		return false
	var body := world.get_node_or_null(str(peer_id)) as Node2D
	if body == null or Interaction.player_dead(body):
		return false
	for cell in cells:
		if (
			body.global_position.distance_to(interaction.cell_center(cell))
			> Interaction.REACH + Interaction.REACH_SLACK
		):
			return false
	var local := peer_id == multiplayer.get_unique_id()
	if local and inventory == null:
		return false
	var placer := ConstructionPlacer.new(map)
	var amount := placer.price(kind, cells)
	if not local and amount.y > 0:
		if inventory == null:
			return false
		var charged := inventory.issued_charges(peer_id)
		var why := BuildCosts.shortage(reported.max(charged) - charged, amount)
		if not why.is_empty():
			receive_place_shortage.rpc_id(peer_id, String(kind), cells[0], why)
			return false
	if not placer.place_for_peer(kind, cells, peer_id, inventory if local else null, quarter_turns):
		return false
	if not local:
		interaction.issue_charge(peer_id, amount)
	if kind == BuildCosts.WALL_BLOCK:
		_publish()
	else:
		var anchor := cells[0]
		var placement := map.structure_placement_at(anchor)
		apply_structure.rpc(
			placement["name"], peer_id, anchor, quarter_turns, placement["id"], false
		)
		if cities != null and BuildCosts.CITY_KINDS.has(kind):
			cities.tick()
	return true


func demolish(cell: Vector2i) -> bool:
	if multiplayer.is_server():
		return host_demolish(cell, multiplayer.get_unique_id())
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	request_demolish.rpc_id(1, cell)
	return true


func host_demolish(cell: Vector2i, peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	var body := world.get_node_or_null(str(peer_id)) as Node2D
	if body == null or Interaction.player_dead(body):
		return false
	var local := peer_id == multiplayer.get_unique_id()
	var reach := Interaction.REACH if local else Interaction.REACH + Interaction.REACH_SLACK
	if body.global_position.distance_to(interaction.cell_center(cell)) > reach:
		return false
	if local and inventory == null:
		return false
	var target := ConstructionRemover.new(map).remove(cell, peer_id, inventory if local else null)
	if target.is_empty():
		return false
	var online := not multiplayer.get_peers().is_empty()
	match target["kind"]:
		BuildCosts.PLANK:
			if online:
				interaction.apply_bridge_removed.rpc(target["cells"])
		BuildCosts.WALL_BLOCK:
			_publish()
		_:
			if online:
				apply_structure_removed.rpc(target["anchor"])
			_publish()
	if not local and target["refund"] != Vector2i.ZERO:
		receive_refund.rpc_id(peer_id, target["refund"])
	return true


@rpc("any_peer", "reliable", "call_remote")
func request_demolish(cell: Vector2i) -> void:
	host_demolish(cell, multiplayer.get_remote_sender_id())


@rpc("authority", "reliable", "call_remote")
func apply_structure_removed(anchor: Vector2i) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var placement := map.structure_placement_at(anchor)
	if not placement.is_empty() and placement["anchor"] == anchor:
		map.remove_structure(placement["id"])


@rpc("authority", "reliable", "call_remote")
func receive_refund(amount: Vector2i) -> void:
	if multiplayer.get_remote_sender_id() == 1 and inventory != null:
		BuildCosts.credit(inventory, amount)


@rpc("authority", "reliable", "call_remote")
func receive_mine_stone(stone: int) -> void:
	if multiplayer.get_remote_sender_id() == 1 and inventory != null and stone > 0:
		inventory.add(Inventory.STONE, stone)


@rpc("authority", "reliable", "call_remote")
func receive_sawmill_wood(wood: int) -> void:
	if multiplayer.get_remote_sender_id() == 1 and inventory != null and wood > 0:
		inventory.add(Inventory.WOOD, wood)


func host_damage_wall(cell: Vector2i) -> bool:
	## Host applies one sword hit to a free-form wall (#35). At 0 hp the cell
	## is removed through host_erase_wall so cities stay in sync.
	if not multiplayer.is_server():
		return false
	var left := map.damage_wall_cell(cell)
	if left < 0:
		return false
	if left == 0:
		return host_erase_wall(cell)
	_publish()
	return true


func host_erase_wall(cell: Vector2i) -> bool:
	## Host removes one free-form wall and sends the chain and the cities.
	## A loop that opens dissolves on the host; peers receive that list.
	if not multiplayer.is_server():
		return false
	if not map.erase_wall_cells([cell]):
		return false
	_publish()
	return true


func publish_structure(structure_name: String, owner: int, anchor: Vector2i) -> void:
	## Host: a castle placed for a peer who just joined. Peers already in the
	## match receive it. The joining peer receives it in the map snapshot that
	## follows on the same channel; a repeat of this call is ignored.
	if not multiplayer.is_server():
		return
	if not multiplayer.get_peers().is_empty():
		var placement := map.structure_placement_at(anchor)
		apply_structure.rpc(structure_name, owner, anchor, 0, placement["id"], true)
	if cities != null:
		cities.tick()


func sync_to_peer(peer_id: int) -> void:
	## Host: free-form walls and solved auto junction cells for a peer that
	## just joined. Cities are sent by Cities.sync_to_peer after this.
	if not multiplayer.is_server():
		return
	var snap := _wall_snapshot()
	apply_wall_state.rpc_id(peer_id, snap[0], snap[1], snap[2])


func _publish() -> void:
	## Walls first, then Cities.tick, so a closed or opened loop is the host's
	## decision and leaves on the same reliable channel.
	if not multiplayer.get_peers().is_empty():
		var snap := _wall_snapshot()
		apply_wall_state.rpc(snap[0], snap[1], snap[2])
	if cities != null:
		cities.tick()


func _wall_snapshot() -> Array:
	## [free-form cells, auto junctions [cell, tile name], [cell, hp] under max].
	var free := map.free_wall_cells()
	var hp_rows: Array = []
	for cell: Vector2i in free:
		var left := map.wall_hp(cell)
		if left < WallBuilder.MAX_HP:
			hp_rows.append([cell, left])
	var autos: Array = []
	for cell: Vector2i in map.auto_structure_cells():
		var name := WallBuilder.atlas_wall_name(map.structure_object_at(cell))
		if name != "":
			autos.append([cell, name])
	return [free, autos, hp_rows]


@rpc("any_peer", "reliable", "call_remote")
func request_place(
	kind: String, cells: Array, quarter_turns: int = 0, reported := Vector2i.ZERO
) -> void:
	if not multiplayer.is_server():
		return
	var parsed: Array[Vector2i] = []
	for cell in cells:
		if cell is Vector2i:
			parsed.append(cell)
	host_place(
		StringName(kind), parsed, multiplayer.get_remote_sender_id(), quarter_turns, reported
	)


@rpc("authority", "reliable", "call_remote")
func receive_place_shortage(kind: String, cell: Vector2i, reason: String) -> void:
	if BuildToolRow.footprint_kind(interaction.build.tool) != StringName(kind):
		return
	var point := interaction.get_canvas_transform() * interaction.cell_center(cell)
	interaction.build.update_preview(point, point)
	interaction.build.reasons.assign([reason])
	interaction.build.cell_ok.fill(false)


@rpc("authority", "reliable", "call_remote")
func apply_structure(
	structure_name: String,
	owner: int,
	anchor: Vector2i,
	quarter_turns: int,
	placement_id: int,
	start_castle: bool
) -> void:
	## Preserve the host ID for city and capture state, including after removal.
	if multiplayer.get_remote_sender_id() != 1:
		return
	ConstructionPlacer.new(map).apply_replica(
		structure_name, anchor, owner, quarter_turns, placement_id, start_castle
	)


@rpc("authority", "reliable", "call_remote")
func apply_wall_state(free_cells: Array, autos: Array, hp_rows: Array = []) -> void:
	## Free-form chain, solved auto junctions and remaining hp the host decided.
	## A late joiner and a live place both use this, so the pieces match.
	if multiplayer.get_remote_sender_id() != 1:
		return
	map.replace_wall_cells_from_host(free_cells)
	for entry in hp_rows:
		if entry is Array and entry.size() >= 2 and entry[0] is Vector2i:
			map.set_wall_hp(entry[0], int(entry[1]))
	for entry in autos:
		if (
			entry is Array
			and entry.size() >= 2
			and entry[0] is Vector2i
			and entry[1] is String
			and str(entry[1]) != ""
		):
			map.apply_solved_auto_junction(entry[0], str(entry[1]))
