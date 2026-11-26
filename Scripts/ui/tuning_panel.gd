class_name TuningPanel
extends PanelContainer

signal close_requested

const TARGET_SIZE := Vector2(32, 28)
const VALUE_SIZE := Vector2(48, 0)

var tuning_sync: TuningSync

var _categories: Dictionary
var _tabs := ButtonGroup.new()
var _values: Dictionary[StringName, Label] = {}
var _resets: Dictionary[StringName, Button] = {}
var _defaults: Dictionary[StringName, float] = {}

@onready var _category_buttons: VBoxContainer = %Categories
@onready var _scroll: ScrollContainer = %Scroll
@onready var _rows: VBoxContainer = %Rows
@onready var _close_button: Button = %Close
@onready var _header: HBoxContainer = %Header
@onready var _confirm_reset: HBoxContainer = %ConfirmReset
@onready var _reset_all: Button = %ResetAll


func _ready() -> void:
	_categories = Tuning.entries_by_category()
	for category: String in _categories:
		var button := Button.new()
		button.name = category.replace(" ", "")
		button.text = category
		button.custom_minimum_size = TARGET_SIZE
		button.add_theme_font_size_override("font_size", 13)
		button.toggle_mode = true
		button.button_group = _tabs
		button.pressed.connect(_show_category.bind(category))
		_category_buttons.add_child(button)
	_close_button.pressed.connect(close_requested.emit)
	_reset_all.pressed.connect(_show_reset_confirmation.bind(true))
	%CancelReset.pressed.connect(_show_reset_confirmation.bind(false))
	%ApplyReset.pressed.connect(_reset_all_values)
	Tuning.events.changed.connect(_refresh_value)


func open() -> void:
	show()
	_show_reset_confirmation(false)
	_show_category(Tuning.BUILDING)
	_close_button.grab_focus()


func _show_category(category: String) -> void:
	var tab := _category_buttons.get_node(category.replace(" ", "")) as Button
	tab.set_pressed_no_signal(true)
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_values.clear()
	_resets.clear()
	_defaults.clear()
	for entry: Dictionary in _categories[category]:
		_add_row(entry)
	_scroll.scroll_vertical = 0


func _add_row(entry: Dictionary) -> void:
	var key: StringName = entry["key"]
	var row := HBoxContainer.new()
	row.name = String(key).replace(".", "_")
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_rows.add_child(row)

	var label := Label.new()
	label.text = entry["label"]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_stepper("Decrease", "−", entry, -1.0))

	var value_label := Label.new()
	value_label.name = "Value"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = VALUE_SIZE
	value_label.add_theme_font_size_override("font_size", 16)
	row.add_child(value_label)
	_values[key] = value_label
	row.add_child(_stepper("Increase", "+", entry, 1.0))

	# Reserve space so the steppers stay under the finger when Reset appears.
	var reset_slot := HBoxContainer.new()
	reset_slot.name = "ResetSlot"
	reset_slot.custom_minimum_size.x = 104
	reset_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(reset_slot)

	var reset_button := Button.new()
	reset_button.name = "Reset"
	reset_button.text = "Reset to %s" % _value_text(entry["default"])
	reset_button.accessibility_name = "%s (%s)" % [reset_button.text, entry["label"]]
	reset_button.custom_minimum_size = TARGET_SIZE
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.add_theme_font_size_override("font_size", 13)
	reset_button.mouse_filter = Control.MOUSE_FILTER_PASS
	reset_button.pressed.connect(tuning_sync.reset.bind(key))
	reset_slot.add_child(reset_button)
	_resets[key] = reset_button
	_defaults[key] = entry["default"]
	_refresh_value(key)


func _stepper(action: String, glyph: String, entry: Dictionary, direction: float) -> Button:
	var button := Button.new()
	button.name = action
	button.text = glyph
	button.accessibility_name = "%s %s" % [action, entry["label"]]
	button.custom_minimum_size = TARGET_SIZE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_step_value.bind(entry["key"], direction * float(entry["step"])))
	return button


func _step_value(key: StringName, delta: float) -> void:
	tuning_sync.step_value(key, delta)


func _refresh_value(key: StringName) -> void:
	if _values.has(key):
		var value := Tuning.value(key)
		_values[key].text = _value_text(value)
		_resets[key].visible = not is_equal_approx(value, _defaults[key])


func _show_reset_confirmation(confirm: bool) -> void:
	_header.visible = not confirm
	_confirm_reset.visible = confirm
	if confirm:
		%CancelReset.grab_focus()
	else:
		_reset_all.grab_focus()


func _reset_all_values() -> void:
	tuning_sync.reset_all()
	_show_reset_confirmation(false)


static func _value_text(value: float) -> String:
	return String.num(value, 2).trim_suffix(".0")
