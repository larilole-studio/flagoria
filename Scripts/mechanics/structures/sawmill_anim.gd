class_name SawmillAnim
extends AnimatedSprite2D
## The sawmill's idle pose and sawing loop use the same strip.

const SHEET := preload("res://art/structures/sawmill_sheet.png")
const CHOP := preload("res://art/audio/sfx/world/trees/tree_chop_02.wav")
const FRAME_SIZE := Vector2i(48, 48)
const FRAME_COUNT := 8
const FOOTPRINT_CENTER := Vector2(24, 24)

static var _frames: SpriteFrames

var _production: SawmillProduction
var _placement_id: int
var _sound: AudioStreamPlayer2D


static func attach(map: TileMap, id: int, top_left: Vector2i, turns: int) -> SawmillAnim:
	var mill := SawmillAnim.new()
	mill.name = "SawmillAnim_%d" % id
	mill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mill.centered = false
	mill.offset = -FOOTPRINT_CENTER
	mill.position = map.map_to_local(top_left + Vector2i.ONE)
	mill.rotation = FootprintOrientation.angle_rad(turns)
	mill.sprite_frames = _loop_frames()
	mill._production = map.sawmill_production
	mill._placement_id = id
	map.add_child(mill)
	return mill


static func idle_texture() -> Texture2D:
	return _loop_frames().get_frame_texture(&"default", 0)


static func _loop_frames() -> SpriteFrames:
	if _frames == null:
		_frames = SpriteFrames.new()
		_frames.set_animation_speed(&"default", 8.0)
		for i in FRAME_COUNT:
			var texture := AtlasTexture.new()
			texture.atlas = SHEET
			texture.region = Rect2i(Vector2i(i * FRAME_SIZE.x, 0), FRAME_SIZE)
			_frames.add_frame(&"default", texture)
	return _frames


func _ready() -> void:
	_sound = AudioStreamPlayer2D.new()
	_sound.name = "SawingSound"
	_sound.bus = &"SFX"
	_sound.stream = CHOP
	_sound.volume_db = -18.0
	_sound.max_distance = 180.0
	add_child(_sound)
	animation_looped.connect(_sound.play.bind(0.0))
	_refresh_playback()


func _process(_delta: float) -> void:
	_refresh_playback()


func _exit_tree() -> void:
	_sound.stop()


func _refresh_playback() -> void:
	if _production.is_producing(_placement_id):
		if not is_playing():
			play()
			_sound.play()
	elif is_playing():
		stop()
		_sound.stop()
