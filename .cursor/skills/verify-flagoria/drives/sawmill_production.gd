## fixture
## launch: --seed 4
extends "res://.cursor/skills/verify-flagoria/drives/place_sawmill.gd"

const WorldChunks := preload("res://Scripts/world/world_chunks.gd")


func run() -> void:
	if not await start_game():
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var inventory: Inventory = current_scene.get_node(INVENTORY)
	var hud: ResourceHud = current_scene.find_child("ResourceHud", true, false)
	var target: Variant = _production_site(map, interaction)
	for action in ["ui_down", "ui_right", "ui_up", "ui_left", "ui_left", "ui_down"]:
		if target != null:
			break
		await _walk(action)
		target = _production_site(map, interaction)
	if target == null:
		printerr("sawmill production: no reachable sawmill site")
		done(false)
		return

	step("grant placement stone and place a sawmill through Buildings")
	inventory.add(Inventory.STONE, 15)
	await click(BUILDINGS)
	await click(SAWMILL_BUTTON)
	await _drag(map, interaction, target)
	var sawmill: Dictionary = map.structure_placement_at(target)
	if (
		sawmill.get("name") != "sawmill"
		or sawmill.get("owner") != get_multiplayer().get_unique_id()
		or not map.sawmill_production.is_producing(sawmill["id"])
		or not _shows_resources(inventory, hud, 0)
	):
		printerr("sawmill production: expected a placed sawmill with zero wood and zero stone")
		done(false)
		return

	step("snapshot before the first payout")
	await snapshot("before-cycle")
	step("advance the host world clock by one minute")
	WorldChunks.refresh(map, 60.0)
	var credited := _shows_resources(inventory, hud, 1)
	await snapshot("after-cycle")
	if not credited:
		printerr("sawmill production: expected one wood and zero stone in the inventory and HUD")
	done(credited)


func _production_site(map: TileMap, interaction: Interaction) -> Variant:
	var placer := ConstructionPlacer.new(map)
	for cell in _nearby_cells(map, interaction):
		if placer.can_place_geometry(BuildCosts.SAWMILL, [cell]).is_empty():
			return cell
	return null


func _shows_resources(inventory: Inventory, hud: ResourceHud, wood: int) -> bool:
	return (
		inventory.count_of(Inventory.WOOD) == wood
		and inventory.count_of(Inventory.STONE) == 0
		and hud.label.is_visible_in_tree()
		and hud.stone_label.is_visible_in_tree()
		and hud.label.text == str(wood)
		and hud.stone_label.text == "0"
	)
