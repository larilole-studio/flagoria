# Wall health and sword breaks

Drive: drives/wall_health.gd
Source: Scripts/mechanics/walls/wall_builder.gd
Source: Scripts/player/player_combat.gd

Free-form palisade cells take three sword hits on the host (#35). Damage
syncs to every peer and to late joiners. Named placements have their own
[building health](./building-health.md) across the footprint.

## Sub-features

- `wall-damage` three host-decided hits crack then remove a free-form cell.
- `wall-save` saves store optional `hp` under 3 in `world.structures`.
- `wall-break-sync` two peers and a late joiner agree on hp and removal.

## How to get to it (user POV)

1. Host or join a two-player game.
2. Place a free-form wall with the Wall tool.
3. Swing the sword at the segment until it breaks.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_wall_health_damage_and_save`
about 0.8 s in `tools/verify.sh`; `test_wall_break_two_players` about 10–15 s
alone; stress runs it at the job's tier.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=wall_health_damage_and_save,wall_break_two_players`, or the full `tools/verify.sh`.
- **Proof.** `PASS test_wall_health_damage_and_save` and `PASS test_wall_break_two_players` with no following `FAIL`.
- **Drive (live).** `bin/launch.sh drives/wall_health.gd --seed 11 --display`. Snapshots `wall-line`, `wall-cracked`, and `wall-broken`.

## Gotchas

- Only the host applies sword damage to free-form walls; clients still swing locally.
- Damage overlays apply to plain `PALISADE_H` and `PALISADE_V` only; corners and posts keep their solved piece until removal.
- Breaking the last cell of a city loop must use `host_erase_wall`, not a local erase.