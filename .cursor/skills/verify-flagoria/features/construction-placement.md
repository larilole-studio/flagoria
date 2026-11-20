# Construction placement

Drive: not player-facing

`ConstructionPlacer` is the shared placement seam (#296, #610).
`can_place(kind, cells, inventory, turns)` reports refusal reasons for the
preview. `place(kind, cells, inventory, turns)` uses the local inventory and
owner. In multiplayer, named footprints and walls go through
`StructureRequests`; `Interaction` submits plank requests. Both handlers check
reach before calling `place_for_peer(kind, cells, owner, inventory, turns)`.
The host supplies inventory for its own purchase and sends the existing wood
charge after a successful remote purchase. A refused writer refunds the
full charge. Peers apply live named placements through `apply_replica` and
read the result through `TileMap.placed_structures` or `structures_for_sync`.

Registered kinds are plank, wall block, wooden tower, castle, guard post and
barracks. Planks need a straight water run touching land or a plank. Walls
need a straight land run touching a wall or structure. Named buildings take
an anchor and quarter turns. Refusals describe empty cells, unknown kinds,
wrong ground, occupancy, straightness, adjacency and insufficient wood.

## Sub-features

- `construction-plank` a straight water run next to land or a plank places and
  spends one wood per cell; land, an existing plank, a bent run, a floating
  cell and too little wood are refused with a reason and spend nothing.
  Planks place while multiplayer is on (#297).
- `construction-plank-occupied` a plank cell under a player, a mob, a wall or
  a structure is `occupied`: nothing is written, no wood is spent, and the
  host's `place_for_peer` for a peer's request refuses it too (#380 item 2).
- `construction-tower` a clear land anchor places `tower_wood` for 10 wood,
  owned by the local peer; water, an overlapping structure/player/mob and short
  wood are refused and spend nothing (#273). A connecting client does not
  write or spend; the host places it (#497).
- `construction-wall` a clear land cell or straight H/V run that 4-touches an
  existing wall, tower or castle places palisade pieces for 2 wood each; water,
  occupied (structure/wall/player/mob/tree/bush), bent, floating (not adjacent),
  and short wood are refused and spend nothing. A connecting client does not
  get `multiplayer on`; the host places the run (#498).
- `build-spend-failed` when spend refuses after the check, `BuildCosts.buy`
  returns `spend failed` and never calls the writer (#380 item 3).
- `construction-atomic-spend` `ConstructionPlacer.place` leaves no written
  run, tower or wall when the charge fails: spend before write, refund on writer
  refusal (covers plank, tower and wall).
- `construction-writer-contract` every registered writer (`build_bridge`,
  `place_wall_cells`, `place_structure`) is all-or-nothing: a refusal writes no
  cell, so the refund in `buy` leaves the map as it was (#380 item 3, #381).

## How to get to it (user POV)

- Interact mode → Plank in the build picker (#225 / `build-placement.md`). The
  shared module itself stays headless-proven here; the live path is the picker.

## Driving it with verify-flagoria helpers

- **Placement seam.** `test_building_seam_placement` checks named footprints,
  rotation, overlap, terrain, world bounds and wood balances.
  `test_building_seam_runs` checks wall and plank support, geometry and
  per-cell charges.
- **Charge and refund seam.** `test_building_seam_refund` covers failed
  charges for planks, walls and towers and full rollback after a refused
  write. `test_build_costs_spend_failed` checks that a failed spend never
  calls its writer (#380 item 3). `test_construction_placer_plank_occupied`
  checks the host and local placement paths (#380 item 2).
  `test_construction_writers_all_or_nothing` checks partial multi-cell
  refusals at the writer boundary (#380 item 3, #381).
- **Peer scenarios.** `test_building_seam_connecting` covers the connecting
  client preview and submit behavior (#297, #497, #498).
  `test_building_seam_host_sync` checks that an already-connected client and
  a late joiner receive the host's rotated guard post, with the same owner
  and anchor and one host charge. Run with `--only=building_seam_host_sync`.
- **Live input.** See [Build castle](./build-castle.md) and
  [Free-form walls](./free-form-walls.md).

## Gotchas

- Never paint planks from a drive to make placement pass; report the missing UI.
- Use `ConstructionPlacer.place` for local builds and `place_for_peer` for
  host-validated requests. The writer and the wood charge share one transaction.
