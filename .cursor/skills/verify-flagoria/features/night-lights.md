# Night lights

Drive: drives/night_lights.gd

At night a gold pool sits on each player and on castles, towers and guard posts. The pools fade in across dusk and out across dawn. Each peer draws them from the players and buildings it already has, and from the shared clock. A headless host creates none.

## Sub-features

- `light-energy` day is off, dusk rises with the clock's smoothstep, night is the full table energy. Headless: `test_night_lights_energy`.
- `light-cap` at most 16 lights. The local player stays; the rest are the nearest. Headless: `test_night_lights_cap`.

## How to get to it (user POV)

- Host a world. At night the hero and the starting castle each have a warm pool. The ground between those pools is darker than either centre.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits 0. Time cost: the two headless tests add under 0.1 s to `tools/verify.sh`. The live drive is about 30 s with `--display`.

- **Run.** `./tools/verify.sh`.
- **Proof.** `-- test_night_lights_energy` and `-- test_night_lights_cap` with no `FAIL` after them.
- **Drive (live).** `bin/launch.sh drives/night_lights.gd --seed 11 --display`. Shot `night-lights` is the hero beside the starting castle. Both are lit. The ground between them is darker than either pool.

## Gotchas

- The light texture is `art/day_night/light_radial_smooth_128.png`. Colour is gold `#f2b632`. Radius is 64 for a player, 96 for a castle, 56 for a tower and 48 for a guard post.
- Energy is 0 through the day hold, smoothstep across the dusk minute, the table value through the night hold, and smoothstep back down across the dawn minute.
- The cap is 16. Past that, the local player stays and the nearest other sources stay.
- A headless host does not create lights and does not run a per-frame light pass. A display peer writes energy on a 0.25 s tick, and only when the value changed.
