## launch: --seed 42
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"

const SavedServers = preload("res://Scripts/shell/saved_servers.gd")
const ACTIONS_ROW := MULTIPLAYER_VIEW + "/Actions"
const CONFIRM := MULTIPLAYER_VIEW + "/Confirm"
const SAVED_LIST := MULTIPLAYER_VIEW + "/SavedScroll/SavedServers"
const SAVED_ADDRESS := "127.0.0.1:9799"


func run() -> void:
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(2400, 1080)
	if not await open_multiplayer():
		return
	print("VERIFY_READY pid=%d scene=%s" % [OS.get_process_id(), MAIN])

	step("empty-list")
	var list := current_scene.get_node_or_null(SAVED_LIST)
	if list == null or list.get_child_count() != 0:
		_fail("expected an empty saved-server list")
		return
	await snapshot("multiplayer-empty")

	step("blank-join")
	await click(JOIN_BUTTON)
	var status: Label = current_scene.get_node(MULTIPLAYER_VIEW + "/JoinStatus")
	if (
		not status.is_visible_in_tree()
		or status.text != "Enter the host's IP address"
		or not current_scene.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		or FileAccess.file_exists(SavedServers.PATH)
	):
		_fail("blank Join did not stay offline with the expected prompt")
		return

	if await capture_saved_server(list):
		await confirm_delete(list)


func capture_saved_server(list: Node) -> bool:
	step("reopen-with-saved-server")
	var fixture := ConfigFile.new()
	fixture.set_value(SavedServers.SECTION, SavedServers.KEY, PackedStringArray([SAVED_ADDRESS]))
	if fixture.save(SavedServers.PATH) != OK:
		return _fail("could not seed the saved-server fixture")
	await click(ACTIONS_ROW + "/BackButton")
	if not menu_root_visible():
		return _fail("Back did not return to the main menu")
	await click(MULTIPLAYER_BUTTON)
	if list.get_child_count() != 1 or list.get_child(0).text != SAVED_ADDRESS:
		return _fail("saved server was not listed after reopening Multiplayer")
	var field: LineEdit = current_scene.get_node(ACTIONS_ROW + "/AddressEntry")
	if (
		not field.is_visible_in_tree()
		or not current_scene.get_node(JOIN_BUTTON).is_visible_in_tree()
	):
		return _fail("the filled list hid the address or Join")
	await snapshot("multiplayer-saved")
	return true


func confirm_delete(list: Node) -> void:
	step("confirm-delete")
	await click(str(current_scene.get_path_to(list.get_child(0))))
	var field: LineEdit = current_scene.get_node(ACTIONS_ROW + "/AddressEntry")
	if field.text != SAVED_ADDRESS:
		_fail("tapping a saved server did not fill the address")
		return
	await click(ACTIONS_ROW + "/DeleteButton")
	if not current_scene.get_node(CONFIRM).is_visible_in_tree():
		_fail("Delete did not ask for confirmation")
		return
	await click(CONFIRM + "/No")
	if list.get_child_count() != 1 or current_scene.get_node(CONFIRM).is_visible_in_tree():
		_fail("No did not cancel the deletion")
		return
	await click(ACTIONS_ROW + "/DeleteButton")
	await click(CONFIRM + "/Yes")
	if list.get_child_count() != 0:
		_fail("Yes did not remove the saved server")
		return
	if not await open_multiplayer():
		return
	done(current_scene.get_node(SAVED_LIST).get_child_count() == 0)


func open_multiplayer() -> bool:
	if change_scene_to_file(MAIN) != OK:
		return _fail("cannot load " + MAIN)
	if not await wait_until(
		func() -> bool: return current_scene != null and current_scene.has_node(MULTIPLAYER_BUTTON),
		START_TIMEOUT_S
	):
		return _fail("no Multiplayer button")
	await click(MULTIPLAYER_BUTTON)
	return true
