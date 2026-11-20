# UI theme

`main_menu_theme.tres` styles the main menu: pixel font, button, line-edit and
slider styles, and a banded backdrop, all in the game palette.

## Candy Glass HUD

Run `python3 tools/ui/gen_hud_e4.py` with CairoSVG and Pillow to regenerate
the transparent sprites in `hud_e4/`. The generator and `RoundHudStyle` share
`DENSITY = 4` texture pixels per logical HUD unit. Godot draws the HUD at
device resolution through the existing fractional `canvas_items` stretch.
HUD sprites and Lilita One labels use linear filtering with mipmaps. The map
panel and pixel-art world retain nearest filtering.

The floating status row aligns half-step hearts, star and points, log and
wood count, and a trophy sticker. The two loss-flash frames last about
60 ms each. The flash is separate from the player's invulnerability blink.

## Map panel

The explored map in play is a wood panel in the top-right corner, below the
mode and menu buttons, 4 px from the right edge (224x144 at (252, 28) in the
480x270 UI space). It uses the files in `map/`:

| file | size | shown |
|---|---|---|
| `ui_map_panel_open.png` | 224x144 | the wood frame; its map window is the transparent 216x124 area at (4, 16) |
| `ui_map_marker_hero_{up,right,down,left}.png` | 16x16 | the local hero, pointing the way it faces; pixel (8, 8) sits on the hero's cell |

The window shows the world at 2 px per cell, centred on the hero. Explored
cells use the map colours in `Scripts/ui/minimap_panel.gd` (water, shore,
sand, swamp, grass, trees, stones, flowers), with a 1 px ink line where
explored land meets explored water. Cells nobody has been near show as mist,
a 1 px dither of `#ffffff` and `#d9e6f2`. The panel is drawn at a whole
number of screen pixels per art pixel, rounding down, so at fractional
window stretches it stays clear of the attack button.

The header carries two controls drawn in code (`Scripts/ui/map_wood_button.gd`)
in the frame's own colours, ink `#2a2238` on light wood `#e0a96b`: a minus
that collapses the window, and a square that opens the parchment. Collapsed,
a 56x24 wood chip in the same corner (a small map and an up chevron) opens
the panel again. The frame PNG is unchanged.

The parchment (`Scripts/ui/parchment_map.gd`) fills the viewport. It is old
paper, not a second wood frame: `#e7d7b1` with a `#cbb98a` dither, a
`#8a5a32` edge and the same ink. Explored cells use the panel's map colours.
Unexplored cells stay that paper fog. Wheel and pinch zoom the sheet in
integer pixel steps; a drag pans, the cross recentres on the hero, and the X
closes it.

## Touch controls

The frosted move stick uses a 56-unit base and a 24-unit pink knob. The
40-unit Attack sprite is scaled to the joystick's diameter and switches
between idle, pressed, aim and disabled frames. `RoundHudStyle` supplies both
controls' textures. The aim cone is drawn with the `AimConeStyle` resource
(`Scripts/player/aim_cone_style.gd`).

## Credits

- Font: `NormalFont.ttf` from the Ninja Adventure asset pack
  (`art/Sprites/NinjaAdventure/HUD/Font/`), CC0 1.0 — see
  `art/Sprites/NinjaAdventure/LICENSE.txt`. Its import is set to
  non-antialiased, unhinted rendering so glyphs stay crisp at integer scale.
- Everything else in the theme (style boxes, gradients) is defined directly in
  the `.tres` file and is original to this project.
- Candy Glass HUD sprites are original project art under `LICENSE.md`.
- Lilita One is bundled under the SIL Open Font License 1.1. See
  [the font licence](fonts/OFL.txt).

- Map panel: `map/ui_map_*.png` are original pixel art made in-house for this
  project, drawn in code in the flagoria palette. Repository licence
  (`LICENSE.md`).

## In-game keyboard

The in-game number pad and letter keyboard (`Scripts/ui/number_pad.tscn`) use their own
keycap styles from `main_menu_theme.tres`, as theme type variations:
`KeyCap` for character keys (tan wood face, ink outline, deeper bottom edge
that moves to the top when pressed), `KeyCapDelete` (muted red) and
`KeyCapOK` (gold, ink text) for the action keys, and `KeyboardPanel` for the
frame around the keys. Restyle the keys by editing those entries.
