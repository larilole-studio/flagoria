extends "res://tests/helpers/test_helpers.gd"

const SITE := Vector2i(19, -59)


func _test_sawmill_animation_lifecycle() -> int:
	var scene := mount_main_scene()
	var map: TileMap = scene.get_node("World/worldMap")
	map.set_process(false)
	map.apply_map_params(_spawn_params(11, 0.003))
	map.generate_chunk(map.map_to_local(SITE))
	map.set_cell(1, SITE + Vector2i.DOWN, TileCatalog.SOURCE_ID, TileCatalog.TREE)
	var inventory: Inventory = scene.get_node("Inventory")
	inventory.add(Inventory.STONE, 15)
	var ok := await _check_sawmill(map, inventory)
	scene.queue_free()
	await process_frame
	if not ok:
		printerr("FAIL sawmill animation: placement, footprint, playback, or demolition")
	return 0 if ok else 1


func _check_sawmill(map: TileMap, inventory: Inventory) -> bool:
	if not ConstructionPlacer.new(map).place(BuildCosts.SAWMILL, [SITE], inventory):
		return false
	var placement: Dictionary = map.structure_placement_at(SITE)
	var mill := map.get_node_or_null("SawmillAnim_%d" % placement["id"]) as AnimatedSprite2D
	if mill == null:
		return false
	var sound := mill.get_node("SawingSound") as AudioStreamPlayer2D
	if (
		not mill.is_visible_in_tree()
		or not mill.is_playing()
		or not sound.playing
		or mill.position != map.map_to_local(SITE)
		or mill.offset != Vector2(-24, -24)
		or mill.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST
		or map.get_cell_alternative_tile(1, SITE + Vector2i.LEFT) != 1
		or ConstructionRemover.new(map).remove(SITE, 1, inventory).is_empty()
	):
		return false
	if mill.is_inside_tree() or sound.playing:
		return false
	await process_frame
	return not is_instance_valid(mill)
