extends RefCounted
## Executes player sword swings and routes aimed bomb throws.

const MAP_PATH := "/root/Flagoria/World/worldMap"
const TOOL_WHEEL_PATH := "/root/Flagoria/CanvasLayer1/ToolWheel"
const BOMB_PATH := "/root/Flagoria/World/BombThrows"
const AttackAimScript := preload("res://Scripts/player/attack_aim.gd")


static func bomb_armed(player) -> bool:
	var wheel := player.get_node_or_null(TOOL_WHEEL_PATH) as ToolWheel
	return wheel != null and wheel.bomb_armed()


static func throw_bomb(player, aimed_reach: Variant) -> void:
	var bombs := player.get_node_or_null(BOMB_PATH) as BombThrows
	if bombs == null:
		return
	var origin: Vector2 = player.to_global(AttackAimScript.ORIGIN)
	var facing := AttackAimScript.direction_vector(player.lastAnimDirection)
	var reach: Vector2 = (
		bombs.auto_reach(player, origin, facing) if aimed_reach == null else aimed_reach
	)
	bombs.send_throw(origin, reach)


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
	_swing_at_structure(player)
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


static func _swing_at_structure(player) -> void:
	if not player.multiplayer.is_server() or player.health.is_dead():
		return
	var map: TileMap = player.get_node_or_null(MAP_PATH)
	var requests := player.get_node_or_null("../StructureRequests") as StructureRequests
	var buildings := player.get_node_or_null("../BuildingHealth") as BuildingHealth
	if map == null or requests == null or buildings == null:
		return
	var origin: Vector2 = player.global_position
	var swing: float = _facing_to_angle(player.lastAnimDirection) + player.swing_turn
	var reach := AimConeStyle.SWORD_REACH
	var arc := AttackAimScript.ARC
	var wall: Vector2i = map._walls.nearest_in_arc(origin, swing, reach, arc)
	if wall != WallBuilder.NO_WALL:
		requests.host_damage_wall(wall)
		return
	var id := buildings.nearest_in_arc(origin, swing, reach, arc)
	if id > 0:
		buildings.host_damage(
			id, int(Tuning.value(&"building_damage.sword")), int(str(player.name))
		)


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
