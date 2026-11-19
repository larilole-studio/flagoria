extends Node
## Autoload: per-device touch HUD positions and scales in user settings,
## separate from world saves. Empty means HudToolRow's default layout.
##
## Each control stores a normalized top-left (x, y in 0..1) and scale s
## (1.0 = today's size). Positions survive viewport resize and rotation.

const SAVE_VERSION := 2
const SIDE := 12.0
const SCALE_MIN := 1.0
const SCALE_MAX := 1.75

## wheel is the tool button. A legacy mode_* key is not an id (#575).
const IDS := ["joystick", "attack", "run", "buildings", "map", "scores", "wheel"]
const PATHS := {
	"joystick": "player_joystick",
	"attack": "TouchScreenButton",
	"run": "RunButton",
	"buildings": "BuildingsButton",
	"map": "MinimapButton",
	"scores": "ScoreboardToggle",
	"wheel": "ToolWheel/ToolButton",
}

## Tests point this at a scratch file.
var save_path := "user://hud_layout.cfg"
var _saved: Dictionary = {}  ## id -> {x, y, s}
var _draft: Dictionary = {}  ## during edit; mirrors _saved until changed


func _ready() -> void:
	HudLayoutDefaults.load_from_disk(self)


func uses_custom() -> bool:
	return not _saved.is_empty()


var _editing := false
var _edit_exclusion := Rect2()


func editing() -> bool:
	return _editing


func blocks_hud_actions() -> bool:
	return _editing


func edit_begin(layer: CanvasLayer) -> void:
	_editing = true
	_edit_exclusion = Rect2()
	_draft = _saved.duplicate(true)
	if _draft.is_empty():
		_draft = capture_from_layer(layer)
	HudLayoutVisual.dismiss_popups(layer)


func edit_end() -> void:
	_editing = false
	_draft.clear()
	_edit_exclusion = Rect2()


func set_edit_exclusion(rect: Rect2) -> void:
	_edit_exclusion = rect


func active_layout() -> Dictionary:
	if _editing:
		return _draft
	return _saved


func layout_active() -> bool:
	return uses_custom() or _editing


func get_entry(id: String) -> Dictionary:
	var src := active_layout()
	if src.has(id):
		return src[id].duplicate()
	return {}


func set_entry(id: String, entry: Dictionary) -> bool:
	if not IDS.has(id):
		return false
	var clean := _sanitize_entry(entry)
	if clean.is_empty():
		return false
	if _editing:
		_draft[id] = clean
	else:
		_saved[id] = clean
	return true


func try_place(id: String, x: float, y: float, s: float, layer: CanvasLayer) -> bool:
	## Move one control if it fits on screen and does not overlap others.
	s = clampf(s, SCALE_MIN, SCALE_MAX)
	var view := layer.get_viewport().get_visible_rect().size
	var size := _hit_size(id, s, layer)
	if size == Vector2.ZERO:
		return false
	var pos := Vector2(x * view.x, y * view.y)
	var rect := Rect2(pos, size)
	rect = clamp_rect(rect, layer)
	return entry_write(id, _entry_from_rect(id, rect, layer, s), layer)


func entry_write(id: String, entry: Dictionary, layer: CanvasLayer) -> bool:
	var rect := _rect_for_entry(id, entry, layer)
	if rect.size == Vector2.ZERO:
		return false
	rect = clamp_rect(rect, layer)
	if _edit_exclusion.size != Vector2.ZERO and rect.intersects(_edit_exclusion):
		return false
	if overlaps(id, rect, layer):
		return false
	if _editing:
		_draft[id] = _entry_from_rect(id, rect, layer, float(entry.get("s", 1.0)))
	else:
		_saved[id] = _entry_from_rect(id, rect, layer, float(entry.get("s", 1.0)))
	apply_control(id, layer)
	_place_popups(layer)
	return true


func save_to_disk() -> void:
	HudLayoutDefaults.save_to_disk(self)


func load_from_disk() -> void:
	HudLayoutDefaults.load_from_disk(self)


func reset() -> void:
	_saved.clear()
	_draft.clear()
	HudLayoutDefaults.remove_save_file(self)


func reset_to_defaults() -> void:
	_saved.clear()
	_draft.clear()
	_editing = false
	_edit_exclusion = Rect2()
	HudLayoutDefaults.remove_save_file(self)
	HudLayoutDefaults.flush_touch_defaults()


func forget_memory() -> void:
	## Clears in-memory layout without touching the save file (tests).
	_saved.clear()
	_draft.clear()
	_editing = false


func capture_into_draft(layer: CanvasLayer) -> void:
	_draft = capture_from_layer(layer)
	_editing = true


func scale_of(id: String, layer: CanvasLayer) -> float:
	return HudLayoutDefaults.scale_of(id, layer, PATHS)


func apply(layer: CanvasLayer) -> void:
	if not layout_active():
		return
	var src := active_layout()
	for id in IDS:
		if src.has(id):
			apply_control(id, layer)
	_place_popups(layer)


func _place_popups(layer: CanvasLayer) -> void:
	var row := layer.get_node_or_null("HudToolRow") as HudToolRow
	if row != null:
		row.place_custom_popups(layer)


func apply_control(id: String, layer: CanvasLayer) -> void:
	var src := active_layout()
	if not src.has(id):
		return
	var node := layer.get_node_or_null(PATHS[id])
	if node == null:
		return
	var entry: Dictionary = src[id]
	var s: float = clampf(float(entry.get("s", 1.0)), SCALE_MIN, SCALE_MAX)
	var view := layer.get_viewport().get_visible_rect().size
	var pos := Vector2(float(entry.get("x", 0.0)) * view.x, float(entry.get("y", 0.0)) * view.y)
	match id:
		"joystick":
			_apply_joystick(node as Node2D, pos, s)
		"attack":
			_apply_attack(node as TouchScreenButton, pos, s)
		"run":
			_apply_run(node as Button, pos, s)
		_:
			_apply_round(node as Button, pos, s)


func overlaps(id: String, rect: Rect2, layer: CanvasLayer, margin := 0.0) -> bool:
	var grow := rect.grow(margin)
	var layout := active_layout()
	for other in IDS:
		if other == id:
			continue
		var orc := Rect2()
		if layout.has(other):
			orc = _rect_for_entry(other, layout[other], layer)
		else:
			orc = control_hit_rect(other, layer)
		if orc.size != Vector2.ZERO and grow.intersects(orc):
			return true
	return false


func clamp_rect(rect: Rect2, layer: CanvasLayer) -> Rect2:
	var view := layer.get_viewport().get_visible_rect()
	var out := rect
	if out.position.x < SIDE:
		out.position.x = SIDE
	if out.position.y < SIDE:
		out.position.y = SIDE
	if out.end.x > view.size.x - SIDE:
		out.position.x = view.size.x - SIDE - out.size.x
	if out.end.y > view.size.y - SIDE:
		out.position.y = view.size.y - SIDE - out.size.y
	if _editing and _edit_exclusion.size != Vector2.ZERO:
		out = _avoid_edit_bar(out)
		if out.position.x < SIDE:
			out.position.x = SIDE
		if out.position.y < SIDE:
			out.position.y = SIDE
		if out.end.x > view.size.x - SIDE:
			out.position.x = view.size.x - SIDE - out.size.x
		if out.end.y > view.size.y - SIDE:
			out.position.y = view.size.y - SIDE - out.size.y
	return out


func _avoid_edit_bar(rect: Rect2) -> Rect2:
	if not rect.intersects(_edit_exclusion):
		return rect
	var best := rect
	var best_dist := INF
	var opts: Array[Vector2] = [
		Vector2(_edit_exclusion.position.x - rect.size.x, rect.position.y),
		Vector2(_edit_exclusion.end.x, rect.position.y),
		Vector2(rect.position.x, _edit_exclusion.position.y - rect.size.y),
		Vector2(rect.position.x, _edit_exclusion.end.y),
	]
	for pos in opts:
		var trial := Rect2(pos, rect.size)
		if trial.intersects(_edit_exclusion):
			continue
		var d: float = pos.distance_squared_to(rect.position)
		if d < best_dist:
			best_dist = d
			best = trial
	return best


func control_visual_rect(id: String, layer: CanvasLayer) -> Rect2:
	return HudLayoutVisual.control_rect(id, layer, PATHS)


func control_hit_rect(id: String, layer: CanvasLayer) -> Rect2:
	var node := layer.get_node_or_null(PATHS[id])
	if node == null:
		return Rect2()
	if id == "scores":
		return ScoreboardToggle.layout_hit_rect(layer)
	match id:
		"joystick":
			var stick := node as Node2D
			var r: float = stick.start_reach()
			return Rect2(stick.global_position - Vector2(r, r), Vector2(r, r) * 2.0)
		"attack":
			var btn := node as TouchScreenButton
			var size := btn.texture_normal.get_size() * btn.scale if btn.texture_normal else Vector2.ZERO
			return Rect2(btn.global_position, size)
		_:
			var c := node as Control
			return c.get_global_rect() if c != null else Rect2()


func _rect_for_entry(id: String, entry: Dictionary, layer: CanvasLayer) -> Rect2:
	var view := layer.get_viewport().get_visible_rect().size
	var s: float = clampf(float(entry.get("s", 1.0)), SCALE_MIN, SCALE_MAX)
	var size := _hit_size(id, s, layer)
	var pos := Vector2(float(entry.get("x", 0.0)) * view.x, float(entry.get("y", 0.0)) * view.y)
	return Rect2(pos, size)


func _hit_size(id: String, s: float, layer: CanvasLayer) -> Vector2:
	match id:
		"joystick":
			var stick := layer.get_node_or_null("player_joystick")
			if stick == null or not stick.has_method("start_reach"):
				return Vector2.ZERO
			var old: Vector2 = stick.scale
			stick.scale = Vector2.ONE * s
			var r: float = stick.start_reach()
			stick.scale = old
			return Vector2(r, r) * 2.0
		"attack":
			var btn := layer.get_node_or_null(PATHS[id]) as TouchScreenButton
			if btn == null or btn.texture_normal == null:
				return Vector2.ZERO
			return btn.texture_normal.get_size() * s
		"run":
			return Vector2(RoundHudStyle.RUN_HIT, RoundHudStyle.RUN_HIT) * s
		_:
			return Vector2(RoundHudStyle.HIT, RoundHudStyle.HIT) * s
	return Vector2.ZERO


func _entry_from_rect(id: String, rect: Rect2, layer: CanvasLayer, s: float) -> Dictionary:
	var view := layer.get_viewport().get_visible_rect().size
	return {
		"x": rect.position.x / view.x if view.x > 0.0 else 0.0,
		"y": rect.position.y / view.y if view.y > 0.0 else 0.0,
		"s": clampf(s, SCALE_MIN, SCALE_MAX),
	}


func _apply_joystick(stick: Node2D, pos: Vector2, s: float) -> void:
	stick.scale = Vector2.ONE * s
	var reach: float = stick.start_reach()
	stick.position = pos + Vector2(reach, reach)


func _apply_attack(btn: TouchScreenButton, pos: Vector2, s: float) -> void:
	btn.scale = Vector2.ONE * s
	btn.position = pos
	if btn.shape is CircleShape2D:
		(btn.shape as CircleShape2D).radius = 24.0 * s


func _apply_run(button: Button, pos: Vector2, s: float) -> void:
	RoundHudStyle.apply_run(button, RoundHudStyle.RUN_HIT * s, RoundHudStyle.RUN_SIZE * s)
	button.position = pos


func _apply_round(button: Button, pos: Vector2, s: float, _is_run := false) -> void:
	if button.get_script() != null and str(button.get_script().resource_path).ends_with("run_control.gd"):
		_apply_run(button, pos, s)
		return
	if button.name == "ScoreboardToggle":
		RoundHudStyle.apply_scores(button, RoundHudStyle.HIT * s, RoundHudStyle.SIZE * s)
	elif button.name == "BuildingsButton":
		RoundHudStyle.apply_build(button, RoundHudStyle.HIT * s, RoundHudStyle.SIZE * s)
	elif button.name == "ModeButton":
		var mode := Interaction.Mode.COMBAT
		var world := button.get_node_or_null("/root/Flagoria/World/Interaction") as Interaction
		if world != null:
			mode = world.mode
		RoundHudStyle.apply_mode(button, mode, RoundHudStyle.HIT * s, RoundHudStyle.SIZE * s)
	else:
		RoundHudStyle.apply(button, RoundHudStyle.HIT * s, RoundHudStyle.SIZE * s)
	button.position = pos


static func _sanitize_entry(entry: Dictionary) -> Dictionary:
	var xv: Variant = _finite(entry.get("x"))
	var yv: Variant = _finite(entry.get("y"))
	var sv: Variant = _finite(entry.get("s"), 1.0)
	if xv == null or yv == null or sv == null:
		return {}
	var x: float = clampf(xv, 0.0, 1.0)
	var y: float = clampf(yv, 0.0, 1.0)
	var s: float = clampf(sv, SCALE_MIN, SCALE_MAX)
	return {"x": x, "y": y, "s": s}


static func _finite(value: Variant, fallback = null):
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	var v := float(value)
	if is_nan(v) or is_inf(v):
		return fallback
	return v


## Capture the default layout after HudToolRow runs (for tests and first save).
func capture_from_layer(layer: CanvasLayer) -> Dictionary:
	return HudLayoutDefaults.capture_from_layer(self, layer)
