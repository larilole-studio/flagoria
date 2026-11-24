class_name ResourceHud
extends HBoxContainer
## The local player's wood count and log sticker.

var label: Label
var _inventory: Inventory


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = RoundHudStyle.FILTER
	add_theme_constant_override("separation", 2)
	var icon := TextureRect.new()
	icon.texture = RoundHudStyle.texture("log")
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	label = Label.new()
	RoundHudStyle.apply_label(label, 10)
	label.text = "0"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _process(_delta: float) -> void:
	if get_parent() is StatusPlateHud:
		return
	follow_hearts()


func follow_hearts() -> void:
	var plate := get_node_or_null("../StatusPlate") as StatusPlateHud
	if plate != null and plate.is_visible_in_tree():
		return
	var hearts := get_node_or_null("../HeartsHud") as Control
	if hearts == null:
		return
	reset_size()
	scale = hearts.scale
	position = Vector2(
		roundf((get_viewport_rect().size.x - size.x * scale.x) / 2.0), hearts.position.y
	)


func bind(inventory: Inventory) -> void:
	## Follow the wood count in `inventory` and show the counter.
	_inventory = inventory
	if not inventory.changed.is_connected(_on_changed):
		inventory.changed.connect(_on_changed)
	label.text = str(inventory.count_of(Inventory.WOOD))
	follow_hearts()
	show()


func _on_changed(resource: StringName, count: int) -> void:
	if resource == Inventory.WOOD:
		label.text = str(count)
		var plate := get_parent() as StatusPlateHud
		if plate != null:
			plate.reflow()
