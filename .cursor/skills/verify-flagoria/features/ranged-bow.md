# Ranged bow

Drive: drives/ranged_bow.gd

One bow on the existing aim (#362). The bow toggle is off until the player turns it on. An aimed attack then fires one shot along that aim and does not swing the sword. The host decides the hit. Peers draw a short line. A plain sword attack is unchanged while the bow is off.

## Sub-features

- `bow-toggle` `World/RangedShots` (`Scripts/mechanics/combat/ranged_shots.gd`) adds `CanvasLayer1/BowButton` in `_ready`. It starts off.
- `bow-shot` with the toggle on, `attack_toward` in `Scripts/player.gd` sends `request_shot` and does not call `attack_animation`. Interact mode still does not aim.
- `bow-flight` `RangedShot.fly` (`Scripts/mechanics/combat/ranged_shot.gd`) walks the segment at `SPEED` 180, `RANGE` 120, `STEP` 1/60. A failed `AttackAim.clear_shot` between samples is terrain. The first mob contact box or living player box wins. The shooter is skipped. `DAMAGE` is 1 and `COOLDOWN` is 1.0 s.
- `bow-host` the host rejects a dead sender, an origin farther than 24 px from the server body, a bad direction, or a live cooldown, then flies from the server body. One `Mob.take_hit` or one `PlayerHealth.take_damage`. `show_shot` draws a 2 px line for 0.2 s. In-flight shots are not in the join snapshot.

## How to get to it (user POV)

- Host a world, press Bow (left of Run), then aim and release the way a sword aim works. The sword does not swing. The line shows where the shot went.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_ranged_shot` is about 0.5 s in `tools/verify.sh`. `test_ranged_two_players` is about 8–12 s per stress run.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=ranged_shot`, or the full `tools/verify.sh`. The two-peer case is the stress scenario `ranged_two_players` (`tests/net/test_ranged_sync.gd`, probe `tests/ranged_probe.gd`, seed 11).
- **Drive (live).** `bin/launch.sh drives/ranged_bow.gd --seed 11 --display`. It hosts, turns the bow on, aims, and snapshots `bow-aim` and `bow-hit`.
- **Proof.** `-- test_ranged_shot` hits a mob in front, misses at `RANGE`, returns terrain for a wall, skips the shooter, and a second apply during HURT or invulnerability returns false. `-- test_ranged_two_players` shows both peers dropping one health, an immediate second shot doing nothing, health at `max_health - 2` after the host cooldown, an away shot leaving that health, and a late joiner seeing it.

## Gotchas

- Calling `attack_animation` as well as `request_shot` would swing and shoot. The bow path returns before the swing.
- A cooldown under 1 s looks like a missed shot because invulnerability lasts 1 s.
- The sent origin is not the flight start. Past 24 px from the server body it is rejected.
