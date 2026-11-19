class_name HudLayoutDefaults
extends RefCounted
## Save file I/O, reset-to-touch-defaults, and layout capture for HudLayout.

const SECTION := "hud"
const SCALE_MIN := 1.0
const SCALE_MAX := 1.75


static func load_from_disk(hl: Node) -> void:
	hl._saved.clear()
	var cfg := ConfigFile.new()
	if cfg.load(hl.save_path) != OK:
		return
	if int(cfg.get_value(SECTION, "version", 0)) != hl.SAVE_VERSION:
		return
	for id in hl.IDS:
		var xv: Variant = _finite(cfg.get_value(SECTION, id + "_x"))
		var yv: Variant = _finite(cfg.get_value(SECTION, id + "_y"))
		var sv: Variant = _finite(cfg.get_value(SECTION, id + "_s"), 1.0)
		if xv == null or yv == null or sv == null:
			continue
		var x: float = xv
		var y: float = yv
		var s: float = sv
		s = clampf(s, SCALE_MIN, SCALE_MAX)
		if x < 0.0 or x > 1.0 or y < 0.0 or y > 1.0:
			continue
		hl._saved[id] = {"x": x, "y": y, "s": s}


static func save_to_disk(hl: Node) -> void:
	if hl._editing:
		hl._saved = hl._draft.duplicate(true)
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "version", hl.SAVE_VERSION)
	for id in hl.IDS:
		if hl._saved.has(id):
			var e: Dictionary = hl._saved[id]
			cfg.set_value(SECTION, id + "_x", e.get("x", 0.0))
			cfg.set_value(SECTION, id + "_y", e.get("y", 0.0))
			cfg.set_value(SECTION, id + "_s", e.get("s", 1.0))
	cfg.save(hl.save_path)
	hl._draft = hl._saved.duplicate(true)


static func remove_save_file(hl: Node) -> void:
	if FileAccess.file_exists(hl.save_path):
		DirAccess.remove_absolute(hl.save_path)


static func flush_touch_defaults() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var scene := tree.root.get_node_or_null("Flagoria")
	if scene == null:
		return
	var layer := scene.get_node_or_null("CanvasLayer1") as CanvasLayer
	if layer == null:
		return
	var row := layer.get_node_or_null("HudToolRow") as HudToolRow
	if row != null:
		row.restore_defaults(layer)


static func capture_from_layer(hl: Node, layer: CanvasLayer) -> Dictionary:
	var out := {}
	var view := layer.get_viewport().get_visible_rect().size
	for id in hl.IDS:
		var rect: Rect2 = hl.control_hit_rect(id, layer)
		if rect.size == Vector2.ZERO and id == "scores" and view.x > 0.0 and view.y > 0.0:
			var toggle := layer.get_node_or_null(hl.PATHS["scores"]) as Control
			if toggle != null:
				rect = Rect2(layer.global_position + toggle.position, Vector2(RoundHudStyle.HIT, RoundHudStyle.HIT))
		if rect.size == Vector2.ZERO:
			continue
		out[id] = {
			"x": clampf(rect.position.x / view.x, 0.0, 1.0),
			"y": clampf(rect.position.y / view.y, 0.0, 1.0),
			"s": scale_of(id, layer, hl.PATHS),
		}
	return out


static func scale_of(id: String, layer: CanvasLayer, paths: Dictionary) -> float:
	var node := layer.get_node_or_null(paths[id])
	if node == null:
		return 1.0
	match id:
		"joystick":
			return (node as Node2D).scale.x
		"attack":
			return (node as TouchScreenButton).scale.x / HudToolRow.attack_default_scale(node)
		_:
			var c := node as Control
			if c == null or c.size.x <= 0.0:
				return 1.0
			if id == "run":
				return c.size.x / RoundHudStyle.RUN_HIT
			return c.size.x / RoundHudStyle.HIT
	return 1.0


static func _finite(value: Variant, fallback = null):
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	var v := float(value)
	if is_nan(v) or is_inf(v):
		return fallback
	return v