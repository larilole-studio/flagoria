# Round HUD buttons

Drive: drives/hud_round_buttons.gd

The match starts with the parchment map and build picker closed. Map sits left of Menu on the top edge. Attack mirrors the joystick and matches its base diameter. Run sits inward and above the wheel on the inside of Attack. Buildings sits above and outward from Attack and opens two compact rings over the dimmed playfield. Captions appear where they fit. From the top, the inner ring holds Plank, Wall and Tower, and the outer ring holds Castle, Guard post and Barracks. The picker follows Buildings in a custom layout. Tap Buildings again, pick a tool or tap outside to close the picker. The selected tool keeps its ring when reopened.

## Sub-features

- `hud-round-arc` Map sits beside Menu, and Buildings sits beside the Attack, Run and tool wheel cluster, with clear space around the tap targets (`-- test_hud_no_overlap` and live drive). Run is a smaller neighbour of the attack button.
- `hud-build-list` Buildings opens the picker and a second tap or an outside tap closes it. Each lilac disc has its own baked-in tool icon, with Lilita One captions where space permits. Picking a building selects that tool, collapses the list and keeps the pale-yellow ring (`-- test_hud_round_buttons`, `-- test_build_picker_switches_tool`).
- `hud-build-saved-layout` If a narrower viewport would put another HUD target over Buildings, Buildings shifts clear. The regression test restores a layout saved at 3840×1080, taps Buildings at 2400×1080, checks that all six tools are visible within the viewport, and taps Buildings again to dismiss (`-- test_build_picker_saved_layout_tap`).
- `hud-no-overlap` All visible tap targets stay inside the viewport and clear of one another at phone, desktop and tablet sizes. The test opens Buildings, Scores and the tool wheel, and repeats the default and Buildings states with a saved custom layout (`-- test_hud_no_overlap`).
- `hud-layout-golden` Stock HUD hit rectangles match the saved layout at four window sizes for the default, Buildings and Scores states (`-- test_hud_layout_golden`).

## How to get to it (user POV)

- Host a world. Buildings sits beside the right-thumb cluster and parchment is closed. Tap Buildings to show Plank, Tower, Castle, Guard post, Barracks and Wall, and tap Map to open parchment. Key 3 arms chop and key 1 returns to sword. Run is the small button beside attack.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_hud_round_buttons` is about 0.8 s in `tools/verify.sh`. The live drive is about 25 s under xvfb.

- **Run.** `./tools/verify.sh`, or `godot --headless --path . --script res://tests/run_tests.gd -- --only=hud_round_buttons,hud_no_overlap,build_picker_saved_layout_tap`.
- **Proof.** `PASS test_hud_round_buttons`, `PASS test_hud_no_overlap` and `PASS test_build_picker_saved_layout_tap`.
- **Drive (live).** `bin/launch.sh drives/hud_round_buttons.gd --seed 49 --display` captures `match-start` (parchment closed, list collapsed), `building-list` (two rings above and inward from Buildings, clear of Attack, with the playfield dimmed), `building-dismissed` (playfield clear after a second tap), `building-selected` (Plank's ring), `parchment` (full sheet open) and `interact` (chop icon on the tool button, arc still clear).

## Gotchas

- Cut has no button. It is the tool while none of Plank, Tower, Castle, Guard post, Barracks or Wall is selected, and again after leaving interact mode.
- The bright ring is the selected state. A darker face alone sits behind the icon and does not read as selected.
- The tap target is larger than the disc. The extra pixels are not drawn, and the picker targets stay clear of each other and the other HUD buttons.
- Replacing the four PNGs in `assets/ui/hud/` changes the icons with no code change. They import without mipmaps and the buttons draw them nearest-neighbour.
