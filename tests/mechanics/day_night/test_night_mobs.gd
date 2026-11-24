extends "res://tests/helpers/test_helpers.gd"
## Ambient caps follow the day/night clock (#559).

const DRIVE_RATE := 0.5
const DRIVE_SEED := 5


func _test_night_mob_caps() -> int:
	## Day, dusk, night and dawn scales, and the cycle switched off.
	## The drive's map (seed 5, rate 0.5) spawns more on the night tick
	## than the day tick. About 1 s.
	print("-- test_night_mob_caps")
	var fail := 0
	if not is_equal_approx(DayNight.spawn_scale_for(float(DayNight.PHASE_HOLD["day"]), true), 1.0):
		printerr("FAIL night_mob_caps day scale")
		fail += 1
	if not is_equal_approx(
		DayNight.spawn_scale_for(float(DayNight.PHASE_HOLD["night"]), true), 2.0
	):
		printerr("FAIL night_mob_caps night scale")
		fail += 1
	if not is_equal_approx(DayNight.spawn_scale_for(float(DayNight.PHASE_HOLD["dusk"]), true), 1.5):
		printerr("FAIL night_mob_caps dusk scale")
		fail += 1
	if not is_equal_approx(DayNight.spawn_scale_for(float(DayNight.PHASE_HOLD["dawn"]), true), 1.5):
		printerr("FAIL night_mob_caps dawn scale")
		fail += 1
	var early := DayNight.night_weight(367.5)
	var mid := DayNight.night_weight(390.0)
	var late := DayNight.night_weight(412.5)
	if not (early > 0.0 and early < mid and mid < late and late < 1.0):
		printerr("FAIL night_mob_caps dusk ramp %s %s %s" % [early, mid, late])
		fail += 1
	var dawn_late := DayNight.night_weight(592.5)
	if not (
		is_equal_approx(DayNight.night_weight(540.0), 1.0)
		and dawn_late < DayNight.night_weight(570.0)
		and dawn_late > 0.0
	):
		printerr("FAIL night_mob_caps dawn ramp")
		fail += 1
	if not is_equal_approx(DayNight.spawn_scale_for(480.0, false), 1.0):
		printerr("FAIL night_mob_caps cycle off is not daytime")
		fail += 1
	var day_caps: Dictionary = MobSpawner.ambient_caps(1.0, 1.0)
	var dusk_caps: Dictionary = MobSpawner.ambient_caps(1.0, 1.5)
	var night_caps: Dictionary = MobSpawner.ambient_caps(1.0, 2.0)
	if day_caps != {"per_player": 10, "total": 30}:
		printerr("FAIL night_mob_caps day caps %s" % day_caps)
		fail += 1
	if dusk_caps != {"per_player": 15, "total": 45}:
		printerr("FAIL night_mob_caps dusk caps %s" % dusk_caps)
		fail += 1
	if night_caps != {"per_player": 20, "total": 60}:
		printerr("FAIL night_mob_caps night caps %s" % night_caps)
		fail += 1
	if (
		MobSpawner.ambient_caps(1.0) != day_caps
		or MobSpawner.ambient_caps(2.0) != {"per_player": 20, "total": 60}
	):
		printerr("FAIL night_mob_caps omitted scale changed the day caps")
		fail += 1
	if MobSpawner.ambient_caps(2.0, 2.0) != {"per_player": 40, "total": 120}:
		printerr("FAIL night_mob_caps rate and night scale %s" % MobSpawner.ambient_caps(2.0, 2.0))
		fail += 1
	for phase in ["day", "dusk", "night", "dawn"]:
		var scale := DayNight.spawn_scale_for(float(DayNight.PHASE_HOLD[phase]), true)
		var want: Dictionary = MobSpawner.ambient_caps(1.0, scale)
		var got: Dictionary = MobSpawner.ambient_caps(
			1.0, DayNight.spawn_scale_for(float(DayNight.PHASE_HOLD[phase]), true)
		)
		if (
			got != want
			or (phase == "day" and got != day_caps)
			or (phase == "night" and got != night_caps)
		):
			printerr("FAIL night_mob_caps %s caps %s" % [phase, got])
			fail += 1
		if phase == "dusk" or phase == "dawn":
			if (
				int(got["per_player"]) <= int(day_caps["per_player"])
				or int(got["per_player"]) >= int(night_caps["per_player"])
			):
				printerr(
					(
						"FAIL night_mob_caps %s per-player %s is not between day and night"
						% [phase, got]
					)
				)
				fail += 1
	var off := MapGenParams.make_defaults()
	off.day_night_cycle = false
	DayNight.begin(off, float(DayNight.PHASE_HOLD["night"]))
	if DayNight.phase() != "day" or not is_equal_approx(MobSpawner.ambient_scale(), 1.0):
		printerr(
			(
				"FAIL night_mob_caps spawner scale with the cycle off %s %s"
				% [DayNight.phase(), MobSpawner.ambient_scale()]
			)
		)
		fail += 1
	off.day_night_cycle = true
	DayNight.begin(off, float(DayNight.PHASE_HOLD["night"]))
	if DayNight.phase() != "night" or not is_equal_approx(MobSpawner.ambient_scale(), 2.0):
		printerr(
			(
				"FAIL night_mob_caps spawner night scale %s %s"
				% [DayNight.phase(), MobSpawner.ambient_scale()]
			)
		)
		fail += 1
	DayNight.stop()
	fail += _drive_map_gap()
	if fail == 0:
		print("PASS test_night_mob_caps")
	return fail


func _test_night_mob_dawn() -> int:
	## Night holds the higher cap. At day the surplus past DESPAWN_RADIUS
	## leaves and the count is the day cap. A mob still inside that radius
	## stays, including when every extra is still in view. About 0.5 s.
	print("-- test_night_mob_dawn")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	world.apply_map_params(_spawn_params(11, 0.0))
	var player := _grass(world)
	var fail := 0
	var night_scale := DayNight.spawn_scale_for(float(DayNight.PHASE_HOLD["night"]), true)
	var day_scale := DayNight.spawn_scale_for(float(DayNight.PHASE_HOLD["day"]), true)
	var night_cap := int(MobSpawner.ambient_caps(1.0, night_scale)["per_player"])
	var day_cap := int(MobSpawner.ambient_caps(1.0, day_scale)["per_player"])
	var in_view := _roster(player, night_cap, 10, "near")
	var at_night: Dictionary = MobSpawner.plan_tick(
		world, [player], in_view, 11, 0, 1.0, night_scale
	)
	if not at_night["spawn"].is_empty() or not at_night["despawn"].is_empty():
		printerr(
			"FAIL night_mob_dawn night changed an in-view roster at the night cap: %s" % at_night
		)
		fail += 1
	var still: Dictionary = MobSpawner.plan_tick(world, [player], in_view, 11, 1, 1.0, day_scale)
	if not still["despawn"].is_empty() or still["despawn"].has("near"):
		printerr("FAIL night_mob_dawn day removed an in-view mob: %s" % still["despawn"])
		fail += 1
	var wandered := _roster(player, day_cap, 10, "near")
	var far_cells := {}
	for i in night_cap - day_cap:
		var mob_name := "far_%d" % i
		var cell := player + Vector2i(80, i)
		wandered.append({"name": mob_name, "cell": cell, "pinned": false})
		far_cells[mob_name] = cell
	var at_day: Dictionary = MobSpawner.plan_tick(world, [player], wandered, 11, 2, 1.0, day_scale)
	if at_day["despawn"].has("near") or not at_day["spawn"].is_empty():
		printerr("FAIL night_mob_dawn near mob or a new spawn: %s" % at_day)
		fail += 1
	for mob_name in at_day["despawn"]:
		var cell: Vector2i = far_cells.get(str(mob_name), player)
		if maxi(absi(cell.x - player.x), absi(cell.y - player.y)) <= MobSpawner.DESPAWN_RADIUS:
			printerr("FAIL night_mob_dawn despawned %s inside the radius" % mob_name)
			fail += 1
	var left := (
		wandered.size() - (at_day["despawn"] as Array).size() + (at_day["spawn"] as Array).size()
	)
	if left != day_cap or at_day["despawn"].size() != night_cap - day_cap:
		printerr(
			(
				"FAIL night_mob_dawn count %s want day cap %s despawn %s"
				% [left, day_cap, at_day["despawn"]]
			)
		)
		fail += 1
	scene.queue_free()
	if fail == 0:
		print("PASS test_night_mob_dawn (night %s -> day %s, near stayed)" % [night_cap, day_cap])
	return fail


func _drive_map_gap() -> int:
	## Same seeds launch.sh --seed writes, at the drive's mob rate.
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var params := MapGenParams.make_defaults()
	params.altitude_seed = DRIVE_SEED
	params.moisture_seed = DRIVE_SEED + 1
	params.temperature_seed = DRIVE_SEED + 2
	params.items_seed = DRIVE_SEED + 3
	params.biome_seed = DRIVE_SEED + 4
	world.apply_map_params(params)
	var player: Vector2i = world.resolve_player_spawn()
	var existing: Array = []
	var opening: Array = MobSpawner.plan(world, player, DRIVE_SEED, DRIVE_RATE)
	for i in opening.size():
		existing.append({"name": "mob_%d" % i, "cell": opening[i]["cell"], "pinned": false})
	var day: Dictionary = MobSpawner.plan_tick(
		world, [player], existing, DRIVE_SEED, 0, DRIVE_RATE, 1.0
	)
	var mid := _apply_plan(existing, day)
	var night: Dictionary = MobSpawner.plan_tick(
		world, [player], mid, DRIVE_SEED, 1, DRIVE_RATE, 2.0
	)
	var after := _apply_plan(mid, night)
	scene.queue_free()
	if after.size() <= mid.size():
		printerr(
			(
				"FAIL night_mob_caps seed %s rate %s day %s night %s (no extra mobs)"
				% [DRIVE_SEED, DRIVE_RATE, mid.size(), after.size()]
			)
		)
		return 1
	print(
		(
			"night_mob_caps: seed %s rate %s day %s night %s"
			% [DRIVE_SEED, DRIVE_RATE, mid.size(), after.size()]
		)
	)
	return 0


func _apply_plan(existing: Array, plan: Dictionary) -> Array:
	var drop := {}
	for mob_name in plan["despawn"]:
		drop[str(mob_name)] = true
	var out: Array = []
	for item in existing:
		if not drop.has(str(item["name"])):
			out.append(item)
	for item in plan["spawn"]:
		out.append({"name": item["name"], "cell": item["cell"], "pinned": false})
	return out


func _roster(player: Vector2i, count: int, distance: int, first_name: String) -> Array:
	var out: Array = []
	for i in count:
		(
			out
			. append(
				{
					"name": first_name if i == 0 else "mob_%d" % i,
					"cell": player + Vector2i(distance, 0),
					"pinned": false,
				}
			)
		)
	return out


func _grass(world: TileMap) -> Vector2i:
	for r in 48:
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var cell := Vector2i(x, y)
				if MobSpawner.is_home_cell(world, cell, MobCatalog.HOME_GRASS):
					return cell
	return Vector2i.ZERO
