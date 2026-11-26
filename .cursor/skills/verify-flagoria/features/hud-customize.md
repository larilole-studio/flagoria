# Customize HUD layout

Drive: drives/hud_customize.gd
Source: Scripts/ui/hud_layout.gd
Source: Scripts/ui/hud_layout_edit.gd

Customize HUD opens the same editor from [main-menu Settings](./settings-client.md) and the in-game menu. Settings previews the controls before a match starts. During a match the editor uses the live touch controls: joystick, attack, run, the tool wheel, Buildings and Map. Layout save version 5 resets older layouts to the defaults. Map sits beside Menu, Attack mirrors the joystick, Run and the tool wheel sit around Attack, and Buildings sits beside that cluster. Solo play pauses while editing; in multiplayer only the local layout changes. Drag moves a control; the size slider or a pinch resizes it between today’s size and 1.75×. Controls stay on screen and cannot overlap. The two-ring picker follows Buildings and opens inward. If obstructed, it tries the other side, then increases both radii together. In cramped layouts, all six discs stay visible and captions can be hidden to fit. The open picker dims the playfield during play. Save writes the layout to user settings on this device (not in world saves). Reset restores the default layout, including the thumb-side wheel button. Positions are stored relative to screen size.

## Sub-features

- `hud-customize-entry` Customize HUD sits in the in-game menu and opens edit mode (the drive opens the menu; headless saves use `-- test_hud_layout_round_trip`).
- `hud-customize-save` Save and load round-trip in user settings (`-- test_hud_layout_round_trip` in `tests/ui/test_hud_layout.gd`).
- `hud-customize-clamp` Off-screen positions clamp; overlaps are rejected (`-- test_hud_layout_clamp_overlap`). The edit bar stays inside the viewport on phone and desktop sizes (`-- test_hud_edit_bar_viewport_sizes`). The top-inset regression remains covered by `-- test_hud_edit_bar_stable_during_drag`.
- `hud-customize-toolbar` The toolbar stays visible and holds its position and size while dragging or resizing. From each entry point, the live drive samples the toolbar's visibility and global rect on 24 held drag frames and 12 slider resize frames. After each release, it checks that the toolbar is fully on screen and clear of the control visuals.
- `hud-customize-reset` Reset clears the saved file and brings back HudToolRow defaults (`-- test_hud_layout_reset`).
- `hud-customize-wheel` The wheel button moves and resizes, saves, and reloads the same place and scale. Reset puts it back inward of Attack, below Run. A save that has `mode` and no wheel id loads, and the arc from the moved button stays on screen (`-- test_hud_layout_wheel_slot` and `-- test_hud_layout_legacy_mode`).
- `hud-customize-edit-guard` In edit mode HUD buttons do not open map, buildings, mode, attack, run, or move the stick (`-- test_hud_layout_edit_blocks_map` and the drive tap on Map).

## How to get to it (user POV)

- Open Settings from the main menu and tap Customize HUD. Drag or resize a control, then select Save to keep the layout. Done or Back returns to Settings.
- Host a world. Open the in-game menu (top-right or Esc). Tap Customize HUD. Drag a control and adjust size. Save layout, then Done. Open the menu again and Reset to restore defaults.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: the `tests/ui/test_hud_layout.gd` cases are about 2.5 s in `tools/verify.sh`. The live drive is about 35 s under xvfb.

- **Run.** `./tools/verify.sh`, or `godot --headless --path . --script res://tests/run_tests.gd -- --only=hud_layout_round_trip,hud_layout_clamp_overlap,hud_layout_reset,hud_layout_edit_blocks_map`.
- **Proof.** Headers for the four `test_hud_layout_*` cases with no `FAIL` after them.
- **Drive (live).** `bin/launch.sh drives/hud_customize.gd --seed 49 --display`. The `settings-toolbar-drag` and `match-toolbar-drag` screenshots show the toolbar and slider while Attack is held. Their `-toolbar-released` counterparts show the toolbar clear of the controls. Other snapshots: `default-layout`, `edit-mode`, `moved-control` (attack and Map moved; edit bar clear of every control visual rect), `moved-wheel` (wheel button moved and resized), `no-overlap`, `after-save-restart`, `wheel-open` (half-moon on screen from the saved spot), `reset-layout`.

## Gotchas

- Layout is local only; multiplayer peers keep their own saved positions.
- Until Save, changes apply for this session but are not written to disk.
- The Map control keeps its saved position and opens the parchment sheet.
