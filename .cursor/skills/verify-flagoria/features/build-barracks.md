# Build barracks

Drive: drives/build_barracks.gd

Interact-mode Barracks tool places `structures/barracks.txt` for 30 wood (#556).
The preview greens the full rotated footprint and charges 30 wood when `commit`
will place. On release, placement goes through `ConstructionPlacer`
(`BuildCosts.BARRACKS` → `StructurePlacer`). The builder owns the barracks. It
is not a flag tower: `StructurePlacer.towers()` does not list it. Land only; no
overlap with structures, players or water. Rotation follows #493. In multiplayer
the host validates and syncs through `StructureRequests`, including late joiners
and world saves. Soldier training is #553.

## Sub-features

- `build-barracks-picker` Barracks button appears in the Buildings column with
  Plank, Tower, Castle, Guard and Wall, stays visible while multiplayer is on,
  and switches `BuildPlacement.tool` to Barracks.
- `build-barracks-place` release spends 30 wood and writes `barracks` owned by
  the local peer; refused water, overlap or short wood spends nothing.
- `build-barracks-sync` a client request syncs owner, anchor and rotation to the
  host, connected peers and a late joiner.
- `build-barracks-save` a placed barracks with rotation survives save and reload.

## How to get to it (user POV)

1. Host alone or two-player with at least 30 wood.
2. Open Buildings, tap Barracks, rotate if needed, aim at clear land (anchor
   on the gate cell).
3. Lift to place.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: unit tests about 2 s together;
`test_barracks_save_round_trip` about 0.5 s; `test_barracks_build_two_players`
about 8–12 s per stress run. Drive about 25–45 s under xvfb.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=barracks_wood,barracks_not_a_tower,build_picker_includes_barracks,barracks_rotation,barracks_save_round_trip,barracks_build_two_players`, or the full `tools/verify.sh`.
- **Proof.** `PASS test_barracks_wood`, `PASS test_barracks_not_a_tower`, `PASS test_build_picker_includes_barracks`, `PASS test_barracks_rotation`, `PASS test_barracks_save_round_trip`, and `PASS test_barracks_build_two_players` with no `FAIL` after them.
- **Drive (live).** `bin/launch.sh drives/build_barracks.gd --seed 11 --display`.

## Gotchas

- The placement anchor is the gate at `(2,3)` of the 5×4 footprint, not the
  centre. Reach is checked on the anchor only.
- Barracks has no team flag, so capture and cities do not treat it as a tower.