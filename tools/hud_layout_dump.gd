extends RefCounted
## Stock HUD snapshots and their shared overlap-test fixture.

const SIZES := [Vector2i(2400, 1080), Vector2i(1920, 1080), Vector2i(1600, 720), Vector2i(2048, 1536)]


static func dump(tree: SceneTree) -> String:
	var window := tree.root
	var original_size := window.size
	var layout := window.get_node("HudLayout")
	layout.forget_memory()
	var scene := await play_scene(tree)
	var hud: CanvasLayer = scene.get_node("CanvasLayer1")
	var lines: Array[String] = []
	var failures := 0
	for size: Vector2i in SIZES:
		await resize(tree, size)
		var visit := func(state: String, state_open: bool) -> int:
			if not state_open:
				printerr("HUD layout: %s failed at %dx%d" % [state, size.x, size.y])
				return 1
			var stretch := window.get_stretch_transform()
			var targets := collect_targets(hud)
			for node: Node in targets:
				var rect: Rect2 = stretch * targets[node]
				lines.append("%dx%d %s %s %.1f %.1f %.1f %.1f" % [
					size.x, size.y, state, node.name, rect.position.x, rect.position.y,
					rect.size.x, rect.size.y,
				])
			return 0
		failures += await visit_states(hud, visit)
	scene.queue_free()
	await tree.process_frame
	window.size = original_size
	layout.load_from_disk()
	lines.sort()
	return "\n".join(lines) + "\n" if failures == 0 else ""


static func play_scene(tree: SceneTree) -> Node:
	var scene: Node = load("res://flagoria_main.tscn").instantiate()
	tree.root.add_child(scene)
	var menu: Control = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	scene.get_node("CanvasLayer1").show()
	var params := MapGenParams.make_defaults()
	params.altitude_seed = 49
	params.moisture_seed = 49
	params.temperature_seed = 49
	params.items_seed = 49
	params.biome_seed = 49
	params.biome_frequency = 0.003
	scene.world_params = params
	scene.get_node("World/worldMap").apply_map_params(params)
	await tree.process_frame
	scene.add_player(scene.multiplayer.get_unique_id())
	await tree.process_frame
	await tree.process_frame
	return scene


static func resize(tree: SceneTree, size: Vector2i) -> void:
	tree.root.size = size
	await tree.process_frame
	await tree.process_frame


static func visit_states(hud: CanvasLayer, visit: Callable, custom := false) -> int:
	var tree := hud.get_tree()
	var fail: int = visit.call("default", true)
	var buildings: BaseButton = hud.get_node("BuildingsButton")
	buildings.set_pressed(true)
	await tree.process_frame
	fail += visit.call("buildings_open", hud.get_node("BuildPicker").visible)
	buildings.set_pressed(false)
	if custom:
		return fail
	var scores: BaseButton = hud.find_child("ScoreboardToggle", true, false)
	scores.pressed.emit()
	await tree.process_frame
	fail += visit.call("scoreboard_open", hud.get_node("ScoreboardPanel").is_open())
	scores.pressed.emit()
	return fail


static func collect_targets(hud: CanvasLayer) -> Dictionary:
	var targets := {}
	_collect_targets(hud, targets)
	return targets


static func _collect_targets(parent: Node, targets: Dictionary) -> void:
	for node in parent.get_children():
		if node is CanvasItem and (not node.is_visible_in_tree() or node.is_queued_for_deletion()):
			continue
		# The wheel options ignore pointer input. The wheel selects by drag angle.
		if node is MapWoodButton or (node is BaseButton and not node.disabled
				and node.mouse_filter != Control.MOUSE_FILTER_IGNORE):
			targets[node] = node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size)
		elif node.has_method("start_reach"):
			var radius := Vector2.ONE * float(node.start_reach())
			var center: Vector2 = node.get_global_transform_with_canvas().origin
			targets[node] = Rect2(center - radius, radius * 2.0)
			# The joystick knob is drawn with a TouchScreenButton but moves with the stick.
			continue
		elif node is TouchScreenButton:
			var size: Vector2 = node.texture_normal.get_size() if node.texture_normal else Vector2.ZERO
			var rect := Rect2(Vector2.ZERO, size)
			if node.shape != null:
				rect = node.shape.get_rect()
				if node.shape_centered:
					rect.position += size * 0.5
			targets[node] = node.get_global_transform_with_canvas() * rect
		_collect_targets(node, targets)
