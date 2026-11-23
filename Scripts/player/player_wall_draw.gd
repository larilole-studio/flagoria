extends RefCounted
## Sets the player's draw order where the sprite overlaps walls.

## Walk frame is 16 px, centred on Sprite2D at (0, -8), so the body runs from
## the feet (this node's origin) up 16 px. Wall caps sit at z 2 through 5.
const BODY_RECT := Rect2(-8, -16, 16, 16)
const WALL_CAP_LAYER := 6
## The hero draws over a wall until about two thirds of the body is on it.
const WALL_COVER_FRACTION := 2.0 / 3.0

var _wall_atlases: Dictionary = {}


func apply(player: Node2D) -> void:
	## Walls are z 1 and their caps are z 2 through 5, so a body that only
	## overlaps the face of a wall would lose its head. Stay above the caps
	## until most of the body is on a wall, then drop behind the wall layer.
	var map := player.get_node_or_null("/root/Flagoria/World/worldMap") as TileMap
	if map == null:
		player.z_index = 0
		return
	var cover := _wall_cover(map, player.global_position)
	# No wall contact keeps the old order (trees stay above the hero). A
	# graze lifts the hero over the wall. Most of the body on the wall drops
	# the hero behind it again.
	if cover <= 0.0 or cover >= WALL_COVER_FRACTION:
		player.z_index = 0
	else:
		player.z_index = map.get_layer_z_index(WALL_CAP_LAYER) + 1


func _wall_cover(map: TileMap, global_position: Vector2) -> float:
	## Share of the body rect that lies on a wall tile. 0 when clear.
	var body := Rect2(global_position + BODY_RECT.position, BODY_RECT.size)
	var area := body.size.x * body.size.y
	if area <= 0.0:
		return 0.0
	var covered := 0.0
	var top_left := map.local_to_map(map.to_local(body.position))
	var bottom_right := map.local_to_map(map.to_local(body.end - Vector2(0.01, 0.01)))
	for y in range(mini(top_left.y, bottom_right.y), maxi(top_left.y, bottom_right.y) + 1):
		for x in range(mini(top_left.x, bottom_right.x), maxi(top_left.x, bottom_right.x) + 1):
			var cell := Vector2i(x, y)
			if not _is_wall(map, cell):
				continue
			var center := map.to_global(map.map_to_local(cell))
			var tile := Vector2(map.tile_set.tile_size)
			var wall := Rect2(center - tile * 0.5, tile)
			var hit := body.intersection(wall)
			if hit.size.x > 0.0 and hit.size.y > 0.0:
				covered += hit.size.x * hit.size.y
	return covered / area


func _is_wall(map: TileMap, cell: Vector2i) -> bool:
	if map.get_cell_source_id(1, cell) == -1:
		return false
	_ensure_wall_atlases()
	return _wall_atlases.has(map.get_cell_atlas_coords(1, cell))


func _ensure_wall_atlases() -> void:
	if not _wall_atlases.is_empty():
		return
	for tile_name: String in TileCatalog.TILES:
		if (
			not tile_name.begins_with("WALL_")
			and not tile_name.begins_with("PALISADE_")
			and not tile_name.begins_with("TOWER_STONE_")
		):
			continue
		_wall_atlases[TileCatalog.TILES[tile_name]["atlas"]] = true
