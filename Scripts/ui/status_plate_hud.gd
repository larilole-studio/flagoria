class_name StatusPlateHud
extends Panel
## Floating top-left row for health, points and resources.

const ROW_POS := Vector2(12, 12)
const ROW_HEIGHT := 24.0
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
	position = ROW_POS
	z_index = 1
	_star = TextureRect.new()
	_star.texture = RoundHudStyle.texture("star")
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_star)


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
	_center(_hearts, 0)
	_center(_star, _hearts.size.x + GAP)
	_center(_score, _star.position.x + _star.size.x + ICON_GAP)
	_center(_wood, _score.position.x + _score.size.x + GAP)
	size = Vector2(_wood.position.x + _wood.size.x, ROW_HEIGHT)


func _center(node: Control, x: float) -> void:
	node.position = Vector2(x, (ROW_HEIGHT - node.size.y) * 0.5)
