# Build placement

Drive: drives/center_build_preview.gd
Source: Scripts/mechanics/building/build_placement.gd
Source: Scripts/mechanics/building/build_preview.gd
Source: Scripts/mechanics/building/build_tool_row.gd
Source: Scripts/mechanics/interact/interaction.gd

Interact-mode build tools (#225 / #273 / #276). The build picker lists Plank,
Wall and Tower in the inner ring, and Castle, Guard post and Barracks in the
outer ring (see [Round HUD buttons](./hud-round-buttons.md)). The rings open
inward above Buildings and dim the playfield. The picker stays closed until
Buildings is open (`BuildPlacement._list_open` starts false; each tool button is
visible only while the list is open). Cut keeps the existing tap, drag and chop
behaviour and is the tool when none of those is selected. Selecting Tower, Castle,
Guard post or Barracks enters interact mode and immediately previews the
footprint at the snapped screen center (#711). Press open playfield and drag to move the preview by the finger's
travel. Cost and refusals are drawn beside the snapped preview. See [Build tower](./build-tower.md), [Build castle](./build-castle.md),
[Build guard post](./build-guard-post.md) and [Build barracks](./build-barracks.md).
Plank and the first Wall run start at the snapped center and extend by the drag
delta along the dominant axis. Wall extensions start from the existing tip
(see [Free-form walls](./free-form-walls.md)). [Demolish](./demolish-construction.md)
previews and removes by tapping the target.
The preview greens exactly the cells `commit` will place and shows that wood cost;
the rest is red. A refusal reason appears when nothing is placeable (including an
empty wall gap). On release, placement goes through `ConstructionPlacer`
(`can_place` / `cost` / `place`). Dead-player gating stays
on `Interaction.player_dead`. `BuildToolRow.MP_HIDDEN` is empty, so nothing hides
when a peer connects; every picker tool stays available in multiplayer (#297,
#497, #498, #527, #528, #556). `update_preview` skips the snap / `can_place` work
only when the snapped cells, wood count, player position and map revision are
unchanged, so a wood spend, a walk out of reach, or a map change cannot leave a
stale green preview. The tool wheel and the lilac picker discs use Candy Glass sprites from `art/ui/hud_e4/`.

For a center-origin Plank drag, leading shore and existing deck stay red.
Preview and commit use up to 10 consecutive cells from the first reachable
water cell at one wood per cell (#684). Cells beyond the cap stay red.

## Sub-features

- `build-picker` Plank, Tower, Castle, Guard post, Barracks and Wall sit in the
  build picker; the picker is hidden until Buildings is open, including in
  combat, and switches `BuildPlacement.tool`. Nothing is hidden in multiplayer.
  Leaving interact resets the tool to Cut.
- `build-plank-snap` a diagonal drag becomes a straight H or V cell run.
- `build-plank-preview` green cells and cost match what commit places and
  charges; red for the rest of the drag; refusal only when nothing places.
- `build-plank-place` release spends wood and writes the bridge through the
  placer; Cut mode still chops.

## How to get to it (user POV)

1. Start a local game (Host alone, offline, or two-player — Plank works in all).
2. Tap Buildings to open the picker, then select chop on the tool wheel to enter interact
   mode if needed.
3. Tap Plank near a shore, then drag in the direction of the water. Lift to
   place the green cells. For a footprint, pick the tool and drag from open
   playfield until the preview is valid. Lift to place or switch tools or modes
   to dismiss the preview.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_build_placement_snap_run`
under 0.05 s in `tools/verify.sh`; `test_build_picker_switches_tool` about 0.3 s;
`test_build_plank_preview_tint_and_cost` about 0.5 s;
`test_build_cut_mode_unchanged` about 0.4 s;
`test_build_plank_drag_places` about 0.6 s;
`test_build_preview_matches_commit_short_wood` about 0.2 s;
`test_build_preview_matches_commit_mid_invalid` about 0.2 s;
`test_build_preview_cache_invalidates_on_wood` about 0.5 s;
`test_build_picker_buttons` about 0.4 s (each ~1.9–2.2 s alone
with `--only=`, against ~1.7 s runner start-up). The centered-preview scene
test adds one scene boot, about 0.5 s.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=build_placement_snap_run,build_preview_starts_centered_and_moves_relatively,build_picker_switches_tool,build_plank_preview_tint_and_cost,build_cut_mode_unchanged,build_plank_drag_places,build_preview_matches_commit_short_wood,build_preview_matches_commit_mid_invalid,build_preview_cache_invalidates_on_wood,build_picker_buttons`, or the full `tools/verify.sh`.
- **Proof.** Headers `-- test_build_placement_snap_run`,
  `-- test_build_preview_starts_centered_and_moves_relatively`,
  `-- test_build_picker_switches_tool`,
  `-- test_build_plank_preview_tint_and_cost`,
  `-- test_build_cut_mode_unchanged`,
  `-- test_build_plank_drag_places`,
  `-- test_build_preview_matches_commit_short_wood`,
  `-- test_build_preview_matches_commit_mid_invalid`,
  `-- test_build_preview_cache_invalidates_on_wood` and
  `-- test_build_picker_buttons` in `artifacts/verify.log`
  with no `FAIL` after them. Visual: `docs/screenshots/build_placement_preview.png`
  shows the picker and a green/red plank preview. The existing
  `bin/capture_build_placement.gd` screenshot helper captures a 10-tile preview
  under xvfb.

- **Run (display).** `bin/launch.sh drives/center_build_preview.gd --display`.
  `centered-tower-warning` shows the Tower outline and wood refusal beside
  screen center before touching the playfield. `tower-after-relative-drag`
  shows both moved to the right. The drive checks the snapped anchor, the wood
  refusal and that the held touch ends outside the footprint.

Plank placement and per-cell charges are covered at the
[construction seam](./construction-placement.md). The drag test covers the 10-cell preview, placement beyond normal reach,
and the 10-wood charge through input.

## Gotchas

- Placement must go through `ConstructionPlacer`; do not paint bridges from the
  UI layer.
- Preview green cells and cost must come from the same `longest_placeable`
  prefix that `commit` places; do not tint from a full-run `can_place`.
- Preview skip cache must include wood, player position and map revision, not
  only the snapped cells (#383).
