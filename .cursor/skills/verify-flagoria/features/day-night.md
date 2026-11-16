# Day and night

Drive: drives/day_night.gd

The host owns a 10 minute clock. The world is tinted through day, dusk, night and dawn. The HUD stays at full brightness. Map Settings has a Day and night switch, on by default. The elapsed time is saved with the world. An older save loads at the start of day with the cycle on. Clients and a late joiner follow the host.

## Sub-features

- `clock-phases` holds and the 15 + 30 + 15 eases. Day `#ffffff`, dusk `#eba684`, night `#808cc8`, dawn `#e8b4c8`, smoothstep into `Color.lerp`. The cycle wraps at 600 seconds. Headless: `test_day_night_phases`.
- `clock-save` the in-game menu writes `clock.elapsed`. Loading that file and hosting restores it. A version 1 save with no clock loads at elapsed 0 with `day_night_cycle` on. Headless: `test_day_night_save`.
- `clock-switch` Map Settings shows Day and night, on until turned off. With the switch off the tint stays at day. The `CanvasModulate` is not on the HUD `CanvasLayer`. Headless: `test_day_night_cycle_off`.
- `clock-sync` a joined peer and a late joiner report the host's night phase. The run waits on that state. Headless: `test_day_night_sync`.

## How to get to it (user POV)

- Main menu, Map Settings: Day and night is on. Host. The world starts in daytime.
- Turn the switch off before Host and the world stays at daytime.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: the three headless tests add about 2 s to `tools/verify.sh`. The sync scenario is about 8 s alone and is part of the netcode stress matrix. The live drive is about 30 s with `--display`.

- **Run.** `./tools/verify.sh`. The sync scenario is `python3 tools/stress_netcode.py --only=test_day_night_sync`.
- **Proof.** `-- test_day_night_phases`, `-- test_day_night_save` and `-- test_day_night_cycle_off` with no `FAIL` after them. `test_day_night_sync` passes on the stress run.
- **Drive (live).** `bin/launch.sh drives/day_night.gd --seed 11 --display`. Shots `day`, `dusk` and `night` are the same map. The HUD matches in all three. At night the ground, hero and water stay readable.

## Gotchas

- The cycle is 10 minutes, so the drive seeks the host clock to the middle of each hold instead of waiting for dusk and night.
- The HUD clock icon, night overlays and mob changes are separate slices. Those art files stay unused. Night lights are covered by night-lights.md.
