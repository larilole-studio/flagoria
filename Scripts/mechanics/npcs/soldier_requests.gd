class_name SoldierRequests
extends Node2D
## Host pipeline for soldier training and orders.

const MOVE_SEARCH_CELLS := 3
const MOVE_COORD_LIMIT := 1 << 20

const NEIGHBOR_CLOCK := [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
	Vector2i(1, -1)
]

var _jobs: Array[Dictionary] = []
var _next_index := {}
var _train_button: Button
var _order_button: Button
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
	var train_anchor := _train_anchor(peer)
	_train_button.visible = train_anchor != Vector2i.MAX
	if _train_button.visible:
		var cost := _training_cost()
		var label := "Train %dw %ds" % [cost.x, cost.y]
		if _train_button.text != label:
			_train_button.text = label
			_train_button.reset_size()
	_order_button.visible = _living_for_owner(peer) > 0
	if _order_button.visible:
		var flip := "hold" if _owner_order(peer) == "follow" else "follow"
		_order_button.text = flip.capitalize()
	if _train_button.visible or _order_button.visible:
		_layout_buttons()


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
			if not _spawn_job(job):
				_refund(job["peer_id"], job["cost"])
	for i in range(finished.size() - 1, -1, -1):
		_jobs.remove_at(finished[i])
	set_physics_process(multiplayer.is_server() and not _jobs.is_empty())


func train(anchor: Vector2i) -> void:
	if multiplayer.is_server():
		host_train(multiplayer.get_unique_id(), anchor)
		return
	var inventory := get_node_or_null("../../Inventory") as Inventory
	if inventory != null:
		var reported := BuildCosts.balance(inventory) + inventory.processed_charges
		request_train.rpc_id(1, anchor, reported)


func host_train(peer_id: int, anchor: Vector2i, reported := Vector2i.ZERO) -> bool:
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
	if _slots_used(peer_id, anchor) >= int(Tuning.value(&"soldiers.cap_per_barracks")):
		return false
	var cost := _training_cost()
	if not _charge(peer_id, cost, reported):
		return false
	(
		_jobs
		. append(
			{
				"peer_id": peer_id,
				"anchor": anchor,
				"left": Tuning.value(&"soldiers.train_seconds"),
				"cost": cost,
			}
		)
	)
	set_physics_process(true)
	return true


@rpc("any_peer", "reliable", "call_remote")
func request_train(anchor: Vector2i, reported: Vector2i) -> void:
	if not multiplayer.is_server():
		return
	host_train(multiplayer.get_remote_sender_id(), anchor, reported)


func host_set_order(peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	var next := "hold" if _owner_order(peer_id) == "follow" else "follow"
	for child in get_children():
		if child is Soldier and child.is_owned_alive(peer_id):
			child.set_order(next)
	return true


@rpc("any_peer", "reliable", "call_remote")
func request_order() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	host_set_order(sender)


func capture_training() -> Array:
	var rows := []
	for job in _jobs:
		var anchor: Vector2i = job["anchor"]
		var cost: Vector2i = job["cost"]
		rows.append([job["peer_id"], anchor.x, anchor.y, job["left"], cost.x, cost.y])
	return rows


func restore_training(rows: Array) -> void:
	if not multiplayer.is_server():
		return
	_jobs.clear()
	for row in rows:
		if not row is Array or row.size() != 6 or not row.all(_finite_number):
			continue
		if row[0] < 1 or row[3] <= 0 or row[4] < 0 or row[5] < 0:
			continue
		(
			_jobs
			. append(
				{
					"peer_id": int(row[0]),
					"anchor": Vector2i(row[1], row[2]),
					"left": float(row[3]),
					"cost": Vector2i(row[4], row[5]),
				}
			)
		)
	set_physics_process(not _jobs.is_empty())


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value)


func host_move(peer_id: int, names: PackedStringArray, target: Vector2) -> bool:
	if not multiplayer.is_server() or not target.is_finite():
		return false
	if maxf(absf(target.x), absf(target.y)) > MOVE_COORD_LIMIT:
		return false
	var body := get_parent().get_node_or_null(str(peer_id)) as Node2D
	var map := _map()
	if body == null or Interaction.player_dead(body) or map == null:
		return false
	var requested := {}
	for unit_name in names:
		requested[unit_name] = true
	var cell := map.local_to_map(map.to_local(target))
	var offsets: Array[Vector2i] = [Vector2i.ZERO]
	for radius in range(1, MOVE_SEARCH_CELLS + 1):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) == radius:
					offsets.append(Vector2i(x, y))
	offsets.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (
				map.to_global(map.map_to_local(cell + a)).distance_squared_to(target)
				< (map.to_global(map.map_to_local(cell + b)).distance_squared_to(target))
			)
	)
	var assigned := false
	for unit: Soldier in soldiers():
		if not requested.has(str(unit.name)) or not unit.is_owned_alive(peer_id):
			continue
		for offset in offsets:
			var destination := map.to_global(map.map_to_local(cell + offset))
			if unit.can_stand_at(destination):
				unit.move_to(destination)
				offsets.erase(offset)
				assigned = true
				break
	return assigned


@rpc("any_peer", "reliable", "call_remote")
func request_move(names: PackedStringArray, target: Vector2) -> void:
	if multiplayer.is_server():
		host_move(multiplayer.get_remote_sender_id(), names, target)


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


func _spawn_job(job: Dictionary) -> bool:
	var peer_id: int = job["peer_id"]
	var anchor: Vector2i = job["anchor"]
	var entry := _barracks_entry(peer_id, anchor)
	var spawner := get_node_or_null("MultiplayerSpawner") as MultiplayerSpawner
	if entry.is_empty() or spawner == null:
		return false
	var pos := spawn_cell(_map(), anchor, int(entry.get("rotation", 0)))
	if pos == Vector2.INF:
		return false
	var index := int(_next_index.get(peer_id, 0))
	var node_name := "soldier_%d_%d" % [peer_id, index]
	while has_node(NodePath(node_name)):
		index += 1
		node_name = "soldier_%d_%d" % [peer_id, index]
	_next_index[peer_id] = index + 1
	var data := {
		"pos": pos,
		"owner": peer_id,
		"order": "follow",
		"hp": MobCatalog.stat(MobCatalog.SOLDIER, "hp"),
		"barracks_anchor": anchor,
		"seed": hash(Vector2i(peer_id, index)),
	}
	return spawner.spawn(_spawn_dict(node_name, data)) != null


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
		if (
			str(entry.get("name")) == "barracks"
			and int(entry.get("owner")) == peer_id
			and entry.get("anchor", Vector2i.ZERO) == anchor
		):
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
		if (
			child is Soldier
			and child.owner_peer == peer_id
			and child.barracks_anchor == anchor
			and child.state != Soldier.State.DYING
		):
			count += 1
	for job in _jobs:
		if int(job["peer_id"]) == peer_id and job["anchor"] == anchor:
			count += 1
	return count


static func _training_cost() -> Vector2i:
	return Vector2i(
		Tuning.value(&"soldiers.training_wood"), Tuning.value(&"soldiers.training_stone")
	)


func _charge(peer_id: int, cost: Vector2i, reported: Vector2i) -> bool:
	var inventory := get_node_or_null("../../Inventory") as Inventory
	if inventory == null:
		return false
	if peer_id == multiplayer.get_unique_id():
		return BuildCosts.charge(inventory, cost)
	var interaction := _interaction()
	if interaction == null:
		return false
	# Account for outstanding debits, as in the two-resource build requests.
	var charged := inventory.issued_charges(peer_id)
	if not BuildCosts.shortage(reported.max(charged) - charged, cost).is_empty():
		return false
	interaction.issue_charge(peer_id, cost)
	return true


func _refund(peer_id: int, cost: Vector2i) -> void:
	if peer_id == multiplayer.get_unique_id():
		receive_training_refund(cost)
	elif peer_id in multiplayer.get_peers():
		receive_training_refund.rpc_id(peer_id, cost)


@rpc("authority", "reliable", "call_remote")
func receive_training_refund(cost: Vector2i) -> void:
	var inventory := get_node_or_null("../../Inventory") as Inventory
	if inventory != null:
		BuildCosts.credit(inventory, cost)


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
		if _slots_used(peer_id, anchor) >= int(Tuning.value(&"soldiers.cap_per_barracks")):
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
		if child is Soldier and child.is_owned_alive(peer_id) and child.order != "follow":
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
		_train_button.pressed.connect(_on_train_pressed)
		hud.add_child(_train_button)
	_order_button = hud.get_node_or_null("SoldierOrderButton") as Button
	if _order_button == null:
		_order_button = Button.new()
		_order_button.name = "SoldierOrderButton"
		_order_button.theme = theme
		_order_button.pressed.connect(_on_order_pressed)
		hud.add_child(_order_button)
	_train_button.visible = false
	_order_button.visible = false


func _layout_buttons() -> void:
	var hud := _train_button.get_parent()
	var plate := hud.get_node("StatusPlate") as Control
	var scoreboard := hud.get_node("ScoreboardPanel") as Control
	var top := plate.get_rect().end.y
	if scoreboard.visible:
		top = maxf(top, scoreboard.get_rect().end.y)
	var start := Vector2(plate.position.x, top + 4.0)
	_train_button.position = start
	_order_button.position = start
	if _train_button.visible:
		_order_button.position.x += _train_button.size.x + 4.0


func _on_train_pressed() -> void:
	var peer := multiplayer.get_unique_id() if multiplayer != null else 1
	var anchor := _train_anchor(peer)
	if anchor != Vector2i.MAX:
		train(anchor)


func _on_order_pressed() -> void:
	var peer := multiplayer.get_unique_id() if multiplayer != null else 1
	if multiplayer.is_server():
		host_set_order(peer)
	else:
		request_order.rpc_id(1)
