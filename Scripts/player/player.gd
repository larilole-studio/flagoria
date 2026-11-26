extends CharacterBody2D

const PlayerCamera := preload("res://Scripts/player/player_camera.gd")
const PlayerCombat := preload("res://Scripts/player/player_combat.gd")
const PlayerHud := preload("res://Scripts/player/player_hud.gd")
const PlayerInput := preload("res://Scripts/player/player_input.gd")
const AttackAimScript := preload("res://Scripts/player/attack_aim.gd")
const PlayerWallDraw := preload("res://Scripts/player/player_wall_draw.gd")

const ACCEL = 120
const FRICTION = 95

var input = Vector2.ZERO
var _wall_draw := PlayerWallDraw.new()

@onready var camera = $Camera2D
@onready var joystick = get_node_or_null(^"/root/Flagoria/CanvasLayer1/player_joystick")  # none when the hero runs outside the game scene, as in tests
@onready var animations = $AnimationPlayer
@onready var weapon = $weapon
@onready var combat_sfx: CombatSfx = $CombatSfx
@onready var health: PlayerHealth = $Health
@onready var sprite: Sprite2D = $Sprite2D
@onready var chop_sprite: Sprite2D = $ChopSprite
@onready var sword: Area2D = $weapon/sword
@onready var sword_shape: CollisionShape2D = $weapon/sword/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

const INTERACTION_PATH := "/root/Flagoria/World/Interaction"
const SWORD_DAMAGE := 1  ## half-hearts per sword hit
const REGEN_AMOUNT := 1  ## half-hearts per regen_timer tick
const BLINK_PERIOD_MS := 100  ## invulnerability blink: this long shown, this long faded
const CHOP_ROWS := {"Down": 0, "Left": 1, "Right": 2, "Up": 3}  ## rows of the chop sheet

const RESPAWN_HOLD_MS := 1000  ## longest a copy waits for its owner to catch up with a respawn

## On copies the owner moves: the respawn spot to hold while the owner's
## synced position is still the one from before it saw the respawn.
var _respawn_hold := Vector2.INF
var _respawn_hold_until := 0
## The owner's health.respawn_count when it sent an update, synced with
## its position. A copy holds the spawn until this reaches the number the
## server gave the respawn, so it needs no baseline of its own.
var owner_respawns := 0
## Physics frames left with the body's collision off after a respawn moved
## it. The physics server moves a body to a new position only at its next
## step, so for one tick the bodies of players who also just respawned still
## stand where they died. Colliding then pushes the owner off the server's
## spot, or (taking a body's top for a floor) carries it along when that
## body jumps to its own spot (found in a multi-peer play-test).
var _respawn_ghost_ticks := 0

var lastAnimDirection: String = "Down"
## The walk facing this player last sent with updateAnimation; the owner sends
## a new one only when the facing changes, not every physics frame.
var _sent_walk_direction := ""
## The walk facing the owner last sent; replayed when an attack ends.
var _walk_direction := "Down"
var isAttacking: bool = false
## How far the current swing turns from its four-way animation to the exact
## aim angle (#231), about AttackAim.ORIGIN; 0 for a four-way swing.
var swing_turn := 0.0


func _ready():
	# Only the owner moves in physics. Copies receive position from the
	# synchronizer during multiplayer polling.
	physics_interpolation_mode = (
		PHYSICS_INTERPOLATION_MODE_ON
		if is_multiplayer_authority()
		else PHYSICS_INTERPOLATION_MODE_OFF
	)
	reset_physics_interpolation()
	health.damaged.connect(_on_damaged)
	health.healed.connect(_on_healed)
	health.died.connect(_on_died)
	health.respawned.connect(_on_respawned)
	health.health_changed.connect(_apply_dead_state.unbind(2))
	health.state_received.connect(_apply_dead_state.unbind(2))
	animations.mixer_applied.connect(_turn_swing)
	var sync := get_node_or_null("MultiplayerSynchronizer")
	if sync:
		sync.synchronized.connect(_on_synchronized)
	if not is_multiplayer_authority():
		return
	camera.make_current()
	# A peer that joins later gets the current walk facing on the next frame.
	multiplayer.peer_connected.connect(func(_id): _sent_walk_direction = "")
	PlayerCamera.attach_zoom(camera)
	var aim := AttackAimScript.new()  # local mouse aim; only the attack is sent
	aim.name = "AttackAim"
	add_child(aim)
	PlayerHud.bind(self, health)
	var interaction = get_node_or_null(INTERACTION_PATH)
	if interaction:
		interaction.bind(self)


func _process(_delta):
	# Hidden while dead; blinks while invulnerable after a hit or a respawn.
	sprite.visible = not health.is_dead() and not chop_sprite.visible
	var faded := health.is_invulnerable() and (Time.get_ticks_msec() / BLINK_PERIOD_MS) % 2 == 1
	sprite.modulate.a = 0.3 if faded else 1.0
	chop_sprite.modulate.a = sprite.modulate.a
	_wall_draw.apply(self)


func _wall_cover(map: TileMap) -> float:
	return _wall_draw._wall_cover(map, global_position)


func set_chop_pose(direction: String, col: int) -> void:
	## Interaction's chop (local only): show chop sheet column `col` facing
	## `direction` in place of the walk sprite, or the walk sprite again for -1.
	chop_sprite.visible = col >= 0 and not health.is_dead()
	if col >= 0:
		lastAnimDirection = direction
		chop_sprite.frame_coords = Vector2i(col, CHOP_ROWS[direction])
	sprite.visible = not health.is_dead() and not chop_sprite.visible


func _physics_process(delta):
	if _respawn_ghost_ticks > 0:
		_respawn_ghost_ticks -= 1
		if _respawn_ghost_ticks == 0:
			_apply_dead_state()
	if not is_multiplayer_authority():
		return
	if health.is_dead():
		velocity = Vector2.ZERO
		return
	if PlayerCamera.map_covers_play(get_tree()):
		velocity = Vector2.ZERO
		return
	player_movement(delta)
	var direction := walk_direction()
	if direction != _sent_walk_direction:
		_sent_walk_direction = direction
		updateAnimation.rpc(direction)


func _unhandled_input(event):
	if not is_multiplayer_authority():
		return
	if health.is_dead():
		return
	if PlayerCamera.map_covers_play(get_tree()):
		return

	if Input.is_action_just_pressed("attack"):
		attack_animation.rpc()


func attack_toward(direction: String, angle := NAN):
	## An aimed attack (AttackAim). The bow tool sends one shot and does
	## not swing. The sword path is the same call as before.
	if not PlayerCombat.try_bow_shot(self, direction, angle):
		attack_animation.rpc(direction, angle)


@rpc("call_local")  # the call local calls in all remotes and the local too
func attack_animation(direction: String = "", angle: float = NAN):
	await PlayerCombat.swing(self, direction, angle)


func _turn_swing() -> void:
	PlayerCombat.turn_swing(weapon, animations, swing_turn)


func sword_active() -> bool:
	## True while this player's swing can hit: mid-attack and alive.
	return isAttacking and not health.is_dead()


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())


func get_input_axis():
	input = PlayerInput.keyboard_axis()
	return input.normalized()


func get_joystick_axis() -> Vector2:
	return PlayerInput.joystick_axis(joystick)


func player_movement(delta):
	PlayerInput.move_player(self, delta)


func walk_direction() -> String:
	return PlayerInput.walk_direction(velocity)


@rpc("call_local")
func updateAnimation(direction: String):
	_walk_direction = direction
	if isAttacking:
		return

	lastAnimDirection = direction
	animations.play("walk" + direction)


func spawn_position() -> Vector2:
	## Where this player respawns: a free spot near the map's land spawn, as
	## on joining.
	var main = get_node_or_null("/root/Flagoria")
	if main and main.has_method("_land_spawn_position"):
		return main._land_spawn_position(self)
	return position


func _on_damaged(_amount: int):
	combat_sfx.play_event("hit")
	combat_sfx.play_event("hurt")


func _on_healed(_amount: int):
	# Regen only runs after damage, so this ticks only while recovering. Only
	# the peer that controls this player hears it.
	if is_multiplayer_authority():
		combat_sfx.play_event("regen")


func _on_died():
	combat_sfx.play_event("sting")


func _apply_dead_state():
	# Follows health state, however it arrived (a hit, set_health_now, a
	# respawn, or a late copy's state reply): a dead player neither blocks
	# movement nor hits until it respawns. The sprite hides in _process.
	var dead := health.is_dead()
	body_shape.set_deferred("disabled", dead or _respawn_ghost_ticks > 0)
	if dead:
		weapon.visible = false
		sword_shape.set_deferred("disabled", true)


func _on_respawned(at: Vector2):
	if is_multiplayer_authority():
		owner_respawns = health.respawn_count
	else:
		_respawn_hold = at
		_respawn_hold_until = Time.get_ticks_msec() + RESPAWN_HOLD_MS
	position = at
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	# On every peer: this body neither pushes nor is pushed until the
	# physics server has every respawned body at its new spot.
	_respawn_ghost_ticks = 1
	body_shape.set_deferred("disabled", true)


func _on_synchronized():
	# The owner keeps sending its pre-respawn position until the respawn
	# reaches it; keep the copy at the spawn until an update the owner sent
	# after it respawned (or the hold runs out), then follow again.
	if _respawn_hold == Vector2.INF:
		return
	if owner_respawns >= health.respawn_count or Time.get_ticks_msec() > _respawn_hold_until:
		_respawn_hold = Vector2.INF
	else:
		position = _respawn_hold


func _on_animation_player_animation_finished(anim_name):
	# An attack ended: back to the walk facing the owner last sent, which no
	# longer arrives every frame.
	lastAnimDirection = _walk_direction
	animations.play("walk" + _walk_direction)


func _on_regen_timer_timeout():
	health.heal(REGEN_AMOUNT)  # server only; full or dead players are skipped


func _on_hurt_box_area_entered(area):
	# An area never reports itself, and the hurtBox is on no layer anyway.
	var collision_player = area.get_parent().get_parent()
	if (
		collision_player.name != name
		and collision_player.has_method("sword_active")
		and collision_player.sword_active()
	):
		# A different player's sword, mid-swing. Every peer sees the overlap; only
		# the server's take_damage counts, and it syncs health and sounds to all.
		health.take_damage(SWORD_DAMAGE)
