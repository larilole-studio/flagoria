extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Open Buildings and select Tower, then move the preview with a remote touch.

const BuildDrag := preload("res://.cursor/skills/verify-flagoria/bin/build_drag.gd")


func run() -> void:
	if not await start_game():
		return
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	step("pick Tower without touching the playfield")
	await click("CanvasLayer1/BuildingsButton")
	await click("CanvasLayer1/BuildPicker/TowerButton")
	var center := root.get_visible_rect().get_center()
	var origin := map.local_to_map(map.to_local(interaction.to_world(center)))
	if not _preview_at(interaction, origin):
		printerr("center build preview: expected a Tower refusal at center cell %s" % [origin])
		done(false)
		return
	await snapshot("centered-tower-warning")

	step("drag from away from the preview")
	var target := origin + Vector2i(4, 0)
	var delta := to_window(map, map.map_to_local(target)) - to_window(map, map.map_to_local(origin))
	var finger := root.get_final_transform() * (center + Vector2(-60, -64))
	var end := finger + delta
	var result := [false]
	await BuildDrag.drag_touch(
		self,
		finger,
		end,
		func() -> void:
			var end_viewport := root.get_final_transform().affine_inverse() * end
			var finger_cell := map.local_to_map(map.to_local(interaction.to_world(end_viewport)))
			result[0] = (
				_preview_at(interaction, target) and not interaction.build.cells.has(finger_cell)
			)
			if result[0]:
				await snapshot("tower-after-relative-drag")
	)
	if not result[0]:
		printerr("center build preview: the warning and footprint did not follow the drag delta")
	done(result[0])


func _preview_at(interaction: Interaction, anchor: Vector2i) -> bool:
	var expected := interaction.get_canvas_transform() * interaction.cell_center(anchor)
	var build := interaction.build
	return (
		build.tool == BuildPlacement.Tool.TOWER
		and build.cells.has(anchor)
		and build.cost_viewport.is_equal_approx(expected)
		and ConstructionPlacer.NOT_ENOUGH_WOOD in build.reasons
	)
