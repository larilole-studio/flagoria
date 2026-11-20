extends RefCounted
## Binds the menu volume controls to AudioSettings.


static func bind_controls(menu: PanelContainer) -> void:
	var audio = menu.get_node("/root/AudioSettings")
	menu.music_volume.value = audio.get_volume("Music")
	menu.sfx_volume.value = audio.get_volume("SFX")
	menu.music_value.text = percent(menu.music_volume.value)
	menu.sfx_value.text = percent(menu.sfx_volume.value)
	menu.music_volume.value_changed.connect(func(v: float) -> void:
		audio.set_volume("Music", v)
		menu.music_value.text = percent(v))
	menu.sfx_volume.value_changed.connect(func(v: float) -> void:
		audio.set_volume("SFX", v)
		menu.sfx_value.text = percent(v))


static func percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)
