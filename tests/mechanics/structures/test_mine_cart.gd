extends "res://tests/helpers/test_helpers.gd"

const SITE := Vector2i(19, -59)


func _test_mine_cart_lifecycle() -> int:
	var scene := mount_main_scene()
	var map: TileMap = scene.get_node("World/worldMap")
	map.set_process(false)
	map.apply_map_params(_spawn_params(11, 0.003))
	var inventory: Inventory = scene.get_node("Inventory")
	inventory.add(Inventory.WOOD, 15)
	var ok := await _check_cart(map, inventory)
	scene.queue_free()
	await process_frame
	return 0 if ok else 1


func _check_cart(map: TileMap, inventory: Inventory) -> bool:
	if not ConstructionPlacer.new(map).place(BuildCosts.MINE, [SITE], inventory):
		printerr("FAIL mine cart: could not place the mine")
		return false
	var mine: Dictionary = map.structure_placement_at(SITE)
	var cart := map.get_node_or_null("MineCart_%d" % mine["id"]) as AnimatedSprite2D
	if cart == null or not cart.is_visible_in_tree():
		printerr("FAIL mine cart: placed mine has no visible cart sprite")
		return false
	if (
		mine["cells"].size() != 9
		or cart.position != map.map_to_local(SITE + Vector2i.UP)
		or cart.offset != Vector2(-24, -24)
		or cart.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST
		or not cart.is_playing()
		or not _check_sheet(cart.sprite_frames)
	):
		printerr("FAIL mine cart: footprint alignment, filtering, or playback differs")
		return false
	if ConstructionRemover.new(map).remove(SITE, 1, inventory).is_empty():
		printerr("FAIL mine cart: could not demolish the mine")
		return false
	await process_frame
	if is_instance_valid(cart):
		printerr("FAIL mine cart: sprite survived demolition")
		return false
	return true


func _check_sheet(frames: SpriteFrames) -> bool:
	var still := frames.get_frame_texture(&"default", 12) as AtlasTexture
	if (
		not frames.get_animation_loop(&"default")
		or frames.get_animation_speed(&"default") != 5.0
		or frames.get_frame_count(&"default") != 20
		or still == null
		or still.atlas.get_size() != Vector2(960, 64)
		or MineCart.parked_texture() != still
	):
		printerr("FAIL mine cart: playback or sheet contract differs")
		return false
	for frame in 20:
		var texture := frames.get_frame_texture(&"default", frame) as AtlasTexture
		if (
			texture == null
			or texture.atlas != still.atlas
			or texture.region != Rect2(frame * 48, 0, 48, 64)
			or frames.get_frame_duration(&"default", frame) != 1.0
		):
			printerr("FAIL mine cart: incorrect slice or duration at frame %d" % frame)
			return false
	return true
