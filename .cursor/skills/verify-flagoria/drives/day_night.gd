## fixture
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Day, dusk and night on one map. The cycle is 10 minutes, so the drive
## seeks the host clock to the middle of each hold and saves that screen.


func run() -> void:
	if not await start_game():
		return
	var clock := root.get_node("DayNight")
	var mod := root.get_node_or_null("DayNight/WorldTint") as CanvasModulate
	var hud := current_scene.get_node("CanvasLayer1")
	var placed := mod != null and not _under_canvas_layer(mod) and not _layer_has_modulate(hud)
	step("day")
	clock.seek_phase("day")
	await snapshot("day")
	step("dusk")
	clock.seek_phase("dusk")
	await snapshot("dusk")
	step("night")
	clock.seek_phase("night")
	await snapshot("night")
	var night_tint: Color = clock.color_of("night")
	var phase := str(clock.phase())
	var night := mod != null and phase == "night" and _same(mod.color, night_tint)
	print(
		"day_night: phase=%s tint=%s hud_clear=%s" % [phase, mod.color if mod else "none", placed]
	)
	done(placed and night)


func _under_canvas_layer(node: Node) -> bool:
	var at := node.get_parent()
	while at != null:
		if at is CanvasLayer:
			return true
		at = at.get_parent()
	return false


func _layer_has_modulate(node: Node) -> bool:
	for child in node.get_children():
		if child is CanvasModulate or _layer_has_modulate(child):
			return true
	return false


func _same(got: Color, want: Color) -> bool:
	return (
		is_equal_approx(got.r, want.r)
		and is_equal_approx(got.g, want.g)
		and is_equal_approx(got.b, want.b)
	)
