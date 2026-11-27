class_name BuildPreview
extends RefCounted

const VALID_TINT := Color(0.2, 0.85, 0.3, 0.42)
const INVALID_TINT := Color(0.92, 0.22, 0.18, 0.48)
const COST_COLOR := Color(0.98, 0.95, 0.88, 1.0)
const REASON_COLOR := Color(1.0, 0.75, 0.55, 1.0)


static func draw_cells(
	canvas: Node2D, interaction: Interaction, cells: Array[Vector2i], cell_ok: Array[bool]
) -> void:
	var map: TileMap = interaction.world_map
	var half := Vector2(map.tile_set.tile_size) * map.global_scale / 2.0
	for i in cells.size():
		var center := canvas.to_local(interaction.cell_center(cells[i]))
		var rect := Rect2(center - half, half * 2.0)
		canvas.draw_rect(rect, VALID_TINT if cell_ok[i] else INVALID_TINT)


static func draw_label(canvas: Node2D, point: Vector2, text: String, refused: bool) -> void:
	if text.is_empty():
		return
	var font := ThemeDB.fallback_font
	const FONT_SIZE := 13
	var anchor := canvas.to_local(point) + Vector2(10, -8)
	var visible := (
		canvas.get_global_transform_with_canvas().affine_inverse() * canvas.get_viewport_rect()
	)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	anchor.x = clampf(
		anchor.x, visible.position.x + 4, maxf(visible.position.x + 4, visible.end.x - width - 4)
	)
	anchor.y = clampf(anchor.y, visible.position.y + FONT_SIZE, visible.end.y - 4)
	canvas.draw_string_outline(
		font, anchor, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, Color(0.15, 0.10, 0.20)
	)
	canvas.draw_string(
		font,
		anchor,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		FONT_SIZE,
		REASON_COLOR if refused else COST_COLOR
	)


static func draw_footprint(
	canvas: Node2D,
	interaction: Interaction,
	top_left: Vector2i,
	anchor: Vector2i,
	tool: BuildPlacement.Tool,
	turns: int
) -> void:
	var is_mine := tool == BuildPlacement.Tool.MINE
	if not is_mine and tool != BuildPlacement.Tool.SAWMILL:
		var mark := canvas.to_local(interaction.cell_center(anchor))
		FootprintOrientation.draw_at(canvas, mark, turns)
		return
	var map: TileMap = interaction.world_map
	var transform := canvas.global_transform.affine_inverse() * map.global_transform
	transform = transform.translated_local(map.map_to_local(top_left + Vector2i.ONE))
	canvas.draw_set_transform_matrix(transform.rotated_local(FootprintOrientation.angle_rad(turns)))
	var still := MineCart.parked_texture() if is_mine else SawmillAnim.idle_texture()
	var center := MineCart.FOOTPRINT_CENTER if is_mine else SawmillAnim.FOOTPRINT_CENTER
	canvas.draw_texture(still, -center, Color(1, 1, 1, 0.8))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
