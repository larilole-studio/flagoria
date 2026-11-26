# HUD button style comparison

Each sheet is a 2×3 grid of the same in-match HUD at 2400×1080, labelled A–F.

| Letter | Style |
| --- | --- |
| A | Candy Glass, the current default |
| B | Carved wood with plank grain and a warm bevel |
| C | Parchment token with an ink border |
| D | Chiseled stone with a pale facet |
| E | Flat pixel discs in gold and grass green |
| F | Deep-leaf cloth with gold stitching |

[Match start](match-start.png) · [Build picker](build-picker.png) ·
[Pressed](pressed.png) · [Tool wheel](tool-wheel.png) ·
[State strip](state-strip.png)

Candy Glass stays the default. Set `FLAGORIA_HUD_STYLE` to `wood`, `parchment`,
`stone`, `pixel` or `banner` to preview another style. After importing the
project, run `python3 tools/ui/compare_hud_styles.py` to regenerate the sheets.
