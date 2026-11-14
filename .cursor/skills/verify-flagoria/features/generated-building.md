# Generated building

Drive: drives/generated_building.gd

A host generates one building at the local player (#26). The debug key is B. The same action is the Generate building button at the bottom of Map Settings, opened from the in-game menu while hosting. Building width, height and style are Map Settings fields (`building_width`, `building_height`, `building_style` on `MapGenParams`). Style 0 uses the stone piece tiles. Style 1 remaps the wall, corner, door and window onto the moss tiles and shifts the solve seed.

Pieces are painted on TileMap layer 7 (`buildings`), never on layer 0 or 1, because chunk refresh rewrites those. Walls, corners, windows and the roof band collide. The floor and the door do not. The host sends the seed, size, style and cell. Each peer runs `WfcBuildingConstraints.solve_building` and paints the same tiles. A peer that joins after the placement receives the same record. A client cannot place one. Neighbour blending is a later slice.

## Sub-features

- `generated-building-determinism` the same seed, size and style return the same tiles; another seed or style does not. The Map Settings button and the B key each place one, the wall blocks, the door does not, and chunk refresh leaves layer 7 in place.
- `generated-building-sync` a client and a late joiner match the host's tiles. The door is open and a wall blocks on every peer. The client cannot place.

## How to get to it (user POV)

1. Host. Open the in-game menu, choose Map Settings, and set Building width (5 to 16).
2. Press Generate building, or close the panel and press B. A building appears around the hero, with one door.
3. Walk through the door. Press B again, somewhere else. The next building uses the current size and style and is a different layout.
4. Walk into a wall. The hero stops. The door still lets the hero through.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_generated_building_determinism` about 2 s in `tools/verify.sh`. `test_generated_building_sync` about 10 s alone; the stress job runs it at the job's tier. The drive is about 25 s under xvfb.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=generated_building_determinism,generated_building_sync`, or the full `tools/verify.sh`.
- **Drive (live).** `bin/launch.sh drives/generated_building.gd --display` (`## launch: --seed 49`). Steps `first`, `second`, `wall`: `start_game()`, press B, `snapshot("building-one")`, leave by the door, press B, `snapshot("building-two")`, walk into a wall, `snapshot("wall-block")`.
- **Proof.** Headers `-- test_generated_building_determinism` and `-- test_generated_building_sync` with no `FAIL` after them. Drive snapshots `01-building-one`, `02-building-two` and `03-wall-block` under `--display` show two buildings, each with a door, and the hero stopped against a wall.

## Gotchas

- Chunk refresh puts plants and water back on layers 0 and 1. The building node clears plants on its footprint, keeps floor and door cells walkable, and clears the cell just outside the door so the way in stays open. The piece tiles stay on layer 7.
- The sky-dock root tile stays without collision. A roof cell that uses it gets a collision alternative on the building layer only.
