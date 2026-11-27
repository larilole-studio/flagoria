# Bomb throw

Drive: drives/ranged_bow.gd
Source: Scripts/mechanics/combat/bomb_shot.gd
Source: Scripts/mechanics/combat/bomb_throws.gd

Arm the bow with key 2 and release along the existing aim cone. The pot flies over terrain to the full throw range, lands with a lit fuse, and bursts. A tap on the touch attack button uses the current facing. Drag length and tap auto-targeting are tracked in #756.

The host validates the throw and decides when the pot lands and explodes. The blast tests player and mob positions and tile centers against an ellipse with a vertical radius of 60% of its horizontal radius. It skips the thrower and their soldiers. An enemy-owned named placement is removed if any footprint cell center is inside. Free-form palisade cells take one existing wall hit per damage point.

The Bomb category in Tuning defaults to 160 px throw range, 40 px horizontal blast radius, 1.0 s fuse, 1.5 s cooldown, and 2 damage.

- **Host seam.** `test_bomb_shot` checks blast geometry, flight over a wall, validation, cooldown, fuse timing, and damage to actors and structures. About 1.5 s.
- **Two peers.** `test_bomb_two_players` uses seed 11. Both replicas see the host's three phases and agree on enemy health and unchanged thrower health. A return throw exercises the client's request to the host. About 5–10 s per stress run.
- **Live drive.** Run `bin/launch.sh drives/ranged_bow.gd --display`. Expect `bow-aim` with the aim cone, `bomb-mid-arc` with an unlit pot above the flight path, `bomb-landed-fuse` with the lit pot, and `bomb-explosion` with a short burst at the same landing point.
