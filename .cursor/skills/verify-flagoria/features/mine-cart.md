# Mine cart animation

Drive: drives/mine_cart.gd
Source: Scripts/mechanics/structures/mine_cart.gd
Source: Scripts/mechanics/structures/structure_placer.gd
Source: Scripts/world/world_chunks.gd
Source: Scripts/mechanics/building/build_preview.gd
Source: Scripts/mechanics/building/build_placement.gd
Source: Scripts/mechanics/building/build_tool_row.gd
Source: Scripts/ui/round_hud_style.gd

The mine's rock and timber cover its existing 3×3 footprint. The cart track
extends one tile beyond the footprint. The picker and placement preview use
the parked pose. While the mine can deliver stone, its cart plays a 20-frame
loop at 5 fps. When the owner is disconnected, it holds frame 12.

- The player drive captures the picker and a valid preview, then frames 7, 12,
  and 18 of the placed mine. The cart should be farther out at frame 7 than
  at frame 18. After saving and loading from Worlds, the drive captures the
  restored mine at frame 9.
- `test_mine_cart_lifecycle` checks the sheet slices, playback settings,
  footprint alignment, and sprite removal through the construction seam.
- `test_mine_cart_late_join` checks that a real join snapshot shows producing
  and idle mines on both peers, and that the host parks a cart when its owner disconnects.
