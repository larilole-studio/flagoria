extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11

const BuildDrag := preload("res://.cursor/skills/verify-flagoria/bin/build_drag.gd")
const BUILDINGS := "CanvasLayer1/BuildingsButton"
const PICKER := "CanvasLayer1/BuildPicker/"


func run() -> void:
	if not await start_game():
		return
	var inventory: Inventory = current_scene.get_node(INVENTORY)
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	await grant_resources("AddWood")
	step("open Buildings and show split prices")
	await click(BUILDINGS)
	await snapshot("buildings-picker")
	for building in ["CastleButton", "GuardButton", "BarracksButton"]:
		var caption: Label = current_scene.get_node(PICKER + building + "/Caption")
		if not caption.is_visible_in_tree():
			printerr("stone costs: missing picker price for ", building)
			done(false)
			return
	await click(BUILDINGS)
	await toggle_mode()
	var site := await guard_site(map, interaction)
	if site.is_empty():
		printerr("stone costs: no reachable guard post site")
		done(false)
		return
	await click(BUILDINGS)
	await click(PICKER + "GuardButton")
	var anchor := site[1]
	var refused := [false]
	step("refuse a guard post with no stone")
	await drag_preview(
		map,
		interaction,
		anchor,
		func() -> void:
			refused[0] = (
				interaction.build.reasons == [BuildCosts.NOT_ENOUGH_STONE]
				and interaction.build.cells.has(anchor)
				and interaction.build.price == Vector2i(14, 6)
			)
			if not refused[0]:
				printerr(
					"stone costs: preview ",
					interaction.build.reasons,
					" ",
					interaction.build.cells,
					" expected anchor ",
					anchor
				)
			await snapshot("not-enough-stone")
	)
	if (
		not refused[0]
		or not map.structure_placement_at(anchor).is_empty()
		or (BuildCosts.balance(inventory) != Vector2i(100, 0))
	):
		printerr("stone costs: underfunded preview, placement or inventory mismatch")
		done(false)
		return

	await grant_resources()
	var funded := BuildCosts.balance(inventory)
	step("preview and place the funded guard post")
	var valid := [false]
	await drag_preview(
		map,
		interaction,
		anchor,
		func() -> void:
			valid[0] = (
				interaction.build.reasons.is_empty()
				and (interaction.build.price == Vector2i(14, 6))
			)
			await snapshot("funded-preview")
	)
	if (
		not valid[0]
		or map.structure_placement_at(anchor).get("name") != "guard_post"
		or (BuildCosts.balance(inventory) != funded - Vector2i(14, 6))
	):
		printerr("stone costs: funded preview, placement or charge mismatch")
		done(false)
		return
	await snapshot("guard-post-placed")

	step("demolish the guard post and refund both resources")
	await click(BUILDINGS)
	await click(PICKER + "DemolishButton")
	var refundable := [false]
	await tap_cell(
		anchor,
		func() -> void:
			refundable[0] = (
				interaction.build.reasons.is_empty() and (interaction.build.price == Vector2i(7, 3))
			)
			await snapshot("demolish-preview")
	)
	await snapshot("guard-post-refunded")
	done(
		(
			refundable[0]
			and map.structure_placement_at(anchor).is_empty()
			and (BuildCosts.balance(inventory) == funded - Vector2i(7, 3))
		)
	)


func guard_site(map: TileMap, interaction: Interaction) -> Array[Vector2i]:
	var placer := ConstructionPlacer.new(map)
	for action in ["", "ui_up", "ui_right", "ui_up", "ui_right", "ui_up", "ui_left"]:
		if not action.is_empty():
			await hold(action, 30)
		var center := root.get_visible_rect().get_center()
		var origin := map.local_to_map(map.to_local(interaction.to_world(center)))
		for dx in [4, 5, 3, -4, -5, -3, 0, 1, -1]:
			for dy in [0, -3, 3, -4, 4, -5, 5, -2, 2]:
				var cell := origin + Vector2i(dx, dy)
				if (
					interaction.in_reach(cell)
					and (placer.can_place_geometry(BuildCosts.GUARD_POST, [cell]).is_empty())
				):
					return [origin, cell]
	return []


func drag_preview(
	map: TileMap, interaction: Interaction, anchor: Vector2i, inspect: Callable
) -> void:
	var center := root.get_visible_rect().get_center()
	var finger := root.get_final_transform() * (center + Vector2(-60, -64))
	var from := (
		interaction.build.cost_viewport if interaction.build.has_pointer_origin() else center
	)
	var origin := map.local_to_map(map.to_local(interaction.to_world(from)))
	var delta := to_window(map, map.map_to_local(anchor)) - to_window(map, map.map_to_local(origin))
	await BuildDrag.drag_touch(self, finger, finger + delta, inspect)
