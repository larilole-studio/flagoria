extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Bow aim and one shot. Start with `bin/launch.sh drives/ranged_bow.gd --seed 11`.

const BOW := "CanvasLayer1/BowButton"


func run() -> void:
	if not await start_game():
		return
	var ok := true
	var shots: RangedShots = current_scene.get_node("World/RangedShots")
	step("bow")
	var button: BaseButton = current_scene.get_node(BOW)
	var placed := await wait_until(func() -> bool: return button.size.y > 1.0, 2.0)
	await click(BOW)
	var armed := await wait_until(func() -> bool: return button.button_pressed, 2.0)
	print("ranged_bow: placed %s armed %s at %s" % [placed, armed, button.position])
	ok = ok and placed and armed and not hero().isAttacking

	step("aim")
	var aim: Node = hero().get_node("AttackAim")
	var at := to_window(hero(), AttackAim.ORIGIN)
	at += root.get_final_transform().basis_xform(Vector2(-36, -12))
	_pointer(at)
	await process_frame
	_click_at(at, true)
	var aiming := await wait_until(func() -> bool: return aim.aiming, 2.0)
	print("ranged_bow: aiming %s toward %s" % [aiming, aim.aim_direction()])
	ok = ok and aiming
	await snapshot("bow-aim")

	step("shot")
	var before := shots.lines_shown()
	_click_at(at, false)
	await process_frame
	var showed := shots.lines_shown() > before
	var swung: bool = bool(hero().get("isAttacking"))
	print("ranged_bow: line %s sword %s" % [showed, swung])
	ok = ok and showed and not swung
	await snapshot("bow-hit")
	done(ok)


func _pointer(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)


func _click_at(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)
