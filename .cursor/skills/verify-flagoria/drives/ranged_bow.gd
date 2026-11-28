extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 49
## Touch bomb aim, the clay pot HUD icon, cooldown, and a tap at a nearby enemy.


func run() -> void:
	if not await start_game():
		return
	var bombs := current_scene.get_node("World/BombThrows") as BombThrows
	var wheel := current_scene.get_node("CanvasLayer1/ToolWheel") as ToolWheel
	var aim := hero().get_node("AttackAim") as AttackAim
	step("arm bomb")
	await tap_key(KEY_2)
	var ok := await wait_until(wheel.bomb_armed, 2.0)

	step("hud icon")
	var tool_button: Button = wheel.get_node("ToolButton")
	ok = ok and _icon_is(tool_button, "wheel_bomb")
	await snapshot("bomb-hud-icon")

	step("open wheel")
	var at := to_window(tool_button, tool_button.size * 0.5)
	_touch_at(at, true)
	ok = await wait_until(wheel.is_open, 2.0) and ok
	await snapshot("bomb-wheel-open")
	_touch_at(at, false)
	await process_frame
	ok = wheel.bomb_armed() and not wheel.is_open() and ok

	var center: Vector2 = root.get_final_transform() * aim.attack_button().aim_center()
	if not await _tap_enemy(bombs, center):
		done(false)
		return

	if not await _cooldown_throw(bombs, center):
		done(false)
		return

	var drag_direction := Vector2(-1, -0.65).normalized()
	_touch_at(center, true)
	for preview in [["short", 44.0, 58.7], ["medium", 65.0, 86.7], ["long", 145.0, 160.0]]:
		step("%s drag" % preview[0])
		_drag_to(center + drag_direction * preview[1])
		await process_frame
		await process_frame
		ok = aim.aiming and absf(aim.bomb_reach().length() - preview[2]) < 1.0 and ok
		await snapshot("bomb-preview-" + preview[0])

	step("throw")
	_touch_at(center + drag_direction * 145.0, false)
	var flying := await wait_until(
		func() -> bool: return bombs.has_phase(BombThrows.Phase.FLIGHT), 2.0
	)
	ok = ok and flying and not hero().isAttacking
	await create_timer(0.14).timeout
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
	await wait_until(func() -> bool: return not bombs.has_phase(BombThrows.Phase.BLAST), 2.0)

	done(ok)


func _tap_enemy(bombs: BombThrows, center: Vector2) -> bool:
	step("tap at a nearby enemy")
	var target := bombs.nearest_enemy(hero(), hero().to_global(AttackAim.ORIGIN))
	if target == null:
		printerr("ranged_bow: no enemy in range for the tap")
		return false
	print("ranged_bow: tap target at ", target.global_position)
	_touch_at(center, true)
	await process_frame
	_touch_at(center, false)
	if not await wait_until(func() -> bool: return bombs.has_phase(BombThrows.Phase.FUSE), 2.0):
		return false
	await process_frame
	await snapshot("bomb-tap-auto-target")
	_touch_at(center, true)
	await process_frame
	_touch_at(center, false)
	await process_frame
	var sender := str(hero().name).to_int()
	if bombs.is_ready(sender) or bombs.has_phase(BombThrows.Phase.FLIGHT):
		printerr("ranged_bow: second throw during cooldown was accepted")
		return false
	await snapshot("bomb-cooldown-rejected")
	if not await wait_until(func() -> bool: return bombs.has_phase(BombThrows.Phase.BLAST), 2.0):
		return false
	return await wait_until(func() -> bool: return not bombs.has_phase(BombThrows.Phase.BLAST), 2.0)


func _cooldown_throw(bombs: BombThrows, center: Vector2) -> bool:
	step("throw after cooldown")
	var sender := str(hero().name).to_int()
	if not await wait_until(func() -> bool: return bombs.is_ready(sender), 3.0):
		printerr("ranged_bow: cooldown did not elapse")
		return false
	_touch_at(center, true)
	await process_frame
	_touch_at(center, false)
	if not await wait_until(func() -> bool: return bombs.has_phase(BombThrows.Phase.FUSE), 2.0):
		printerr("ranged_bow: throw after cooldown did not land")
		return false
	await process_frame
	await snapshot("bomb-cooldown-ready")
	if not await wait_until(func() -> bool: return bombs.has_phase(BombThrows.Phase.BLAST), 2.0):
		return false
	return await wait_until(func() -> bool: return not bombs.has_phase(BombThrows.Phase.BLAST), 2.0)


func _icon_is(button: Button, sprite: String) -> bool:
	var style := button.get_theme_stylebox("normal") as StyleBoxTexture
	return (
		style != null
		and (
			style.texture == RoundHudStyle.texture(sprite + "_normal")
			or style.texture == RoundHudStyle.texture(sprite + "_selected")
		)
	)


func _touch_at(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag_to(point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point
	Input.parse_input_event(event)
