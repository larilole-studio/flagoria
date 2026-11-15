class_name StatusPlateHud
extends PanelContainer
## Nine-patch status row: hearts, points, wood (#509, Direction C).

const PLATE_POS := Vector2(12, 12)
const PLATE_W := 100.0
const PLATE_H := 24.0
const HEART_SLOT := Vector2(6, 7)
const POINTS_X := 39.0
const WOOD_GAP := 6.0
const COUNT_GAP := 2.0
const FONT_SIZE := 8
const FONT := preload("res://art/Sprites/NinjaAdventure/HUD/Font/NormalFont.ttf")

var _hearts: Control
var _score: Label
var _wood: ResourceHud


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("panel", RoundHudStyle.status_plate_style())
	custom_minimum_size = Vector2(PLATE_W, PLATE_H)
	size = custom_minimum_size
	position = PLATE_POS
	z_index = 1
	get_viewport().size_changed.connect(_fit_pixel_scale)
	_fit_pixel_scale()


func bind_nodes(hearts: Control, score: Label, wood: ResourceHud) -> void:
	_hearts = hearts
	_score = score
	_wood = wood
	_layout_children()


func _process(_delta: float) -> void:
	if _hearts == null:
		return
	_layout_children()


func _layout_children() -> void:
	if _hearts == null or _score == null or _wood == null:
		return
	var k := scale.x
	_hearts.scale = Vector2(k, k)
	_hearts.position = position + HEART_SLOT * k
	var pts_y := (PLATE_H - FONT_SIZE) * 0.5
	_score.add_theme_font_size_override("font_size", FONT_SIZE)
	if _score.get_theme_font("font") != FONT:
		_score.add_theme_font_override("font", FONT)
	_score.scale = Vector2(k, k)
	_score.position = position + Vector2(POINTS_X, pts_y) * k
	_score.add_theme_color_override("font_color", Color(0.91, 0.89, 0.89))
	_wood.scale = Vector2(k, k)
	_wood.position = position + Vector2(
			POINTS_X + _text_w(_score) + WOOD_GAP,
			pts_y,
	) * k
	_wood.follow_plate_slot(_score)


func _text_w(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x


func _fit_pixel_scale() -> void:
	var stretch := get_viewport().get_final_transform().get_scale().x
	if stretch <= 0.0:
		return
	var k := maxf(roundf(stretch), 1.0) / stretch
	scale = Vector2(k, k)
	position = PLATE_POS * k