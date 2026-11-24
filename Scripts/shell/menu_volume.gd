extends RefCounted
## Binds the menu volume controls to AudioSettings.


static func bind_controls(menu: PanelContainer) -> void:
	bind_slider(menu.music_volume, menu.music_value, "Music")
	bind_slider(menu.sfx_volume, menu.sfx_value, "SFX")


static func bind_slider(slider: HSlider, label: Label, bus: String) -> void:
	var audio = slider.get_node("/root/AudioSettings")
	refresh_slider(slider, label, bus)
	slider.value_changed.connect(
		func(value: float) -> void:
			audio.set_volume(bus, value)
			label.text = percent(value)
	)


static func refresh_slider(slider: HSlider, label: Label, bus: String) -> void:
	var audio = slider.get_node("/root/AudioSettings")
	slider.set_value_no_signal(audio.get_volume(bus))
	label.text = percent(slider.value)


static func percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)
