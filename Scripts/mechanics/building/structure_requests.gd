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
	request_place.rpc_id(1, String(kind), cells, quarter_turns)
	return true


func host_place(kind: StringName, cells: Array[Vector2i], peer_id: int, quarter_turns: int = 0) -> bool:
	## Host accepts `peer_id`'s request, or places for itself. False charges nothing.
	if not multiplayer.is_server() or not BuildCosts.is_requestable(kind) or cells.is_empty():
		return false
	if BuildCosts.NAMED_STRUCTURES.has(kind) and cells.size() != 1:
		return false
	var body := world.get_node_or_null(str(peer_id)) as Node2D
	if body == null or Interaction.player_dead(body):
		return false
	for cell in cells:
		if body.global_position.distance_to(interaction.cell_center(cell)) > Interaction.REACH + Interaction.REACH_SLACK:
			return false
	var local := peer_id == multiplayer.get_unique_id()
	if local and inventory == null:
		return false
	var placer := ConstructionPlacer.new(map)
	if not placer.place_for_peer(kind, cells, peer_id, inventory if local else null, quarter_turns):
		return false
	if not local:
		interaction.rpc_id(peer_id, "receive_charge", placer.cost(kind, cells))
	if kind == BuildCosts.WALL_BLOCK:
		_publish()
	else:
		apply_structure.rpc(ConstructionPlacer.named_structure_file(kind), peer_id, cells[0], quarter_turns)
		if cities != null and BuildCosts.CITY_KINDS.has(kind):
			cities.tick()
	return true


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
		apply_structure.rpc(structure_name, owner, anchor, 0)
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
func request_place(kind: String, cells: Array, quarter_turns: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var parsed: Array[Vector2i] = []
	for cell in cells:
		if cell is Vector2i:
			parsed.append(cell)
	host_place(StringName(kind), parsed, multiplayer.get_remote_sender_id(), quarter_turns)


@rpc("authority", "reliable", "call_remote")
func apply_structure(structure_name: String, owner: int, anchor: Vector2i, quarter_turns: int = 0) -> void:
	## Applied only from peer 1, so ids follow the host's list. The same
	## placement arriving again (snapshot, then this call) is left as it is.
	## `quarter_turns` is clockwise; 0 keeps an older three-field row.
	if multiplayer.get_remote_sender_id() != 1:
		return
	ConstructionPlacer.new(map).apply_replica(structure_name, anchor, owner, quarter_turns)


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
		if entry is Array and entry.size() >= 2 and entry[0] is Vector2i \
				and entry[1] is String and str(entry[1]) != "":
			map.apply_solved_auto_junction(entry[0], str(entry[1]))
