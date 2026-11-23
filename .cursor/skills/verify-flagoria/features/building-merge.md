# Building merge

Drive: drives/building_merge.gd
Source: Scripts/mechanics/building_blocks/building_merge.gd

Full-edge neighbours merge into one solved footprint with a shared wall (#27). Shift+B removes the building under the hero and re-broadcasts the remaining records. Every peer rebuilds from the list, including late joiners on `sync_to_peer`.

## Sub-features

- `building-merge-local` `tests/mechanics/building_blocks/test_building_merge.gd` and `Scripts/mechanics/building_blocks/building_merge.gd`: east flush merge, overlap and stagger negatives, north-stack roof to floor, removal replay, determinism.
- `building-merge-sync` `tests/net/test_building_merge_sync.gd` and `tests/building_merge_probe.gd`: host, client, and a late joiner agree on the seam; after `remove_at(1)` the first building stands alone with one door.

## How to get to it (user POV)

1. Host with seed 49. Press B to place a building, walk east, press B again flush against the first. The shared wall has no double thickness.
2. Stand on the second building and press Shift+B. The second footprint disappears and the first ring closes.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_building_merge` about 1 s in `tools/verify.sh`. `test_building_merge_two_players` about 10–15 s alone; the stress job runs it at the job's tier. The drive is about 30 s under xvfb.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=building_merge,building_merge_two_players`, or the full `tools/verify.sh`.
- **Drive (live).** `bin/launch.sh drives/building_merge.gd --display` (`## launch: --seed 49`). Places two flush footprints, `snapshot("buildings-shared-wall")`, Shift+B on the second building, `snapshot("building-resealed")`.
- **Proof.** Headers `-- test_building_merge` and `-- test_building_merge_two_players` with no `FAIL` after them. Drive snapshots `01-buildings-shared-wall` and `02-building-resealed` show one shared wall and a closed ring on the first building after removal.