# Building health

Drive: drives/building_health.gd
Source: Scripts/mechanics/structures/building_health.gd
Source: Scripts/mechanics/structures/structure_placer.gd
Source: Scripts/mechanics/structures/structure_saves.gd
Source: Scripts/mechanics/building/structure_requests.gd
Source: Scripts/mechanics/combat/bomb_throws.gd
Source: Scripts/mechanics/tuning/tuning.gd
Source: Scripts/player/player_combat.gd

Aim a sword or bomb at a named building owned by another side, the mobs, or
nobody. A sword hits a palisade in its arc first, then looks for the nearest building when the arc is clear of palisades. A bomb
damages a building once if its ellipse covers a footprint cell center. Your
own buildings take zero damage. In Tuning, the Buildings group sets HP per
type and sword damage. Bombs use their usual damage value.

A damaged building shows a short team-colored health bar above its footprint.
Cracks appear at half health and become heavier at quarter health. At zero
HP the footprint and its collision are removed. Starting castles keep their
footprints at zero HP. The world save keeps remaining HP and omits destroyed
buildings. Older placements without HP start full.

## Verification

- **Unit seam.** `test_tuning_defaults_and_live_price` checks the registered
  defaults. `test_building_health_tuning` checks fallback HP and overrides. `test_building_health_save` checks neutral and mob ownership,
  damage and zero signals, starting castles, and the world-save round trip.
  `test_bomb_shot` checks that a blast hits a building once across several
  footprint cells and leaves a friendly tower at full health.
- **Peer scenario.** `test_building_health_two_players` checks that the host
  accepts a client's sword request, rejects a direct client-side damage call,
  sends remaining HP to a late joiner, and clears the whole footprint on all
  three peers after the client's bomb.
- **Display drive.** Run `bin/launch.sh drives/building_health.gd --display`
  after Doctor. The fixture places a mob-owned wooden tower near spawn.
  Real mouse input aims and throws each bomb. Expect `tower-full` to show the
  intact tower, `tower-cracked` to show a purple bar and heavy cracks, and
  `tower-destroyed` to show the cleared footprint after the last blast.
