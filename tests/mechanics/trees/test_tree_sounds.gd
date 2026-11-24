extends "res://tests/helpers/test_helpers.gd"
## Tree chop sounds, and a chop cancelled by the hero's death (#265).


func _chop_scene() -> Dictionary:
	## The main scene with a grass patch, one tree at (10, 8) and the local
	## player two cells below it; the test steps the chop clock itself.
	## Isolation (#359): freeze TileMap processing, reset MapGen, and pin
	## spawn on the painted stand cell so a revive does not
	## resolve_player_spawn → generate_chunk over the paint.
	var scene = mount_main_scene()
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	var world = scene.get_node("World/worldMap")
	root.get_node("MapGen").reset_to_defaults()
	world.set_process(false)
	world.clear()
	for x in range(4, 16):
		for y in range(4, 14):
			world.set_cell(0, Vector2i(x, y), TileCatalog.SOURCE_ID, TileCatalog.GRASS_A)
	world.set_cell(1, Vector2i(10, 8), TileCatalog.SOURCE_ID, TileCatalog.TREE)
	var stand := Vector2i(10, 10)
	world.spawn_point = stand
	world._castle_front = stand
	var player = add_combat_actor(scene, world.to_global(world.map_to_local(stand)))
	await process_frame
	var interaction: Interaction = scene.get_node("World/Interaction")
	interaction.set_process(false)
	interaction.set_mode(Interaction.Mode.INTERACT)
	return {
		"scene": scene,
		"world": world,
		"player": player,
		"interaction": interaction,
		"inventory": scene.get_node("Inventory")
	}


static func _names(log: Array[AudioStream]) -> Array[String]:
	var names: Array[String] = []
	for stream in log:
		names.append(stream.resource_path.get_file().get_basename())
	return names


func _test_chop_tree_sounds() -> int:
	## Each impact plays a tree_chop clip (never the same one twice in a row)
	## with leaf_rustle, the last impact adds tree_crack, and the fall at
	## 560 ms plays tree_fall then wood_pickup as the wood is added. All on
	## the SFX bus, the fall on its own player.
	print("-- test_chop_tree_sounds")
	var fail := 0
	var s: Dictionary = await _chop_scene()
	var interaction: Interaction = s["interaction"]
	var inventory: Inventory = s["inventory"]
	var tree := Vector2i(10, 8)
	var run_to := func(t: float) -> void:
		interaction.step_chop(t - maxf(interaction.chop_time, 0.0))
	if not interaction.start_chop(tree):
		printerr("FAIL chop_tree_sounds: could not start chopping %s" % tree)
		fail += 1
	run_to.call(0.15)
	var got := _names(interaction.sfx_log)
	if got.size() != 2 or not got[0].begins_with("tree_chop_") or got[1] != "leaf_rustle_01":
		printerr("FAIL chop_tree_sounds: first hit sounds %s" % [got])
		fail += 1
	run_to.call(0.47)
	got = _names(interaction.sfx_log)
	if (
		got.size() != 5
		or not got[2].begins_with("tree_chop_")
		or got[2] == got[0]
		or got[3] != "leaf_rustle_01"
		or got[4] != "tree_crack_01"
	):
		printerr("FAIL chop_tree_sounds: last hit sounds %s" % [got])
		fail += 1
	run_to.call(0.55)
	if interaction.sfx_log.size() != 5 or inventory.count_of(Inventory.WOOD) != 0:
		printerr(
			(
				"FAIL chop_tree_sounds: sounds or wood before the fall: %s"
				% [_names(interaction.sfx_log)]
			)
		)
		fail += 1
	run_to.call(0.57)
	got = _names(interaction.sfx_log)
	if (
		got.size() != 7
		or got[5] != "tree_fall_01"
		or not got[6].begins_with("wood_pickup_")
		or (
			inventory.count_of(Inventory.WOOD)
			!= InteractableCatalog.by_id("tree").amount_of(Inventory.WOOD)
		)
	):
		printerr(
			(
				"FAIL chop_tree_sounds: at the fall sounds %s, wood %s"
				% [got, inventory.count_of(Inventory.WOOD)]
			)
		)
		fail += 1
	# Both clips stay on separate SFX players so the fall can layer over the hit.
	var channels := {}
	for node in interaction.get_children():
		if node is AudioStreamPlayer2D and node.stream != null:
			channels[node.stream.resource_path.get_file().get_basename()] = node.bus
	if (
		got.size() == 7
		and (channels.get("tree_fall_01") != &"SFX" or channels.get(got[2]) != &"SFX")
	):
		printerr("FAIL chop_tree_sounds: the fall replaced the hit or left the SFX bus")
		fail += 1
	interaction.step_chop(1.0)
	if interaction.sfx_log.size() != 7:
		printerr(
			"FAIL chop_tree_sounds: sounds after the chop ended: %s" % [_names(interaction.sfx_log)]
		)
		fail += 1
	s["player"].queue_free()
	s["scene"].queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_chop_tree_sounds")
	return fail


func _test_chop_cancel_on_death() -> int:
	## The hero dying mid-chop, even after the last impact and before the
	## fall, cancels it: the tree stays, no wood is added and no fall or
	## pickup sound plays. After the respawn a new chop works.
	## Time cost: about 0.5 s alone with --only=chop_cancel_on_death.
	print("-- test_chop_cancel_on_death")
	var fail := 0
	var s: Dictionary = await _chop_scene()
	var interaction: Interaction = s["interaction"]
	var inventory: Inventory = s["inventory"]
	var world = s["world"]
	var health: PlayerHealth = s["player"].health
	var tree := Vector2i(10, 8)
	var run_to := func(t: float) -> void:
		interaction.step_chop(t - maxf(interaction.chop_time, 0.0))
	if not interaction.start_chop(tree):
		printerr("FAIL chop_cancel_on_death: could not start chopping %s" % tree)
		fail += 1
	run_to.call(0.5)  # both hits landed, the fall is at 560 ms
	health.set_health_now(0)
	interaction.step_chop(1.0)
	var got := _names(interaction.sfx_log)
	if (
		interaction.chopping()
		or not world.has_tree(tree)
		or inventory.count_of(Inventory.WOOD) != 0
		or got.has("tree_fall_01")
		or got.size() != 5
	):
		printerr(
			(
				"FAIL chop_cancel_on_death: chopping %s, tree %s, wood %s, sounds %s"
				% [
					interaction.chopping(),
					world.has_tree(tree),
					inventory.count_of(Inventory.WOOD),
					got
				]
			)
		)
		fail += 1
	# Revive without resolve_player_spawn / generate_chunk (#359).
	health.set_health_now(health.max_health)
	s["player"].position = world.to_global(world.map_to_local(Vector2i(10, 10)))
	if health.is_dead() or not interaction.start_chop(tree):
		printerr(
			"FAIL chop_cancel_on_death: no new chop after the respawn (dead %s)" % health.is_dead()
		)
		fail += 1
	interaction.step_chop(0.6)
	if (
		world.has_tree(tree)
		or (
			inventory.count_of(Inventory.WOOD)
			!= InteractableCatalog.by_id("tree").amount_of(Inventory.WOOD)
		)
	):
		printerr("FAIL chop_cancel_on_death: the chop after the respawn did not fell the tree")
		fail += 1
	s["player"].queue_free()
	s["scene"].queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_chop_cancel_on_death")
	return fail
