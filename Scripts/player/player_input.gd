extends RefCounted
## Reads movement controls and applies the walk, run and joystick speed rules.


static func keyboard_axis() -> Vector2:
	var x := int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	var y := int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	return Vector2(x, y)


static func joystick_axis(joystick) -> Vector2:
	## The touch joystick's direction while a finger holds it, read every
	## physics frame: the joystick only signals on touch and drag events, so a
	## finger held still sends nothing.
	if not is_instance_valid(joystick) or joystick.ongoing_drag == -1:
		return Vector2.ZERO
	return joystick.get_button_pos().normalized()


static func _speed_scale(player: Node) -> float:
	## Run button on this hero's HUD. Missing when a hero is built on its own,
	## which keeps the walk cap. Joystick direction is not part of this scale.
	var button := player.get_node_or_null(^"../../CanvasLayer1/RunButton")
	if button != null and button.has_method("speed_scale"):
		return float(button.speed_scale())
	return 1.0


static func move_player(player, delta) -> void:
	player.input = player.get_input_axis()
	var max_speed := int(Tuning.value(&"movement.keyboard_speed"))
	if player.input == Vector2.ZERO:
		player.input = player.get_joystick_axis()
		if player.input != Vector2.ZERO:
			max_speed = int(Tuning.value(&"movement.joystick_speed"))
	var scale := _speed_scale(player)
	max_speed *= scale

	if player.input == Vector2.ZERO:  # no input
		if player.velocity.length() > (player.FRICTION * delta):
			# if we are moving we will slow down
			player.velocity -= player.velocity.normalized() * (player.FRICTION * delta)
		else:
			player.velocity = Vector2.ZERO
	else:  # moving the player
		player.velocity += (player.input * player.ACCEL * scale * delta)
		player.velocity = player.velocity.limit_length(max_speed)

	player.move_and_slide()


static func walk_direction(velocity: Vector2) -> String:
	## The walk animation's facing for the owner's current velocity.
	if velocity.x < 0:
		return "Left"
	if velocity.x > 0:
		return "Right"
	if velocity.y < 0:
		return "Up"
	return "Down"
