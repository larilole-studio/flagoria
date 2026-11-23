# Mob band

Drive: drives/mob_band.gd
Source: Scripts/mechanics/mobs/mob_spawner.gd

The host keeps spawning and removing mobs around living players. The opening wave from the world seed stays. Later ticks add mobs in a ring around each player and remove mobs that have wandered far away, up to a cap. A mob that is chasing is kept.

## How to get to it (user POV)

- Host a world and walk the island. Mobs from the opening wave stand off the spawn. Over time, mobs appear in the ring around the hero and ones left far behind are gone. A second player shares that set, including someone who joins later.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_mob_band_plan` is about 0.5 s in `tools/verify.sh`. `test_mob_band_two_players` is about 5 s per run locally (one host, one client, then a late joiner; budget 15 s; the netcode stress job runs it at the job's tier). The live drive is about 5 s under xvfb.

- **Drive (live).** `bin/launch.sh drives/mob_band.gd --seed 11 --display` (the drive's `## launch: --seed 11` line). Steps `near`, `ring`. `snapshot("band-near-hero")` once the ground under the hero is drawn, then `snapshot("band-mob-in-ring")` when a mob is on screen and between 13 and 40 cells from the hero.
- **Proof.** `-- test_mob_band_plan` and `-- test_mob_band_two_players` appear in the verify log, no `FAIL` line follows either, and the run ends with `All tests passed.` and `Verification passed.` The unit test checks fixed seed 11 waves for one and two players, as well as despawn and population caps. The two-player test is the stress scenario.

## Rules

- A new mob is on its home ground, farther than 12 cells from every living player, and within 40 of at least one. Each 32×32 chunk contributes one cell per tick.
- An unpinned mob farther than 64 cells from every living player is removed. A chasing mob stays. Nothing is removed while no living player exists.
- Caps at 1× are 10 mobs per player and 30 in the world. The host's mob rate scales those the same way as the opening caps. New names are `mob_a_N`. Those figures are the day hold. Night doubles them; dusk and dawn sit between. See [Night mobs](./night-mobs.md).
- The server decides. Peers and late joiners get the spawn and the free through the mob spawner. The set is not written into the save.

## Gotchas

- The first automatic tick waits 45 s after a living player appears, so a short sync test still sees only the opening wave. The stress probe sets that delay to 0 and calls the tick itself.
