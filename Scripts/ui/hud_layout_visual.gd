class_name HudLayoutVisual
extends RefCounted
## Full on-screen rects for HUD layout overlap checks (joystick ring, attack art).


static func blocks_hud_actions() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var hl := tree.root.get_node_or_null("HudLayout")
	return hl != null and hl.blocks_hud_actions()


static func control_rect(id: String, layer: CanvasLayer, paths: Dictionary) -> Rect2:
	var node := layer.get_node_or_null(paths[id])
	if node == null:
		return Rect2()
	match id:
		"joystick":
			return _joystick_rect(node as Node2D)
		"attack":
			var atk := node as TouchScreenButton
			if atk.texture_normal != null:
				var sz: Vector2 = atk.texture_normal.get_size() * atk.global_scale
				return Rect2(atk.global_position - sz * 0.5, sz)
			return atk.get_global_rect()
		_:
			var ctrl := node as Control
			return ctrl.get_global_rect() if ctrl != null else Rect2()


static func dismiss_popups(layer: CanvasLayer) -> void:
	var panel := layer.get_node_or_null("MinimapPanel") as MinimapPanel
	if panel != null:
		panel.collapse_panel()
		if panel.parchment != null and panel.parchment.is_open():
			panel.parchment.hide_map()
	var map_btn := layer.get_node_or_null("MinimapButton") as BaseButton
	if map_btn != null:
		map_btn.set_pressed_no_signal(false)
	var buildings := layer.get_node_or_null("BuildingsButton") as BaseButton
	if buildings != null:
		buildings.set_pressed(false)
	var scores := layer.get_node_or_null("ScoreboardPanel") as ScoreboardPanel
	if scores != null:
		scores.close()
	var wheel := layer.get_node_or_null("ToolWheel")
	if wheel != null and wheel.has_method("close"):
		wheel.close()


static func _joystick_rect(stick: Node2D) -> Rect2:
	var ring := stick.get_node_or_null("joystick") as Sprite2D
	if ring != null and ring.texture != null:
		var sz: Vector2 = ring.texture.get_size() * stick.global_scale
		return Rect2(stick.global_position - sz * 0.5, sz)
	var r: float = stick.start_reach() if stick.has_method("start_reach") else 64.0
	return Rect2(stick.global_position - Vector2(r, r), Vector2(r, r) * 2.0)


static func nearest_clear_rect(rect: Rect2, view: Rect2, occupied: Array[Rect2]) -> Rect2:
	var last := (view.end - rect.size).max(view.position)
	rect.position = rect.position.clamp(view.position, last)
	if rect_clear(rect, view, occupied):
		return rect
	var closest := rect
	var distance := INF
	for y in range(ceili(view.position.y), floori(last.y) + 1, 4):
		for x in range(ceili(view.position.x), floori(last.x) + 1, 4):
			var point := Vector2(x, y)
			var candidate_distance := point.distance_squared_to(rect.position)
			if candidate_distance >= distance:
				continue
			var candidate := Rect2(point, rect.size)
			if rect_clear(candidate, view, occupied):
				closest = candidate
				distance = candidate_distance
	return closest


static func rect_clear(rect: Rect2, view: Rect2, occupied: Array[Rect2], spacing := 0.0) -> bool:
	if not view.encloses(rect):
		return false
	for other in occupied:
		if rect.intersects(other) or rect.get_center().distance_to(other.get_center()) < spacing:
			return false
	return true
