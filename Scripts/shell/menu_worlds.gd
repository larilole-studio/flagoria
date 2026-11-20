extends RefCounted
## Builds the Worlds picker and handles saved-world actions.


const WorldsSaveList = preload("res://Scripts/shell/worlds_save_list.gd")
const WorldSavePreview = preload("res://Scripts/ui/world_save_preview.gd")

var menu: PanelContainer


func _init(main_menu: PanelContainer) -> void:
	menu = main_menu


func _on_worlds_pressed() -> void:
	var panel := _worlds_panel()
	menu.main_menu.hide()
	panel.show()
	_refresh_worlds()
	var scroll := panel.get_node_or_null("Margin/VBox/Scroll") as ScrollContainer
	if scroll:
		scroll.scroll_vertical = 0


func _worlds_list() -> ItemList:
	return _worlds_panel().get_node("Margin/VBox/Scroll/List") as ItemList


func _worlds_panel() -> PanelContainer:
	var existing := menu.get_parent().get_node_or_null("WorldsPanel") as PanelContainer
	if existing:
		return existing
	var panel := PanelContainer.new()
	panel.name = "WorldsPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.theme = menu.theme
	panel.visible = false
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "VBox"
	box.custom_minimum_size = Vector2(240, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	var title := Label.new()
	title.text = "Worlds"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 96)
	box.add_child(scroll)
	var list := WorldsSaveList.new()
	list.name = "List"
	list.auto_height = true
	list.fixed_icon_size = WorldSavePreview.ICON_SIZE
	list.icon_mode = ItemList.ICON_MODE_LEFT
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	box.add_child(buttons)
	_world_button(buttons, "Load", _on_load_world_pressed)
	_world_button(buttons, "Delete", _on_delete_world_pressed)
	_world_button(buttons, "Rename", _on_rename_world_pressed)
	_world_button(buttons, "NewWorld", menu._on_new_world_pressed).text = "New world"
	var confirm := HBoxContainer.new()
	confirm.name = "Confirm"
	confirm.visible = false
	box.add_child(confirm)
	var ask := Label.new()
	ask.name = "Ask"
	ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ask.text = "Delete this world?"
	confirm.add_child(ask)
	_world_button(confirm, "Yes", _on_delete_yes_pressed)
	_world_button(confirm, "No", _on_delete_no_pressed)
	var rename := HBoxContainer.new()
	rename.name = "Rename"
	rename.visible = false
	box.add_child(rename)
	var rename_field := LineEdit.new()
	rename_field.name = "Name"
	rename_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_field.text_submitted.connect(_on_rename_yes_pressed)
	rename.add_child(rename_field)
	var keyboard := menu.get_node_or_null("LetterKeyboard")
	if keyboard:
		keyboard.attach_text(rename_field)
	_world_button(rename, "Confirm", _on_rename_yes_pressed)
	_world_button(rename, "Cancel", _on_rename_no_pressed)
	var status := Label.new()
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	_world_button(box, "Back", _on_worlds_back_pressed)
	menu.get_parent().add_child(panel)
	return panel


func _world_button(parent: Node, node_name: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = node_name
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


func _refresh_worlds() -> void:
	var list := _worlds_list()
	list.clear()
	list.fixed_icon_size = WorldSavePreview.ICON_SIZE
	for row in MapSave.list_saves():
		var when: Dictionary = Time.get_datetime_dict_from_unix_time(int(row["modified"]))
		var stamp := "%04d-%02d-%02d %02d:%02d" % [when["year"], when["month"], when["day"], when["hour"], when["minute"]]
		list.add_item("%s  %s" % [row["name"], stamp])
		var i := list.item_count - 1
		list.set_item_icon(i, WorldSavePreview.icon_for(menu.get_tree(), str(row["path"]), str(row["name"])))
		list.set_item_metadata(i, row["name"])


func _selected_world() -> String:
	var list := _worlds_list()
	var picked := list.get_selected_items()
	if picked.is_empty():
		return ""
	return str(list.get_item_metadata(picked[0]))


func _world_status(text: String) -> void:
	var status := _worlds_panel().get_node("Margin/VBox/Status") as Label
	status.text = text


func _on_load_world_pressed() -> void:
	var save_name := _selected_world()
	if save_name == "":
		_world_status("Select a world")
		return
	var err := str(menu.get_node("/root/MapGen").load_map_inputs(MapSave.path_for(save_name)))
	if err != "":
		_world_status(err)
		return
	menu.get_node("/root/Flagoria").save_name = save_name
	menu._begin_host()


func _on_delete_world_pressed() -> void:
	if _selected_world() == "":
		_world_status("Select a world")
		return
	_on_rename_no_pressed()
	var panel := _worlds_panel()
	panel.get_node("Margin/VBox/Buttons").hide()
	panel.get_node("Margin/VBox/Confirm").show()
	_world_status("")


func _on_rename_world_pressed() -> void:
	var save_name := _selected_world()
	if save_name == "":
		_world_status("Select a world")
		return
	_on_delete_no_pressed()
	var panel := _worlds_panel()
	panel.get_node("Margin/VBox/Buttons").hide()
	var rename := panel.get_node("Margin/VBox/Rename")
	rename.show()
	var field := rename.get_node("Name") as LineEdit
	field.text = save_name
	field.grab_focus()
	_world_status("")


func _on_rename_yes_pressed(_new_text: String = "") -> void:
	var save_name := _selected_world()
	var rename := _worlds_panel().get_node("Margin/VBox/Rename")
	var field := rename.get_node("Name") as LineEdit
	var new_name := field.text
	var err := str(MapSave.rename_save(save_name, new_name) if save_name != "" else "Select a world")
	if err != "":
		_world_status(err)
		return
	var clean := new_name.strip_edges().validate_filename()
	_on_rename_no_pressed()
	_refresh_worlds()
	_select_world_named(clean)
	_world_status("")


func _on_rename_no_pressed() -> void:
	var panel := _worlds_panel()
	var rename := panel.get_node_or_null("Margin/VBox/Rename")
	if rename:
		rename.hide()
	panel.get_node("Margin/VBox/Buttons").show()


func _select_world_named(save_name: String) -> void:
	if save_name == "":
		return
	var list := _worlds_list()
	for i in list.item_count:
		if str(list.get_item_metadata(i)) == save_name:
			list.select(i)
			list.ensure_current_is_visible()
			return


func _on_delete_yes_pressed() -> void:
	var save_name := _selected_world()
	var err := str(MapSave.delete_save(save_name) if save_name != "" else "Select a world")
	_on_delete_no_pressed()
	_refresh_worlds()
	_world_status("" if err == "" else err)


func _on_delete_no_pressed() -> void:
	var panel := _worlds_panel()
	panel.get_node("Margin/VBox/Confirm").hide()
	panel.get_node("Margin/VBox/Buttons").show()


func _on_worlds_back_pressed() -> void:
	_on_delete_no_pressed()
	_on_rename_no_pressed()
	_worlds_panel().hide()
	menu.main_menu.show()
