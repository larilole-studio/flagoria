# Tree chop canopy sway (#398)

On impact, the canopy shifts 2 px right. In the return frame, the top shifts 2 px left of idle and the lower canopy returns to idle. The trunk stays fixed. Axe impacts still land at 140 and 460 ms, and the stump appears at 560 ms.

- [In-game hit comparison](in-game-hit-comparison.png) shows 2× crops of the regular and birch impact screenshots.
- [Hit-sheet comparison](hit-sheet-comparison.png) shows the idle sprite and both hit frames at 4× for regular, bushy, birch and pine trees.
- Regular tree screenshots from the chop variants drive under xvfb ([before](before-regular-hit.png), [after](after-regular-hit.png)).
- Birch screenshots from the same drive ([before](before-birch-hit.png), [after](after-birch-hit.png)).
- Original 1 px hit sheets for [regular and bushy trees](before-tree-hit-sheet.png), [birch](before-birch-hit-sheet.png) and [pine](before-pine-hit-sheet.png).
