extends "res://tests/helpers/test_helpers.gd"
## Audio buses, volume settings and menu settings persistence.

const MAIN := preload("res://flagoria_main.tscn")
const MENU := "CanvasLayer2/MainMenu"
const WORLDS_BUTTON := MENU + "/MarginContainer/VBoxContainer/WorldsButton"
const MOB_RATE := "CanvasLayer2/WorldsPanel/Margin/VBox/Body/GameplayScroll/Rows/MobRateRow/MobRate"


func _test_audio_settings() -> int:
	## Music and SFX buses exist under Master; game sounds use SFX; the menu
	## sliders set bus volume_db, 0 mutes, and values persist across a reload.
	print("-- test_audio_settings")
	var fail := 0
	var audio = root.get_node("AudioSettings")
	var saved_path: String = audio.save_path
	audio.save_path = "user://test_audio_settings.cfg"
	DirAccess.remove_absolute(audio.save_path)
	# Start from defaults, whatever the real settings file held at launch.
	audio.load_from_disk()

	# Corrupt or hand-edited values: defaults or clamp, never a crash or mute.
	# [saved value, expected volume]; NaN cannot be a dictionary key.
	var bad := [
		["abc", 1.0],
		[[0.5], 1.0],
		[NAN, 1.0],
		[INF, 1.0],
		[-0.5, 1.0],
		[7, 1.0],
		[1.5, 1.0],
		[0.3, 0.3]
	]
	for pair in bad:
		var value = pair[0]
		var cfg := ConfigFile.new()
		cfg.set_value(audio.SECTION, "SFX", value)
		cfg.save(audio.save_path)
		audio.load_from_disk()
		var idx := AudioServer.get_bus_index("SFX")
		if not is_equal_approx(audio.get_volume("SFX"), pair[1]) or AudioServer.is_bus_mute(idx):
			printerr(
				(
					"FAIL audio_settings: saved %s loads as %s mute=%s, want %s"
					% [value, audio.get_volume("SFX"), AudioServer.is_bus_mute(idx), pair[1]]
				)
			)
			fail += 1
	DirAccess.remove_absolute(audio.save_path)
	audio.load_from_disk()
	for bus in ["Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus)
		if idx < 0 or AudioServer.get_bus_send(idx) != &"Master":
			printerr("FAIL audio_settings: bus %s missing or not sending to Master" % bus)
			fail += 1

	var scene = MAIN.instantiate()
	root.add_child(scene)
	var menu = scene.get_node(MENU)
	var sliders := {"Music": menu.music_volume, "SFX": menu.sfx_volume}
	for bus in sliders:
		var slider: HSlider = sliders[bus]
		var idx := AudioServer.get_bus_index(bus)
		if not is_equal_approx(slider.value, audio.DEFAULTS[bus]):
			printerr(
				(
					"FAIL audio_settings: %s slider starts at %s want %s"
					% [bus, slider.value, audio.DEFAULTS[bus]]
				)
			)
			fail += 1
		slider.value = 0.25
		var label: Label = menu.music_value if bus == "Music" else menu.sfx_value
		if label.text != "25%":
			printerr("FAIL audio_settings: %s label shows %s at 0.25" % [bus, label.text])
			fail += 1
		if (
			not is_equal_approx(AudioServer.get_bus_volume_db(idx), linear_to_db(0.25))
			or AudioServer.is_bus_mute(idx)
		):
			printerr(
				(
					"FAIL audio_settings: %s at 0.25 gives %s dB mute=%s"
					% [bus, AudioServer.get_bus_volume_db(idx), AudioServer.is_bus_mute(idx)]
				)
			)
			fail += 1
		slider.value = 0.0
		if not AudioServer.is_bus_mute(idx):
			printerr("FAIL audio_settings: %s at 0 is not muted" % bus)
			fail += 1
	menu.sfx_volume.value = 0.4

	var player = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	player.name = "2"
	scene.get_node("World").add_child(player)
	var routed: Array = [player.get_node("Footsteps")]
	routed.append_array(player.get_node("CombatSfx").get_children())
	for node in routed:
		if node.bus != &"SFX":
			printerr("FAIL audio_settings: %s plays on %s, not SFX" % [node.name, node.bus])
			fail += 1

	fail += await check_settings_restart(scene, audio)
	DirAccess.remove_absolute(audio.save_path)
	audio.save_path = saved_path
	audio.load_from_disk()
	if fail == 0:
		print("PASS test_audio_settings")
	return fail


func check_settings_restart(scene: Node, audio: Node) -> int:
	var game = root.get_node("GameSettings")
	var saved_path: String = game.save_path
	game.save_path = "user://test_menu_game_settings.cfg"
	DirAccess.remove_absolute(game.save_path)
	game.load_from_disk()
	scene.get_node(WORLDS_BUTTON).pressed.emit()
	scene.get_node(MOB_RATE).value = 0.75

	var audio_cfg := ConfigFile.new()
	var game_cfg := ConfigFile.new()
	var keys_saved := (
		audio_cfg.load(audio.save_path) == OK
		and is_equal_approx(audio_cfg.get_value("audio", "SFX", 0.0), 0.4)
		and game_cfg.load(game.save_path) == OK
		and is_equal_approx(game_cfg.get_value("gameplay", "mob_rate", 0.0), 0.75)
	)
	await free_ui_scene(scene)
	# Rebuild the menu after both autoloads reload their files, as on launch.
	audio.reset_to_defaults()
	audio.load_from_disk()
	game.load_from_disk()
	var restarted := await mount_ui_scene(MAIN, root.size, 1)
	restarted.get_node(WORLDS_BUTTON).pressed.emit()
	var menu = restarted.get_node(MENU)
	var rate: HSlider = restarted.get_node(MOB_RATE)
	var ok: bool = (
		keys_saved
		and is_equal_approx(menu.sfx_volume.value, 0.4)
		and is_equal_approx(menu.music_volume.value, 0.0)
		and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
		and is_equal_approx(rate.value, 0.75)
	)
	await free_ui_scene(restarted)
	DirAccess.remove_absolute(game.save_path)
	game.save_path = saved_path
	game.load_from_disk()
	if not ok:
		printerr("FAIL audio_settings: menu values or config keys did not survive restart")
		return 1
	return 0
