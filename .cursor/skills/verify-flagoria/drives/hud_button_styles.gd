extends "res://.cursor/skills/verify-flagoria/drives/hud_round_buttons.gd"
## launch: --seed 49

const ATTACK := "CanvasLayer1/TouchScreenButton"
const JOYSTICK := "CanvasLayer1/player_joystick"


func host_from_menu() -> void:
	if "--menu-reference" in OS.get_cmdline_user_args():
		step("main-menu")
		await snapshot("main-menu")
	await super.host_from_menu()


func run() -> void:
	if not await start_game():
		return
	var parchment: ParchmentMap = current_scene.get_node("CanvasLayer1/ParchmentMap")
	var buildings := current_scene.get_node(BUILDINGS) as Button
	var attack := current_scene.get_node(ATTACK) as TouchScreenButton
	var stick := current_scene.get_node(JOYSTICK)
	var wheel := current_scene.get_node(TOOL_BUTTON).get_parent() as ToolWheel
	var ok := await wait_until(
		func() -> bool:
			return (
				buildings.size.x >= RoundHudStyle.HIT
				and attack.is_visible_in_tree()
				and stick.get_button_pos().length() < 0.35
			),
		5.0
	)
	for path in [BUILDINGS, ATTACK, JOYSTICK, TOOL_BUTTON, MENU_BUTTON, RUN_BUTTON, MAP_BUTTON]:
		ok = current_scene.get_node(path).is_visible_in_tree() and ok
	ok = not parchment.is_open() and not _plank().is_visible_in_tree() and ok

	step("match-start")
	await snapshot("match-start")
	step("build-picker")
	await click(BUILDINGS)
	var opened := await wait_until(func() -> bool: return _plank().is_visible_in_tree(), 2.0)
	ok = opened and _picker_ok() and ok
	await snapshot("build-picker")
	await click(BUILDINGS)

	step("pressed")
	var touch := InputEventScreenTouch.new()
	touch.position = root.get_final_transform() * attack.aim_center()
	touch.pressed = true
	Input.parse_input_event(touch)
	var held := await wait_until(
		func() -> bool: return attack.texture_normal == RoundHudStyle.texture("attack_pressed"), 2.0
	)
	ok = held and ok
	await snapshot("pressed")
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame

	step("tool-wheel")
	var key := InputEventAction.new()
	key.action = &"tool_wheel"
	key.pressed = true
	Input.parse_input_event(key)
	var fan_open := await wait_until(wheel.is_open, 2.0)
	ok = fan_open and ok
	await snapshot("tool-wheel")
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	done(ok)
