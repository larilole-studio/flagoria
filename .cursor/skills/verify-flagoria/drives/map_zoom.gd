extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 42
## World pinch through the window input path, followed by the parchment map.


func run() -> void:
	if not await start_game():
		return
	var camera: Camera2D = hero().get_node("Camera2D")
	var chart: MapChart = current_scene.get_node(MAP_CHART)
	var parchment: ParchmentMap = current_scene.get_node("CanvasLayer1/ParchmentMap")
	if not await wait_until(func() -> bool: return chart.explored.explored_count() > 0, 5.0):
		done(false)
		return
	var default_zoom := camera.zoom
	var window := Vector2(root.size)
	var a := window * Vector2(0.4, 0.5)
	var b := window * Vector2(0.6, 0.5)
	var wide := window * Vector2(0.8, 0.5)
	var narrow := window * Vector2(0.45, 0.5)
	var hud := current_scene.get_node("CanvasLayer1")
	var ok := not hud.has_node("MinimapPanel") and not hud.has_node("MinimapButton")
	step("default")
	await snapshot("default")
	step("pinch-out")
	await _touch(0, a, true)
	await _touch(1, a, true)
	await _drag(1, b)
	await _drag(1, wide)
	var zoom_in := camera.zoom.x / default_zoom.x
	var rendered_in := await _camera_settled(camera)
	await snapshot("zoomed-in")
	step("pinch-in")
	await _drag(1, narrow)
	var zoom_out := camera.zoom.x / default_zoom.x
	var rendered_out := await _camera_settled(camera)
	await snapshot("zoomed-out")
	await _touch(0, a, false)
	await _touch(1, narrow, false)
	print("map zoom: window %s, factor 1.0 -> %s -> %s" % [root.size, zoom_in, zoom_out])
	ok = ok and rendered_in and rendered_out \
			and is_equal_approx(zoom_in, 2.0) and is_equal_approx(zoom_out, 0.75)
	ok = ok and hud.get_node("player_joystick").ongoing_drag == -1

	step("parchment")
	await click("CanvasLayer1/MapButton")
	var opened := parchment.is_open()
	await snapshot("parchment")
	var default_cell_px := parchment.cell_px
	await _touch(0, a, true)
	await _touch(1, b, true)
	await _drag(1, wide)
	var sheet_zoomed := parchment.cell_px > default_cell_px
	await _touch(0, a, false)
	await _touch(1, wide, false)
	print("map zoom: parchment open %s, sheet %s -> %s px, camera factor %s"
			% [opened, default_cell_px, parchment.cell_px, camera.zoom.x / default_zoom.x])
	await click("CanvasLayer1/ParchmentMap/CloseButton")
	done(ok and opened and sheet_zoomed and not parchment.is_open()
			and is_equal_approx(camera.zoom.x / default_zoom.x, zoom_out))


func _camera_settled(camera: Camera2D) -> bool:
	return await wait_until(func() -> bool:
		return is_equal_approx(camera.get_canvas_transform().get_scale().x, camera.zoom.x)
	, 2.0)


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	Input.parse_input_event(event)
	await process_frame
