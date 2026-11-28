extends "res://tests/helpers/test_helpers.gd"


func _test_tuning_defaults_and_live_price() -> int:
	print("-- test_tuning_defaults_and_live_price")
	var expected := {
		&"building.plank_wood": 1.0,
		&"building.wall_block_wood": 2.0,
		&"building.tower_wood": 10.0,
		&"building.castle_wood": 35.0,
		&"building.guard_post_wood": 14.0,
		&"building.barracks_wood": 20.0,
		&"building.mine_wood": 15.0,
		&"building.sawmill_stone": 15.0,
		&"building.castle_stone": 15.0,
		&"building.guard_post_stone": 6.0,
		&"building.barracks_stone": 10.0,
		&"building.refund_share": 0.5,
		&"building_hp.castle": 60.0,
		&"building_hp.barracks": 30.0,
		&"building_hp.tower_wood": 40.0,
		&"building_hp.guard_post": 40.0,
		&"building_hp.mine": 25.0,
		&"building_hp.sawmill": 25.0,
		&"building_hp.default": 25.0,
		&"building_damage.sword": 1.0,
		&"mine.cycle_seconds": 60.0,
		&"mine.stone_per_cycle": 1.0,
		&"sawmill.cycle_seconds": 60.0,
		&"sawmill.wood_per_cycle": 1.0,
		&"hand_mining.rock_hits": 2.0,
		&"hand_mining.rock_stone": 2.0,
		&"chopping.tree_hits": 2.0,
		&"chopping.tree_wood": 3.0,
		&"chopping.pine_hits": 2.0,
		&"chopping.pine_wood": 3.0,
		&"chopping.bush_hits": 2.0,
		&"chopping.bush_wood": 1.0,
		&"soldiers.training_wood": 8.0,
		&"soldiers.training_stone": 4.0,
		&"soldiers.train_seconds": 4.0,
		&"soldiers.cap_per_barracks": 20.0,
		&"soldiers.sight_range": 96.0,
		&"soldiers.walk_speed": 48.0,
		&"movement.keyboard_speed": 130.0,
		&"movement.joystick_speed": 60.0,
		&"bomb.max_range": 160.0,
		&"bomb.blast_radius": 40.0,
		&"bomb.fuse_seconds": 1.0,
		&"bomb.cooldown_seconds": 1.5,
		&"bomb.damage": 2.0,
		&"command.select_max_px": 160.0,
		&"command.blocked_seconds": 2.0,
		&"command.marker_seconds": 3.0,
		&"visuals.cloud_far_speed": 0.5,
		&"visuals.cloud_near_speed": 1.0,
		&"visuals.mine_cart_fps": 5.0,
	}
	var fail := 0
	var defaults := {}
	for entries in Tuning.entries_by_category().values():
		for entry in entries:
			defaults[entry["key"]] = entry["default"]
	if defaults != expected:
		printerr("FAIL tuning defaults: got %s, want %s" % [defaults, expected])
		fail += 1
	Tuning.set_value(&"building.castle_wood", 40.6)
	var changed_price := BuildCosts.price(BuildCosts.CASTLE)
	Tuning.reset_all()
	var restored_price := BuildCosts.price(BuildCosts.CASTLE)
	if changed_price != Vector2i(41, 15) or restored_price != Vector2i(35, 15):
		printerr(
			"FAIL tuning castle price: changed %s, restored %s" % [changed_price, restored_price]
		)
		fail += 1
	if fail == 0:
		print("PASS test_tuning_defaults_and_live_price")
	return fail
