# Main menu

Drive: not player-facing

The main menu keeps Map Settings, Host, Worlds, Join, the join address and Settings in one view. Settings opens the Music and Sound effects sliders, Mob spawns, tower range, damage and cooldown, and raid controls. Only the settings list scrolls when it needs more room. Back stays below the list and returns to the main menu. The tower rows are the host's TowerGuns settings ([Defense towers](./defense-towers.md)).

## Sub-features

- `menu-theme` `art/ui/main_menu_theme.tres`, applied in `flagoria_main.tscn`.
- `menu-host-join` Host and Join buttons; enter `localhost` to join a host on the same machine on UDP `9786`. A [blank address](./join-no-ip.md) shows `Enter the host's IP address`. A hostname or IPv4 address may add `:port` (see [Join an address with an optional port](./join-port.md)). Tapping the address opens the on-screen letter keyboard (see [Touch controls](./touch-controls.md)).
- `menu-volume` Music and Sound effects sliders (see `audio.md`).
- `menu-mob-rate` Mob spawns slider (`MobRateRow`, `Scripts/shell/game_settings.gd`): 0.5 to 3.0 in 0.25 steps, default 2.0, saved in user settings section `gameplay`. Only the host's rate places mobs (see [Mobs](./mobs.md)).
- `menu-raids` Rows under that slider: raids on or off (off by default), interval, group size and radius. See [Mob raids](./mob-raid.md).
- `menu-sfx` every button plays the UI click, Back plays back (see `audio.md`).
- `menu-quiet-log` unhandled input on the menu logs no InputMap errors.
- `menu-quit` back or window close asks before quitting (see [In-game menu and quit prompt](./ingame-menu.md)).

## How to get to it (user POV)

- Launch the game; the menu is the first screen.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`.

- **Run.** Run `./.cursor/skills/verify-flagoria/bin/drive-verify.sh` (or `./tools/verify.sh`) and read `artifacts/verify.log`.
- **Layout test.** Run `test_main_menu_landscape_layout` at 2400×1080. The visible main menu controls fit inside the viewport. Clicking Settings reveals the scroll area and Back within the viewport. Clicking Back restores the main menu.
- **Proof.** Each header `-- test_audio_settings`, `-- test_dedicated_server_join`, `-- test_mob_spawn_rate`, `-- test_main_menu_letter_keyboard`, `-- test_main_menu_input_no_log_spam` (runs a separate headless process, ~2 s) appears in the log, no `FAIL` line follows it, and the run ends with `All tests passed.` and `Verification passed.`

## Gotchas

- The theme's Button styles are checked by `verify-generators` (`PASS menu theme (5 Button styles) used by the main menu`). For visual review, launch under xvfb with `--resolution 2400x1080 --rendering-driver opengl3`, then click Settings and Back. The [landscape captures](../../../../docs/evidence/main-menu-662/) show each view.
