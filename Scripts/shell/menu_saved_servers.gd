extends MarginContainer
## Saved-server selection and confirmation on the Multiplayer screen.

const SavedServers = preload("res://Scripts/shell/saved_servers.gd")

var _selected := ""

@onready var _scroll: ScrollContainer = $VBoxContainer/SavedScroll
@onready var _list: VBoxContainer = $VBoxContainer/SavedScroll/SavedServers
@onready var _address: LineEdit = $VBoxContainer/Actions/AddressEntry
@onready var _delete: Button = $VBoxContainer/Actions/DeleteButton
@onready var _confirm: HBoxContainer = $VBoxContainer/Confirm
@onready var _ask: Label = $VBoxContainer/Confirm/Ask
@onready var _empty: Label = $VBoxContainer/SavedScroll/SavedServersEmpty


func _ready() -> void:
	_delete.pressed.connect(_ask_to_delete)
	_confirm.get_node("Yes").pressed.connect(_delete_selected)
	_confirm.get_node("No").pressed.connect(_confirm.hide)


func refresh_servers() -> void:
	_selected = ""
	_delete.disabled = true
	_confirm.hide()
	for row in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	var group := ButtonGroup.new()
	for address in SavedServers.addresses():
		var row := Button.new()
		row.text = address
		# Let a touch drag starting on a row reach the ScrollContainer.
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.toggle_mode = true
		row.button_group = group
		row.pressed.connect(_select_server.bind(address))
		_list.add_child(row)
	_empty.visible = _list.get_child_count() == 0
	_scroll.scroll_vertical = 0


func _select_server(address: String) -> void:
	_selected = address
	_address.text = address
	_delete.disabled = false
	_confirm.hide()


func _ask_to_delete() -> void:
	_ask.text = "Delete this server?"
	_confirm.show()


func _delete_selected() -> void:
	if SavedServers.remove(_selected) == OK:
		refresh_servers()
	else:
		_ask.text = "Could not delete this server."
