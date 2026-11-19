# Map Settings panel

Drive: drives/map_settings_random.gd

Map Settings opens the **Map Generation** panel (`map_admin_panel.tscn`, `Scripts/MapAdminPanel.gd`). The scrolling form starts with five seed fields and a noise-type selector. The host can open the same panel from the in-game menu, where **Host with these** is disabled.

## Sub-features

- `settings-open` opens the panel from Main Menu → Map Settings.
- `settings-edit` changes seeds and numeric parameters (scrollable on 480×270).
- `settings-host` starts a host with the chosen parameters (Host with these / Host after Back).
- `settings-persist` restores last-used values from `user://` across restarts, and shows the in-use value on reopen even when a field still holds a dirty string.
- `settings-rows` exported booleans get switches, including **Day and night**, and numeric parameters with `@export_range` get spin boxes, including **Birch min chance**. The arranged rows have a 140 px label and 140 px field. The host sends generation parameters to clients through `to_dict`.
- `settings-generate-building` **Generate building** is at the end of the scrolling form. In a hosted world it uses the current building size and style fields (see [Generated building](./generated-building.md)).
- `settings-number-pad` tapping a seed or number field opens the on-screen number pad (`Scripts/number_pad.gd`, see [Touch controls](./touch-controls.md)), and on a phone it stays open after the tap.
- `settings-bottom-visible` the five action buttons stay fully inside the 480×270 layout space, which the 1280×720 window and the 854×480 landscape window both show (stretch aspect keep). They are two equal pairs (Random seeds / Random specs, then Defaults / Back) and Host with these centered on its own row, pinned below the scroll area (#406 kept that pin; #217 is the five-button arrangement). Headless: `-- test_map_settings_bottom_buttons_visible`.
- `settings-random-specs` **Random specs** sets every map-gen property (except `chunk_*`) inside `MapGenParams.PLAYABLE_RANGES`, randomises seeds, keeps ordered thresholds, and picks island or archipelago so the map stays playable (#335). **Random seeds** still only changes seeds. Headless: `-- test_random_specs_playable`, `-- test_random_seed_unchanged_by_specs_contract`, `-- test_random_specs_panel_button`.

## How to get to it (user POV)

- Launch the game → Main Menu → **Map Settings**.
- Adjust controls → **Random seeds** / **Random specs** / **Defaults** / **Back** or **Host with these**. During a match, open **Map Settings** from the host’s in-game menu to use **Generate building**.

## Driving it with verify-flagoria helpers

Preconditions:

- `doctor.sh` exits `0`.
- `xvfb-run` available for visual proof; otherwise skip and record the skip.

- **Random specs drive.** `bin/launch.sh drives/map_settings_random.gd --display` opens Map Settings and snapshots the five buttons at the 1280×720 window (`01-map-settings-before.png`), at the 854×480 landscape window (`02-map-settings-landscape.png`), then after **Random specs** back at 1280×720 (`03-map-settings-after-random.png`). It then clicks Back and checks the main menu returns. About 3 s.
- **Screenshot open panel (legacy).** Run `./.cursor/skills/verify-flagoria/bin/drive-map-settings-screenshot.sh`. Exit `0` writes `artifacts/out/map_settings.png` (~10 s); the committed `artifacts/map_settings.png` is the reference to compare by eye. Exit `2` means xvfb missing (skip visual).
- **Headless coverage.** `-- test_map_settings_covers_params` checks host control and map-input coverage. `-- test_map_settings_water_reopen` checks the displayed in-use value. `-- test_map_settings_number_pad_touch_tap` checks that a touch edit reaches the seed. `-- test_map_settings_bottom_buttons_visible` checks the five action buttons stay inside the 480×270 view. `-- test_map_settings_number_pad_spin_boxes` checks that invalid text is filtered, an out-of-range water altitude clamps, and the saved value affects generated terrain after reload.
- **Proof.** Drive PNGs show all five action buttons and the pinned bottom row, at 1280×720 and at 854×480, with no overlap and no button cut by the window edge. Before/after **Random specs** differ in seed and/or numeric fields.

## Gotchas

- Viewport is 480×270 with stretch aspect keep, so a 1280×720 window and an 854×480 landscape window use the same layout space. Not every field is on screen at once. The scroll area has no fixed minimum height, so the three pinned button rows stay fully inside that space (#406, #217).
- Joining clients receive host params over RPC; editing Map Settings on a pure client does not author the world.
- Do not claim screenshot proof when GL/xvfb failed.
