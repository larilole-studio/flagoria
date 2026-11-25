# Map Settings panel

Drive: drives/map_settings_random.gd
Source: Scripts/ui/MapAdminPanel.gd
Source: Scripts/world/MapGenParams.gd

Main Menu → **Settings** → **Map Settings** opens the Map Generation panel. The in-game host menu opens the same panel with **Host with these** disabled.

- **Island size** sets island radius, archipelago spacing, archipelago island radius, and half-world extent in tiles. Small uses 80 / 80 / 40 / 512, Medium 140 / 112 / 52 / 768, and Big 200 / 144 / 64 / 1024. The archipelago fields govern the common presets, including open sea beyond the world extent. The island radius is available to single-island maps when Advanced turns archipelago spacing off.
- **Biome size** sets biome frequency. Small uses 0.006, Medium 0.003, and Big 0.002. The lower frequency makes larger biome regions.
- **Spawn biome** defaults to Any. Oceanic, Temperate, Continental, and Dense archipelago search for clear land in that biome. The starting castle's gate front stays in the chosen biome when the spawn search found it.
- New settings start at Medium / Medium / Any. A fresh host starts near wood reachable on foot. If there is none within seven walking steps plus an adjacent chop, generation adds up to three trees. The fallback trees regenerate from the saved or synced map inputs like other plants.
- **Advanced** opens the scrolling raw controls, including seeds, day and night, building settings and **Generate building**. The seed and spin fields use the touch number pad. Existing map values populate the raw fields and presets show **Custom** when the values do not match a preset. Advanced starts closed each time the panel opens.
- **Random seeds** rerolls seeds. **Random specs** rerolls the common choices and seeds in the common view, or the raw generation specs and seeds in Advanced. **Defaults** restores new-world inputs. **Back** saves the settings and returns to Settings or, when opened in a match, to the world. **Host with these** starts a world with the selected inputs.

## Verification

- Run `bin/launch.sh drives/map_settings_random.gd --display --seed 42` from the verify-flagoria skill. Set `VERIFY_WINDOW_SIZE=2400x1080` for ultrawide evidence. In the Settings shot, check that **Map Settings** and **Back** fit below the sliders. Compare the common and Advanced shots for five fully visible action buttons, three complete selectors in the common view, and raw rows scrollable in Advanced. The drive backs out to Settings, reopens Map Settings, and hosts through **Host with these** for the spawn shot.
- `-- test_map_settings_simple_choices` checks the common view, presets, and spawn-biome input. `-- test_map_settings_bottom_buttons_visible` checks the 480×270 layout. `-- test_map_settings_covers_params`, `-- test_map_settings_water_reopen`, `-- test_map_settings_number_pad_touch_tap`, `-- test_map_settings_number_pad_spin_boxes`, and `-- test_random_specs_panel_button` cover the raw controls.
- `-- test_spawn_presets_and_starter_wood` hosts with all island sizes and named biomes, verifies wood for seeds 11, 42, and 99, and verifies a fallback grove on a map without natural wood. See [issue evidence](../../../../docs/evidence/map-settings-664/coverage.md) for the biome render results.
- `-- test_random_specs_playable` covers the raw randomization ranges, and `-- test_random_seed_unchanged_by_specs_contract` covers seed-only randomization.
