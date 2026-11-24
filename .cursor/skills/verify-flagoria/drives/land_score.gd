extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Land score (#279, features/land-score.md). Seed 11. The starting castle
## is a city. A tap on its flag draws the range ring. The score HUD shows
## the covered cell count plus earned awards.


func run() -> void:
	step("castle")
	if not await start_game():
		done(false)
		return
	var land: LandScore = current_scene.get_node("World/LandScore")
	var points: Points = current_scene.get_node("Points")
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var scored := await wait_until(func() -> bool: return points.total_of(1) > 0, 8.0)
	await snapshot("castle")
	if not scored:
		printerr("land_score: castle did not score")
		done(false)
		return
	step("ring")
	var flag := _castle_flag(map)
	if flag.x == 1 << 20:
		printerr("land_score: no castle flag")
		done(false)
		return
	await tap_cell(flag)
	var selected := await wait_until(func() -> bool: return land.selected_tower > 0, 3.0)
	await snapshot("ring")
	var radius := land.ring_radius_px()
	var want := float(LandScore.range_cells) * float(map.tile_set.tile_size.x)
	var total := points.total_of(1)
	var earned := points.earned_of(1)
	var covered := land.covered_of(1)
	var score := current_scene.find_child("ScoreHud", true, false) as Label
	var shown := (
		score != null and score.is_visible_in_tree() and score.text == str(covered + earned)
	)
	print(
		(
			"land_score: score %s earned %s covered %s shown %s selected %s radius %s"
			% [
				total,
				earned,
				covered,
				score.text if score != null else "missing",
				land.selected_tower,
				radius
			]
		)
	)
	done(selected and is_equal_approx(radius, want) and total - earned == covered and shown)


func _castle_flag(map: TileMap) -> Vector2i:
	var placed: Dictionary = map.placed_structures()
	var towers: Dictionary = map._structures.towers()
	for id in placed:
		if str(placed[id]["name"]) == "castle" and towers.has(id) and not towers[id].is_empty():
			return towers[id][0]
	return Vector2i(1 << 20, 0)
