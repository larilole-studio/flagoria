# Sage HUD discs

Drive: drives/hud_button_styles.gd

Source: Scripts/ui/round_hud_style.gd

In-match buttons and the joystick use flat menu-sage discs with a soft
shadow, ink edge, and off-white marks. Pressed faces turn deep green and
disabled faces turn muted mauve. The discs and Candy Glass stickers load
from `art/ui/hud_e4/` with linear filtering and mipmaps.

The drive hosts seed 49 and captures four views.

- `match-start` shows the closed HUD with the picker and parchment closed.
- `build-picker` shows both Buildings picker rings and their captions.
- `pressed` shows Attack while a touch holds it down.
- `disabled` shows Attack, the joystick, Buildings, Run, the tool button,
  Map, and Menu in their disabled states. The drive temporarily disables
  the controls for the capture and restores them afterward.

At the texture API seam, `test_hud_button_styles` checks the sprite directory,
filtering, mipmaps, sage faces, and the heart and log sticker textures.
