# Produce stone at placed mines

Drive: drives/mine_production.gd
Source: Scripts/mechanics/structures/mine_production.gd
Source: Scripts/mechanics/structures/structure_placer.gd
Source: Scripts/mechanics/structures/structure_saves.gd
Source: Scripts/mechanics/building/structure_requests.gd
Source: Scripts/world/TileMap.gd
Source: Scripts/world/world_chunks.gd

Each mine starts its own cycle when placed. After every 60 seconds of host
game time it sends one stone directly to the placement owner. Completed cycles
are skipped while the owner is disconnected. Production continues after the
adjacent rock is depleted and ends on demolition. Saves preserve the elapsed
time in each mine's cycle. Older saves start at zero.

`map.mine_production.is_producing(placement_id)` reports whether a placed mine
can deliver to its owner.

- Drive `drives/mine_production.gd` under xvfb to place a mine through Buildings.
  The before screen shows the new mine and zero stone. The after screen shows
  the same mine and one stone after advancing the host clock by 60 seconds.
- `test_mine_production_save` covers the first two boundaries, rock depletion,
  saving mid-cycle, loading a legacy placement and stopping on demolition.
- `test_mine_production_sync` checks staggered mines with two ENet peers,
  owner-only delivery, no production on the joiner clock and a disconnected owner's cycle.
