extends "res://.cursor/skills/verify-flagoria/drives/tuning_panel.gd"
## launch: --seed 101

const DRIVE_PORT := 19786


func host_from_menu() -> void:
	# Keep the evidence session off the default port used by other drives.
	current_scene.host_port = DRIVE_PORT
	await super.host_from_menu()


func run() -> void:
	if DisplayServer.get_name() != "headless":
		root.size = WINDOW_SIZE
	if not await start_game():
		return
	if not get_multiplayer().multiplayer_peer is ENetMultiplayerPeer:
		_fail("host did not open a network listener")
		return
	step("raise Castle wood to 40 before the client joins")
	await _touch(MENU_BUTTON)
	await _touch(TUNING_BUTTON)
	for i in 5:
		await _touch(CASTLE_WOOD + "/Increase")
	if not _shows_value(CASTLE_WOOD, "40"):
		_fail("host did not set Castle wood to 40")
		return
	step("wait for the joiner's Mine wood edit")
	if not await wait_until(func() -> bool: return BuildCosts.cost(BuildCosts.MINE) == 16, 60):
		_fail("the joiner's Mine wood edit did not reach the host")
		return
	step("wait for the joiner to return to the main menu")
	done(await wait_until(func() -> bool: return get_multiplayer().get_peers().is_empty(), 45))
