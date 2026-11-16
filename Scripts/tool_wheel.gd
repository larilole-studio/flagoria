class_name ToolWheel
extends Control
## Hold-to-select sword, bow and chop (#574).
## A tap under TAP_MS with no drag swaps to the previous tool. A longer
## press, or any drag, opens a half-moon that fans from the button toward
## the centre. Releasing selects the highlighted tool.
## A headless --server host never builds this node. It does not run _process.

enum Tool { SWORD, BOW, CHOP }

const TAP_MS := 200
const DRAG_PX := 6.0
const ARC_R := 56.0
const NAMES: PackedStringArray = ["Sword", "Bow", "Chop"]
const DIRECT: PackedStringArray = ["tool_sword", "tool_bow", "tool_chop"]
const SWORD_ICON := preload("res://assets/ui/hud/icon_mode_attack.png")
const CHOP_ICON := preload("res://assets/ui/hud/icon_mode_interact.png")
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
var _bow_icon: Texture2D
var _face_box: StyleBox


static func builds_on(args: PackedStringArray, display_name: String) -> bool:
	## False only for a headless dedicated host. Tests pass other pairs.
	return not (display_name == "headless" and args.has("--server"))


static func headless_host() -> bool:
	return not builds_on(OS.get_cmdline_user_args(), DisplayServer.get_name())


func bow_armed() -> bool:
	return tool == Tool.BOW


func is_open() -> bool:
	return _open


func highlighted() -> int:
	return _highlight


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	set_physics_process(false)
	_ensure_actions()
	_bow_icon = _make_bow_icon()
	_button = _make_disc("ToolButton")
	add_child(_button)
	_face_box = _button.get_theme_stylebox("normal")
	_button.icon = SWORD_ICON
	_button.tooltip_text = "Sword"
	for i in NAMES.size():
		var opt := _make_disc(NAMES[i])
		opt.visible = false
		opt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		opt.icon = _icon_for(i)
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
	if next < Tool.SWORD or next > Tool.CHOP:
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
	_highlight = clampi(_highlight + step, Tool.SWORD, Tool.CHOP)
	_paint_options()


func _highlight_at(pos: Vector2) -> void:
	var delta := pos - _button_center()
	if delta.length() < DRAG_PX:
		return
	## theta 0 is up, PI/2 is left, PI is down. The right half snaps to the
	## nearer end so a thumb moving up or down still lands on the arc.
	var theta := atan2(-delta.x, -delta.y)
	if theta < 0.0:
		theta = 0.0 if theta > -PI * 0.5 else PI
	var best := 0
	var best_d := INF
	for i in 3:
		var opt := PI * (float(i) + 0.5) / 3.0
		var d := absf(theta - opt)
		if d < best_d:
			best_d = d
			best = i
	_highlight = best
	_paint_options()


func _set_open(show: bool) -> void:
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
		# The round normal style stays. Removing it falls back to the
		# theme's square, which is what the unhighlighted options were.
		if i == _highlight and _open:
			opt.add_theme_stylebox_override("normal", opt.get_theme_stylebox("pressed"))
		elif _face_box != null:
			opt.add_theme_stylebox_override("normal", _face_box)


func _place_options() -> void:
	if _button == null:
		return
	var half := RoundHudStyle.HIT * 0.5
	for i in _options.size():
		var opt := _options[i]
		opt.position = _option_center(i) - Vector2(half, half)


func _option_center(index: int) -> Vector2:
	var theta := PI * (float(index) + 0.5) / 3.0
	return _button_center() + Vector2(-sin(theta), -cos(theta)) * ARC_R


func _button_center() -> Vector2:
	var sz := _button.size
	if sz.x < 1.0:
		sz = _button.custom_minimum_size
	return _button.position + sz * 0.5


func _refresh_button() -> void:
	if _button == null:
		return
	_button.icon = _icon_for(tool)
	_button.tooltip_text = NAMES[tool]


func _icon_for(which: int) -> Texture2D:
	if which == Tool.BOW:
		return _bow_icon
	if which == Tool.CHOP:
		return CHOP_ICON
	return SWORD_ICON


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
		pts.append(center + Vector2(-sin(theta), -cos(theta)) * ARC_R)
	draw_polyline(pts, ARC_COLOR, 2.0, true)


func _make_disc(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	RoundHudStyle.apply(button)
	return button


func _ensure_actions() -> void:
	_bind("tool_wheel", KEY_Q)
	_bind("tool_sword", KEY_1)
	_bind("tool_bow", KEY_2)
	_bind("tool_chop", KEY_3)


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


static func _make_bow_icon() -> Texture2D:
	## Stand-in until the wheel art lands (#576). A pale bow on a clear tile.
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ink := Color(0.95, 0.93, 0.86, 1)
	for y in 32:
		var t := (float(y) - 15.5) / 15.5
		var x := int(round(20.0 - 12.0 * (1.0 - t * t)))
		for dx in 2:
			var px := x + dx
			if px >= 0 and px < 32:
				image.set_pixel(px, y, ink)
		if y >= 2 and y <= 29:
			image.set_pixel(24, y, ink)
	return ImageTexture.create_from_image(image)
