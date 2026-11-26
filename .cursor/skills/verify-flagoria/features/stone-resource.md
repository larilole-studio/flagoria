# Stone resource

Drive: drives/stone_resource.gd
Source: Scripts/mechanics/trees/inventory.gd
Source: Scripts/ui/resource_hud.gd
Source: Scripts/saves/player_save.gd
Source: Scripts/mechanics/interact/interaction.gd

Stone belongs to the local player's inventory. The top-left status row shows the
stone sticker and balance immediately after wood. A new world starts at zero.
World saves store stone beside wood in the player section. A missing stone key
loads as zero, including when replacing a session with an existing balance.

- **HUD fixture drive.** Run `bin/launch.sh drives/stone_resource.gd --display`. Host a
  fresh world and check `zero-stone` for hearts, score, wood and stone in that
  order, with both resources at zero. The drive adds stone through
  `Inventory.add`. In `after-stone-add`, stone reads 12 and wood stays at zero.
  The row stays clear of Menu.
- **Save tests.** `test_player_save_round_trip` checks both saved balances.
  `test_player_save_legacy_defaults` loads a wood-only player section into a
  scene with stone and checks that the saved wood loads and stone resets.
- **Two-peer test.** `test_resource_rpc_isolation` checks the joiner's named
  yields, stone charge and existing wood-only RPC, along with independent host
  inventory changes.
