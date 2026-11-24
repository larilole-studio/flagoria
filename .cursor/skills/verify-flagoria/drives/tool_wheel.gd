extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Phone-sized window: closed tool button, open half-moon, then chop selected.
## bin/launch.sh drives/tool_wheel.gd --seed 11 --display

const WHEEL := "CanvasLayer1/ToolWheel"
const PHONE := Vector2i(844, 390)


func run() -> void:
	# Exercise the touch handlers without synthesized mouse events.
	Input.emulate_mouse_from_touch = false
	if not await start_game():
		return
	var win := current_scene.get_window()
	win.size = PHONE
	await process_frame
	await process_frame
	var wheel: ToolWheel = current_scene.get_node(WHEEL)
	var button: Button = wheel.get_node("ToolButton")
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	if not await wait_until(func() -> bool: return button.size.y > 1.0, 2.0):
		_fail("tool button has no size")
		return
	print(
		(
			"tool wheel: window %s visible %s"
			% [win.size, current_scene.get_viewport().get_visible_rect().size]
		)
	)

	step("closed")
	if (
		not _selected(wheel, interaction, ToolWheel.Tool.SWORD)
		or not _icon_is(button, "wheel_sword")
		or not _arc_left(wheel)
	):
		_fail("wheel did not start closed with the sword icon and left arc")
		return
	await snapshot("tool-closed")

	var at := to_window(button, button.size * 0.5)
	step("first-tap")
	await _tap(at)
	if not _selected(wheel, interaction, ToolWheel.Tool.SWORD):
		_fail("expected sword after first tap, got %s" % ToolWheel.NAMES[wheel.tool])
		return

	step("hold")
	_touch(at, true)
	if (
		not await wait_until(func() -> bool: return wheel.is_open(), 2.0)
		or not _options_visible(wheel)
		or not _arc_left(wheel)
		or wheel.highlighted() != ToolWheel.Tool.SWORD
	):
		_fail("hold did not open the arc with sword highlighted")
		return
	await snapshot("tool-open")
	_touch(at, false)
	await process_frame
	if not _selected(wheel, interaction, ToolWheel.Tool.SWORD):
		_fail("expected sword after hold release, got %s" % ToolWheel.NAMES[wheel.tool])
		return

	step("drag-select")
	for tool in [ToolWheel.Tool.BOW, ToolWheel.Tool.SWORD, ToolWheel.Tool.CHOP]:
		var option: Control = wheel.get_node(ToolWheel.NAMES[tool])
		var target := to_window(option, option.size * 0.5)
		_touch(at, true)
		await process_frame
		_drag(target)
		await process_frame
		var highlighted: bool = wheel.is_open() and wheel.highlighted() == tool
		_touch(target, false)
		await process_frame
		if not highlighted or not _selected(wheel, interaction, tool):
			_fail("touch drag did not highlight and select %s" % ToolWheel.NAMES[tool])
			return
	if not _icon_is(button, "wheel_chop"):
		_fail("chop selection did not update the button icon")
		return
	await snapshot("tool-selected")

	step("swap")
	await _tap(at)
	if not _selected(wheel, interaction, ToolWheel.Tool.SWORD):
		_fail("expected sword after swap, got %s" % ToolWheel.NAMES[wheel.tool])
		return
	await _tap(at, Vector2(3, 0))
	if not _selected(wheel, interaction, ToolWheel.Tool.CHOP):
		_fail("expected chop after second swap, got %s" % ToolWheel.NAMES[wheel.tool])
		return
	done(true)


func _selected(wheel: ToolWheel, interaction: Interaction, tool: ToolWheel.Tool) -> bool:
	var mode := (
		Interaction.Mode.INTERACT if tool == ToolWheel.Tool.CHOP else Interaction.Mode.COMBAT
	)
	return (
		not wheel.is_open()
		and wheel.tool == tool
		and interaction.mode == mode
		and wheel.bow_armed() == (tool == ToolWheel.Tool.BOW)
	)


func _tap(at: Vector2, offset := Vector2.ZERO) -> void:
	_touch(at, true)
	_touch(at + offset, false)
	await process_frame


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


func _icon_is(button: Button, sprite: String) -> bool:
	var style := button.get_theme_stylebox("normal") as StyleBoxTexture
	return (
		style != null
		and (
			style.texture == RoundHudStyle.texture(sprite + "_normal")
			or style.texture == RoundHudStyle.texture(sprite + "_selected")
		)
	)


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
