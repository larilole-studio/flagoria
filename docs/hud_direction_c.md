# In-game HUD

The HUD loads sage soft-shadow discs and Candy Glass stickers from
`art/ui/hud_e4/`. `RoundHudStyle.DENSITY`
is 4 texture pixels per HUD unit. The HUD uses linear filtering with mipmaps
on the fractional 480×270 canvas. The world and parchment map use nearest filtering.

The floating status row starts at (12, 12) and aligns the hearts, star and
points, and log and wood count along one centre line. Counters
and picker captions use Lilita One with a plum outline and one-unit drop.

## HUD layout in 480×270

The 24-unit Map, Menu, Build, picker, Rotate and wheel discs have 32-unit hit
targets. Run has 32-unit art and a 36-unit hit target.

### Top-edge menu and map

| Node | Art box (x, y, w, h) | Hit box |
|-|-|-|
| Menu | (444, 12, 24, 24) | (440, 8, 32, 32) |
| Map | (404, 12, 24, 24) | (400, 8, 32, 32) |

Map opens the parchment map.

### Right-thumb combat arc

| Node | Art box (x, y, w, h) | Centre | Hit |
|-|-|-|-|
| Attack | (375, 173, 56, 56) | (403, 201) | circle, radius 28, centred |
| Run | (335, 169, 32, 32) | (351, 185) | 36×36, centred |
| Tool wheel | (343, 211, 24, 24) | (355, 223) | 32×32, centred |
| Build | (424, 136.5, 24, 24) | (436, 148.5) | 32×32, centred |

Attack mirrors the joystick across the visible canvas and matches its base diameter. Run and the tool wheel sit west of Attack and move with it as the canvas expands. Build sits above-right of Attack and opens two compact rings over a dimmed playfield toward the middle of the screen. The inner ring holds Plank, Wall and Tower at a radius of 50 px. The outer ring holds Castle, Guard post and Barracks at 90 px. The picker follows a customized Build button and opens rightward from the left half, with a mirrored or wider layout if controls obstruct it. Tap Build again, choose an option or tap outside to close it.

### Joystick

Keep the approved centre **(77, 201)**. The 56×56 base then occupies (49, 173, 56, 56). The 24×24 knob starts centred on (77, 201), top-left (65, 189). The travel boundary is 20 and the start radius is 28.

### Art states

Pressed faces shift down and turn deep green. Map and picker selection add a
gold ring. Buildings shows a close icon in a gold ring while the picker is
open. The tool wheel switches among sword, bow, and axe icons. Attack has
an off-white charge arc and a gold aim arc. Disabled discs use a muted
mauve face and lighter sage marks.
