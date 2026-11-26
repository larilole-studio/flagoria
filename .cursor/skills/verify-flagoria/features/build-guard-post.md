# Build guard post

Drive: drives/build_guard_post.gd
Source: Scripts/mechanics/building/build_placement.gd
Source: Scripts/mechanics/structures/structure_placer.gd

Interact-mode Guard post tool places `structures/guard_post.txt` for 14 wood and 6 stone
(#528). The preview greens the full rotated footprint and charges 14 wood and 6 stone when
`commit` will place. On release, placement goes through `ConstructionPlacer`
(`BuildCosts.GUARD_POST` → `StructurePlacer`). The builder owns the guard post
and its team flag. Land only; no overlap with structures, players or water.
Rotation follows #493. In multiplayer the host validates and syncs through
`StructureRequests`, including late joiners and world saves. Defensive fire stays
with #37 and #280.

## Sub-features

- `build-guard-picker` Guard post button appears in the build picker with
  Plank, Tower, Castle and Wall, stays visible while multiplayer is on, and
  switches `BuildPlacement.tool` to Guard.
- `build-guard-place` release spends 14 wood and 6 stone and writes `guard_post` owned by the
  local peer; water, overlap, and resource shortages leave balances intact.
- `build-guard-sync` a client request syncs owner, anchor and rotation to the
  host, connected peers and a late joiner.
- `build-guard-save` a placed guard post with rotation survives save and reload
  with owner flag colours.

## How to get to it (user POV)

1. Host alone or two-player with at least 14 wood and 6 stone.
2. Open Buildings, tap Guard post, rotate if needed, then drag the centered preview to clear land (anchor
   on the gate cell).
3. Lift to place; the flag uses the builder's colour.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Placement and charge use the shared
[construction seam](./construction-placement.md). Time cost: `test_guard_post_save_round_trip` about 0.4 s.
`test_guard_build_two_players` about 8–12 s per stress run.
`test_building_seam_host_sync` about 7 s per stress run. Drive about 25–45 s
under xvfb.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=building_seam_placement,guard_post_save_round_trip,build_picker_buttons,guard_build_two_players,building_seam_host_sync`, or the full `tools/verify.sh`.
- **Proof.** `PASS test_building_seam_placement`, `PASS test_guard_post_save_round_trip`, `PASS test_build_picker_buttons`, `PASS test_guard_build_two_players` and `PASS test_building_seam_host_sync` with no `FAIL` after them.
- **Drive (live).** `bin/launch.sh drives/build_guard_post.gd --seed 11 --display`.

## Gotchas

- The placement anchor is the gate at `(2,3)` of the 5×4 footprint, not the
  flag cell. Reach is checked on the anchor only.
- A lone guard post is not a city until a wall loop closes; do not expect a land
  score change from placement alone.
