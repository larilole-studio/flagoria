class_name RangedShots
extends Node2D
## Host-checked bow shots for World/RangedShots (#362).
## A peer asks; the host rejects a dead sender, an origin more than
## ORIGIN_LIMIT from the server body, a bad direction, or a live cooldown,
## then flies from the server body. One hit is applied. Peers only draw the
## short line. In-flight shots are not part of the join snapshot.

const ORIGIN_LIMIT := 24.0
const LINE_WIDTH := 2.0
const LINE_TIME := 0.2
const LINE_COLOR := Color(1.0, 0.93, 0.2)

var accepted := 0
var rejected := 0
var _shown := 0
var _until := {}  ## peer id -> msec when this shooter may fire again
var _lines: Array = []


func _ready() -> void:
	z_index = 20
	_ensure_bow()


func _process(_delta: float) -> void:
	_place_bow()
	if _lines.is_empty():
		return
	var now := Time.get_ticks_msec()
	var kept: Array = []
	for line in _lines:
		if int(line["until"]) > now:
			kept.append(line)
	if kept.size() != _lines.size():
		_lines = kept
	queue_redraw()


func lines_shown() -> int:
	return _shown


func cooldown_until(peer_id: int) -> int:
	return int(_until.get(peer_id, 0))


func cooldown_ready(peer_id: int) -> bool:
	return Time.get_ticks_msec() >= cooldown_until(peer_id)


func send_shot(origin: Vector2, direction: Vector2) -> void:
	## Local player entry. The host resolves its own shot; a client asks.
	if not Interaction.multiplayer_on(multiplayer) or multiplayer.is_server():
		var id := multiplayer.get_unique_id()
		resolve(1 if id <= 0 else id, origin, direction)
		return
	request_shot.rpc_id(1, origin, direction)


@rpc("any_peer", "reliable", "call_remote")
func request_shot(origin: Vector2, direction: Vector2) -> void:
	if not multiplayer.is_server():
		return
	resolve(multiplayer.get_remote_sender_id(), origin, direction)


func resolve(sender_id: int, origin: Vector2, direction: Vector2) -> bool:
	## Server only. True when the shot was accepted. Damage is still one
	## take_hit or take_damage, which can return false during hurt time.
	if Interaction.multiplayer_on(multiplayer) and not multiplayer.is_server():
		return false
	var body := get_node_or_null("../" + str(sender_id)) as Node2D
	if body == null or _is_dead(body):
		rejected += 1
		return false
	if not RangedShot._finite(origin) or not RangedShot._finite(direction) \
			or direction.length_squared() <= 0.0000001:
		rejected += 1
		return false
	# The sent origin can be a lie. The flight starts at the server body.
	if origin.distance_to(body.global_position) > ORIGIN_LIMIT:
		rejected += 1
		return false
	var now := Time.get_ticks_msec()
	if now < cooldown_until(sender_id):
		rejected += 1
		return false
	var from := body.global_position + AttackAim.ORIGIN
	var hit := RangedShot.fly(get_node_or_null("../worldMap"), from, direction, _mobs(), _players(), body)
	_until[sender_id] = now + int(RangedShot.COOLDOWN * 1000.0)
	accepted += 1
	RangedShot.apply(hit, sender_id)
	var end: Vector2 = hit.get("end", from)
	show_shot.rpc(from, end)
	return true


@rpc("authority", "call_local", "reliable")
func show_shot(origin: Vector2, end: Vector2) -> void:
	_lines.append({
		"a": origin,
		"b": end,
		"until": Time.get_ticks_msec() + int(LINE_TIME * 1000.0),
	})
	_shown += 1
	queue_redraw()


func _draw() -> void:
	for line in _lines:
		draw_line(to_local(line["a"]), to_local(line["b"]), LINE_COLOR, LINE_WIDTH)


func _is_dead(body: Node) -> bool:
	var health := body.get_node_or_null("Health") as PlayerHealth
	return health != null and health.is_dead()


func _mobs() -> Array:
	var root := get_node_or_null("../Mobs")
	if root != null and root.has_method("mobs"):
		return root.mobs()
	return []


func _players() -> Array:
	var out: Array = []
	var world := get_parent()
	if world == null:
		return out
	for child in world.get_children():
		if child is CharacterBody2D and child.get_node_or_null("Health") != null:
			out.append(child)
	return out


func _ensure_bow() -> void:
	var layer := get_node_or_null("../../CanvasLayer1")
	if layer == null or layer.get_node_or_null("BowButton") != null:
		return
	var button := Button.new()
	button.name = "BowButton"
	button.toggle_mode = true
	button.button_pressed = false
	button.text = ""
	button.tooltip_text = "Weapon"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RoundHudStyle.apply_weapon(button, false)
	button.toggled.connect(func(_on: bool) -> void: RoundHudStyle.apply_weapon(button, _on))
	layer.add_child(button)
	_place_bow()


func _place_bow() -> void:
	var button := get_node_or_null("../../CanvasLayer1/BowButton") as Control
	if button == null:
		return
	var hl := get_node_or_null("/root/HudLayout")
	if hl != null and hl.layout_active():
		return
	var inset := Vector2(2, 2)
	button.position = HudToolRow.LAYOUT["weapon"] - inset
	button.z_index = 4
	RoundHudStyle.apply_weapon(button as Button, (button as Button).button_pressed)
