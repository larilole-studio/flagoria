extends RefCounted
## Handles menu transitions for hosting, joining and connection feedback.

const JoinAddress = preload("res://Scripts/net/join_address.gd")


static func _on_new_world_pressed(menu: PanelContainer) -> void:
	## A new match, even if a save was loaded and not hosted yet.
	menu.get_node("/root/MapGen").clear_loaded_world()
	menu.get_node("/root/Flagoria").save_name = ""
	menu._on_host_button_pressed()


static func _on_host_button_pressed(menu: PanelContainer):
	## Host the loaded world when there is one. Otherwise start a new match
	## in its own save file.
	var map_gen = menu.get_node("/root/MapGen")
	var game = menu.get_node("/root/Flagoria")
	if not map_gen.has_loaded_world():
		var menu_script: GDScript = load("res://Scripts/shell/ingame_menu.gd")
		game.save_name = menu_script.unused_save_name(
			menu_script.auto_save_name(Time.get_datetime_dict_from_system())
		)
	menu._begin_host()


static func _begin_host(menu: PanelContainer) -> void:
	var map_gen = menu.get_node("/root/MapGen")
	map_gen.save_to_disk()
	menu.emit_signal("new_server_created", map_gen.params.duplicate_params())
	menu.main_menu.hide()
	if menu.admin_panel:
		menu.admin_panel.hide()
	var worlds := menu.get_parent().get_node_or_null("WorldsPanel")
	if worlds:
		worlds.hide()
	menu.ux_layer.show()
	menu.get_node("/root/MusicPlayer").play(menu.get_node("/root/MusicPlayer").GAME_TRACK)
	menu.emit_signal("new_player_added", menu.multiplayer.get_unique_id())


static func _on_join_button_pressed(menu: PanelContainer):
	var address: String = menu.address_entry.text
	if address.strip_edges().is_empty():
		menu.show_address_error(JoinAddress.ERROR_EMPTY)
		return
	var parsed: Dictionary = JoinAddress.parse(address)
	if not parsed["ok"]:
		# Stay on the menu. A bad address never opens an ENet client.
		menu.show_address_error(str(parsed["error"]))
		return
	menu.join_status.visible = false
	menu.join_status.text = ""
	menu.main_menu.hide()
	if menu.admin_panel:
		menu.admin_panel.hide()
	menu.ux_layer.show()
	menu.get_node("/root/MusicPlayer").play(menu.get_node("/root/MusicPlayer").GAME_TRACK)
	menu.emit_signal("new_player_joined", int(parsed["port"]))


static func show_join_failed(menu: PanelContainer, address: String) -> void:
	## Bring the main menu back after a join that never connected (#348).
	## Message copy is fixed in the issue: "Could not join <address>".
	_show_status(menu, "Could not join %s" % address)


static func show_address_error(menu: PanelContainer, message: String) -> void:
	## A typed address that Join will not dial. Shown at once, with no
	## connection attempt. The address field is left as typed.
	_show_status(menu, message)


static func _show_status(menu: PanelContainer, message: String) -> void:
	if menu.admin_panel:
		menu.admin_panel.hide()
	menu.ux_layer.hide()
	menu.main_menu.show()
	menu.join_status.text = message
	menu.join_status.visible = true
	menu.get_node("/root/MusicPlayer").play(menu.get_node("/root/MusicPlayer").MENU_TRACK)
