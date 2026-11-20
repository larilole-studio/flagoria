# Join failure returns to the main menu

Drive: drives/join_fail.gd

A Join that never connects (wrong address, host not running, port blocked) returns to the main menu with a visible `Could not join <address>` message instead of leaving the player on an empty game screen (#348). A client whose host quits mid-game also lands back on the main menu.

## Sub-features

- `join-fail-no-host` `multiplayer.connection_failed` and a non-`OK` `create_client` close the peer, hide the HUD, show the main menu, restore menu music, and set `JoinStatus` to `Could not join <address>` (`Scripts/shell/MainMenu.gd` `show_join_failed`, `flagoria_main.gd` `_on_join_failed`).
- `join-fail-host-quits` `multiplayer.server_disconnected` calls `leave_to_main_menu()` (scene reload), same as the in-game Main menu button.

## How to get to it (user POV)

- Launch, enter an address with no host, press Join; after the ENet timeout the menu is back with the red status line under the address field.
- Or join a live host that then quits: the client reloads to the main menu.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `join_fail_no_host` ~6 s in verify (~8 s alone with `--only=`); `join_fail_host_quits` ~6–8 s (probe); live drive ~8 s.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=join_fail_no_host,join_fail_host_quits`, or full `tools/verify.sh`.
- **Drive (live).** `bin/launch.sh drives/join_fail.gd --display` (## launch: --seed 42). Steps `menu`, `join`: open the main scene, set address `127.0.0.1`, join a free UDP port with nothing listening, wait for the menu and `JoinStatus`, `snapshot("before-join")` then `snapshot("join-failed")`, `done(true)`.
- **Proof.** Headers `-- test_join_fail_no_host`, `-- test_join_fail_host_quits` with no `FAIL` after them. Drive snapshots show the main menu with `Could not join 127.0.0.1` under the address field.

## Gotchas

- One dial stops sending connect packets after about 1.5 s (`set_timeout(8, 800, 3000)`) and then waits out the cap. Join dials again every 1 s for 6 s, so a host that is still starting is contacted, and a join with nobody listening still returns inside 8 s. After the server accepts the peer, a lost host is noticed within about 6 s (`set_timeout(8, 4000, 5500)`). The longest castle placement measured with four joins at once was 331 ms, and a 2 s stall after accept left the peer up.
- `leave_to_main_menu` reloads the current scene; the host-quits check runs in `tests/join_fail_probe.gd` as its own process (same pattern as `test_ingame_menu_leave`). That probe dials only after the server log says it is listening, so a slow boot is not treated as an unanswered dial.
