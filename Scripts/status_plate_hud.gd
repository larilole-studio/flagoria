class_name StatusPlateHud
extends PanelContainer
## Nine-patch status row: hearts, points, wood (#509, Direction C).

const PLATE_POS := Vector2(12, 12)
const PLATE_W := 100.0
const PLATE_H := 24.0
const HEART_SLOT := Vector2(6, 7)
const POINTS_X := 39.0
const WOOD_GAP := 6.0
const FONT_SIZE := 8
const FONT := preload("res://art/Sprites/NinjaAdventure/HUD/Font/NormalFont.ttf")
const FONT_COLOR := Color(0.91, 0.89, 0.89)

var _hearts: Control
var _score: Label
var _wood: ResourceHud
var _mounted := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("panel", RoundHudStyle.status_plate_style())
	custom_minimum_size = Vector2(PLATE_W, PLATE_H)
	size = custom_minimum_size
	position = PLATE_POS
	z_index = 1
	clip_contents = true
	get_viewport().size_changed.connect(_fit_pixel_scale)
	_fit_pixel_scale()


func bind_nodes(hearts: Control, score: Label, wood: ResourceHud) -> void:
	_hearts = hearts
	_score = score
	_wood = wood
	if not _mounted:
		_mount(hearts)
		_mount(score)
		_mount(wood)
		_mounted = true
	reflow()


func reflow() -> void:
	_layout_children()


func _mount(node: Control) -> void:
	if node.get_parent() == self:
		return
	node.get_parent().remove_child(node)
	add_child(node)
	node.z_index = 1
	node.show()


func _layout_children() -> void:
	if _hearts == null or _score == null or _wood == null:
		return
	_hearts.position = HEART_SLOT
	_hearts.scale = Vector2.ONE
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pts_y := (PLATE_H - FONT_SIZE) * 0.5
	_score.position = Vector2(POINTS_X, pts_y)
	_score.scale = Vector2.ONE
	_score.add_theme_font_size_override("font_size", FONT_SIZE)
	_score.add_theme_font_override("font", FONT)
	_score.add_theme_color_override("font_color", FONT_COLOR)
	_score.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wood.reset_size()
	var wood_x := POINTS_X + _text_w(_score) + WOOD_GAP
	_wood.position = Vector2(wood_x, pts_y)
	_wood.scale = Vector2.ONE
	_wood.label.add_theme_font_size_override("font_size", FONT_SIZE)
	_wood.label.add_theme_font_override("font", FONT)
	_wood.label.add_theme_color_override("font_color", FONT_COLOR)
	_wood.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	reflow()