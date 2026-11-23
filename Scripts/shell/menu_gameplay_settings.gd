extends RefCounted
## Binds the host gameplay controls to GameSettings.


static func bind_controls(menu: PanelContainer) -> void:
	# Mob spawn rate: used when this game hosts; a joining client gets the
	# host's mobs.
	var game = menu.get_node("/root/GameSettings")
	menu.mob_rate.min_value = game.MOB_RATE_MIN
	menu.mob_rate.max_value = game.MOB_RATE_MAX
	menu.mob_rate.step = game.MOB_RATE_STEP
	menu.mob_rate.value = game.mob_rate
	menu.mob_rate_value.text = game.rate_label(game.mob_rate)
	menu.mob_rate.value_changed.connect(
		func(v: float) -> void:
			game.set_mob_rate(v)
			menu.mob_rate_value.text = game.rate_label(game.mob_rate)
	)
	# Tower guns read these on the host. A client's saved values are not the match.
	menu.tower_range.min_value = game.TOWER_RANGE_MIN
	menu.tower_range.max_value = game.TOWER_RANGE_MAX
	menu.tower_range.step = game.TOWER_RANGE_STEP
	menu.tower_range.value = game.tower_range
	menu.tower_range_value.text = game.px_label(game.tower_range)
	menu.tower_range.value_changed.connect(
		func(v: float) -> void:
			game.set_tower_range(v)
			menu.tower_range_value.text = game.px_label(game.tower_range)
	)
	menu.tower_damage.min_value = game.TOWER_DAMAGE_MIN
	menu.tower_damage.max_value = game.TOWER_DAMAGE_MAX
	menu.tower_damage.step = 1
	menu.tower_damage.value = game.tower_damage
	menu.tower_damage_value.text = str(game.tower_damage)
	menu.tower_damage.value_changed.connect(
		func(v: float) -> void:
			game.set_tower_damage(v)
			menu.tower_damage_value.text = str(game.tower_damage)
	)
	menu.tower_cooldown.min_value = game.TOWER_COOLDOWN_MIN
	menu.tower_cooldown.max_value = game.TOWER_COOLDOWN_MAX
	menu.tower_cooldown.step = game.TOWER_COOLDOWN_STEP
	menu.tower_cooldown.value = game.tower_cooldown
	menu.tower_cooldown_value.text = game.seconds_label(game.tower_cooldown)
	menu.tower_cooldown.value_changed.connect(
		func(v: float) -> void:
			game.set_tower_cooldown(v)
			menu.tower_cooldown_value.text = game.seconds_label(game.tower_cooldown)
	)
	# Raids stay off until the host turns them on. The sliders are the
	# interval, the group size and the target radius (#529).
	menu.raids_enabled.button_pressed = game.raids_enabled
	menu.raids_enabled.toggled.connect(func(on: bool) -> void: game.set_raids_enabled(on))
	menu.raid_interval.min_value = game.RAID_INTERVAL_MIN
	menu.raid_interval.max_value = game.RAID_INTERVAL_MAX
	menu.raid_interval.step = game.RAID_INTERVAL_STEP
	menu.raid_interval.value = game.raid_interval_s
	menu.raid_interval_value.text = _seconds(game.raid_interval_s)
	menu.raid_interval.value_changed.connect(
		func(v: float) -> void:
			game.set_raid_interval_s(v)
			menu.raid_interval_value.text = _seconds(game.raid_interval_s)
	)
	menu.raid_group.min_value = game.RAID_GROUP_MIN
	menu.raid_group.max_value = game.RAID_GROUP_MAX
	menu.raid_group.step = 1.0
	menu.raid_group.value = game.raid_group
	menu.raid_group_value.text = str(game.raid_group)
	menu.raid_group.value_changed.connect(
		func(v: float) -> void:
			game.set_raid_group(int(round(v)))
			menu.raid_group_value.text = str(game.raid_group)
	)
	menu.raid_radius.min_value = game.RAID_RADIUS_MIN
	menu.raid_radius.max_value = game.RAID_RADIUS_MAX
	menu.raid_radius.step = 1.0
	menu.raid_radius.value = game.raid_radius_cells
	menu.raid_radius_value.text = str(game.raid_radius_cells)
	menu.raid_radius.value_changed.connect(
		func(v: float) -> void:
			game.set_raid_radius_cells(int(round(v)))
			menu.raid_radius_value.text = str(game.raid_radius_cells)
	)


static func _seconds(v: float) -> String:
	return "%ds" % roundi(v)
