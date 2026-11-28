extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Place a barracks and train a soldier through the HUD.

const BuildDrag := preload("res://.cursor/skills/verify-flagoria/bin/build_drag.gd")
const TRAIN := "CanvasLayer1/TrainButton"
const ORDER := "CanvasLayer1/SoldierOrderButton"


func run() -> void:
	if not await start_game():
		return
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var inventory: Inventory = current_scene.get_node(INVENTORY)
	var requests: SoldierRequests = current_scene.get_node("World/Soldiers")
	var peer := get_multiplayer().get_unique_id()
	await grant_resources()
	var anchor: Vector2i = await _reachable_site(map, interaction)
	if anchor == Vector2i.MAX:
		printerr("train_soldier: no nearby buildable barracks")
		done(false)
		return

	step("build an owned barracks")
	await click("CanvasLayer1/BuildingsButton")
	await click("CanvasLayer1/BuildPicker/BarracksButton")
	var center := root.get_visible_rect().get_center()
	var finger := root.get_final_transform() * (center + Vector2(-60, -64))
	var from := interaction.build.cost_viewport
	var origin := map.local_to_map(map.to_local(interaction.to_world(from)))
	var shift := to_window(map, map.map_to_local(anchor)) - to_window(map, map.map_to_local(origin))
	await BuildDrag.drag_touch(self, finger, finger + shift)
	var placement: Dictionary = map.structure_placement_at(anchor)
	var train: Button = current_scene.get_node(TRAIN)
	if (
		placement.get("name") != "barracks"
		or placement.get("owner") != peer
		or not await wait_until(func() -> bool: return train.is_visible_in_tree(), 2.0)
	):
		printerr("train_soldier: no owned barracks with a visible Train button at ", anchor)
		done(false)
		return

	done(await _train_and_hold(inventory, requests, train, peer))


func _train_and_hold(
	inventory: Inventory, requests: SoldierRequests, train: Button, peer: int
) -> bool:
	var before := BuildCosts.balance(inventory)
	var seconds := Tuning.value(&"soldiers.train_seconds")
	var cost := Vector2i(
		Tuning.value(&"soldiers.training_wood"), Tuning.value(&"soldiers.training_stone")
	)
	if train.text != "Train %dw %ds" % [cost.x, cost.y]:
		printerr("train_soldier: incorrect Train label: ", train.text)
		return false
	await snapshot("train-ready")

	step("pay wood and stone and wait for training")
	var started := Time.get_ticks_msec()
	await click(TRAIN)
	if (
		BuildCosts.balance(inventory) != before - cost
		or requests.pending_job_count() != 1
		or not requests.soldiers().is_empty()
	):
		printerr("train_soldier: waiting state or training charge did not match")
		return false
	await snapshot("training-paid")
	if not await wait_until(func() -> bool: return requests.soldiers().size() == 1, seconds + 5.0):
		printerr("train_soldier: timed out waiting for the soldier")
		return false
	var soldier: Soldier = requests.soldiers()[0]
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	if elapsed < seconds - 0.15 or soldier.owner_peer != peer or soldier.order != "follow":
		printerr("train_soldier: unexpected trained soldier or wait of %.2f s" % elapsed)
		return false
	await snapshot("soldier-following")

	step("switch the soldier to Hold")
	await click(ORDER)
	if soldier.order != "hold":
		printerr("train_soldier: Hold was not applied")
		return false
	await snapshot("soldier-holding")
	return true


func _reachable_site(map: TileMap, interaction: Interaction) -> Vector2i:
	var placer := ConstructionPlacer.new(map)
	for action in ["", "ui_up", "ui_right", "ui_up", "ui_right", "ui_up", "ui_left"]:
		if not action.is_empty():
			await hold(action, 30)
		var origin := map.local_to_map(map.to_local(hero().global_position))
		for dy in [-4, -3, -2, 1, 2, 3]:
			for dx in [0, 3, -3, 4, -4, 1, -1]:
				var cell := origin + Vector2i(dx, dy)
				if (
					interaction.in_reach(cell)
					and placer.can_place_geometry(BuildCosts.BARRACKS, [cell]).is_empty()
					and SoldierRequests.spawn_cell(map, cell, 0) != Vector2.INF
				):
					return cell
	return Vector2i.MAX
