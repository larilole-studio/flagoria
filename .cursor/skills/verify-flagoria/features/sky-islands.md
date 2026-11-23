# Sky islands

Drive: drives/sky_islands.gd
Source: Scripts/world/world_chunks.gd
Source: Scripts/world/sky_islands.gd
Source: Scripts/world/cloud_motion.gd

The map node delegates `predict_cell` to `Scripts/world/world_chunks.gd`.

Open sea is an empty cell, so the clear colour (`#7cc8f2`) is the sky. Land is the Island terrain: a coast cell is an island-edge piece, and an inland cell stays grass, sand or swamp. Sand and swamp do not touch the sky. The map paints cloud stamps on sky. Display peers animate those stamps locally. A plank bridge from the shore uses the plain (transparent) pieces. Sea still blocks movement.

## Sub-features

- `sky-clear` the view at gameplay zoom (camera zoom 0.7) has no grey void.
- `sky-edge` the coast is an island-edge piece over sky, not a hard grass tile against a water tile.
- `sky-collision` the hero cannot walk onto the sky.
- `cloud-drift` pixel-snapped parallax moves fainter far clouds at 0.5 world px/s and a smaller near layer at 1.0 world px/s, fading at wraps and hiding over land or bridges.

## How to get to it (user POV)

Host a world. The shore around the start is an island edge over blue sky. Clouds hang over the open sky, not on the grass.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: the drive is about 15 s and is not part of `tools/verify.sh`.

- **Run.** `./.cursor/skills/verify-flagoria/bin/launch.sh drives/sky_islands.gd --seed 42 --display`
- **Proof.** The run prints `sky_islands: shore=true zoom=(0.7, 0.7)` and `01-island_edge.png` shows an island edge over sky, with the hero standing on the coast.

## Gotchas

- Headless play skips the cloud pass. Clouds are visual only and are not part of the saved world.
- `predict_cell` still reports water for open sea, so bridges, mobs and spawn keep their water checks. The drawn cell is empty.
