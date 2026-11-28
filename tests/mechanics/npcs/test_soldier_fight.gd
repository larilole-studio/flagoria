extends "res://tests/helpers/test_helpers.gd"
## Soldiers fight mobs in range; owner hits do not hurt the soldier (#554).

const SEED := 7


func _paint_pad(world, cells: Array) -> void:
	world.set_process(false)
	world.clear()
	var seen := {}
	for c in cells:
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			seen[n] = true
			world.set_cell(0, n, TileCatalog.SOURCE_ID, TileCatalog.GRASS_A)


func _test_soldier_fight() -> int:
	print("-- test_soldier_fight")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	scene.world_params = _spawn_params(SEED, 0.0)
	var world = scene.get_node("World/worldMap")
	world.apply_map_params(scene.world_params)
	world.generate_chunk(Vector2(0, 0))
	var peer := 1
	var owner: Node2D = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	owner.name = str(peer)
	scene.get_node("World").add_child(owner)
	owner.set_physics_process(false)
	var soldier: Soldier = load(Soldier.SOLDIER_SCENE).instantiate()
	soldier.name = "soldier_test"
	scene.get_node("World/Soldiers").add_child(soldier)
	var base := Vector2(256, 256)
	(
		soldier
		. setup_soldier(
			{
				"type": MobCatalog.SOLDIER,
				"pos": base,
				"seed": SEED,
				"owner": peer,
				"order": "hold",
			}
		)
	)
	soldier.set_physics_process(false)
	var slime: Mob = load("res://Mobs/mob.tscn").instantiate()
	slime.setup(MobCatalog.SLIME, base + Vector2(40, 0), SEED)
	slime.set_physics_process(false)
	scene.get_node("World/Mobs").add_child(slime)
	owner.position = base + Vector2(10, 0)
	slime.position = base + Vector2(6, 0)
	var health: PlayerHealth = owner.get_node("Health")
	var owner_start := health.health
	var mob_start := slime.hp
	var sold_start := soldier.hp
	var fail := 0
	for _i in 80:
		soldier.think(0.1)
	if slime.hp >= mob_start:
		printerr("FAIL soldier_fight mob hp %d" % slime.hp)
		fail += 1
	if soldier.hp >= sold_start:
		printerr("FAIL soldier_fight soldier hp %d" % soldier.hp)
		fail += 1
	if health.health != owner_start:
		printerr("FAIL soldier_fight owner hurt %d" % health.health)
		fail += 1
	var probe: Soldier = load(Soldier.SOLDIER_SCENE).instantiate()
	(
		probe
		. setup_soldier(
			{
				"type": MobCatalog.SOLDIER,
				"pos": Vector2.ZERO,
				"seed": 1,
				"owner": peer,
				"hp": MobCatalog.stat(MobCatalog.SOLDIER, "hp"),
			}
		)
	)
	if probe.take_hit(peer):
		printerr("FAIL soldier_fight owner take_hit landed")
		fail += 1
	var hp_track := probe.hp
	for _k in 4:
		probe.state = Soldier.State.IDLE
		probe._timer = 0.0
		if not probe.take_hit(2):
			printerr("FAIL soldier_fight peer hit round %d" % _k)
			fail += 1
			break
		hp_track -= 1
	if probe.state != Soldier.State.DYING or probe.hp != hp_track:
		printerr("FAIL soldier_fight dying %s hp %d" % [probe.state, probe.hp])
		fail += 1
	scene.spawn_mobs()
	scene.get_node("World/Mobs").clear_mobs()
	if not scene.get_node("World/Soldiers").get_node_or_null("soldier_test"):
		printerr("FAIL soldier_fight clear_mobs removed soldier")
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_soldier_fight")
	return fail
