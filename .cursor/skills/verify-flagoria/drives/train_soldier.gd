extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Place a barracks, train a soldier, toggle follow and hold.

const ROTATE_BTN := "CanvasLayer1/FootprintRotateButton"
const STAND_OFFS := [
	Vector2i(0, 5),
	Vector2i(5, 0),
	Vector2i(-5, 0),
	Vector2i(0, -5),
	Vector2i(0, 4),
	Vector2i(4, 0),
	Vector2i(-4, 0),
	Vector2i(0, -4),
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
		printerr("train_soldier: no anchor on this seed")
		done(false)
		return
	if not await _stand_near(it, map, placer, inventory, anchor):
		printerr("train_soldier: could not reach anchor %s" % anchor)
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
	var hero_node := hero()
	var start := hero_node.global_position
	hero_node.global_position = start + Vector2(64, 0)
	for _i in 30:
		await physics_frame
	await snapshot("soldier-following")
	var order_btn: Button = current_scene.get_node("CanvasLayer1/SoldierOrderButton")
	order_btn.pressed.emit()
	for _i in 8:
		await process_frame
	hero_node.global_position = start + Vector2(128, 0)
	for _i in 30:
		await physics_frame
	await snapshot("soldier-holding")
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


func _stand_near(
	it: Interaction,
	map: TileMap,
	placer: ConstructionPlacer,
	inventory: Inventory,
	anchor: Vector2i
) -> bool:
	var one: Array[Vector2i] = [anchor]
	for off: Vector2i in STAND_OFFS:
		hero().global_position = map.to_global(map.map_to_local(anchor + off))
		for i in 8:
			await process_frame
		if (
			it.in_reach(anchor)
			and (
				placer
				. can_place(BuildCosts.BARRACKS, one, inventory, it.build.footprint_rotation)
				. is_empty()
			)
		):
			return true
	return false
