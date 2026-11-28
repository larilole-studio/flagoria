# Place a sawmill

Drive: drives/place_sawmill.gd
Source: Scripts/mechanics/building/build_costs.gd
Source: Scripts/mechanics/building/build_placement.gd
Source: Scripts/mechanics/building/build_tool_row.gd
Source: Scripts/mechanics/building/construction_placer.gd
Source: Scripts/mechanics/structures/structure_placer.gd
Source: Scripts/mechanics/trees/tree_cuts.gd
Source: Scripts/mechanics/tuning/tuning.gd
Source: Scripts/ui/hud_tool_row.gd
Source: Scripts/world/TileMap.gd

Open Buildings and select **Sawmill** to start a 3×2 preview at screen centre.
Drag to a reachable clear site whose anchor touches a live tree or pine
orthogonally. The ready preview shows **15 stone**. A diagonal tree, bush,
stump or absent tree turns it red and shows **not adjacent to a tree**.
A clear site with a live neighbour and too little stone shows **not enough stone**.
The preview and hooded mill leave the generated ground visible.

The buyer owns the sawmill and spends stone only. The host checks the current
tree when processing a request. A placed sawmill survives chopping and returns
through the named structure save path. Owner demolition refunds 7 stone at the
default price. The price can be changed under Building costs in Tuning.

- Drive `drives/place_sawmill.gd` under xvfb (about 15 s) and check the picker,
  the red corner preview and the green edge preview. The two placement captures
  show generated swamp and grass, with wood holding at 999 while stone
  goes from 999 to 984 and then 969.
- `test_place_sawmill` checks the shared geometry and purchase rules, including
  anchor-only trees, bushes, chopped trees and pine (under 1 s).
- `test_place_sawmill_sync` checks stale requests, ownership, replicas and
  buyer-only charges across two ENet peers (under 1 s).
- `test_sawmill_save_and_demolish` checks the named save path after chopping,
  owner and starting-castle protection, refunds, and ground atlas equality
  before placement and after placement, reload and demolition (under 1 s).
