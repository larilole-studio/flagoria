## fixture
extends "res://.cursor/skills/verify-flagoria/drives/hud_round_buttons.gd"
## launch: --seed 49
## The final capture temporarily blocks HUD input and disables visible buttons.

const ATTACK := "CanvasLayer1/TouchScreenButton"
const JOYSTICK := "CanvasLayer1/player_joystick"


func run() -> void:
	if not await start_game():
		return
	var parchment: ParchmentMap = current_scene.get_node("CanvasLayer1/ParchmentMap")
	var buildings := current_scene.get_node(BUILDINGS) as Button
	var attack := current_scene.get_node(ATTACK) as TouchScreenButton
	var stick := current_scene.get_node(JOYSTICK)
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
	var picker_closed := await wait_until(
		func() -> bool: return not _plank().is_visible_in_tree(), 2.0
	)
	ok = picker_closed and ok

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

	step("disabled")
	var layer := current_scene.get_node("CanvasLayer1") as CanvasLayer
	var layout := root.get_node("HudLayout")
	layout.edit_begin(layer)
	RoundHudStyle.apply_attack(attack)
	RoundHudStyle.apply_joystick(stick)

	var disabled_before: Dictionary[Button, bool] = {}
	for path in [BUILDINGS, RUN_BUTTON, TOOL_BUTTON, MAP_BUTTON, MENU_BUTTON]:
		var button := current_scene.get_node(path) as Button
		disabled_before[button] = button.disabled
		button.disabled = true
		ok = button.get_draw_mode() == BaseButton.DRAW_DISABLED and ok
	ok = (
		attack.texture_normal == RoundHudStyle.texture("attack_disabled")
		and stick.joystick.texture == RoundHudStyle.texture("joystick_base_disabled")
		and stick.touch.texture_normal == RoundHudStyle.texture("joystick_knob_disabled")
		and ok
	)
	await snapshot("disabled")

	for button in disabled_before:
		button.disabled = disabled_before[button]
	layout.edit_end()
	RoundHudStyle.apply_attack(attack)
	RoundHudStyle.apply_joystick(stick)
	done(ok)
