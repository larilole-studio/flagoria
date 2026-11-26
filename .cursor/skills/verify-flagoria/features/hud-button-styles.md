# HUD button styles

Drive: drives/hud_button_styles.gd

Source: Scripts/ui/round_hud_style.gd

Candy Glass (`current`) is the default. Set `FLAGORIA_HUD_STYLE` to `teal`,
`leaf`, or `sand` for a glass recolor, or to `flat`, `shadow`, or `ghost`
for a minimal disc. Empty and unknown values use Candy Glass. All styles use
linear filtering with mipmaps, and the heart and resource stickers keep their
Candy Glass sprites.

The drive hosts seed 49 and checks the closed HUD, both Buildings picker
rings with captions, Attack held by touch, and the open sword/chop/bow fan.
The [comparison sheets](../../../../docs/evidence/hud-button-styles/) show the
closed HUD for each style and the supported button states, including Rotate.
Run `python3 tools/ui/compare_hud_styles.py` to regenerate both sheets from
2400×1080 match captures and source sprites.

`test_hud_button_styles` checks style resolution, key sprite imports, shared
stickers, and filtering through `RoundHudStyle`.
