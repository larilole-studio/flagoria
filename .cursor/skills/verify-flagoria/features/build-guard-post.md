# Build guard post

Drive: drives/build_guard_post.gd

Interact-mode Guard post tool places `structures/guard_post.txt` for 20 wood
(#528). The preview greens the full rotated footprint and charges 20 wood when
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
- `build-guard-place` release spends 20 wood and writes `guard_post` owned by the
  local peer; refused water, overlap or short wood spends nothing.
- `build-guard-sync` a client request syncs owner, anchor and rotation to the
  host, connected peers and a late joiner.
- `build-guard-save` a placed guard post with rotation survives save and reload
  with owner flag colours.

## How to get to it (user POV)

1. Host alone or two-player with at least 20 wood.
2. Open Buildings, tap Guard post, rotate if needed, aim at clear land (anchor
   on the gate cell).
3. Lift to place; the flag uses the builder's colour.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_construction_placer_guard`
about 0.6 s in `tools/verify.sh`; `test_guard_post_save_round_trip` about 0.4 s;
`test_guard_build_two_players` about 8–12 s per stress run. Drive about 25–45 s
under xvfb.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=construction_placer_guard,guard_post_save_round_trip,build_picker_buttons,guard_build_two_players`, or the full `tools/verify.sh`.
- **Proof.** `PASS test_construction_placer_guard`, `PASS test_guard_post_save_round_trip`, `PASS test_build_picker_buttons`, and `PASS test_guard_build_two_players` with no `FAIL` after them.
- **Drive (live).** `bin/launch.sh drives/build_guard_post.gd --seed 11 --display`.

## Gotchas

- The placement anchor is the gate at `(2,3)` of the 5×4 footprint, not the
  flag cell. Reach is checked on the anchor only.
- A lone guard post is not a city until a wall loop closes; do not expect a land
  score change from placement alone.