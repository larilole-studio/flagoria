class_name CloudMotion
extends Node2D
## Local sprite motion for the cloud stamps painted by SkyIslands.

# A 686 world-pixel screen at zoom 0.7 takes about 23 min (far) or 11 min (near).
const FAR_SPEED := 0.5
const NEAR_SPEED := 1.0
const FADE_SECONDS := 12.0
const NEAR_LAYER_FRACTION := 0.25
const TRAVEL_PIXELS := 704.0
const TILE_SIZE := 16

class Stamp:
	var sprite: Sprite2D
	var origin: Vector2
	var size: Vector2
	var phase: float
	var near: bool

var _map  # TileMap script, with the world's sea and bridge queries.
var _layer: int
var _atlas: TileSetAtlasSource
var _stamps: Dictionary[Vector2i, Stamp] = {}
var _time := 0.0


static func attach(map, layer: int) -> CloudMotion:
	var motion := CloudMotion.new()
	motion.name = "CloudMotion"
	motion._map = map
	motion._layer = layer
	motion._atlas = map.tile_set.get_source(TileCatalog.SOURCE_ID)
	motion.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.add_child(motion)
	map.set_layer_modulate(layer, Color(1, 1, 1, 0))
	return motion


func refresh(window: Rect2i) -> void:
	var previous := _stamps
	_stamps = {}
	# Old chunks stay painted. Retain nearby stamps outside the current chunk
	# too, including the overhang of the landscape camera at gameplay zoom.
	var nearby := window.grow(16 + ceili(TRAVEL_PIXELS / (2.0 * TILE_SIZE))) if window.has_area() else window
	for y in range(nearby.position.y, nearby.end.y):
		for x in range(nearby.position.x, nearby.end.x):
			var cell := Vector2i(x, y)
			var atlas_cell: Vector2i = _map.get_cell_atlas_coords(_layer, cell)
			var size := _stamp_size(cell, atlas_cell)
			if size == Vector2i.ZERO:
				continue
			var stamp: Stamp = previous.get(cell)
			if stamp == null or stamp.size != Vector2(size * TILE_SIZE):
				stamp = _make_stamp(cell, atlas_cell, size)
			else:
				previous.erase(cell)
			_stamps[cell] = stamp
	for stamp: Stamp in previous.values():
		stamp.sprite.free()
	show_at_time(_time)


func _stamp_size(cell: Vector2i, atlas_cell: Vector2i) -> Vector2i:
	var size: Vector2i
	match atlas_cell:
		TileCatalog.CLOUD_S:
			return Vector2i.ONE
		TileCatalog.CLOUD_M_0:
			size = Vector2i(2, 1)
		TileCatalog.CLOUD_L_0:
			size = Vector2i(3, 2)
		_:
			return Vector2i.ZERO
	# A later paint window can clip the remains of an older stamp.
	for y in size.y:
		for x in size.x:
			var offset := Vector2i(x, y)
			if _map.get_cell_atlas_coords(_layer, cell + offset) != atlas_cell + offset:
				return Vector2i.ZERO
	return size


func _make_stamp(cell: Vector2i, atlas_cell: Vector2i, size: Vector2i) -> Stamp:
	var stamp := Stamp.new()
	stamp.size = Vector2(size * TILE_SIZE)
	stamp.origin = (_map.map_to_local(cell) - Vector2.ONE * (TILE_SIZE / 2.0)).round()
	var key := absi(hash(cell))
	stamp.phase = float(key % 4093) / 4093.0
	stamp.near = float(key % 1024) / 1024.0 < NEAR_LAYER_FRACTION
	stamp.sprite = Sprite2D.new()
	stamp.sprite.texture = _atlas.texture
	stamp.sprite.region_enabled = true
	stamp.sprite.region_filter_clip_enabled = true
	stamp.sprite.region_rect = Rect2(_atlas.get_tile_texture_region(atlas_cell).position, stamp.size)
	stamp.sprite.centered = false
	stamp.sprite.z_index = -1 if stamp.near else -2
	add_child(stamp.sprite)
	return stamp


func _process(delta: float) -> void:
	show_at_time(_time + delta)


func show_at_time(seconds: float) -> void:
	## Also used for deterministic sampling by the evidence capture.
	_time = seconds
	var viewport := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var view := get_global_transform_with_canvas().affine_inverse() * viewport
	for stamp: Stamp in _stamps.values():
		var speed := NEAR_SPEED if stamp.near else FAR_SPEED
		var age := fposmod(_time + stamp.phase * TRAVEL_PIXELS / speed, TRAVEL_PIXELS / speed)
		var distance := age * speed
		stamp.sprite.position = (stamp.origin + Vector2(distance - TRAVEL_PIXELS / 2.0, 0)).round()
		var bounds := Rect2(stamp.sprite.position, stamp.size)
		if not view.grow(16.0).intersects(bounds):
			stamp.sprite.hide()
			continue
		# Both sides of the wrap reach zero alpha over the same duration.
		var fade := smoothstep(0.0, FADE_SECONDS, age)
		fade *= smoothstep(0.0, FADE_SECONDS, (TRAVEL_PIXELS - distance) / speed)
		stamp.sprite.modulate.a = fade * (0.88 if stamp.near else 0.66)
		stamp.sprite.visible = fade > 0.0 and _over_sea(bounds.position, bounds.size)


func _over_sea(top_left: Vector2, size: Vector2) -> bool:
	var first: Vector2i = _map.local_to_map(top_left)
	var last: Vector2i = _map.local_to_map(top_left + size - Vector2.ONE)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if not _map.is_open_sea(Vector2i(x, y)):
				return false
	return true


func visible_cloud_count() -> int:
	var view := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var count := 0
	for cell in _stamps:
		var stamp := _stamps[cell]
		if stamp.sprite.visible and stamp.sprite.modulate.a >= 0.2:
			var bounds := stamp.sprite.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, stamp.size)
			if view.encloses(bounds):
				count += 1
	return count
