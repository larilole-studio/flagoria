extends "res://tests/helpers/test_helpers.gd"

const WorldChunks := preload("res://Scripts/world/world_chunks.gd")
const SITE := Vector2i(19, -59)


func _test_mine_production_save() -> int:
	var scene := mount_main_scene()
	var world: TileMap = scene.get_node("World/worldMap")
	world.set_process(false)
	var params := _spawn_params(11, 0.003)
	scene.world_params = params
	world.apply_map_params(params)
	var inventory: Inventory = scene.get_node("Inventory")
	inventory.add(Inventory.WOOD, 15)
	WorldChunks.refresh(world, 45.0)
	var ok: bool = (
		ConstructionPlacer.new(world).place(BuildCosts.MINE, [SITE], inventory)
		and world.destroy_decor(SITE + Vector2i.DOWN)
		and _check_cycles(scene, world, inventory)
	)
	scene.queue_free()
	await process_frame
	if not ok:
		printerr("FAIL mine production: timing, save, legacy load or demolition")
	return 0 if ok else 1


func _check_cycles(scene: Node, world: TileMap, inventory: Inventory) -> bool:
	WorldChunks.refresh(world, 59.75)
	if inventory.count_of(Inventory.STONE) != 0:
		return false
	WorldChunks.refresh(world, 0.25)
	if inventory.count_of(Inventory.STONE) != 1:
		return false
	WorldChunks.refresh(world, 60.0)
	return inventory.count_of(Inventory.STONE) == 2 and _check_reload(scene, world, inventory)


func _check_reload(scene: Node, world: TileMap, inventory: Inventory) -> bool:
	WorldChunks.refresh(world, 15.25)
	var saved: Dictionary = scene.get_node("CanvasLayer1/InGameMenu").save_world()
	if saved["error"] != "":
		return false
	var result := MapSave.load_world(saved["path"])
	DirAccess.remove_absolute(saved["path"])
	var loaded: WorldSave = result["world"]
	if loaded == null:
		return false
	world.apply_map_params(loaded.params)
	if StructureSaves.restore(loaded.structures, world) != 1:
		return false
	WorldChunks.refresh(world, 44.5)
	if inventory.count_of(Inventory.STONE) != 2:
		return false
	WorldChunks.refresh(world, 0.25)
	if (
		inventory.count_of(Inventory.STONE) != 3
		or ConstructionRemover.new(world).remove(SITE, 1, inventory).is_empty()
	):
		return false
	WorldChunks.refresh(world, 120.0)
	return inventory.count_of(Inventory.STONE) == 3 and _legacy_cycle(world, inventory)


func _legacy_cycle(world: TileMap, inventory: Inventory) -> bool:
	var legacy := {
		WorldSave.chunk_key(SITE):
		{
			WorldSave.cell_key(SITE):
			{
				"structure": "mine",
				"owner": 1,
			}
		}
	}
	if StructureSaves.restore(legacy, world) != 1:
		return false
	WorldChunks.refresh(world, 59.75)
	if inventory.count_of(Inventory.STONE) != 3:
		return false
	WorldChunks.refresh(world, 0.25)
	return inventory.count_of(Inventory.STONE) == 4
