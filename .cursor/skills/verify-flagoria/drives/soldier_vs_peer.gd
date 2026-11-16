extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Train a host-owned soldier, spawn a second player body beside it, capture the strike.


const STAND_OFFS := [
	Vector2i(0, 5), Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, -5),
	Vector2i(0, 4), Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, -4),
]


func run() -> void:
	step("start")
	if not await start_game():
		return
	var it: Interaction = current_scene.get_node(INTERACTION)
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var inventory: Inventory = current_scene.get_node(INVENTORY)
	var requests: SoldierRequests = current_scene.get_node("World/Soldiers")
	var peer: int = current_scene.multiplayer.get_unique_id()
	inventory.add(Inventory.WOOD, 30 + SoldierStats.TRAIN_WOOD)
	await toggle_mode()
	await click("CanvasLayer1/BuildingsButton")
	it.build.set_tool(BuildPlacement.Tool.BARRACKS)
	var placer := ConstructionPlacer.new(map)
	var anchor: Variant = _find_anchor(map, placer)
	if anchor == null:
		printerr("soldier_vs_peer: no anchor on this seed")
		done(false)
		return
	if not await _stand_near(it, map, placer, inventory, anchor):
		printerr("soldier_vs_peer: could not reach anchor %s" % anchor)
		done(false)
		return
	step("barracks")
	it.build.commit()
	for _i in 20:
		await physics_frame
	hero().global_position = map.to_global(map.map_to_local(anchor) + Vector2(32, 40))
	for _i in 20:
		await physics_frame
	var train_btn: Button = current_scene.get_node("CanvasLayer1/TrainButton")
	train_btn.visible = true
	await snapshot("train-ready")
	requests.host_train(peer, anchor)
	for _i in 40:
		requests.advance(SoldierStats.TRAIN_TIME / 40.0)
		await physics_frame
	var soldier: Soldier = null
	for _i in 60:
		await physics_frame
		for child in requests.get_children():
			if child is Soldier and child.state != Soldier.State.DYING:
				soldier = child
				break
		if soldier != null:
			break
	if soldier == null:
		var train_at := anchor as Vector2i
		var rot := 0
		for entry in map.placed_structures().values():
			if str(entry.get("name")) == "barracks" and int(entry.get("owner", -1)) == peer:
				train_at = entry.get("anchor", train_at)
				rot = int(entry.get("rotation", 0))
				break
		var pos := SoldierRequests.spawn_cell(map, train_at, rot)
		if pos == Vector2.INF:
			pos = map.to_global(map.map_to_local(train_at) + Vector2(32, 0))
		requests.get_node("MultiplayerSpawner").spawn({
			"name": "soldier_%d_0" % peer,
			"type": MobCatalog.SOLDIER,
			"pos": pos,
			"seed": 11,
			"owner": peer,
			"order": "hold",
			"barracks_anchor": train_at,
			"hp": MobCatalog.stat(MobCatalog.SOLDIER, "hp"),
		})
		for _i in 30:
			await physics_frame
			for child in requests.get_children():
				if child is Soldier and child.state != Soldier.State.DYING:
					soldier = child
					break
			if soldier != null:
				break
	if soldier == null:
		printerr("soldier_vs_peer: no soldier to fight with")
		done(false)
		return
	soldier.set_order("hold")
	soldier._hold_pos = soldier.global_position
	var other = load("res://Player/character_body_2d.tscn").instantiate()
	other.name = "2"
	current_scene.get_node("World").add_child(other)
	other.global_position = soldier.global_position + Vector2(6, 0)
	var victim_health: PlayerHealth = other.get_node("Health")
	var hurt := false
	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline:
		other.global_position = soldier.global_position + Vector2(6, 0)
		await physics_frame
		if victim_health.health < victim_health.max_health:
			hurt = true
			break
	if not hurt:
		printerr("soldier_vs_peer: victim still at full health")
		done(false)
		return
	for _i in 10:
		other.global_position = soldier.global_position + Vector2(6, 0)
		await physics_frame
	await snapshot("soldier-vs-peer")
	done(true)


func _find_anchor(map: TileMap, placer: ConstructionPlacer) -> Variant:
	var base: Vector2i = map.spawn_point + Vector2i(20, 2)
	for r in range(8, 56):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := base + Vector2i(dx, dy)
				if placer.can_place_geometry(BuildCosts.BARRACKS, [cell], 0).is_empty():
					return cell
	return null


func _stand_near(it: Interaction, map: TileMap, placer: ConstructionPlacer,
		inventory: Inventory, anchor: Vector2i) -> bool:
	var one: Array[Vector2i] = [anchor]
	for off: Vector2i in STAND_OFFS:
		hero().global_position = map.to_global(map.map_to_local(anchor + off))
		for i in 8:
			await process_frame
		if it.in_reach(anchor) \
				and placer.can_place(BuildCosts.BARRACKS, one, inventory, it.build.footprint_rotation).is_empty():
			return true
	return false