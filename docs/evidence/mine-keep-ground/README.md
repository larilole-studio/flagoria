# Mine ground blend evidence

A placed mine keeps the generated terrain under and around its 3×3
footprint, including the track apron. The cart sheet already has a
transparent base, so grass, swamp or sand shows through the rails.

The before and after captures are from one headless drive under xvfb that
placed a mine beside a rock on each ground type. The preview is from
`drives/place_mine.gd` on swamp, and does not paint a sand patch.

| Screenshot | What it shows |
|---|---|
| [Before and after](before-after.png) | Grass, swamp and sand, before placement and after. |
| [Placed on three grounds](placed-grass-swamp-sand.png) | The same three sites after placement. |
| [Preview on swamp](preview-swamp.png) | Ready preview at 15 wood; swamp tiles stay visible. |
| [Placed on swamp](placed-swamp-wide.png) | The same site after confirm, still on swamp. |

Individual crops: `grass-before.png`, `grass-after.png`, `swamp-before.png`,
`swamp-after.png`, `sand-before.png`, `sand-after.png`.
