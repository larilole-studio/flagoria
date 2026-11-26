## fixture
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 42


func run() -> void:
	if not await start_game():
		return
	var hud := current_scene.find_child("ResourceHud", true, false) as ResourceHud
	var inventory := current_scene.get_node("Inventory") as Inventory

	step("new-world")
	var ok := hud.is_visible_in_tree() and hud.label.text == "0" and hud.stone_label.text == "0"
	await snapshot("zero-stone")

	step("add-stone")
	inventory.add(Inventory.STONE, 12)
	ok = ok and hud.label.text == "0" and hud.stone_label.text == "12"
	await snapshot("after-stone-add")
	done(ok)
