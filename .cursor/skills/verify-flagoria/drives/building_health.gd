## fixture
## launch: --seed 11
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## Set up a mob-owned tower. Arm and aim every bomb through player input.

const WorldMap := preload("res://Scripts/world/TileMap.gd")


func run() -> void:
	if not await start_game():
		return
	var map: WorldMap = current_scene.get_node(WORLD_MAP)
	var buildings: BuildingHealth = current_scene.get_node("World/BuildingHealth")
	var bombs: BombThrows = current_scene.get_node("World/BombThrows")
	var wheel: ToolWheel = current_scene.get_node("CanvasLayer1/ToolWheel")
	if not await wait_until(func() -> bool: return map.spawn_point != Vector2i.ZERO, 10.0):
		done(false)
		return
	var anchor := _place_tower(map)
	var placement := map.structure_placement_at(anchor)
	if placement.is_empty():
		printerr("building_health: could not place a tower in view and inside throw range")
		done(false)
		return
	var id: int = placement["id"]
	var target := map.map_to_local(anchor)

	step("intact enemy tower")
	await tap_key(KEY_2)
	if not await wait_until(wheel.bomb_armed, 2.0):
		done(false)
		return
	await snapshot("tower-full")

	var bombed := await _bomb_tower(map, target, buildings, bombs, id)

	var cleared := func(cell: Vector2i) -> bool:
		return map.structure_placement_at(cell).is_empty() and map.get_cell_source_id(1, cell) == -1
	if not bombed or not placement["cells"].all(cleared):
		done(false)
		return
	step("tower destroyed and footprint cleared")
	await snapshot("tower-destroyed")
	done(true)


func _bomb_tower(
	map: WorldMap, target: Vector2, buildings: BuildingHealth, bombs: BombThrows, id: int
) -> bool:
	var damage := int(Tuning.value(&"bomb.damage"))
	var maximum := buildings.max_hp(id)
	var cracked := false
	var peer_id := int(str(hero().name))
	for remaining in range(maximum - damage, -damage, -damage):
		if not await wait_until(func() -> bool: return bombs.is_ready(peer_id), 4.0):
			return false
		step("aim and throw to reach %d tower HP" % maxi(0, remaining))
		await _aim_and_throw(to_window(map, target))
		if not await wait_until(func() -> bool: return buildings.hp(id) == maxi(0, remaining), 4.0):
			printerr("building_health: bomb missed, tower HP is ", buildings.hp(id))
			return false
		if (remaining <= maximum * 0.25 and remaining > 0 and not cracked) or remaining <= 0:
			if not await wait_until(
				func() -> bool: return not bombs.has_phase(BombThrows.Phase.BLAST), 2.0
			):
				return false
			if remaining > 0:
				cracked = true
				await snapshot("tower-cracked")
	return cracked


func _place_tower(map: WorldMap) -> Vector2i:
	var tower := StructurePlacer.load_named("tower_wood")
	var start := map.local_to_map(map.to_local(hero().global_position))
	var directions := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for distance: int in [6, 7, 5, 8, 4]:
		for direction: Vector2i in directions:
			for slide: int in [0, 1, -1, 2, -2]:
				var anchor := (
					start + direction * distance + Vector2i(-direction.y, direction.x) * slide
				)
				if not map.is_drawn(anchor):
					continue
				if map.place_structure(tower, anchor, StructurePlacer.OWNER_MOBS) > 0:
					return anchor
	return start


func _aim_and_throw(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var button := InputEventMouseButton.new()
		button.position = at
		button.global_position = at
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		Input.parse_input_event(button)
		await process_frame
