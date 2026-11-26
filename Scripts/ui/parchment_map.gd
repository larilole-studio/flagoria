class_name ParchmentMap
extends Control
## The full explored map on old parchment. The world keeps running underneath.
## While this is open the local hero cannot move or attack, wheel and pinch
## zoom the sheet, a drag pans it, and a hit on the hero closes it.

const GROUP := "fullscreen_map"
const INSET := 8
const BUTTON_SIZE := Vector2(24, 20)  ## 10% above the original 22×18, in whole pixels
const BUTTON_GAP := 2
const BUTTON_MARGIN := 8  ## flush to the inner edge of the wood frame (INSET)
const DISMISS_GUARD_MSEC := 250  ## ignore Map/Menu after Close so the lift cannot open them
const CELL_PX := 2
const MIN_CELL_PX := 1  ## most zoomed out; nearest-filter pixel steps
const DEFAULT_CELL_PX := 2  ## opening zoom; one world cell per two art pixels
const MAX_CELL_PX := 16  ## cells are easy to read
const FOG_TILE_PX := 32  ## fog art tile; scales with cell_px at default zoom
## Aged paper, with ink and wood trim.
const PAPER := Color("e7d7b1")
const PAPER_SHADE := Color("cbb98a")
const PAPER_EDGE := Color("8a5a32")
const PAPER_HI := Color("f3e6c4")
const INK := Color("2a2238")

var pan := Vector2.ZERO  ## pixels added to the hero-centred origin
var cell_px := DEFAULT_CELL_PX  ## art pixels per world cell; nearest-filter steps
var _health: PlayerHealth
var _press_pos := Vector2.ZERO
var _press_pan := Vector2.ZERO
var _view: Control
var _fog: ImageTexture
var _close: MapWoodButton
var _recentre: MapWoodButton
var _zoom_in: MapWoodButton
var _zoom_out: MapWoodButton
var _touches := {}  ## touch index -> screen position
var _pinch_span := 0.0
var _pinch_cell_px := DEFAULT_CELL_PX
var _magnify_cell_px := 0.0  ## fractional zoom carried between magnify events
var _dismiss_guard: Control
var _guard_until_msec := 0
var _guard_holds := 0

@onready var chart: MapChart = $"../MapChart"
@onready var _map_button: Button = $"../MapButton"


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_NEAREST
	z_index = 20
	add_to_group(GROUP)
	_fog = ImageTexture.create_from_image(_fog_image())
	_view = Control.new()
	_view.name = "MapView"
	_view.clip_contents = true
	_view.mouse_filter = MOUSE_FILTER_IGNORE
	_view.texture_filter = TEXTURE_FILTER_NEAREST
	_view.draw.connect(_draw_map)
	add_child(_view)
	chart.chart_changed.connect(_view.queue_redraw)
	chart.chart_cleared.connect(hide_map)
	_map_button.pressed.connect(_toggle_map)
	_zoom_out = _button("ZoomOutButton", MapWoodButton.Glyph.MINUS, _on_zoom_out)
	_zoom_in = _button("ZoomInButton", MapWoodButton.Glyph.CROSS, _on_zoom_in)
	_recentre = _button("RecentreButton", MapWoodButton.Glyph.TARGET, _on_recentre)
	_close = _button("CloseButton", MapWoodButton.Glyph.X, _on_close)
	resized.connect(_fit)
	get_viewport().size_changed.connect(_fit)
	_fit()


func is_open() -> bool:
	return visible


func show_map() -> void:
	pan = Vector2.ZERO
	cell_px = DEFAULT_CELL_PX
	_bind_health()
	show()
	_fit()
	_view.queue_redraw()


func hide_map(from_pointer := false) -> void:
	var was_open := visible
	hide()
	_unbind_health()
	_touches.clear()
	_pinch_span = 0.0
	_pinch_cell_px = DEFAULT_CELL_PX
	_magnify_cell_px = 0.0
	if was_open:
		_arm_dismiss_guard(from_pointer)


func min_cell_px() -> int:
	## Most zoomed-out allowed step; pan must show every explored cell.
	return MIN_CELL_PX


func view_cells_rect() -> Rect2i:
	## Explored-map cells currently under the map window.
	var origin := _origin()
	var lo := Vector2i(floori(origin.x / cell_px), floori(origin.y / cell_px))
	var cells := Vector2i(ceili(_view.size.x / cell_px), ceili(_view.size.y / cell_px))
	return Rect2i(lo, cells)


func explored_fully_visible() -> bool:
	if chart == null:
		return true
	var bounds := chart.explored.explored_rect()
	if bounds.size == Vector2i.ZERO:
		return true
	var cells := bounds.size + Vector2i.ONE
	var lo := Vector2(bounds.position * cell_px)
	var hi := Vector2((bounds.position + cells) * cell_px)
	var view_lo := _origin()
	var view_hi := view_lo + _view.size
	return (
		view_lo.x <= lo.x + 0.5
		and view_lo.y <= lo.y + 0.5
		and view_hi.x >= hi.x - 0.5
		and view_hi.y >= hi.y - 0.5
	)


func hero_view_focus() -> Vector2:
	## MapView-local point on the hero marker for wheel or pinch zoom.
	var marker_scale := float(cell_px) / float(MapChart.CELL_PX)
	var hero := (
		Vector2(chart.hero_cell * cell_px)
		+ Vector2.ONE * marker_scale
		- Vector2(MapChart.HERO_ANCHOR) * marker_scale
	)
	return hero - _origin()


func hero_screen_position() -> Vector2:
	return _view.position + hero_view_focus()


func map_pixel_at_view(focus: Vector2) -> Vector2:
	## World map pixel under a point in MapView local coordinates.
	return _origin() + focus


func _button(node_name: String, glyph: int, handler: Callable) -> MapWoodButton:
	var button := MapWoodButton.new()
	button.name = node_name
	button.glyph = glyph
	button.size = BUTTON_SIZE
	button.activated.connect(handler)
	add_child(button)
	return button


func _fit() -> void:
	var rect := get_viewport_rect()
	position = Vector2.ZERO
	size = rect.size
	_view.position = Vector2(INSET, INSET)
	_view.size = Vector2(maxi(size.x - INSET * 2, 1), maxi(size.y - INSET * 2, 1))
	# Flush into the sheet's top-right corner, just inside the wood frame.
	var origin := _toolbar_origin()
	var step := Vector2(BUTTON_SIZE.x + BUTTON_GAP, 0)
	_zoom_out.position = origin
	_zoom_in.position = origin + step
	_recentre.position = origin + step * 2
	_close.position = origin + step * 3
	queue_redraw()


func _toolbar_origin() -> Vector2:
	var row_width := BUTTON_SIZE.x * 4 + BUTTON_GAP * 3
	var x := maxf(float(BUTTON_MARGIN), size.x - BUTTON_MARGIN - row_width)
	return Vector2(x, BUTTON_MARGIN)


func _process(_delta: float) -> void:
	if visible:
		_view.queue_redraw()
	_try_release_guard()


func _gui_input(event: InputEvent) -> void:
	# Mouse events made from a finger are ignored: the touch event pans once.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed:
			if button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(_view_focus(button.position), cell_px + 1)
				accept_event()
				return
			if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(_view_focus(button.position), cell_px - 1)
				accept_event()
				return
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_press_pos = button.position
				_press_pan = pan
			accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		# The sheet follows the finger.
		pan = _press_pan - (event.position - _press_pos)
		_view.queue_redraw()
		accept_event()
	elif event is InputEventMagnifyGesture:
		var base := _magnify_cell_px if _magnify_cell_px > 0.0 else float(cell_px)
		var target := clampf(base * event.factor, min_cell_px(), MAX_CELL_PX)
		_zoom_at(_view_focus(event.position), roundi(target))
		_magnify_cell_px = target
		accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not touch.canceled:
			if _touches.size() >= 2:
				accept_event()
				return
			_touches[touch.index] = touch.position
			if _touches.size() == 1:
				_press_pos = touch.position
				_press_pan = pan
			if _touches.size() == 2:
				_pinch_span = _touch_span()
				_pinch_cell_px = cell_px
		elif _touches.erase(touch.index):
			_pinch_span = 0.0
			if _touches.size() == 1:
				_press_pos = _touches.values()[0]
				_press_pan = pan
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		accept_event()
		if not _touches.has(drag.index):
			return
		_touches[drag.index] = drag.position
		if _touches.size() == 2:
			var span := _touch_span()
			if _pinch_span > 0.0:
				var stepped := roundi(_pinch_cell_px * span / _pinch_span)
				_zoom_at(_view_focus(_pinch_mid()), stepped)
			elif span > 0.0:
				_pinch_span = span
				_pinch_cell_px = cell_px
		else:
			pan = _press_pan - (drag.position - _press_pos)
			_view.queue_redraw()


func _toggle_map() -> void:
	if HudLayoutVisual.blocks_hud_actions() or chart.local_player() == null:
		return
	if is_open():
		hide_map(true)
	else:
		_clear_guard()
		show_map()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_M and event.pressed and not event.echo:
		_toggle_map()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
		return
	var lift := false
	if event is InputEventScreenTouch:
		lift = not event.pressed
	elif event is InputEventMouseButton:
		lift = event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
	if _dismiss_guard != null and lift:
		_guard_holds = 0
		_try_release_guard()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER_EDGE)
	draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), PAPER)
	draw_rect(Rect2(3, 3, size.x - 6, 1), PAPER_HI)
	var frame := Rect2(INSET - 1, INSET - 1, _view.size.x + 2, _view.size.y + 2)
	draw_rect(frame, INK, false, 1.0)


func _draw_map() -> void:
	var window := _view.size
	var origin := _origin()
	_draw_fog(window, origin)
	if chart == null:
		return
	var top_left := Vector2i(floori(origin.x / cell_px), floori(origin.y / cell_px))
	var extent := Vector2i(ceili(window.x / cell_px), ceili(window.y / cell_px))
	var first := ExploredMap.chunk_of(top_left)
	var last := ExploredMap.chunk_of(top_left + extent)
	var chunk_px := ExploredMap.CHUNK * cell_px
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			var tex: ImageTexture = chart.chunk_texture(Vector2i(cx, cy))
			if tex:
				var at := Vector2(Vector2i(cx, cy) * ExploredMap.CHUNK * cell_px) - origin
				_view.draw_texture_rect(tex, Rect2(at, Vector2(chunk_px, chunk_px)), false)
	var marker: Texture2D = MapChart.HERO.get(chart.facing, MapChart.HERO["Down"])
	var marker_scale := float(cell_px) / float(MapChart.CELL_PX)
	var marker_size := marker.get_size() * marker_scale
	var hero_at := (
		Vector2(chart.hero_cell * cell_px)
		- origin
		+ Vector2.ONE * marker_scale
		- Vector2(MapChart.HERO_ANCHOR) * marker_scale
	)
	_view.draw_texture_rect(marker, Rect2(hero_at, marker_size), false)
	chart.paint_city_walls(_view, top_left, Vector2i(window), cell_px)


func _origin() -> Vector2:
	return Vector2(chart.hero_cell * cell_px) - _view.size * 0.5 + pan


func _zoom_at(focus: Vector2, stepped: int) -> void:
	_magnify_cell_px = 0.0
	var clamped := clampi(stepped, min_cell_px(), MAX_CELL_PX)
	var old_px := cell_px
	var changed := clamped != old_px
	if not changed and clamped != stepped:
		return
	var anchor_cell := map_pixel_at_view(focus) / float(old_px)
	cell_px = clamped
	if changed:
		var new_origin := Vector2(anchor_cell * float(cell_px)) - focus
		pan = new_origin - Vector2(chart.hero_cell * cell_px) + _view.size * 0.5
	if clamped == min_cell_px():
		_center_explored_in_view()
	_view.queue_redraw()


func _center_explored_in_view() -> void:
	if chart == null:
		return
	var bounds := chart.explored.explored_rect()
	if bounds.size == Vector2i.ZERO:
		pan = Vector2.ZERO
		return
	var cells := bounds.size + Vector2i.ONE
	var lo := Vector2(bounds.position * cell_px)
	var hi := Vector2((bounds.position + cells) * cell_px)
	var center := (lo + hi) * 0.5
	var map_w := hi.x - lo.x
	var map_h := hi.y - lo.y
	var origin := center - _view.size * 0.5
	if map_w > _view.size.x:
		origin.x = clampf(origin.x, hi.x - _view.size.x, lo.x)
	if map_h > _view.size.y:
		origin.y = clampf(origin.y, hi.y - _view.size.y, lo.y)
	pan = origin - Vector2(chart.hero_cell * cell_px) + _view.size * 0.5


func _draw_fog(window: Vector2, origin: Vector2) -> void:
	var fog_step := float(FOG_TILE_PX) * float(cell_px) / float(CELL_PX)
	var y := fposmod(-origin.y, fog_step) - fog_step
	while y < window.y + fog_step:
		var x := fposmod(-origin.x, fog_step) - fog_step
		while x < window.x + fog_step:
			_view.draw_texture_rect(_fog, Rect2(Vector2(x, y), Vector2(fog_step, fog_step)), false)
			x += fog_step
		y += fog_step


func _view_focus(screen_pos: Vector2) -> Vector2:
	return screen_pos - _view.position


func _touch_span() -> float:
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])


func _pinch_mid() -> Vector2:
	var pts: Array = _touches.values()
	return ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5


func _on_close() -> void:
	hide_map(true)


func _on_zoom_in() -> void:
	_zoom_at(hero_view_focus(), cell_px + 1)


func _on_zoom_out() -> void:
	_zoom_at(hero_view_focus(), cell_px - 1)


func _on_recentre() -> void:
	pan = Vector2.ZERO
	_view.queue_redraw()


func _on_damaged(_amount: int) -> void:
	if visible:
		hide_map()


func _bind_health() -> void:
	_unbind_health()
	var player := chart.local_player() if chart else null
	if player == null:
		return
	_health = player.get_node_or_null("Health") as PlayerHealth
	if _health and not _health.damaged.is_connected(_on_damaged):
		_health.damaged.connect(_on_damaged)


func _unbind_health() -> void:
	if _health and _health.damaged.is_connected(_on_damaged):
		_health.damaged.disconnect(_on_damaged)
	_health = null


func _arm_dismiss_guard(from_pointer: bool) -> void:
	## Eat Map/Menu input after Close until the pointer is up and a short wait.
	_clear_guard()
	var parent := get_parent()
	if parent == null:
		return
	var guard := Control.new()
	guard.name = "ParchmentDismissGuard"
	guard.mouse_filter = Control.MOUSE_FILTER_STOP
	guard.z_index = 30
	var rect := Rect2()
	for path in ["../InGameMenu/MenuButton"]:
		var other := get_node_or_null(path) as Control
		if other != null:
			var other_rect := other.get_global_rect().grow(4)
			rect = other_rect if rect.size == Vector2.ZERO else rect.merge(other_rect)
	if _close != null:
		var close_rect := _close.get_global_rect().grow(4)
		rect = close_rect if rect.size == Vector2.ZERO else rect.merge(close_rect)
	guard.position = rect.position
	guard.size = rect.size
	guard.gui_input.connect(_on_guard_input)
	parent.add_child(guard)
	_dismiss_guard = guard
	_guard_holds = 1 if from_pointer else 0
	_guard_until_msec = Time.get_ticks_msec() + DISMISS_GUARD_MSEC
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_guard_input(event: InputEvent) -> void:
	if _dismiss_guard == null:
		return
	var pointer := event is InputEventScreenTouch
	if event is InputEventMouseButton:
		pointer = event.button_index == MOUSE_BUTTON_LEFT
	if not pointer:
		return
	_dismiss_guard.accept_event()
	_guard_holds += 1 if event.pressed else -1
	_guard_holds = maxi(_guard_holds, 0)
	_try_release_guard()


func _try_release_guard() -> void:
	if _dismiss_guard == null or Time.get_ticks_msec() < _guard_until_msec:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _guard_holds > 1:
		return
	_clear_guard()


func _clear_guard() -> void:
	_guard_holds = 0
	_guard_until_msec = 0
	if _dismiss_guard != null and is_instance_valid(_dismiss_guard):
		_dismiss_guard.queue_free()
	_dismiss_guard = null
	process_mode = Node.PROCESS_MODE_INHERIT


func _fog_image() -> Image:
	## Paper fog: a dither of the sheet, not the panel's blue mist.
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var grain := (x + 2 * y) % 4 == 0
			var speck := (x * 5 + y * 3) % 37 == 0
			img.set_pixel(x, y, PAPER_EDGE if speck else (PAPER_SHADE if grain else PAPER))
	return img
