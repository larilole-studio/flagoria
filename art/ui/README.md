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

### HUD button style exploration

Candy Glass (`current`, `hud_e4/`) is the default in
`RoundHudStyle.SELECTED`. Set `FLAGORIA_HUD_STYLE` before launch to preview
`teal`, `leaf`, `sand`, `flat`, `shadow`, or `ghost`. Empty and unknown
values use Candy Glass. The buttons and joystick use linear filtering with
mipmaps. Hearts and resource stickers keep their Candy Glass sprites.

Run `python3 tools/ui/gen_hud_styles.py` with CairoSVG and Pillow to regenerate
the [variant sprites](hud_styles/). Run `python3 tools/ui/compare_hud_styles.py`
to generate the [match capture and state strip](../../docs/evidence/hud-button-styles/).

## Map panel

Map or M opens the parchment sheet (`Scripts/ui/parchment_map.gd`). It
fills the viewport with `#e7d7b1` paper, a `#cbb98a` dither for unexplored
cells, and a `#8a5a32` edge. Explored cells use the terrain palette in
`Scripts/ui/map_chart.gd`, with a 1 px ink line along explored coastlines.

The four 16 × 16 `map/ui_map_marker_hero_*.png` textures show the hero's
facing. Pixel (8, 8) anchors each marker to the hero's cell. Wheel and pinch
zoom the sheet in whole pixels per cell. A drag pans, the target button
recentres on the hero, and X closes the sheet.

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
