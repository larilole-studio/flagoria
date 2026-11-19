# Round HUD buttons

Drive: drives/hud_round_buttons.gd

The match starts with the minimap and build picker closed. Map sits left of Menu on the top edge. Buildings sits above Attack. It opens two compact rings of labelled discs. From the top, the inner ring holds Plank, Wall and Tower, and the outer ring holds Castle, Guard post and Barracks. The picker follows Buildings in a custom layout. Tap Buildings again, pick a tool or tap outside to close the picker. The selected tool keeps its ring when reopened. The tool wheel sits beside Run.

## Sub-features

- `hud-round-arc` Map sits beside Menu and Buildings sits above Attack, with clear space around the tap targets (`-- test_hud_no_overlap` and live drive). Run is a smaller neighbour of the attack button. `CanvasLayer1/MapReopen` is absent (`-- test_hud_round_buttons`).
- `hud-build-list` Buildings opens the picker and a second tap or an outside tap closes it. Each disc has a tool icon and label. Picking a building selects that tool, collapses the list and keeps the gold ring (`-- test_hud_round_buttons`, `-- test_build_picker_switches_tool`).
- `hud-minimap-closed` the wood panel stays hidden until Map opens it, and a second press closes it. While it is open, every arc button sits outside the panel. Selecting chop keeps a picked build tool, and sword clears it back to Cut (`-- test_hud_round_buttons`).
- `hud-no-overlap` All visible tap targets stay inside the viewport and clear of one another at phone, desktop and tablet sizes. The test opens Buildings, Map, Scores and the tool wheel, and repeats the default and Buildings states with a saved custom layout (`-- test_hud_no_overlap`).
- `hud-layout-golden` Stock HUD hit rectangles match the saved layout at four window sizes for the default, Buildings, Map and Scores states (`-- test_hud_layout_golden`).

## How to get to it (user POV)

- Host a world. Buildings is above Attack and the minimap is closed. Tap Buildings to show Plank, Tower, Castle, Guard post, Barracks and Wall, and tap Map to open the panel. Key 3 arms chop and key 1 returns to sword. Run is the small button beside attack.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_hud_round_buttons` is about 0.8 s in `tools/verify.sh`. The live drive is about 25 s under xvfb.

- **Run.** `./tools/verify.sh`, or `godot --headless --path . --script res://tests/run_tests.gd -- --only=hud_round_buttons,hud_no_overlap`.
- **Proof.** `PASS test_hud_round_buttons` and `PASS test_hud_no_overlap`.
- **Drive (live).** `bin/launch.sh drives/hud_round_buttons.gd --seed 49 --display`. Snapshots: `match-start` (minimap closed, list collapsed), `building-list` (two labelled rings above and inward from Buildings, clear of Attack), `building-selected` (Plank's ring), `minimap` (panel open, arc clear of it), `interact` (chop icon on the tool button, arc still clear).

## Gotchas

- Cut has no button. It is the tool while none of Plank, Tower, Castle, Guard post, Barracks or Wall is selected, and again after leaving interact mode.
- Collapse and maximize stay on the wood frame. Collapse hides the panel; Map opens it again.
- The wood panel sits left of the arc. With the minimap open, Buildings and Map each lie outside the panel rect. The drive checks that before the minimap and interact shots.
- The bright ring is the selected state. A darker face alone sits behind the icon and does not read as selected.
- The tap target is larger than the disc. The extra pixels are not drawn, and the picker targets stay clear of each other and the other HUD buttons.
- Replacing the four PNGs in `assets/ui/hud/` changes the icons with no code change. They import without mipmaps and the buttons draw them nearest-neighbour.
