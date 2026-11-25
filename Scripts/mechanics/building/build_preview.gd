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
	var anchor := canvas.to_local(point) + Vector2(8, -12)
	canvas.draw_string_outline(
		font, anchor, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 2, Color(0.15, 0.10, 0.20)
	)
	canvas.draw_string(
		font,
		anchor,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		REASON_COLOR if refused else COST_COLOR
	)
