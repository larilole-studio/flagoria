extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 4

const ATTACK := "CanvasLayer1/TouchScreenButton"


func run() -> void:
	if not await start_game():
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var it := current_scene.get_node(INTERACTION) as Interaction
	var inventory := current_scene.get_node(INVENTORY) as Inventory

	step("approach-rock")
	var cell := await _approach_rock(map, it)
	if cell == Vector2i.MAX:
		printerr("mine: no walkable rock reached")
		done(false)
		return

	var initial := inventory.count_of(Inventory.STONE)
	step("sword-leaves-rock-intact")
	await _aim_attack(it.cell_center(cell) - hero().global_position)
	if not await _sword_swung() or not map.mineable_rock(cell):
		printerr("mine: expected a sword swing to leave rock %s intact" % cell)
		done(false)
		return

	done(await _mine_rock(map, it, inventory, cell, initial))


func _sword_swung() -> bool:
	if not await wait_until(func() -> bool: return hero().isAttacking, 1.0):
		return false
	return await wait_until(func() -> bool: return not hero().isAttacking, 2.0)


func _mine_rock(
	map: TileMap, it: Interaction, inventory: Inventory, cell: Vector2i, initial: int
) -> bool:
	await toggle_mode()
	var hits: Array[int] = []
	it.chop_hit.connect(
		func(target: Vector2i, hit: int) -> void:
			if target == cell:
				hits.append(hit)
	)
	step("first-mining-hit")
	var offset := it.cell_center(cell) - hero().global_position
	await _aim_attack(offset + offset.normalized() * 2.0)
	if not await wait_until(func() -> bool: return hits.size() >= 1, 4.0):
		printerr("mine: chop did not reach rock at %s" % cell)
		return false
	if hits != [1] or not map.mineable_rock(cell) or inventory.count_of(Inventory.STONE) != initial:
		return false
	await snapshot("rock-hit")

	step("deplete-rock")
	if not await wait_until(func() -> bool: return not it.chopping(), 4.0):
		printerr("mine: finish timed out, hits %s and target %s" % [hits, it.chop_cell])
		return false
	if (
		hits != [1, 2]
		or map.mineable_rock(cell)
		or inventory.count_of(Inventory.STONE) != initial + 2
	):
		printerr(
			(
				"mine: hits %s, rock present %s, stone %d"
				% [hits, map.mineable_rock(cell), inventory.count_of(Inventory.STONE)]
			)
		)
		return false
	await snapshot("rock-depleted")
	return true


func _approach_rock(map: TileMap, it: Interaction) -> Vector2i:
	for attempt in 28:
		var closest := Vector2i.MAX
		var best := 160.0
		for cell in map.get_used_cells(GROUND_DECOR_LAYER):
			if not map.mineable_rock(cell):
				continue
			var distance := hero().global_position.distance_to(it.cell_center(cell))
			if distance < best:
				closest = cell
				best = distance
		if closest == Vector2i.MAX:
			await hold("ui_down", 15)
			continue
		if best > 12.0 and best < 27.0:
			return closest
		var offset := it.cell_center(closest) - hero().global_position
		if best <= 12.0:
			offset = -offset if best > 0.1 else Vector2.UP
		await hold(_move_action(offset), 8 if best > 40.0 else 4)
	return Vector2i.MAX


func _move_action(offset: Vector2) -> String:
	if absf(offset.x) > absf(offset.y):
		return "ui_right" if offset.x > 0.0 else "ui_left"
	return "ui_down" if offset.y > 0.0 else "ui_up"


func _aim_attack(offset: Vector2) -> void:
	var button = current_scene.get_node(ATTACK)
	var origin := root.get_final_transform() * Vector2(button.aim_center())
	var delta := to_window(hero(), hero().to_local(hero().global_position + offset))
	delta -= to_window(hero(), Vector2.ZERO)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = origin if pressed else origin + delta
		event.pressed = pressed
		Input.parse_input_event(event)
		if pressed:
			await process_frame
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = origin + delta
			drag.relative = delta
			Input.parse_input_event(drag)
		await process_frame
