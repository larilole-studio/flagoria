# Night mobs

Drive: drives/night_mobs.gd
Source: Scripts/mechanics/mobs/mob_spawner.gd

Nights are more dangerous. The host's ambient caps follow the shared clock: the day hold stays at today's caps, night doubles the per-player and total caps, and dusk and dawn ramp between those with the same smoothstep as the tint. At dawn, mobs above the day cap despawn only once they are past `DESPAWN_RADIUS` of every player, so nothing vanishes on screen. With the cycle off in Map Settings, the caps stay at the day figures. The host decides. A joiner reads the same clock and sees the host's mobs.

## How to get to it (user POV)

- Host with Day and night left on. Walk until dusk. More mobs appear around the island than in the daytime, and the extras are gone from the band again after dawn once they have wandered out of view.
- Turn Day and night off in Map Settings before Host. The band matches a daytime world.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_night_mob_caps` and `test_night_mob_dawn` add about 2 s to `tools/verify.sh`. `test_night_mob_sync` is about 6 s per run and is part of the netcode stress matrix. The live drive is about 15 s under xvfb.

- **Run.** `./tools/verify.sh`. The sync scenario is `python3 tools/stress_netcode.py --only=test_night_mob_sync`.
- **Proof.** `-- test_night_mob_caps` and `-- test_night_mob_dawn` appear in the verify log, no `FAIL` line follows either, and the run ends with `All tests passed.` and `Verification passed.` `test_night_mob_sync` passes on the stress run: both peers report the night phase, the same scale, and the same mob rows.
- **Drive (live).** `bin/launch.sh drives/night_mobs.gd --seed 5 --display`. The mob rate slider is set to 0.5, then Host. The drive walks onto the grass and frames the cluster. Shots `day-mobs` and `night-mobs` are the same map. The night shot shows more mobs.

## Rules

- Scale is `1 + night weight`. Weight is 0 in the day hold, 1 in the night hold, and the smoothstep across the dusk window and back across dawn.
- Per-player uses `ceili` and the total uses `roundi`, on `rate * scale`, the same rounding as the day caps.
- The host reads `DayNight.spawn_scale()` inside the ambient tick only. A joiner uses that same call on the elapsed the host sent. Neither side does this every frame.
- An unpinned mob past `DESPAWN_RADIUS` is still removed. A mob inside that radius is not removed to meet a lower cap.

## Gotchas

- The drive seeks the holds and runs one host tick at each, instead of waiting out the 10 minute cycle or the 45 s band.
- The opening wave does not use the night scale. The extra mobs are the ambient tick.
