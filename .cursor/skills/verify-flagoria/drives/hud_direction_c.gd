extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## Direction C HUD at 1280x720 and 1920x1080: discs, plate, weapon swap.
## bin/launch.sh drives/hud_direction_c.gd --display --seed 49

const SCORES := "CanvasLayer1/ScoreboardToggle"
const BOW := "CanvasLayer1/BowButton"
const CUSTOMIZE := "CanvasLayer1/InGameMenu/Pause/Panel/Margin/VBox/CustomizeHud"


func run() -> void:
	if not await start_game():
		return
	await _snap_size("hud-1280", 1280, 720)
	step("scores-selected")
	await click(SCORES)
	await snapshot("scores-selected")
	await click(SCORES)
	step("interact")
	await click(MODE_BUTTON)
	await snapshot("mode-interact")
	await click(MODE_BUTTON)
	step("bow")
	await click(BOW)
	await snapshot("weapon-bow-1280")
	await click(MENU_BUTTON)
	await click(CUSTOMIZE)
	var ok := await wait_until(func() -> bool:
		return root.get_node("HudLayout").editing()
	, 3.0)
	await snapshot("hud-disabled-edit")
	step("1080p")
	await _snap_size("hud-1920", 1920, 1080)
	done(ok)


func _snap_size(label: String, width: int, height: int) -> void:
	DisplayServer.window_set_size(Vector2i(width, height))
	await process_frame
	await process_frame
	await snapshot(label)