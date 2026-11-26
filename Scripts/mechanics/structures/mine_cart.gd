class_name MineCart
extends AnimatedSprite2D
## The mine's producing loop and parked still share the same strip.

const SHEET := preload("res://art/structures/mine_cart_sheet.png")
const FRAME_SIZE := Vector2i(48, 64)
const FRAME_COUNT := 20
const IDLE_FRAME := 12
# The track extends below the 48×48 footprint. Rotate around the footprint center.
const FOOTPRINT_CENTER := Vector2(24, 24)

static var _frames: SpriteFrames

var _production: MineProduction
var _placement_id: int


static func attach(
	map: TileMap, production: MineProduction, id: int, top_left: Vector2i, turns: int
) -> MineCart:
	var cart := MineCart.new()
	cart.name = "MineCart_%d" % id
	cart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cart.centered = false
	cart.offset = -FOOTPRINT_CENTER
	cart.position = map.map_to_local(top_left + Vector2i.ONE)
	cart.rotation = FootprintOrientation.angle_rad(turns)
	cart.sprite_frames = _loop_frames()
	cart._production = production
	cart._placement_id = id
	cart._refresh_playback()
	map.add_child(cart)
	return cart


static func parked_texture() -> Texture2D:
	return _loop_frames().get_frame_texture(&"default", IDLE_FRAME)


static func _loop_frames() -> SpriteFrames:
	if _frames == null:
		_frames = SpriteFrames.new()
		_frames.set_animation_speed(&"default", Tuning.value(&"visuals.mine_cart_fps"))
		for i in FRAME_COUNT:
			var texture := AtlasTexture.new()
			texture.atlas = SHEET
			texture.region = Rect2i(Vector2i(i * FRAME_SIZE.x, 0), FRAME_SIZE)
			_frames.add_frame(&"default", texture)
	return _frames


func _ready() -> void:
	Tuning.events.changed.connect(_on_tuning_changed)
	_on_tuning_changed(&"visuals.mine_cart_fps")


func _on_tuning_changed(key: StringName) -> void:
	if key != &"visuals.mine_cart_fps":
		return
	var fps := Tuning.value(key)
	if sprite_frames.get_animation_speed(&"default") != fps:
		sprite_frames.set_animation_speed(&"default", fps)


func _process(_delta: float) -> void:
	_refresh_playback()


func _refresh_playback() -> void:
	if _production.is_producing(_placement_id):
		if not is_playing():
			set_frame_and_progress(0, 0.0)
			play()
	elif is_playing() or frame != IDLE_FRAME:
		stop()
		frame = IDLE_FRAME
