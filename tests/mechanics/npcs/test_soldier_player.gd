extends "res://tests/helpers/test_helpers.gd"
## Soldiers in Follow or Hold strike enemy players; the owner is never a target (#555).

const SEED := 7


func _make_scene(soldier: Soldier, owner: Node2D, other: Node2D, slime: Mob) -> Dictionary:
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	scene.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var owner_peer: int = scene.multiplayer.get_unique_id()
	scene.world_params = _spawn_params(SEED, 0.0)
	var world = scene.get_node("World/worldMap")
	world.apply_map_params(scene.world_params)
	world.generate_chunk(Vector2(0, 0))
	owner.name = str(owner_peer)
	other.name = "2"
	scene.get_node("World").add_child(owner)
	scene.get_node("World").add_child(other)
	owner.set_physics_process(false)
	other.set_physics_process(false)
	(
		soldier
		. setup_soldier(
			{
				"type": MobCatalog.SOLDIER,
				"pos": Vector2(256, 256),
				"seed": SEED,
				"owner": owner_peer,
				"order": "hold",
			}
		)
	)
	soldier.name = "soldier_test"
	scene.get_node("World/Soldiers").add_child(soldier)
	soldier.set_physics_process(false)
	if slime != null:
		slime.set_physics_process(false)
		scene.get_node("World/Mobs").add_child(slime)
	await process_frame
	return {"scene": scene, "owner_peer": owner_peer}


func _test_soldier_player() -> int:
	print("-- test_soldier_player")
	var fail := 0
	var base := Vector2(256, 256)
	# Owner at 10 px, other peer in contact range: other takes damage, owner does not.
	var soldier: Soldier = load(Soldier.SOLDIER_SCENE).instantiate()
	var owner: Node2D = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	var other: Node2D = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	var built := await _make_scene(soldier, owner, other, null)
	var scene: Node = built["scene"]
	owner.position = base + Vector2(10, 0)
	other.position = base + Vector2(6, 0)
	var owner_health: PlayerHealth = owner.get_node("Health")
	var other_health: PlayerHealth = other.get_node("Health")
	var owner_start := owner_health.health
	var other_start := other_health.health
	for _i in 80:
		other.position = base + Vector2(6, 0)
		owner.position = base + Vector2(10, 0)
		soldier.think(0.1)
		owner_health.advance(0.1)
		other_health.advance(0.1)
	if other_health.health >= other_start:
		printerr("FAIL soldier_player other hp %d" % other_health.health)
		fail += 1
	if owner_health.health != owner_start:
		printerr("FAIL soldier_player owner hurt %d" % owner_health.health)
		fail += 1
	scene.queue_free()
	await process_frame
	# Mob at 20 px, other peer at 40 px: mob is struck first.
	soldier = load(Soldier.SOLDIER_SCENE).instantiate()
	owner = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	other = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	var slime: Mob = load("res://Mobs/mob.tscn").instantiate()
	slime.setup(MobCatalog.SLIME, base + Vector2(8, 0), SEED)
	built = await _make_scene(soldier, owner, other, slime)
	scene = built["scene"]
	owner.position = base + Vector2(-30, 0)
	other.position = base + Vector2(40, 0)
	slime.position = base + Vector2(8, 0)
	var mob_start := slime.hp
	var other2 := other.get_node("Health") as PlayerHealth
	var other2_start := other2.health
	for _j in 80:
		slime.position = base + Vector2(8, 0)
		soldier.think(0.1)
		other2.advance(0.1)
	if slime.hp >= mob_start:
		printerr("FAIL soldier_player mob hp %d" % slime.hp)
		fail += 1
	if other2.health < other2_start:
		printerr("FAIL soldier_player other hurt before mob at %d" % other2.health)
		fail += 1
	scene.queue_free()
	await process_frame
	# Dead peer: no further take_damage.
	soldier = load(Soldier.SOLDIER_SCENE).instantiate()
	owner = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	other = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	built = await _make_scene(soldier, owner, other, null)
	scene = built["scene"]
	owner.position = base + Vector2(-40, 0)
	other.position = base + Vector2(6, 0)
	var dead_health: PlayerHealth = other.get_node("Health")
	dead_health.set_health_now(0)
	var calls := 0
	dead_health.damaged.connect(func(_amt: int) -> void: calls += 1)
	for _k in 40:
		other.position = base + Vector2(6, 0)
		soldier.think(0.1)
		dead_health.advance(0.1)
	if calls != 0:
		printerr("FAIL soldier_player dead peer damaged %d times" % calls)
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_soldier_player")
	return fail
