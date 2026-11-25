extends PanelContainer

const MenuVolume = preload("res://Scripts/shell/menu_volume.gd")
const MenuGameplaySettings = preload("res://Scripts/shell/menu_gameplay_settings.gd")
const MenuJoinFlow = preload("res://Scripts/shell/menu_join_flow.gd")
const MenuWorlds = preload("res://Scripts/shell/menu_worlds.gd")

@onready var main_menu = $"."
@onready var address_entry = $MarginContainer/VBoxContainer/AddressEntry
@onready var join_status: Label = $MarginContainer/VBoxContainer/JoinStatus
@onready var ux_layer = $/root/Flagoria/CanvasLayer1
@onready var play_panel: MarginContainer = $MarginContainer
@onready var settings_panel: MarginContainer = $SettingsPanel
@onready var music_volume: HSlider = %SettingsRows/MusicVolumeRow/MusicVolume
@onready var sfx_volume: HSlider = %SettingsRows/SFXVolumeRow/SFXVolume
@onready var music_value: Label = %SettingsRows/MusicVolumeRow/MusicValue
@onready var sfx_value: Label = %SettingsRows/SFXVolumeRow/SFXValue
@onready var mob_rate: HSlider = %SettingsRows/MobRateRow/MobRate
@onready var mob_rate_value: Label = %SettingsRows/MobRateRow/MobRateValue
@onready var tower_range: HSlider = %SettingsRows/TowerRangeRow/TowerRange
@onready var tower_range_value: Label = %SettingsRows/TowerRangeRow/TowerRangeValue
@onready var tower_damage: HSlider = %SettingsRows/TowerDamageRow/TowerDamage
@onready var tower_damage_value: Label = %SettingsRows/TowerDamageRow/TowerDamageValue
@onready var tower_cooldown: HSlider = %SettingsRows/TowerCooldownRow/TowerCooldown
@onready var tower_cooldown_value: Label = %SettingsRows/TowerCooldownRow/TowerCooldownValue
@onready var raids_enabled: CheckButton = %SettingsRows/RaidsRow/RaidsEnabled
@onready var raid_interval: HSlider = %SettingsRows/RaidIntervalRow/RaidInterval
@onready var raid_interval_value: Label = %SettingsRows/RaidIntervalRow/RaidIntervalValue
@onready var raid_group: HSlider = %SettingsRows/RaidGroupRow/RaidGroup
@onready var raid_group_value: Label = %SettingsRows/RaidGroupRow/RaidGroupValue
@onready var raid_radius: HSlider = %SettingsRows/RaidRadiusRow/RaidRadius
@onready var raid_radius_value: Label = %SettingsRows/RaidRadiusRow/RaidRadiusValue

var admin_panel: PanelContainer
var _settings_over_match := false
var _worlds := MenuWorlds.new(self)

signal new_server_created
signal new_player_added
signal new_player_joined(port: int)


func _ready() -> void:
	var music = get_node("/root/MusicPlayer")
	music.play(music.MENU_TRACK)
	MenuVolume.bind_controls(self)
	MenuGameplaySettings.bind_controls(self)
	# The join address is typed on the in-game letter keyboard, not the OS one.
	var keyboard: NumberPad = preload("res://Scripts/ui/number_pad.tscn").instantiate()
	keyboard.name = "LetterKeyboard"
	add_child(keyboard)
	keyboard.attach_text(address_entry)
	visibility_changed.connect(keyboard.close)
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
	($LetterKeyboard as NumberPad).close()
	play_panel.hide()
	settings_panel.show()


func _on_settings_back_pressed() -> void:
	settings_panel.hide()
	play_panel.show()


func _on_map_settings_pressed() -> void:
	# Keep Settings selected while the map panel is open so Back reveals it.
	main_menu.hide()
	if admin_panel == null:
		return
	# Panel may still be deferred-added on the very first frame.
	if not admin_panel.is_inside_tree():
		await admin_panel.ready
	admin_panel.load_from_params(get_node("/root/MapGen").params)
	admin_panel.show()


func _on_admin_host_requested() -> void:
	# Hosting leaves Settings behind: the menu comes back at the top level.
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
	main_menu.show()


func show_join_failed(address: String) -> void:
	MenuJoinFlow.show_join_failed(self, address)


func show_address_error(message: String) -> void:
	MenuJoinFlow.show_address_error(self, message)
