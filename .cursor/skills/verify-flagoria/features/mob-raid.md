# Mob raids

Drive: drives/mob_raid.gd

The host can send a small group of idle mobs at the nearest player city, or at the nearest owned tower when no city is in range. On arrival they damage free-form palisades and can capture an undefended flag the way any mob already can. Raids stay off until the host turns them on from the main menu.

## How to get to it (user POV)

1. On the main menu, under Mob spawns, turn Raids on. Interval, Group and Radius sit on the next rows (45 s, 3 mobs, 48 cells until changed).
2. Host a world and close a palisade ring around a wooden tower you own.
3. Idle mobs inside the radius walk to that city and strike the wall. With raids off they keep wandering and the wall stays whole.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_raid_target` is about 1 s inside `tools/verify.sh` and does not open a peer (a standalone headless run, including engine start, was 4 s). `test_raid_two_players` worst 8.3 s and `test_raid_off_two_players` worst 7.5 s over five local runs each (one host, one client, and a late joiner on the on-path; the netcode stress job runs each at the job's tier). The live drive is about 2 s under xvfb.

- **Drive (live).** `bin/launch.sh drives/mob_raid.gd --seed 11 --display` (the drive's `## launch: --seed 11` line). Steps `raid-city-intact`, `raid-wall-cracked`. `snapshot("raid-city-intact")` shows the palisade city before a strike, then `snapshot("raid-wall-cracked")` once a straight wall is at 2 hp.
- **Proof.** `-- test_raid_target`, `-- test_raid_two_players` and `-- test_raid_off_two_players` appear in the verify log, no `FAIL` line follows any of them, and the run ends with `All tests passed.` and `Verification passed.` The seed-11 unit test checks target choice, settings, clock and group size, and castle-wall immunity. The two-peer stress scenarios check wall health with raids on and off and whether a late joiner receives the damage.

## Rules

- The host decides. Clients see the mob move and the wall hp that already replicates. A late joiner gets mobs, wall hp and capture from the existing snapshots.
- Target choice prefers the nearest player-owned city inside the radius, then the nearest owned tower. Ties go to the smaller placement id. Neutral and mob owners are ignored. The seed and the tick pick which idle mobs join, not the target.
- A raid mob stays pinned, so the ambient band does not despawn it past 64 cells. A player chase still wins until the mob is calm, then the raid resumes.
- Raiders damage free-form walls only. A castle's stone auto-wall stops them and is not passed to `host_damage_wall`.

## Gotchas

- Raids default off. A save with no raid keys stays off.
- The strike needs a free-form palisade. Castle stone is not one, so the drive and the tests close a palisade ring the way a city test does.
- The first automatic raid waits for the interval (45 s unless the menu changes it). The two-peer probe uses a short in-memory interval and observes the raid clock and wall damage through the normal physics loop.
