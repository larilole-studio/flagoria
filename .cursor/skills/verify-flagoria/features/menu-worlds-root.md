# Main menu navigation

Drive: drives/menu_worlds_root.gd
Source: flagoria_main.gd
Source: Scripts/shell/MainMenu.gd
Source: Scripts/shell/menu_worlds.gd

The Flagoria menu offers **Worlds**, **Multiplayer** and **Settings**. Worlds keeps saved-world actions and opens Map Settings. Multiplayer holds the address, Join and connection feedback. Settings offers the volume sliders and Customize HUD. Worlds contains the [gameplay rows](./settings-client.md).

The worlds list uses most of the screen. Actions sit in a slim column on the right, bottom-aligned for a landscape thumb.

Run `bin/launch.sh drives/menu_worlds_root.gd --display` from the verify-flagoria skill. Compare the five 2400×1080 captures.

- `main-menu` shows Flagoria above Worlds, Multiplayer and Settings in order.
- `worlds` shows the save list taking most of the space, with a compact Gameplay column and a slim right-hand column for Load, Delete, Rename, New world, Host, Map Settings and Back.
- `map-settings` shows Map Generation. Back returns to Worlds, then Worlds Back returns to the root.
- `multiplayer` shows the address, Join and Back. The status appears when there is a join error.
- `settings` shows the settings rows and Back returns to the root.

`test_main_menu_landscape_layout` checks the navigation and bounds at both landscape sizes. `test_quit_prompt_on_back` covers Android back, the letter keyboard and the quit prompt.
