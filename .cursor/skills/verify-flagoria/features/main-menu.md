# Main menu

Drive: drives/menu_worlds_root.gd
Source: Scripts/shell/MainMenu.gd

The main menu opens with **Worlds**, **Multiplayer** and **Settings**. Worlds lists saves and offers Host and [Map Settings](./map-settings-panel.md). Multiplayer contains the join address, Join and any connection status. Settings opens the Music and Sound effects sliders, Mob spawns, tower range, damage and cooldown, and raid controls. See [Main menu navigation](./menu-worlds-root.md) for the player path and screenshots. The tower rows are the host's TowerGuns settings ([Defense towers](./defense-towers.md)).

## Sub-features

- `menu-theme` `art/ui/main_menu_theme.tres`, applied in `flagoria_main.tscn`.
- `menu-host-join` Host and Join buttons; enter `localhost` to join a host on the same machine on UDP `9786`. A [blank address](./join-no-ip.md) shows `Enter the host's IP address`. A hostname or IPv4 address may add `:port` (see [Join an address with an optional port](./join-port.md)). Tapping the address opens the on-screen letter keyboard (see [Touch controls](./touch-controls.md)).
- `menu-volume` Music and Sound effects sliders (see `audio.md`).
- `menu-mob-rate` Mob spawns slider (`MobRateRow`, `Scripts/shell/game_settings.gd`): 0.5 to 3.0 in 0.25 steps, default 2.0, saved in user settings section `gameplay`. Only the host's rate places mobs (see [Mobs](./mobs.md)).
- `menu-raids` Rows under that slider: raids on or off (off by default), interval, group size and radius. See [Mob raids](./mob-raid.md).
- `menu-sfx` every button plays the UI click, Back plays back (see `audio.md`).
- `menu-quiet-log` unhandled input on the menu logs no InputMap errors.
- `menu-quit` Android back closes the keyboard or steps out of a submenu. On the root or during a match, back asks before quitting. Window close also asks before quitting (see [In-game menu and quit prompt](./ingame-menu.md)).

## How to get to it (user POV)

- Launch the game; the menu is the first screen.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`.

- **Run.** Run `./.cursor/skills/verify-flagoria/bin/drive-verify.sh` (or `./tools/verify.sh`) and read `artifacts/verify.log`.
- **Layout test.** `test_main_menu_landscape_layout` checks the three root buttons, each submenu and the Back buttons at 2400×1080 and 480×270.
- **Proof.** Each header `-- test_audio_settings`, `-- test_dedicated_server_join`, `-- test_mob_spawn_rate`, `-- test_main_menu_letter_keyboard`, `-- test_main_menu_input_no_log_spam` (runs a separate headless process, ~2 s) appears in the log, no `FAIL` line follows it, and the run ends with `All tests passed.` and `Verification passed.`

## Gotchas

- The theme's Button styles are checked by `verify-generators` (`PASS menu theme (5 Button styles) used by the main menu`). For visual review, use the [main menu navigation drive](./menu-worlds-root.md).
