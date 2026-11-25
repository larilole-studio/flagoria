class_name StatusPlateHud
extends Panel
## Floating top-left row for health, points and resources.

const MARGIN := 12.0
const GAP := 6.0
const ICON_GAP := 2.0

var _hearts: Control
var _score: Label
var _wood: ResourceHud
var _star: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = RoundHudStyle.FILTER
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	z_index = 1
	_star = TextureRect.new()
	_star.name = "Star"
	_star.texture = RoundHudStyle.texture("star")
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_star)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(place):
		vp.size_changed.connect(place)
	place()


func place() -> void:
	position = Vector2(MARGIN, MARGIN) + safe_inset(self)


static func safe_inset(node: CanvasItem) -> Vector2:
	## Viewport-space top-left inset of the display safe area.
	var vp := node.get_viewport() if node != null else null
	var view := vp.get_visible_rect().size if vp != null else Vector2.ZERO
	return safe_inset_from(
		Rect2(DisplayServer.get_display_safe_area()),
		Vector2(DisplayServer.window_get_position()),
		Vector2(DisplayServer.window_get_size()),
		view
	)


static func safe_inset_from(
	safe: Rect2, win_pos: Vector2, win_size: Vector2, view_size: Vector2
) -> Vector2:
	## Map a screen-space safe area onto the viewport.
	if win_size.x <= 0.0 or win_size.y <= 0.0 or view_size.x <= 0.0 or view_size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		maxf(safe.position.x - win_pos.x, 0.0) * view_size.x / win_size.x,
		maxf(safe.position.y - win_pos.y, 0.0) * view_size.y / win_size.y
	)


func bind_nodes(hearts: Control, score: Label, wood: ResourceHud) -> void:
	_hearts = hearts
	_score = score
	_wood = wood
	for node in [_hearts, _score, _wood]:
		if node.get_parent() != self:
			node.reparent(self, false)
		node.scale = Vector2.ONE
		node.show()
	if not _hearts.resized.is_connected(reflow):
		_hearts.resized.connect(reflow)
	reflow()


func reflow() -> void:
	if _hearts == null:
		return
	_score.reset_size()
	_wood.reset_size()
	var row_h := _hearts.size.y
	row_h = maxf(row_h, _score.size.y)
	row_h = maxf(row_h, _wood.size.y)
	row_h = maxf(row_h, _star.size.y)
	_center(_hearts, 0, row_h)
	_center(_star, _hearts.size.x + GAP, row_h)
	_center(_score, _star.position.x + _star.size.x + ICON_GAP, row_h)
	_center(_wood, _score.position.x + _score.size.x + GAP, row_h)
	size = Vector2(_wood.position.x + _wood.size.x, row_h)
	place()


func _center(node: Control, x: float, row_h: float) -> void:
	node.position = Vector2(x, (row_h - node.size.y) * 0.5)
