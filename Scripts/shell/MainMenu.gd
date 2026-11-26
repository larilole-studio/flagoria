extends PanelContainer

signal new_server_created
signal new_player_added
signal new_player_joined(port: int)

const MenuVolume = preload("res://Scripts/shell/menu_volume.gd")
const MenuJoinFlow = preload("res://Scripts/shell/menu_join_flow.gd")
const MenuWorlds = preload("res://Scripts/shell/menu_worlds.gd")

var letter_keyboard: NumberPad
var admin_panel: PanelContainer
var _previewing_hud := false
var _settings_over_match := false
var _worlds := MenuWorlds.new(self)

@onready var main_menu = $"."
@onready var address_entry: LineEdit = %AddressEntry
@onready var join_status: Label = $MultiplayerPanel/VBoxContainer/JoinStatus
@onready var ux_layer = $/root/Flagoria/CanvasLayer1
@onready var play_panel: MarginContainer = $MarginContainer
@onready var multiplayer_panel: MarginContainer = $MultiplayerPanel
@onready var settings_panel: MarginContainer = $SettingsPanel
@onready var music_volume: HSlider = %SettingsRows/MusicVolumeRow/MusicVolume
@onready var sfx_volume: HSlider = %SettingsRows/SFXVolumeRow/SFXVolume
@onready var music_value: Label = %SettingsRows/MusicVolumeRow/MusicValue
@onready var sfx_value: Label = %SettingsRows/SFXVolumeRow/SFXValue
@onready var hud_editor: Control = ux_layer.get_node("InGameMenu/HudLayoutEdit")


func _ready() -> void:
	var music = get_node("/root/MusicPlayer")
	music.play(music.MENU_TRACK)
	MenuVolume.bind_controls(self)
	hud_editor.closed.connect(_on_hud_preview_closed)
	# The join address is typed on the in-game letter keyboard, not the OS one.
	letter_keyboard = preload("res://Scripts/ui/number_pad.tscn").instantiate()
	letter_keyboard.name = "LetterKeyboard"
	add_child(letter_keyboard)
	letter_keyboard.attach_text(address_entry)
	visibility_changed.connect(letter_keyboard.close)
	admin_panel = preload("res://Scripts/ui/map_admin_panel.tscn").instantiate()
	admin_panel.visible = false
	admin_panel.closed.connect(_on_admin_closed)
	admin_panel.start_host_requested.connect(_on_admin_host_requested)
	# Defer so we are not adding children while the parent CanvasLayer is still setting up.
	get_parent().call_deferred("add_child", admin_panel)


static func percent(v: float) -> String:
	return MenuVolume.percent(v)


func _unhandled_input(_event):
	# No "quit" action is mapped in project.godot. Without this guard the check
	# logs an InputMap error for every unhandled event.
	if InputMap.has_action("quit") and Input.is_action_just_pressed("quit"):
		get_tree().quit()


func _on_new_world_pressed() -> void:
	MenuJoinFlow._on_new_world_pressed(self)


func _on_host_button_pressed():
	MenuJoinFlow._on_host_button_pressed(self)


func _begin_host() -> void:
	MenuJoinFlow._begin_host(self)


func _on_join_button_pressed():
	MenuJoinFlow._on_join_button_pressed(self)


func _on_worlds_pressed() -> void:
	_worlds._on_worlds_pressed()


func _on_load_world_pressed() -> void:
	_worlds._on_load_world_pressed()


func _on_delete_world_pressed() -> void:
	_worlds._on_delete_world_pressed()


func _on_rename_world_pressed() -> void:
	_worlds._on_rename_world_pressed()


func _on_rename_yes_pressed(_new_text: String = "") -> void:
	_worlds._on_rename_yes_pressed(_new_text)


func _on_rename_no_pressed() -> void:
	_worlds._on_rename_no_pressed()


func _on_delete_yes_pressed() -> void:
	_worlds._on_delete_yes_pressed()


func _on_worlds_back_pressed() -> void:
	_worlds._on_worlds_back_pressed()


func open_settings_over_match() -> void:
	## Host, during a match: the same Map Settings panel, without leaving the
	## world. Host stays disabled so it cannot start a second server.
	if admin_panel == null or not admin_panel.is_inside_tree():
		return
	_settings_over_match = true
	admin_panel.load_from_params(get_node("/root/MapGen").params)
	var start := admin_panel.get_node_or_null("Margin/VBox/Buttons2/Start") as Button
	if start != null:
		start.disabled = true
	admin_panel.show()


func _on_settings_pressed() -> void:
	play_panel.hide()
	settings_panel.show()


func _on_settings_back_pressed() -> void:
	settings_panel.hide()
	play_panel.show()


func _on_customize_hud_pressed() -> void:
	settings_panel.hide()
	_previewing_hud = true
	ux_layer.layer = get_parent().layer + 1
	hud_editor.open(true)
	ux_layer.show()


func _on_hud_preview_closed() -> void:
	if not _previewing_hud:
		return
	ux_layer.hide()
	ux_layer.layer = get_parent().layer
	_previewing_hud = false
	settings_panel.show()


func show_multiplayer() -> void:
	play_panel.hide()
	settings_panel.hide()
	join_status.hide()
	multiplayer_panel.refresh_servers()
	multiplayer_panel.show()
	show()


func _on_multiplayer_back_pressed() -> void:
	letter_keyboard.close()
	multiplayer_panel.hide()
	play_panel.show()


func navigate_back() -> bool:
	if _previewing_hud:
		hud_editor.close_editor()
		return true
	if ux_layer.visible:
		return false
	var worlds := get_parent().get_node_or_null("WorldsPanel") as Control
	if letter_keyboard.is_visible_in_tree():
		letter_keyboard.close()
	elif admin_panel.is_visible_in_tree():
		var pad := admin_panel.get_node("NumberPad") as NumberPad
		if pad.is_visible_in_tree():
			pad.close()
		else:
			admin_panel._on_back_pressed()
	elif worlds != null and worlds.is_visible_in_tree():
		_on_worlds_back_pressed()
	elif multiplayer_panel.is_visible_in_tree():
		_on_multiplayer_back_pressed()
	elif settings_panel.is_visible_in_tree():
		_on_settings_back_pressed()
	else:
		return false
	return true


func _on_map_settings_pressed() -> void:
	letter_keyboard.close()
	_worlds._worlds_panel().hide()
	# Panel may still be deferred-added on the very first frame.
	if not admin_panel.is_inside_tree():
		await admin_panel.ready
	admin_panel.load_from_params(get_node("/root/MapGen").params)
	admin_panel.show()


func _on_admin_host_requested() -> void:
	# Keep the root selected for the next time the menu is shown.
	settings_panel.hide()
	play_panel.show()
	_on_host_button_pressed()


func _on_admin_closed() -> void:
	var start: Button = null
	if admin_panel != null:
		start = admin_panel.get_node_or_null("Margin/VBox/Buttons2/Start") as Button
	if start != null:
		start.disabled = false
	if _settings_over_match:
		_settings_over_match = false
		return
	_worlds._worlds_panel().show()


func show_join_failed(address: String) -> void:
	MenuJoinFlow.show_join_failed(self, address)


func show_address_error(message: String) -> void:
	MenuJoinFlow.show_address_error(self, message)
