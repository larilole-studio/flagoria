extends RefCounted
## Binds the host gameplay controls to GameSettings.


static func bind_controls(rows: VBoxContainer) -> void:
	# Mob spawn rate: used when this game hosts; a joining client gets the
	# host's mobs.
	var game = rows.get_node("/root/GameSettings")
	var mob_rate: HSlider = rows.get_node("MobRateRow/MobRate")
	mob_rate.min_value = game.MOB_RATE_MIN
	mob_rate.max_value = game.MOB_RATE_MAX
	mob_rate.step = game.MOB_RATE_STEP
	mob_rate.value = game.mob_rate
	var mob_rate_value: Label = rows.get_node("MobRateRow/MobRateValue")
	mob_rate_value.text = game.rate_label(game.mob_rate)
	mob_rate.value_changed.connect(
		func(v: float) -> void:
			game.set_mob_rate(v)
			mob_rate_value.text = game.rate_label(game.mob_rate)
	)
	# Tower guns read these on the host. A client's saved values are not the match.
	var tower_range: HSlider = rows.get_node("TowerRangeRow/TowerRange")
	tower_range.min_value = game.TOWER_RANGE_MIN
	tower_range.max_value = game.TOWER_RANGE_MAX
	tower_range.step = game.TOWER_RANGE_STEP
	tower_range.value = game.tower_range
	var tower_range_value: Label = rows.get_node("TowerRangeRow/TowerRangeValue")
	tower_range_value.text = game.px_label(game.tower_range)
	tower_range.value_changed.connect(
		func(v: float) -> void:
			game.set_tower_range(v)
			tower_range_value.text = game.px_label(game.tower_range)
	)
	var tower_damage: HSlider = rows.get_node("TowerDamageRow/TowerDamage")
	tower_damage.min_value = game.TOWER_DAMAGE_MIN
	tower_damage.max_value = game.TOWER_DAMAGE_MAX
	tower_damage.step = 1
	tower_damage.value = game.tower_damage
	var tower_damage_value: Label = rows.get_node("TowerDamageRow/TowerDamageValue")
	tower_damage_value.text = str(game.tower_damage)
	tower_damage.value_changed.connect(
		func(v: float) -> void:
			game.set_tower_damage(v)
			tower_damage_value.text = str(game.tower_damage)
	)
	var tower_cooldown: HSlider = rows.get_node("TowerCooldownRow/TowerCooldown")
	tower_cooldown.min_value = game.TOWER_COOLDOWN_MIN
	tower_cooldown.max_value = game.TOWER_COOLDOWN_MAX
	tower_cooldown.step = game.TOWER_COOLDOWN_STEP
	tower_cooldown.value = game.tower_cooldown
	var tower_cooldown_value: Label = rows.get_node("TowerCooldownRow/TowerCooldownValue")
	tower_cooldown_value.text = game.seconds_label(game.tower_cooldown)
	tower_cooldown.value_changed.connect(
		func(v: float) -> void:
			game.set_tower_cooldown(v)
			tower_cooldown_value.text = game.seconds_label(game.tower_cooldown)
	)
	# Raids stay off until the host turns them on. The sliders are the
	# interval, the group size and the target radius (#529).
	var raids_enabled: CheckButton = rows.get_node("RaidsRow/RaidsEnabled")
	raids_enabled.button_pressed = game.raids_enabled
	raids_enabled.toggled.connect(func(on: bool) -> void: game.set_raids_enabled(on))
	var raid_interval: HSlider = rows.get_node("RaidIntervalRow/RaidInterval")
	raid_interval.min_value = game.RAID_INTERVAL_MIN
	raid_interval.max_value = game.RAID_INTERVAL_MAX
	raid_interval.step = game.RAID_INTERVAL_STEP
	raid_interval.value = game.raid_interval_s
	var raid_interval_value: Label = rows.get_node("RaidIntervalRow/RaidIntervalValue")
	raid_interval_value.text = _seconds(game.raid_interval_s)
	raid_interval.value_changed.connect(
		func(v: float) -> void:
			game.set_raid_interval_s(v)
			raid_interval_value.text = _seconds(game.raid_interval_s)
	)
	var raid_group: HSlider = rows.get_node("RaidGroupRow/RaidGroup")
	raid_group.min_value = game.RAID_GROUP_MIN
	raid_group.max_value = game.RAID_GROUP_MAX
	raid_group.step = 1.0
	raid_group.value = game.raid_group
	var raid_group_value: Label = rows.get_node("RaidGroupRow/RaidGroupValue")
	raid_group_value.text = str(game.raid_group)
	raid_group.value_changed.connect(
		func(v: float) -> void:
			game.set_raid_group(int(round(v)))
			raid_group_value.text = str(game.raid_group)
	)
	var raid_radius: HSlider = rows.get_node("RaidRadiusRow/RaidRadius")
	raid_radius.min_value = game.RAID_RADIUS_MIN
	raid_radius.max_value = game.RAID_RADIUS_MAX
	raid_radius.step = 1.0
	raid_radius.value = game.raid_radius_cells
	var raid_radius_value: Label = rows.get_node("RaidRadiusRow/RaidRadiusValue")
	raid_radius_value.text = str(game.raid_radius_cells)
	raid_radius.value_changed.connect(
		func(v: float) -> void:
			game.set_raid_radius_cells(int(round(v)))
			raid_radius_value.text = str(game.raid_radius_cells)
	)


static func _seconds(v: float) -> String:
	return "%ds" % roundi(v)
