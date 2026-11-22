extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## Candy Glass HUD at 1280x720 and 1920x1080 with the floating status row.
## bin/launch.sh drives/hud_direction_c.gd --display --seed 49

const WHEEL := "CanvasLayer1/ToolWheel"
const CUSTOMIZE := "CanvasLayer1/InGameMenu/Pause/Panel/Margin/VBox/CustomizeHud"


func run() -> void:
	if not await start_game():
		return
	await _resize_window("hud-1280", 1280, 720)
	step("interact")
	await toggle_mode()
	await snapshot("mode-interact")
	await toggle_mode()
	step("bow")
	var wheel: ToolWheel = current_scene.get_node(WHEEL)
	await tap_key(KEY_2)
	var armed := await wait_until(func() -> bool: return wheel.bow_armed(), 2.0)
	await snapshot("weapon-bow-1280")
	step("1080p")
	await _resize_window("hud-1920", 1920, 1080)
	step("customize")
	await click(MENU_BUTTON)
	await click(CUSTOMIZE)
	var ok := await wait_until(func() -> bool:
		return root.get_node("HudLayout").editing()
	, 3.0)
	await snapshot("hud-disabled-edit")
	done(ok and armed)


func _resize_window(label: String, width: int, height: int) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(width, height))
	root.size = Vector2i(width, height)
	for _i in 12:
		await process_frame
	await snapshot(label)
	if DisplayServer.get_name() != "headless":
		var img := root.get_texture().get_image()
		print("drive: %s png %dx%d" % [label, img.get_width(), img.get_height()])