# Produce wood at placed sawmills

Drive: drives/sawmill_production.gd
Source: Scripts/mechanics/structures/sawmill_production.gd
Source: Scripts/mechanics/structures/structure_placer.gd
Source: Scripts/mechanics/structures/structure_saves.gd
Source: Scripts/mechanics/building/structure_requests.gd
Source: Scripts/mechanics/tuning/tuning.gd
Source: Scripts/world/TileMap.gd
Source: Scripts/world/world_chunks.gd

Each placed sawmill credits its connected owner directly after every 60 seconds
of host game time. The default payout is one wood. The Sawmill tuning category
controls the cycle length and payout. A disconnected owner's completed cycles
are skipped. Production continues after the neighboring tree is chopped and
ends when the sawmill is removed. Saves preserve each sawmill's cycle progress.
Legacy placements start with a full cycle remaining.

`map.sawmill_production.is_producing(placement_id)` reports whether the sawmill
can deliver to its owner.

- The display drive provides 15 starting stone and places a sawmill through
  Buildings. The before screen shows the sawmill, zero wood and zero stone.
  After one minute of host game time, the wood HUD shows one and the stone HUD
  still shows zero.
- `test_sawmill_production_save` checks cycle boundaries, tree removal,
  mid-cycle save and reload, demolition, and legacy placements.
- `test_sawmill_production_sync` uses two ENet peers to check owner-only credit,
  host authority, and skipped cycles after disconnect.
