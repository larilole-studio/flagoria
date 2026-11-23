# Explored map

Drive: drives/explored_map.gd
Source: Scripts/world/explored_map.gd
Source: Scripts/ui/parchment_map.gd

Map beside Menu, or M, opens the full parchment sheet directly. The chart reveals cells within 10 cells of the local hero and stores them in 32 × 32 cell chunks. `MapChart` paints newly revealed cells and their coastline neighbours. World saves keep the explored cells in `player.charted`.

Drag to pan. Use +/−, the wheel or a two-finger pinch to zoom the sheet in whole pixels per cell. The buttons zoom at the hero, and the wheel and pinch zoom at the pointer or midpoint. Recentre pans back to the hero while keeping the zoom. Reopening starts at 2 pixels per cell.

The world keeps running while the sheet is open. The local hero cannot move or attack until Close, Esc, M, or a hit dismisses the sheet.

## Verification

- `-- test_explored_map` checks cell coverage and chunk addressing. `-- test_minimap_incremental_render` compares incremental and full chart painting.
- `-- test_minimap_panel_in_scene` checks the playing HUD and opens parchment with a touch on Map. `-- test_parchment_map` checks pan, zoom, modal controls and dismissal.
- `bin/launch.sh drives/explored_map.gd --display --seed 42` checks parchment framing on desktop and phone-sized windows. Expect screenshots of the open sheet, pan, zoom limits, recentre and return to play.
