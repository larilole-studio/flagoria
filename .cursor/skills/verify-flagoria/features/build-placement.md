# Build placement

Drive: not player-facing

Interact-mode build tools (#225 / #273 / #276). The Buildings column lists Plank,
Tower, Castle, Guard post, Barracks and Wall on round discs under the wood counter
(see [Round HUD buttons](./hud-round-buttons.md)). The column stays closed until
Buildings is open (`BuildPlacement._list_open` starts false; each tool button is
visible only while the list is open). Cut keeps the existing tap, drag and chop
behaviour and is the tool when none of those is selected. Plank snaps a drag to a
horizontal or vertical cell run. Tower, Castle, Guard post and Barracks preview a
footprint under the finger (see [Build tower](./build-tower.md), [Build castle](./build-castle.md),
[Build guard post](./build-guard-post.md) and [Build barracks](./build-barracks.md)).
Wall keeps a tip and places a connected palisade chain (see [Free-form walls](./free-form-walls.md)).
The preview greens exactly the cells `commit` will place and shows that wood cost;
the rest is red. A refusal reason appears when nothing is placeable (including an
empty wall gap). On release, placement goes through `ConstructionPlacer`
(`can_place` / `cost` / `place`). Ghost tiles wait on art. Dead-player gating stays
on `Interaction.player_dead`. `BuildToolRow.MP_HIDDEN` is empty, so nothing hides
when a peer connects; every column tool stays available in multiplayer (#297,
#497, #498, #527, #528, #556). `update_preview` skips the snap / `can_place` work
only when the snapped cells, wood count, player position and map revision are
unchanged, so a wood spend, a walk out of reach, or a map change cannot leave a
stale green preview. The Cut icon uses the AxeTool sprite padded into
`art/ui/ui_tool_cut.png`; build-tool icons live under `art/ui/`.

Reach (`Interaction.REACH`) is the length bound for a drag preview; no separate
run-length cap was added (#380 item 1 left open).

## Sub-features

- `build-picker` Plank, Tower, Castle, Guard post, Barracks and Wall sit in the
  Buildings column; the column is hidden until Buildings is open, including in
  combat, and switches `BuildPlacement.tool`. Nothing is hidden in multiplayer.
  Leaving interact resets the tool to Cut.
- `build-plank-snap` a diagonal drag becomes a straight H or V cell run.
- `build-plank-preview` green cells and cost match what commit places and
  charges; red for the rest of the drag; refusal only when nothing places.
- `build-plank-place` release spends wood and writes the bridge through the
  placer; Cut mode still chops.

## How to get to it (user POV)

1. Start a local game (Host alone, offline, or two-player — Plank works in all).
2. Tap Buildings to open the column, then select chop on the tool wheel to enter interact
   mode if needed.
3. Tap Plank, drag across water next to land; green cells and the wood cost
   follow the finger (green = what will place). Lift to place. Tower, Castle,
   Guard post and Barracks: see their feature files. Wall: see
   [Free-form walls](./free-form-walls.md).

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_build_placement_snap_run`
under 0.05 s in `tools/verify.sh`; `test_build_picker_switches_tool` about 0.3 s;
`test_build_plank_preview_tint_and_cost` about 0.5 s;
`test_build_plank_places_and_spends` about 0.5 s;
`test_build_cut_mode_unchanged` about 0.4 s;
`test_build_plank_drag_places` about 0.6 s;
`test_build_preview_matches_commit_short_wood` about 0.2 s;
`test_build_preview_matches_commit_mid_invalid` about 0.2 s;
`test_build_preview_cache_invalidates_on_wood` about 0.5 s;
`test_build_picker_hides_on_multiplayer_start` about 0.4 s (each ~1.9–2.2 s alone
with `--only=`, against ~1.7 s runner start-up). Screenshot drive about 15 s
under xvfb.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=build_placement_snap_run,build_picker_switches_tool,build_plank_preview_tint_and_cost,build_plank_places_and_spends,build_cut_mode_unchanged,build_plank_drag_places,build_preview_matches_commit_short_wood,build_preview_matches_commit_mid_invalid,build_preview_cache_invalidates_on_wood,build_picker_hides_on_multiplayer_start`, or the full `tools/verify.sh`.
- **Proof.** Headers `-- test_build_placement_snap_run`,
  `-- test_build_picker_switches_tool`,
  `-- test_build_plank_preview_tint_and_cost`,
  `-- test_build_plank_places_and_spends`,
  `-- test_build_cut_mode_unchanged`,
  `-- test_build_plank_drag_places`,
  `-- test_build_preview_matches_commit_short_wood`,
  `-- test_build_preview_matches_commit_mid_invalid`,
  `-- test_build_preview_cache_invalidates_on_wood` and
  `-- test_build_picker_hides_on_multiplayer_start` in `artifacts/verify.log`
  with no `FAIL` after them. Visual: `docs/screenshots/build_placement_preview.png`
  shows the picker and a green/red plank preview (captured under xvfb).

## Gotchas

- Placement must go through `ConstructionPlacer`; do not paint bridges from the
  UI layer.
- Preview green cells and cost must come from the same `longest_placeable`
  prefix that `commit` places; do not tint from a full-run `can_place`.
- Do not invent a run-length cap for the preview; raise it as a question if
  REACH is not enough (#380).
- Preview skip cache must include wood, player position and map revision, not
  only the snapped cells (#383).