# Round HUD buttons

Drive: drives/hud_round_buttons.gd

The match starts with the wood minimap closed and the build list collapsed. Buildings and Map are round buttons on a quarter arc in the top-right corner, clear of the menu button and the wood counter. Chop is the tool wheel, beside Run, not a third arc button. Each disc is 18 pixels, with a tap target of at least 24 (`RoundHudStyle` disc 18, tap target 24). Buildings opens Plank, Tower, Castle, Guard post, Barracks and Wall on the same discs in columns that open leftward from Buildings and stay above the attack controls, all on screen; their icons are smaller so the disc and the gold ring stay visible, and each tap target is still at least 24. The column stays closed until Buildings is open (`BuildPlacement._list_open`); tool buttons show only while the list is open. A second tap on Buildings, or picking one, collapses the column. The picked tool keeps the gold ring. Map toggles the minimap, and the open panel sits left of the arc so it does not cover a button. Mode toggles attack and interact, and its icon follows the mode. Run sits beside the attack button, smaller than that button, and still holds, latches and follows Shift. Nothing in the column hides when a peer connects (`BuildToolRow.MP_HIDDEN` is empty). The icons are `assets/ui/hud/icon_buildings.png`, `icon_map.png`, `icon_run.png`, `icon_mode_attack.png` and `icon_mode_interact.png`.

## Sub-features

- `hud-round-arc` Buildings and Map sit in a top-right arc, each at least the round hit size, clear of the wood counter, the menu and each other (`-- test_hud_no_overlap` and live drive). Run is a smaller neighbour of the attack button. `CanvasLayer1/MapReopen` is absent (`-- test_hud_round_buttons`).
- `hud-build-list` Buildings opens the column and a second tap closes it. Each entry is a round disc with the tool icon inside it. Picking a building selects that tool, collapses the list and keeps the gold ring (`-- test_hud_round_buttons`, `-- test_build_picker_switches_tool`).
- `hud-minimap-closed` the wood panel stays hidden until Map opens it, and a second press closes it. While it is open, every arc button sits outside the panel. Selecting chop keeps a picked build tool, and sword clears it back to Cut (`-- test_hud_round_buttons`).
- `hud-no-overlap` All visible tap targets stay inside the viewport and clear of one another at phone, desktop and tablet sizes. The test opens Buildings, Map, Scores and the tool wheel, and repeats the default and Buildings states with a saved custom layout (`-- test_hud_no_overlap`).
- `hud-layout-golden` Stock HUD hit rectangles match the saved layout at four window sizes for the default, Buildings, Map and Scores states (`-- test_hud_layout_golden`).

## How to get to it (user POV)

- Host a world. The arc is in the top-right and the minimap is closed. Tap Buildings to show Plank, Tower, Castle, Guard post, Barracks and Wall, and tap Map to open the panel. Key 3 arms chop and key 1 returns to sword. Run is the small button beside attack.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_hud_round_buttons` is about 0.8 s in `tools/verify.sh`. The live drive is about 25 s under xvfb.

- **Run.** `./tools/verify.sh`, or `godot --headless --path . --script res://tests/run_tests.gd -- --only=hud_round_buttons,hud_no_overlap`.
- **Proof.** `PASS test_hud_round_buttons` and `PASS test_hud_no_overlap`.
- **Drive (live).** `bin/launch.sh drives/hud_round_buttons.gd --seed 49 --display`. Snapshots: `match-start` (minimap closed, list collapsed), `building-list` (columns of discs left of Buildings, clear of Attack), `building-selected` (Plank's ring), `minimap` (panel open, arc clear of it), `interact` (chop icon on the tool button, arc still clear).

## Gotchas

- Cut has no button. It is the tool while none of Plank, Tower, Castle, Guard post, Barracks or Wall is selected, and again after leaving interact mode.
- Collapse and maximize stay on the wood frame. Collapse hides the panel; Map opens it again.
- The wood panel sits left of the arc. With the minimap open, Buildings and Map each lie outside the panel rect. The drive checks that before the minimap and interact shots.
- The bright ring is the selected state. A darker face alone sits behind the icon and does not read as selected.
- The tap target is larger than the disc. The extra pixels are not drawn, and the three arc targets stay clear of each other and of the menu button.
- Replacing the four PNGs in `assets/ui/hud/` changes the icons with no code change. They import without mipmaps and the buttons draw them nearest-neighbour.
