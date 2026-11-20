class_name ScoreboardToggle
extends Button
## Round scoreboard toggle beside the points label (#509, #492).

const GAP := 4.0


func _ready() -> void:
	tooltip_text = "Scores"
	text = ""
	icon = null
	focus_mode = FOCUS_NONE
	RoundHudStyle.apply_scores(self)
	pressed.connect(_on_pressed)
	get_viewport().size_changed.connect(_follow_score)


func _process(_delta: float) -> void:
	if _hud_layout_active():
		return
	_follow_score()


func _hud_layout_active() -> bool:
	var hl := get_node_or_null("/root/HudLayout")
	return hl != null and hl.layout_active()


func _status_sibling(node_name: String) -> Node:
	var node := get_node_or_null(NodePath("../" + node_name))
	if node != null:
		return node
	var plate := get_node_or_null("../StatusPlate") as StatusPlateHud
	if plate != null:
		return plate.get_node_or_null(node_name)
	return null


func _follow_score() -> void:
	var hl := get_node_or_null("/root/HudLayout")
	if hl != null and hl.layout_active():
		return
	var plate := get_node_or_null("../StatusPlate") as StatusPlateHud
	if plate != null:
		scale = Vector2.ONE
		var row := plate.get_global_rect()
		position = Vector2(row.end.x, row.get_center().y - size.y * 0.5)
		set_anchors_preset(Control.PRESET_TOP_LEFT)
	else:
		var score := _status_sibling("ScoreHud") as Control
		var hearts := _status_sibling("HeartsHud") as Control
		if score == null:
			return
		var k := hearts.scale.x if hearts != null else 1.0
		scale = Vector2(k, k)
		var hit := RoundHudStyle.HIT * k
		var score_w := score.size.x * k
		var y := score.position.y + (score.size.y * k - hit) * 0.5
		position = Vector2(score.position.x + score_w + GAP * k, y)
		set_anchors_preset(Control.PRESET_TOP_LEFT)
	var panel := get_node_or_null("../ScoreboardPanel") as ScoreboardPanel
	if panel != null:
		panel.follow_hud_row()
	_refresh_disc()


func _on_pressed() -> void:
	if HudLayoutVisual.blocks_hud_actions():
		set_pressed_no_signal(false)
		_refresh_disc()
		return
	var panel := get_node_or_null("../ScoreboardPanel") as ScoreboardPanel
	if panel != null:
		panel.toggle()
	_refresh_disc()


func _refresh_disc() -> void:
	var panel := get_node_or_null("../ScoreboardPanel") as ScoreboardPanel
	var open := panel != null and panel.is_open()
	if get_meta(&"scores_open", false) == open:
		return
	set_meta(&"scores_open", open)
	set_pressed_no_signal(open)
	RoundHudStyle.refresh_toggle(self, open)


## Hit rect for Customize HUD capture when the toggle has not laid out yet.
static func layout_hit_rect(layer: CanvasLayer) -> Rect2:
	var toggle := layer.get_node_or_null("ScoreboardToggle") as Control
	if toggle != null and toggle.is_visible_in_tree():
		var ready := toggle.get_global_rect()
		if ready.size.x > 0.0:
			return ready
	var plate := layer.get_node_or_null("StatusPlate") as StatusPlateHud
	var hearts := layer.get_node_or_null("HeartsHud") as Control
	if hearts == null and plate != null:
		hearts = plate.get_node_or_null("HeartsHud") as Control
	if hearts == null:
		return Rect2()
	var score := layer.get_node_or_null("ScoreHud") as Control
	if score == null and plate != null:
		score = plate.get_node_or_null("ScoreHud") as Control
	var k := maxf(hearts.scale.x, 0.001)
	var hit := RoundHudStyle.HIT * k
	var score_w := 36.0 * k
	var score_h := 12.0 * k
	var score_y := hearts.position.y + (hearts.size.y + ScoreHud.GAP) * k
	if score != null:
		if score.size.x > 0.0:
			score_w = score.size.x * k
		if score.size.y > 0.0:
			score_h = score.size.y * k
		if score.position.y > 0.0:
			score_y = score.position.y
	var y := score_y + (score_h - hit) * 0.5
	var local := Vector2(hearts.position.x + score_w + GAP * k, y)
	var origin: Vector2 = layer.global_position + local
	return Rect2(origin, Vector2(hit, hit))