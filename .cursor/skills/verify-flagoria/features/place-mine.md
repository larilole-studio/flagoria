# Place a mine

Drive: drives/place_mine.gd
Source: Scripts/mechanics/building/build_costs.gd
Source: Scripts/mechanics/building/build_placement.gd
Source: Scripts/mechanics/building/build_tool_row.gd
Source: Scripts/mechanics/building/construction_placer.gd
Source: Scripts/mechanics/structures/structure_placer.gd
Source: Scripts/ui/hud_tool_row.gd
Source: Scripts/world/TileMap.gd

Open Buildings and select **Mine** to start the 3×3 preview at screen center.
Drag the anchor to reachable, clear land with a live rock on one of its four
edges. The ready preview shows **15 wood**. A diagonal or missing rock turns
the preview red and shows **not adjacent to a rock**. An otherwise valid site
with less than 15 wood shows **not enough wood**.
The preview and placed mine show the existing terrain through the sprite,
including around the track apron.

The buyer owns the mine and spends only wood. The host checks the current
rock before accepting a multiplayer request. Mines use the named structure
save path and stay in place after a nearby rock disappears. Demolish returns
7 wood to the owner.

- Drive `drives/place_mine.gd` under xvfb for the Buildings picker with Mine,
  the red preview at a diagonal rock, and the valid preview and placed mine
  beside a rock. Check that the terrain stays visible and placement leaves
  85 wood after spending 15 of the 100 wood granted from the game menu.
- `test_place_mine` covers the shared placement rules, including diagonal,
  anchor-only and destroyed rocks.
- `test_place_mine_sync` uses two ENet peers to check the stale request refusal,
  matching placements and buyer-only wood charges.
- `test_mine_save_and_demolish` checks the saved anchor and owner after the
  rock is gone, demolition ownership, starting castle protection and refund.
  It also compares ground atlases in and around the footprint, including the
  track apron, before placement and after placement, reload and demolition.
