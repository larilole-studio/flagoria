class_name SoldierCommand
extends Node2D
## Local Command input and ground overlays. SoldierRequests owns simulation.

const FULL_DRAG_PX := 120.0
const NO_POINTER := -1
const MOUSE := -2
const KEYBOARD := -3
const RANGE_FILL := Color(1.0, 1.0, 1.0, 0.08)
const RANGE_LINE := Color(1.0, 1.0, 1.0, 0.35)

var selected_names := PackedStringArray()
var _selector := NO_POINTER
var _origin := Vector2.ZERO
var _radius := 0.0
var _dragged := false
var _map_pointer := NO_POINTER
var _map_down := Vector2.ZERO
var _map_target := Vector2.ZERO
var _map_dragged := false
var _ordered := PackedStringArray()
var _marker := Vector2.ZERO
var _marker_left := 0.0
var _saw_move := false

@onready var _player = get_parent()
@onready var _aim: AttackAim = _player.get_node("AttackAim")
@onready var _requests: SoldierRequests = _player.get_node_or_null("../Soldiers")
@onready var _zoom = _player.get_node_or_null("Camera2D/MapZoom")
@onready var _scoreboard := (
	get_node_or_null("/root/Flagoria/CanvasLayer1/ScoreboardPanel") as ScoreboardPanel
)


func _ready() -> void:
	z_index = 3


static func names_in_range(
	units: Array, peer_id: int, center: Vector2, radius: float
) -> PackedStringArray:
	var names := PackedStringArray()
	for unit: Soldier in units:
		if unit.is_owned_alive(peer_id) and BombShot.contains(center, radius, unit.global_position):
			names.append(str(unit.name))
	return names


func preview_names() -> PackedStringArray:
	if _requests == null or _radius <= 0.0:
		return PackedStringArray()
	return names_in_range(
		_requests.soldiers(), multiplayer.get_unique_id(), global_position, _radius
	)


func _available() -> bool:
	if _requests == null or not _player.command_armed() or not _aim.can_aim():
		return false
	var wheel := get_node_or_null("/root/Flagoria/CanvasLayer1/ToolWheel") as ToolWheel
	return not HudLayoutVisual.blocks_hud_actions() and not wheel.is_open()


func _process(delta: float) -> void:
	if not _player.command_armed() or _player.health.is_dead():
		if not selected_names.is_empty():
			selected_names.clear()
			queue_redraw()
	elif _requests != null:
		for unit_name in selected_names.duplicate():
			var unit := _requests.get_node_or_null(NodePath(unit_name)) as Soldier
			if unit == null or not unit.is_owned_alive(multiplayer.get_unique_id()):
				selected_names.erase(unit_name)
	if not _available():
		_cancel_gesture()
	if _marker_left > 0.0:
		queue_redraw()
		_marker_left -= delta
		var moving := false
		for unit_name in _ordered:
			var unit := _requests.get_node_or_null(NodePath(unit_name)) as Soldier
			if unit != null and unit.order == "move":
				moving = true
				break
		if _saw_move and not moving:
			_marker_left = 0.0
		_saw_move = _saw_move or moving
	if _player.command_armed() or _marker_left > 0.0:
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_cancel_gesture()


func _cancel_gesture() -> void:
	if _radius > 0.0:
		queue_redraw()
	_selector = NO_POINTER
	_radius = 0.0
	_map_pointer = NO_POINTER


func _input(event: InputEvent) -> void:
	if not _available() or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event.is_action("attack") and not event.is_echo():
		_select_pointer(KEYBOARD, get_viewport().get_mouse_position(), event.is_pressed(), true)
	elif event is InputEventScreenTouch:
		if event.canceled:
			_cancel_gesture()
			return
		_select_pointer(event.index, event.position, event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_select_pointer(MOUSE, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_move_pointer(event.index, event.position)
	elif event is InputEventMouseMotion:
		_move_pointer(KEYBOARD if _selector == KEYBOARD else MOUSE, event.position)


func _select_pointer(pointer: int, pos: Vector2, pressed: bool, keyboard := false) -> void:
	if pressed:
		if _map_pointer != NO_POINTER and _map_pointer != pointer:
			_map_pointer = NO_POINTER
		var attack = _aim.attack_button()
		if _selector != NO_POINTER:
			return
		if (
			not keyboard
			and (attack == null or not attack.is_visible_in_tree() or not attack.hits(pos))
		):
			return
		_selector = pointer
		_origin = pos if keyboard else attack.aim_center()
		_dragged = false
		_radius = 0.0
	elif pointer == _selector:
		# A press inside the button can be off-centre and still be a tap.
		if _dragged:
			_update_radius(pos)
		else:
			_radius = Tuning.value(&"command.select_max_px")
		selected_names = preview_names()
		_selector = NO_POINTER
		_radius = 0.0
	elif pointer == _map_pointer:
		_map_pointer = NO_POINTER
		if (
			not _map_dragged
			and pos.distance_to(_map_down) <= AttackAim.TOUCH_DEAD_ZONE
			and not _on_hud(pos)
		):
			_send_move(_map_target)
		return  # MapZoom still needs the release to clear its own gesture.
	else:
		return
	get_viewport().set_input_as_handled()


func _move_pointer(pointer: int, pos: Vector2) -> void:
	if pointer == _selector:
		_update_radius(pos)
	elif pointer == _map_pointer and pos.distance_to(_map_down) > AttackAim.TOUCH_DEAD_ZONE:
		_map_dragged = true


func _update_radius(pos: Vector2) -> void:
	var drag := pos - _origin
	if drag.length() > AttackAim.TOUCH_DEAD_ZONE:
		_dragged = true
		var screen_px := get_viewport().get_final_transform().basis_xform(drag).length()
		_radius = Tuning.value(&"command.select_max_px") * minf(screen_px / FULL_DRAG_PX, 1.0)
	else:
		_radius = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not _available() or selected_names.is_empty() or _selector != NO_POINTER:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch and event.pressed:
		_begin_map_tap(event.index, event.position)
	elif (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	):
		_begin_map_tap(MOUSE, event.position)


func _begin_map_tap(pointer: int, pos: Vector2) -> void:
	if not _on_hud(pos):
		_map_pointer = pointer
		_map_down = pos
		_map_target = get_canvas_transform().affine_inverse() * pos
		_map_dragged = false


func _on_hud(pos: Vector2) -> bool:
	return _zoom != null and _zoom.starts_on_hud(pos)


func _send_move(target: Vector2) -> void:
	if selected_names.is_empty():
		return
	if multiplayer.is_server():
		if not _requests.host_move(multiplayer.get_unique_id(), selected_names, target):
			return
	else:
		_requests.request_move.rpc_id(1, selected_names, target)
	_ordered = selected_names.duplicate()
	_marker = target
	_marker_left = Tuning.value(&"command.marker_seconds")
	_saw_move = false


func _draw() -> void:
	if _radius <= 0.0 and selected_names.is_empty() and _marker_left <= 0.0:
		return
	var px := _aim.screen_px()
	var peer_id := multiplayer.get_unique_id()
	var team := (
		_scoreboard.flag_color(peer_id) if _scoreboard != null else ScoreboardPanel.FLAG_HOST
	)
	var shown := selected_names
	if _radius > 0.0:
		_ellipse(Vector2.ZERO, _radius, RANGE_LINE, px, RANGE_FILL)
		shown = preview_names()
	for unit_name in shown:
		var unit := _requests.get_node_or_null(NodePath(unit_name)) as Soldier
		if unit != null and unit.visible:
			_ellipse(to_local(unit.global_position), 7.0, Color(team.lightened(0.15), 0.65), px)
	if _marker_left > 0.0:
		var pos := to_local(_marker)
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)
		var x := Vector2(6, 0)
		var y := Vector2(0, 4)
		for axis in [x, y]:
			draw_line(pos - axis, pos + axis, Color(0.12, 0.1, 0.1, pulse), 3.0 * px, true)
			draw_line(pos - axis, pos + axis, Color(team.lightened(0.38), pulse), 1.5 * px, true)


func _ellipse(
	center: Vector2, radius: float, line: Color, width: float, fill := Color.TRANSPARENT
) -> void:
	var points := PackedVector2Array()
	for i in 48:
		points.append(center + Vector2.from_angle(TAU * i / 48.0) * BombShot.radii(radius))
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, line, width, true)
