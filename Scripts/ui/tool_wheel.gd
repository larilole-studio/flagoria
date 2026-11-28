class_name ToolWheel
extends Control
## Hold-to-select sword, bomb, chop and command (#574).
## A tap under TAP_MS with no drag swaps to the previous tool. A longer
## press, or any drag, opens a half-moon to the left of the button when that
## arc fits, and otherwise toward the open side of the screen so every
## option stays visible. Releasing selects the highlighted tool.
## A headless --server host never builds this node. It does not run _process.

enum Tool { SWORD, BOMB, CHOP, COMMAND }

const TAP_MS := 200
const DRAG_PX := 6.0
const ARC_R := 64.0
const NAMES: PackedStringArray = ["Sword", "Bomb", "Chop", "Command"]
const DIRECT: PackedStringArray = ["tool_sword", "tool_bomb", "tool_chop", "tool_command"]
const ARC_COLOR := Color(0.95, 0.92, 0.86, 0.9)
const _MOUSE := -2

var tool := Tool.SWORD
var previous := Tool.SWORD
var _open := false
var _highlight := Tool.SWORD
var _tracking := false
var _pointer := -1
var _down_msec := 0
var _down_pos := Vector2.ZERO
var _moved := false
var _applying := false
var _timer: Timer
var _button: Button
var _options: Array[Button] = []
var _hit := RoundHudStyle.HIT
var _art := RoundHudStyle.SIZE
var _fan_sign := -1.0
var _fan_radius := ARC_R


static func builds_on(args: PackedStringArray, display_name: String) -> bool:
	## False only for a headless dedicated host. Tests pass other pairs.
	return not (display_name == "headless" and args.has("--server"))


static func headless_host() -> bool:
	return not builds_on(OS.get_cmdline_user_args(), DisplayServer.get_name())


func bomb_armed() -> bool:
	return tool == Tool.BOMB


func is_open() -> bool:
	return _open


func highlighted() -> int:
	return _highlight


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	set_physics_process(false)
	_ensure_actions()
	_button = _make_disc("ToolButton")
	add_child(_button)
	_button.tooltip_text = "Sword"
	for i in NAMES.size():
		var opt := _make_disc(NAMES[i])
		RoundHudStyle.apply_wheel(opt, i)
		opt.visible = false
		opt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		opt.tooltip_text = NAMES[i]
		add_child(opt)
		_options.append(opt)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_hold)
	add_child(_timer)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_refresh_button()


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	_place_options()


func place_button(pos: Vector2) -> void:
	## HudToolRow sets the closed button. Options stay on the arc around it.
	if _button == null:
		return
	_button.position = pos
	_place_options()
	queue_redraw()


func select(next: int) -> void:
	if next < Tool.SWORD or next > Tool.COMMAND:
		return
	if next != tool:
		previous = tool
		tool = next
	_apply_mode()
	_refresh_button()


func follow_mode(mode: int) -> void:
	## Keep the armed tool aligned when something else sets Interaction.mode.
	if _applying:
		return
	if mode == Interaction.Mode.INTERACT:
		if tool != Tool.CHOP:
			select(Tool.CHOP)
	elif tool == Tool.CHOP:
		select(Tool.SWORD)


func quick_swap() -> void:
	if previous == tool:
		return
	select(previous)


func close() -> void:
	_tracking = false
	_pointer = -1
	_moved = false
	if _timer != null:
		_timer.stop()
	_set_open(false)


func _apply_mode() -> void:
	var interaction := get_node_or_null("/root/Flagoria/World/Interaction")
	if interaction == null:
		return
	var mode: int = Interaction.Mode.INTERACT if tool == Tool.CHOP else Interaction.Mode.COMBAT
	if interaction.mode == mode:
		return
	_applying = true
	interaction.set_mode(mode)
	_applying = false


func _input(event: InputEvent) -> void:
	if not _hud_live():
		return
	if HudLayoutVisual.blocks_hud_actions():
		if _tracking or _open:
			close()
		return
	if _keys(event):
		return
	if event is InputEventScreenTouch:
		if _tracking and _pointer == _MOUSE:
			return
		_on_touch(event)
	elif event is InputEventScreenDrag and _tracking and event.index == _pointer:
		_on_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _tracking and _pointer != _MOUSE:
			return
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _tracking and _pointer == _MOUSE:
			_on_move(event.position)
		elif _open and not _tracking:
			_highlight_at(event.position)
	elif _open and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge(1)


func _keys(event: InputEvent) -> bool:
	if event is InputEventKey and event.echo:
		return false
	if event.is_action_pressed("tool_wheel"):
		_highlight = tool
		_set_open(true)
		get_viewport().set_input_as_handled()
		return true
	if event.is_action_released("tool_wheel") and _open and not _tracking:
		select(_highlight)
		close()
		get_viewport().set_input_as_handled()
		return true
	for i in DIRECT.size():
		if event.is_action_pressed(DIRECT[i]):
			select(i)
			close()
			get_viewport().set_input_as_handled()
			return true
	if _open and not _tracking:
		if event.is_action_pressed("ui_up"):
			_nudge(-1)
			return true
		if event.is_action_pressed("ui_down"):
			_nudge(1)
			return true
	return false


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_begin(event.position, event.index)
		return
	if event.index != _pointer:
		return
	_end(event.position)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		_begin(event.position, _MOUSE)
		return
	if _pointer != _MOUSE:
		return
	_end(event.position)


func _begin(pos: Vector2, pointer: int) -> void:
	if _tracking or _button == null or not _button.get_global_rect().has_point(pos):
		return
	_tracking = true
	_pointer = pointer
	_down_msec = Time.get_ticks_msec()
	_down_pos = pos
	_moved = false
	_button.set_pressed_no_signal(true)
	_timer.start(float(TAP_MS) / 1000.0)


func _on_hold() -> void:
	if not _tracking or _open:
		return
	_highlight = tool
	_set_open(true)


func _on_move(pos: Vector2) -> void:
	if _tracking and not _moved and pos.distance_to(_down_pos) >= DRAG_PX:
		_moved = true
		if not _open:
			_highlight = tool
			_set_open(true)
	if _open:
		_highlight_at(pos)


func _end(pos: Vector2) -> void:
	if not _tracking:
		return
	_timer.stop()
	var elapsed := Time.get_ticks_msec() - _down_msec
	var dragged := _moved or pos.distance_to(_down_pos) >= DRAG_PX
	if _open:
		if dragged:
			_highlight_at(pos)
		select(_highlight)
	elif elapsed < TAP_MS and not dragged:
		quick_swap()
	_tracking = false
	_pointer = -1
	_moved = false
	_set_open(false)


func _nudge(step: int) -> void:
	_highlight = clampi(_highlight + step, Tool.SWORD, Tool.COMMAND)
	_paint_options()


func _highlight_at(pos: Vector2) -> void:
	var delta := pos - _button_center()
	if delta.length() < DRAG_PX:
		return
	## theta 0 is up, PI/2 is along the open side, PI is down. The closed
	## half snaps to the nearer end so a thumb moving up or down still lands.
	var theta := atan2(_fan_sign * delta.x, -delta.y)
	if theta < 0.0:
		theta = 0.0 if theta > -PI * 0.5 else PI
	var best := 0
	var best_d := INF
	for i in NAMES.size():
		var opt := PI * (float(i) + 0.5) / NAMES.size()
		var d := absf(theta - opt)
		if d < best_d:
			best_d = d
			best = i
	_highlight = best
	_paint_options()


func _set_open(show: bool) -> void:
	if not show and _button != null:
		_button.set_pressed_no_signal(false)
	if _open == show:
		_paint_options()
		return
	_open = show
	if show:
		_place_options()
	_paint_options()
	queue_redraw()


func _paint_options() -> void:
	for i in _options.size():
		var opt := _options[i]
		opt.visible = _open
		RoundHudStyle.refresh_toggle(opt, i == _highlight and _open)


func _place_options() -> void:
	if _button == null:
		return
	_layout_fan()
	var half := RoundHudStyle.HIT * 0.5
	for i in _options.size():
		var opt := _options[i]
		opt.position = _option_center(i) - Vector2(half, half)


func _option_center(index: int) -> Vector2:
	return _clamp_center(_raw_center(index, _fan_sign, _fan_radius))


func _raw_center(index: int, sign: float, radius: float) -> Vector2:
	var theta := PI * (float(index) + 0.5) / NAMES.size()
	return _button_center() + Vector2(sign * sin(theta), -cos(theta)) * radius


func _layout_fan() -> void:
	## Open toward the side with more room, so a button moved to the left
	## edge still shows the whole half-moon. The default thumb slot has more
	## room on the left, which keeps today's arc.
	var view := get_viewport().get_visible_rect().size
	var center := _button_center()
	var pad := RoundHudStyle.HIT * 0.5 + 1.0
	var prefer := -1.0 if center.x - pad >= view.x - center.x - pad else 1.0
	_fan_sign = prefer
	_fan_radius = ARC_R
	if _fan_fits(prefer, ARC_R):
		return
	if _fan_fits(-prefer, ARC_R):
		_fan_sign = -prefer
		return
	var lo := 12.0
	var hi := ARC_R
	for _step in 6:
		var mid := (lo + hi) * 0.5
		if _fan_fits(prefer, mid):
			lo = mid
		else:
			hi = mid
	_fan_radius = lo


func _fan_fits(sign: float, radius: float) -> bool:
	var view := get_viewport().get_visible_rect()
	var half := Vector2.ONE * RoundHudStyle.HIT * 0.5
	for i in NAMES.size():
		var center := _raw_center(i, sign, radius)
		if not view.encloses(Rect2(center - half, half * 2.0)):
			return false
	return true


func _clamp_center(center: Vector2) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var half := RoundHudStyle.HIT * 0.5
	var edge := 1.0
	return Vector2(
		clampf(center.x, edge + half, maxf(edge + half, view.x - edge - half)),
		clampf(center.y, edge + half, maxf(edge + half, view.y - edge - half))
	)


func _button_center() -> Vector2:
	var sz := _button.size
	if sz.x < 1.0:
		sz = _button.custom_minimum_size
	return _button.position + sz * 0.5


func _refresh_button() -> void:
	if _button == null:
		return
	style_button(_hit, _art)
	_button.tooltip_text = NAMES[tool]


func style_button(hit: float, art: float) -> void:
	_hit = hit
	_art = art
	RoundHudStyle.apply_wheel(_button, tool, hit, art)


func _hud_live() -> bool:
	var layer := get_parent() as CanvasLayer
	return layer != null and layer.visible


func _draw() -> void:
	if not _open or _button == null:
		return
	var pts := PackedVector2Array()
	var center := _button_center()
	for step in 17:
		var theta := PI * float(step) / 16.0
		var at := center + Vector2(_fan_sign * sin(theta), -cos(theta)) * _fan_radius
		pts.append(_clamp_center(at))
	draw_polyline(pts, ARC_COLOR, 2.0, true)


func _make_disc(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	return button


func _ensure_actions() -> void:
	_bind("tool_wheel", KEY_Q)
	_bind("tool_sword", KEY_1)
	_bind("tool_bomb", KEY_2)
	_bind("tool_chop", KEY_3)
	_bind("tool_command", KEY_4)


func _bind(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == key:
			return
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	InputMap.action_add_event(action, event)
