# Soldier visual assets

All runtime artwork uses palette v1.1 and is drawn at the native 16 px
world grid. The host's units are blue. Other sides use the red ramp.

| Sheet | Frames | Feet in each frame |
| --- | --- | --- |
| `soldier_sheet` | 9 columns × 4 rows of 16 px. Rows face down, up, left and right. Columns 0–1 idle, 2–5 walk and 6–8 strike. | (8, 15) |
| `squad_5` | Three 32 px frames for idle and two shuffle steps. | (16, 18) |
| `company_20` | Three 48 px frames for idle and two shuffle steps. | (24, 32) |
| `move_marker` | Three 16 px frames for the destination flag and its ground pulse. | Flag pin |
| `selection_ring` | One 32 × 16 px foot indicator. | (16, 8) |
| `cracks_sheet` | Two 48 × 32 px overlays for moderate and severe damage, sampled on the structure's tile grid. | Top-left aligned |
| `alert_icon` | Two 16 px frames for the map alert pulse. | Center |

Formation sprites have front-rank foot pivots. The common soldier
hurtbox is unchanged by a formation's visual width. The 24 px Command
disc under `art/ui/hud_e4` is stored at 4× like the other wheel art.

Run `python3 tools/art/check_soldier_palette.py` with Pillow to check all
runtime PNGs. The x1 and x4 review boards and team comparison are under
`docs/evidence/soldier-visuals`.
