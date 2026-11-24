extends RefCounted
## Executes player sword swings and routes aimed bow shots.

const MAP_PATH := "/root/Flagoria/World/worldMap"
const TOOL_WHEEL_PATH := "/root/Flagoria/CanvasLayer1/ToolWheel"
const RANGED_PATH := "/root/Flagoria/World/RangedShots"
const AttackAimScript := preload("res://Scripts/player/attack_aim.gd")


static func try_bow_shot(player, direction: String, angle: float) -> bool:
	var wheel: Node = player.get_node_or_null(TOOL_WHEEL_PATH)
	if wheel == null or not wheel.has_method("bow_armed") or not bool(wheel.bow_armed()):
		return false
	var shots: Node = player.get_node_or_null(RANGED_PATH)
	if shots != null and shots.has_method("send_shot"):
		shots.send_shot(
			player.global_position + AttackAimScript.ORIGIN,
			_bow_aim(direction, angle, player.lastAnimDirection)
		)
	return true


static func _bow_aim(direction: String, angle: float, facing: String) -> Vector2:
	if not is_nan(angle):
		return Vector2.from_angle(angle)
	var named := AttackAimScript.direction_vector(direction)
	if named != Vector2.ZERO:
		return named
	return AttackAimScript.direction_vector(facing)


static func swing(player, direction: String, angle: float) -> void:
	# `direction` is Up, Down, Left or Right from an aimed attack; anything
	# else, or none (Space, the touch button), swings in the facing direction.
	# `angle` (radians) is the exact aim: the swing plays `direction`'s
	# animation turned to it, and the sprite still faces `direction`. An angle
	# that is not finite or not within 45 degrees of `direction` is rejected:
	# the swing goes the facing direction, as for an unknown direction.
	# Every peer, the server included, checks and swings the same way, and
	# the server's copy still decides what the sword hits.
	player.swing_turn = 0.0
	if direction in AttackAimScript.DIRECTIONS:
		var turn := 0.0 if is_nan(angle) else AttackAimScript.turn_to(direction, angle)
		if not is_nan(turn):
			player.lastAnimDirection = direction
			player.swing_turn = turn
	player.animations.stop()
	player.combat_sfx.play_event("swing")
	player.animations.play("attack" + player.lastAnimDirection)
	player.isAttacking = true
	player.weapon.visible = true
	player.sword_shape.set_deferred("disabled", false)  # the sword only hits during a swing
	_swing_world_decor(player, direction, angle)
	await player.animations.animation_finished
	player.weapon.visible = false
	player.sword_shape.set_deferred("disabled", true)
	player.isAttacking = false
	player.swing_turn = 0.0


static func turn_swing(weapon: Node2D, animations: AnimationPlayer, swing_turn: float) -> void:
	## After each animation step: turn the swing's weapon about the aim
	## origin by swing_turn, so its hitbox follows the exact aim angle.
	if swing_turn == 0.0 or not str(animations.current_animation).begins_with("attack"):
		return
	var origin := AttackAimScript.ORIGIN
	weapon.position = origin + (weapon.position - origin).rotated(swing_turn)
	weapon.rotation += swing_turn


static func _swing_world_decor(player, direction: String, angle: float) -> void:
	## Combat swing: destroy walkable stones in the aim arc (#198).
	var map: Node = player.get_node_or_null(MAP_PATH)
	if map == null or player.health.is_dead():
		return
	var facing := (
		direction if direction in AttackAimScript.DIRECTIONS else str(player.lastAnimDirection)
	)
	var swing := _facing_to_angle(facing)
	if not is_nan(angle) and facing in AttackAimScript.DIRECTIONS:
		var turn := AttackAimScript.turn_to(facing, angle)
		if not is_nan(turn):
			swing += turn
	map._object_removals.cells_in_arc(
		player.global_position, swing, AimConeStyle.SWORD_REACH, AttackAimScript.ARC, true
	)
	if not player.multiplayer.is_server():
		return
	var requests: StructureRequests = (
		player.get_node_or_null("../StructureRequests") as StructureRequests
	)
	if requests == null:
		return
	var cell: Vector2i = map._walls.nearest_in_arc(
		player.global_position, swing, AimConeStyle.SWORD_REACH, AttackAimScript.ARC
	)
	if cell == WallBuilder.NO_WALL:
		return
	requests.host_damage_wall(cell)


static func _facing_to_angle(facing: String) -> float:
	match facing:
		"Up":
			return Vector2.UP.angle()
		"Left":
			return Vector2.LEFT.angle()
		"Right":
			return Vector2.RIGHT.angle()
		_:
			return Vector2.DOWN.angle()
