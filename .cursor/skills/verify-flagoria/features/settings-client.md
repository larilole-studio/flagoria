# Client settings

Drive: drives/settings_client.gd
Source: Scripts/shell/MainMenu.gd
Source: Scripts/shell/menu_gameplay_settings.gd
Source: Scripts/shell/menu_worlds.gd

From the main menu, open Settings to adjust Music and Sound effects or select Customize HUD. The HUD editor displays the touch controls without starting a match. Save writes the layout to this device. Done or Back returns to Settings. Use Worlds to adjust mob spawns, tower range, damage and cooldown, or raid options for hosted matches.

Run the drive with `VERIFY_WINDOW_SIZE=2400x1080 ./.cursor/skills/verify-flagoria/bin/launch.sh drives/settings_client.gd --display` from the repository root. It uses scratch settings and writes three screenshots.

- `settings` shows both volume sliders and Customize HUD. Map Settings and gameplay rows are absent.
- `customize-hud` shows the six touch controls and the existing editor. The drive drags Map, saves the layout and returns to Settings using both Done and Back.
- `worlds-gameplay` shows the gameplay column beside the wider saved-worlds list. Host, Map Settings and Back remain visible in the actions column.

The drive exits with `VERIFY_DONE ok` after Back from Settings and Worlds returns to the root. `test_main_menu_landscape_layout` checks menu contents at two landscape sizes. `test_audio_settings` reloads the saved audio and gameplay keys and checks both sliders in a new menu instance. `test_quit_prompt_on_back` covers Android back and the window-close prompt.
