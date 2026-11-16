class_name SoldierRequests
extends Node2D
## Host pipeline for barracks soldier training and follow/hold (#553).

const NEIGHBOR_CLOCK := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]

var _jobs: Array[Dictionary] = []
var _next_index := {}
var _train_button: Button
var _order_button: Button
var _ui_peer := -1
var _headless := false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	var spawner := get_node_or_null("MultiplayerSpawner") as MultiplayerSpawner
	if spawner:
		spawner.spawn_function = _make_soldier
	_ensure_buttons()
	if not _headless:
		set_process(true)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		advance(delta)


func _process(_delta: float) -> void:
	if _headless or _train_button == null:
		return
	var peer := multiplayer.get_unique_id() if multiplayer != null else 1
	if peer != _ui_peer:
		_ui_peer = peer
	var train_anchor := _train_anchor(peer)
	_train_button.visible = train_anchor != Vector2i.MAX
	_order_button.visible = _living_for_owner(peer) > 0
	if _order_button.visible:
		var flip := "hold" if _owner_order(peer) == "follow" else "follow"
		_order_button.text = flip.capitalize()


func pending_job_count() -> int:
	return _jobs.size()


func advance(seconds: float) -> void:
	if not multiplayer.is_server() or seconds <= 0.0:
		return
	var finished: Array[int] = []
	for i in _jobs.size():
		var job: Dictionary = _jobs[i]
		job["left"] = float(job["left"]) - seconds
		if job["left"] <= 0.0:
			finished.append(i)
			_spawn_job(job)
	for i in range(finished.size() - 1, -1, -1):
		_jobs.remove_at(finished[i])
	set_physics_process(multiplayer.is_server() and not _jobs.is_empty())


func host_train(peer_id: int, anchor: Vector2i) -> bool:
	if not multiplayer.is_server():
		return false
	var map := _map()
	var body := get_parent().get_node_or_null(str(peer_id)) as Node2D
	if map == null or body == null or Interaction.player_dead(body):
		return false
	var entry := _barracks_entry(peer_id, anchor)
	if entry.is_empty():
		return false
	if not _in_reach(body, map, entry):
		return false
	if _slots_used(peer_id, anchor) >= SoldierStats.CAP_PER_BARRACKS:
		return false
	if not _charge(peer_id, SoldierStats.TRAIN_WOOD):
		return false
	_jobs.append({"peer_id": peer_id, "anchor": anchor, "left": SoldierStats.TRAIN_TIME})
	set_physics_process(true)
	return true


@rpc("any_peer", "reliable", "call_remote")
func request_train(anchor: Vector2i) -> void:
	if not multiplayer.is_server():
		return
	host_train(multiplayer.get_remote_sender_id(), anchor)


func host_set_order(peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	var next := "hold"
	for child in get_children():
		if child is Soldier and child.owner_peer == peer_id and child.state != Soldier.State.DYING:
			next = "hold" if child.order == "follow" else "follow"
			child.set_order(next)
	return true


@rpc("any_peer", "reliable", "call_remote")
func request_order() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	host_set_order(sender)


func spawn_saved(row: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var spawner := get_node_or_null("MultiplayerSpawner") as MultiplayerSpawner
	if spawner == null:
		return
	var name := str(row.get("name", "soldier_saved"))
	spawner.spawn(_spawn_dict(name, row))


func soldiers() -> Array:
	return get_children().filter(func(n: Node) -> bool: return n is Soldier)


func _spawn_job(job: Dictionary) -> void:
	var peer_id: int = job["peer_id"]
	var anchor: Vector2i = job["anchor"]
	var map := _map()
	var entry := _barracks_entry(peer_id, anchor)
	if entry.is_empty():
		return
	var rotation := int(entry.get("rotation", 0))
	var pos := spawn_cell(map, anchor, rotation)
	if pos == Vector2.INF:
		_refund(peer_id, SoldierStats.TRAIN_WOOD)
		return
	var spawner := get_node_or_null("MultiplayerSpawner") as MultiplayerSpawner
	if spawner == null:
		return
	var index := int(_next_index.get(peer_id, 0))
	_next_index[peer_id] = index + 1
	var node_name := "soldier_%d_%d" % [peer_id, index]
	spawner.spawn(_spawn_dict(node_name, {
		"pos": pos,
		"owner": peer_id,
		"order": "follow",
		"hp": MobCatalog.stat(MobCatalog.SOLDIER, "hp"),
		"barracks_anchor": anchor,
		"seed": hash(Vector2i(peer_id, index)),
	}))


static func spawn_cell(map: TileMap, anchor: Vector2i, rotation: int) -> Vector2:
	var base := StructurePlacer.load_named("barracks")
	if base == null:
		return Vector2.INF
	var structure := Structure.rotated(base, rotation)
	var footprint := StructurePlacer.footprint(structure, anchor)
	for off: Vector2i in NEIGHBOR_CLOCK:
		var cell: Vector2i = anchor + off
		if footprint.has(cell):
			continue
		if map.predicted_clear(cell):
			return map.map_to_local(cell)
	return Vector2.INF


func _spawn_dict(name: String, data: Dictionary) -> Dictionary:
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var anchor: Vector2i = data.get("barracks_anchor", Vector2i.ZERO)
	if data.has("barracks_anchor") and data["barracks_anchor"] is Array:
		var a: Array = data["barracks_anchor"]
		anchor = Vector2i(int(a[0]), int(a[1]))
	if data.has("pos") and data["pos"] is Array:
		var p: Array = data["pos"]
		pos = Vector2(float(p[0]), float(p[1]))
	return {
		"name": name,
		"type": MobCatalog.SOLDIER,
		"pos": pos,
		"seed": int(data.get("seed", 0)),
		"owner": int(data.get("owner", 0)),
		"order": str(data.get("order", "follow")),
		"hp": int(data.get("hp", MobCatalog.stat(MobCatalog.SOLDIER, "hp"))),
		"barracks_anchor": anchor,
	}


func _make_soldier(data: Dictionary) -> Node:
	var soldier: Soldier = load(Soldier.SOLDIER_SCENE).instantiate()
	soldier.name = data["name"]
	soldier.setup_soldier(data)
	return soldier


func _map() -> TileMap:
	return get_parent().get_node_or_null("worldMap") as TileMap


func _interaction() -> Interaction:
	return get_parent().get_node_or_null("Interaction") as Interaction


func _barracks_entry(peer_id: int, anchor: Vector2i) -> Dictionary:
	var map := _map()
	if map == null:
		return {}
	for entry in map.placed_structures().values():
		if str(entry.get("name")) == "barracks" and int(entry.get("owner")) == peer_id \
				and entry.get("anchor", Vector2i.ZERO) == anchor:
			return entry
	return {}


func _in_reach(body: Node2D, map: TileMap, entry: Dictionary) -> bool:
	var anchor: Vector2i = entry.get("anchor", Vector2i.ZERO)
	var rotation := int(entry.get("rotation", 0))
	var base := StructurePlacer.load_named("barracks")
	if base == null:
		return false
	var structure := Structure.rotated(base, rotation)
	var footprint := StructurePlacer.footprint(structure, anchor)
	var interaction := _interaction()
	if interaction == null:
		return false
	var limit := Interaction.REACH + Interaction.REACH_SLACK
	for cell: Vector2i in footprint:
		if body.global_position.distance_to(interaction.cell_center(cell)) <= limit:
			return true
	return false


func _slots_used(peer_id: int, anchor: Vector2i) -> int:
	var count := 0
	for child in get_children():
		if child is Soldier and child.owner_peer == peer_id and child.barracks_anchor == anchor \
				and child.state != Soldier.State.DYING:
			count += 1
	for job in _jobs:
		if int(job["peer_id"]) == peer_id and job["anchor"] == anchor:
			count += 1
	return count


func _charge(peer_id: int, wood: int) -> bool:
	if wood <= 0:
		return false
	if peer_id == multiplayer.get_unique_id():
		var inventory := get_node_or_null("../../Inventory") as Inventory
		return inventory != null and inventory.spend(Inventory.WOOD, wood)
	var interaction := _interaction()
	if interaction == null:
		return false
	interaction.rpc_id(peer_id, "receive_charge", wood)
	return true


func _refund(peer_id: int, wood: int) -> void:
	if wood <= 0:
		return
	if peer_id == multiplayer.get_unique_id():
		var inventory := get_node_or_null("../../Inventory") as Inventory
		if inventory:
			inventory.add(Inventory.WOOD, wood)
	else:
		receive_wood.rpc_id(peer_id, wood)


@rpc("authority", "reliable", "call_remote")
func receive_wood(wood: int) -> void:
	var inventory := get_node_or_null("../../Inventory") as Inventory
	if inventory and wood > 0:
		inventory.add(Inventory.WOOD, wood)


func _train_anchor(peer_id: int) -> Vector2i:
	var map := _map()
	var body := get_parent().get_node_or_null(str(peer_id)) as Node2D
	if map == null or body == null:
		return Vector2i.MAX
	var best := Vector2i.MAX
	var best_d := INF
	for entry in map.placed_structures().values():
		if str(entry.get("name")) != "barracks" or int(entry.get("owner")) != peer_id:
			continue
		var anchor: Vector2i = entry.get("anchor", Vector2i.ZERO)
		if _slots_used(peer_id, anchor) >= SoldierStats.CAP_PER_BARRACKS:
			continue
		if not _in_reach(body, map, entry):
			continue
		var d := body.global_position.distance_squared_to(_interaction().cell_center(anchor))
		if d < best_d:
			best_d = d
			best = anchor
	return best


func _living_for_owner(peer_id: int) -> int:
	var n := 0
	for child in get_children():
		if child is Soldier and child.owner_peer == peer_id and child.state != Soldier.State.DYING:
			n += 1
	return n


func _owner_order(peer_id: int) -> String:
	for child in get_children():
		if child is Soldier and child.owner_peer == peer_id and child.state != Soldier.State.DYING:
			return child.order
	return "follow"


func _ensure_buttons() -> void:
	var hud := get_node_or_null("/root/Flagoria/CanvasLayer1") as CanvasLayer
	if hud == null:
		return
	var theme: Theme = load("res://art/ui/main_menu_theme.tres")
	_train_button = hud.get_node_or_null("TrainButton") as Button
	if _train_button == null:
		_train_button = Button.new()
		_train_button.name = "TrainButton"
		_train_button.theme = theme
		_train_button.text = "Train %d" % SoldierStats.TRAIN_WOOD
		_train_button.position = Vector2(4, 196)
		_train_button.pressed.connect(_on_train_pressed)
		hud.add_child(_train_button)
	_order_button = hud.get_node_or_null("SoldierOrderButton") as Button
	if _order_button == null:
		_order_button = Button.new()
		_order_button.name = "SoldierOrderButton"
		_order_button.theme = theme
		_order_button.position = Vector2(4, 214)
		_order_button.pressed.connect(_on_order_pressed)
		hud.add_child(_order_button)
	_train_button.visible = false
	_order_button.visible = false


func _on_train_pressed() -> void:
	var peer := multiplayer.get_unique_id() if multiplayer != null else 1
	var anchor := _train_anchor(peer)
	if anchor == Vector2i.MAX:
		return
	if multiplayer.is_server():
		host_train(peer, anchor)
	else:
		request_train.rpc_id(1, anchor)


func _on_order_pressed() -> void:
	var peer := multiplayer.get_unique_id() if multiplayer != null else 1
	if multiplayer.is_server():
		host_set_order(peer)
	else:
		request_order.rpc_id(1)