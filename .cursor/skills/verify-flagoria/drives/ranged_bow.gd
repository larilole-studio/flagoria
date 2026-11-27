extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Bow aim and the three phases of a pot throw.


func run() -> void:
	if not await start_game():
		return
	var bombs := current_scene.get_node("World/BombThrows") as BombThrows
	var shots := current_scene.get_node("World/RangedShots") as RangedShots
	step("bow")
	var wheel := current_scene.get_node("CanvasLayer1/ToolWheel") as ToolWheel
	await tap_key(KEY_2)
	var ok := await wait_until(wheel.bow_armed, 2.0)

	step("aim")
	var aim: Node = hero().get_node("AttackAim")
	var at := to_window(hero(), AttackAim.ORIGIN)
	at += root.get_final_transform().basis_xform(Vector2(-36, -12))
	_pointer(at)
	await process_frame
	_click_at(at, true)
	ok = await wait_until(func() -> bool: return aim.aiming, 2.0) and ok
	await snapshot("bow-aim")

	step("throw")
	var before := shots.lines_shown()
	_click_at(at, false)
	var flying := await wait_until(
		func() -> bool: return bombs.has_phase(BombThrows.Phase.FLIGHT), 2.0
	)
	ok = ok and flying and shots.lines_shown() == before and not hero().isAttacking
	var mid_arc := Time.get_ticks_msec() + 175
	await wait_until(func() -> bool: return Time.get_ticks_msec() >= mid_arc, 0.4)
	ok = ok and bombs.has_phase(BombThrows.Phase.FLIGHT)
	await snapshot("bomb-mid-arc")

	step("land")
	var landed := await wait_until(
		func() -> bool: return bombs.has_phase(BombThrows.Phase.FUSE), 2.0
	)
	ok = ok and landed
	await snapshot("bomb-landed-fuse")

	step("explode")
	var exploded := await wait_until(
		func() -> bool: return bombs.has_phase(BombThrows.Phase.BLAST), 2.0
	)
	await create_timer(0.07).timeout
	ok = ok and exploded and bombs.has_phase(BombThrows.Phase.BLAST)
	await snapshot("bomb-explosion")
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
