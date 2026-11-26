class_name ResourceHud
extends HBoxContainer
## The local player's resource stickers and balances.

var label: Label
var stone_label: Label
var _inventory: Inventory


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = RoundHudStyle.FILTER
	add_theme_constant_override("separation", 6)
	label = _add_counter("log")
	stone_label = _add_counter("stone")


func _add_counter(sticker: String) -> Label:
	var counter := HBoxContainer.new()
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_theme_constant_override("separation", 2)
	add_child(counter)
	var icon := TextureRect.new()
	icon.texture = RoundHudStyle.texture(sticker)
	if sticker == "stone":
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(icon)
	var count := Label.new()
	RoundHudStyle.apply_label(count, 10)
	count.text = "0"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(count)
	return count


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
	## Follow both resource counts in `inventory`.
	if _inventory != inventory:
		if is_instance_valid(_inventory):
			_inventory.changed.disconnect(_on_changed)
		_inventory = inventory
		inventory.changed.connect(_on_changed)
	label.text = str(inventory.count_of(Inventory.WOOD))
	stone_label.text = str(inventory.count_of(Inventory.STONE))
	follow_hearts()
	show()


func _on_changed(resource: StringName, count: int) -> void:
	match resource:
		Inventory.WOOD:
			label.text = str(count)
		Inventory.STONE:
			stone_label.text = str(count)
		_:
			return
	var plate := get_parent() as StatusPlateHud
	if plate != null:
		plate.reflow()
