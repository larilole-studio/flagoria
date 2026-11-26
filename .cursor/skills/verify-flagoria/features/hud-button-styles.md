# HUD button styles

Drive: drives/hud_button_styles.gd

Source: Scripts/ui/round_hud_style.gd

Candy Glass (`current`) is the default. Set `FLAGORIA_HUD_STYLE` to `sage`,
`sage-light`, `deep`, or `role` for soft-shadow discs in main menu colours.
`shadow` gives the original Soft-shadow sand discs, and `ghost` gives
transparent discs with a gold and ink ring. Empty and unknown values use
Candy Glass. All styles use linear filtering with mipmaps. Heart and resource
stickers use their Candy Glass sprites.

The drive hosts seed 49 and checks the closed HUD, both Buildings picker
rings with captions, Attack held by touch, and the open sword/chop/bow fan.
The [comparison sheets](../../../../docs/evidence/hud-button-styles/) show the
closed HUD for each style, supported button states including Rotate, and
the Worlds, Multiplayer, and Settings buttons from the main menu. Run
`python3 tools/ui/compare_hud_styles.py` to regenerate the sheets from
2400×1080 captures and source sprites.

At the texture API seam, `test_hud_button_styles` checks style resolution,
retired values, sprite imports, joystick face colours, shared stickers, and
mipmaps through `RoundHudStyle`.
