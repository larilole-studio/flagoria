extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Phone-sized window: closed tool button, open half-moon, then chop selected.
## bin/launch.sh drives/tool_wheel.gd --seed 11 --display

const WHEEL := "CanvasLayer1/ToolWheel"
const PHONE := Vector2i(844, 390)


func run() -> void:
	if not await start_game():
		return
	var win := current_scene.get_window()
	win.size = PHONE
	await process_frame
	await process_frame
	var wheel: ToolWheel = current_scene.get_node(WHEEL)
	var button: Control = wheel.get_node("ToolButton")
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var ok := await wait_until(func() -> bool: return button.size.y > 1.0, 2.0)
	print("tool wheel: window %s visible %s" % [win.size, current_scene.get_viewport().get_visible_rect().size])

	step("closed")
	ok = ok and not wheel.is_open() and wheel.tool == ToolWheel.Tool.SWORD \
			and interaction.mode == Interaction.Mode.COMBAT \
			and _icon_is(button, "icon_mode_attack.png") and _arc_left(wheel)
	await snapshot("tool-closed")

	step("open")
	var at := to_window(button, button.size * 0.5)
	_touch(at, true)
	await create_timer(0.25).timeout
	ok = ok and wheel.is_open() and _options_visible(wheel) and _arc_left(wheel)
	await snapshot("tool-open")

	step("selected")
	var chop: Control = wheel.get_node("Chop")
	var chop_at := to_window(chop, chop.size * 0.5)
	_drag(chop_at)
	await process_frame
	ok = ok and wheel.highlighted() == ToolWheel.Tool.CHOP
	_touch(chop_at, false)
	await process_frame
	ok = ok and not wheel.is_open() and wheel.tool == ToolWheel.Tool.CHOP \
			and interaction.mode == Interaction.Mode.INTERACT \
			and _icon_is(button, "icon_mode_interact.png") and not wheel.bow_armed()
	await snapshot("tool-selected")
	print("tool wheel: closed sword, open half-moon, selected chop: %s" % ok)
	done(ok)


func _arc_left(wheel: ToolWheel) -> bool:
	var button := (wheel.get_node("ToolButton") as Control).get_global_rect().get_center()
	var previous := -1.0
	for node_name in ToolWheel.NAMES:
		var at := (wheel.get_node(node_name) as Control).get_global_rect().get_center()
		if at.x >= button.x - 8.0 or at.y <= previous:
			printerr("tool wheel: %s at %s button %s" % [node_name, at, button])
			return false
		previous = at.y
	return true


func _options_visible(wheel: ToolWheel) -> bool:
	for node_name in ToolWheel.NAMES:
		var opt := wheel.get_node(node_name) as CanvasItem
		if opt == null or not opt.visible:
			return false
	return true


func _icon_is(button: Control, file_name: String) -> bool:
	var icon: Texture2D = button.get("icon")
	return icon != null and str(icon.resource_path).ends_with(file_name)


func _touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = at
	Input.parse_input_event(event)


func _drag(at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = at
	event.relative = Vector2(0, 8)
	Input.parse_input_event(event)
