extends "res://tests/helpers/test_helpers.gd"
## Resource HUD in the main scene.


func _test_resource_hud_in_scene() -> int:
	## In the real main scene, the local player's spawn shows the wood counter
	## centred at the top at the hearts' scale, starting at 0, and wood added
	## to the inventory, or spent from it, updates it.
	print("-- test_resource_hud_in_scene")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.add_player(scene.multiplayer.get_unique_id())
	await process_frame
	var plate := scene.get_node_or_null("CanvasLayer1/StatusPlate") as StatusPlateHud
	var hud: ResourceHud = _hud_on_canvas(scene, "ResourceHud") as ResourceHud
	var hearts: Control = _hud_on_canvas(scene, "HeartsHud") as Control
	var menu_rect: Rect2 = scene.get_node("CanvasLayer1/InGameMenu").menu_button.get_global_rect()
	hud.follow_hearts()
	var hud_rect := hud.get_global_rect()
	if (
		not hud.visible
		or hud.label.text != "0"
		or hud.scale != hearts.scale
		or plate == null
		or not plate.visible
		or hud.get_parent() != plate
		or hud_rect.intersects(menu_rect)
		or not plate.get_theme_stylebox("panel") is StyleBoxEmpty
		or hud.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	):
		printerr(
			(
				"FAIL resource_hud_in_scene: counter visible %s text '%s' at %s plate %s"
				% [hud.visible, hud.label.text, hud_rect, plate]
			)
		)
		fail += 1
	var inventory: Inventory = scene.get_node("Inventory")
	if (
		inventory.add(Inventory.WOOD, 3) != 3
		or inventory.count_of(Inventory.WOOD) != 3
		or hud.label.text != "3"
	):
		printerr("FAIL resource_hud_in_scene: counter '%s' after 3 wood" % hud.label.text)
		fail += 1
	if not inventory.spend(Inventory.WOOD, 2) or hud.label.text != "1":
		printerr("FAIL resource_hud_in_scene: counter '%s' after spending 2 wood" % hud.label.text)
		fail += 1
	var score: Control = _hud_on_canvas(scene, "ScoreHud") as Control
	var star := plate.get_node_or_null("Star") as Control
	var inset := StatusPlateHud.safe_inset(plate)
	var content := hearts.get_global_rect().merge(hud.get_global_rect())
	if score != null:
		content = content.merge(score.get_global_rect())
	var left := content.position.x - inset.x
	var top := content.position.y - inset.y
	var row_h := maxf(hearts.size.y, hud.size.y)
	if score != null:
		row_h = maxf(row_h, score.size.y)
	if star != null:
		row_h = maxf(row_h, star.size.y)
	if (
		not is_equal_approx(left, top)
		or not is_equal_approx(left, StatusPlateHud.MARGIN)
		or not is_equal_approx(plate.size.y, row_h)
	):
		printerr(
			(
				"FAIL resource_hud_in_scene: margins left=%s top=%s inset=%s plate=%s row_h=%s"
				% [left, top, inset, plate.get_global_rect(), row_h]
			)
		)
		fail += 1
	var notch := StatusPlateHud.safe_inset_from(
		Rect2(0, 48, 1920, 1032), Vector2.ZERO, Vector2(1920, 1080), Vector2(480, 270)
	)
	if notch != Vector2(0, 12):
		printerr("FAIL resource_hud_in_scene: safe inset %s, want (0, 12)" % notch)
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_resource_hud_in_scene")
	return fail
