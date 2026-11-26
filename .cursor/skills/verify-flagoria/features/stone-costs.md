# Stone building costs (#724)

Drive: drives/stone_costs.gd

Source: Scripts/mechanics/building/build_costs.gd
Source: Scripts/mechanics/building/build_placement.gd
Source: Scripts/mechanics/building/build_tool_row.gd
Source: Scripts/mechanics/building/construction_placer.gd
Source: Scripts/mechanics/building/construction_remover.gd
Source: Scripts/mechanics/building/structure_requests.gd
Source: Scripts/mechanics/interact/interaction.gd
Source: Scripts/mechanics/trees/inventory.gd
Source: Scripts/ui/hud_tool_row.gd

| Building | Price | Demolish refund |
|---|---|---|
| Castle | 35 wood + 15 stone | 17 wood + 7 stone |
| Guard post | 14 wood + 6 stone | 7 wood + 3 stone |
| Barracks | 20 wood + 10 stone | 10 wood + 5 stone |

Open Buildings to see the three prices. Drag a guard post to a clear site.
The drive grants wood through the in-game menu and captures the red
`not enough stone` preview. Release leaves the site empty and the counters
unchanged. After Max resources, the same site shows a green 14 wood + 6 stone
preview. Release places the guard post and takes both resources. Switch to
Demolish and hold a tap on the guard post to see the 7 wood + 3 stone refund.
Release removes it and updates both counters. Time cost is about 15 seconds
under xvfb.

The public placement seam checks wood-only, stone-only and combined shortages
in `test_building_seam_placement`. The cost table and rounded refunds are covered
by `test_build_cost_table`. The existing `test_castle_build_two_players`,
`test_guard_build_two_players` and `test_barracks_build_two_players` send an
underfunded request to a valid site, then fund the same site and check both
peers' balances and shared placement. The host prices the build and deducts
outstanding charges from the buyer's reported balance before accepting a
request. Inventories remain peer-owned. The existing peer scenarios use their
current time budgets.

[Reviewed display evidence](../../../../docs/evidence/stone-costs/README.md).
