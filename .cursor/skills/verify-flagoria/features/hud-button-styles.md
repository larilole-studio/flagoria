# HUD button styles

Drive: drives/hud_button_styles.gd

Source: Scripts/ui/round_hud_style.gd

Candy Glass is the default. Set `FLAGORIA_HUD_STYLE` to `wood`, `parchment`,
`stone`, `pixel` or `banner` before launching Godot to preview opaque pixel-art
discs. Empty and unknown values use Candy Glass with the shipped constant.

The drive hosts seed 49 and captures the closed HUD, both Buildings picker
rings with captions, Attack held down by touch, and the open sword/chop/bow
fan. The [comparison sheets](../../../../docs/evidence/hud-button-styles/)
include a generated strip for disabled and selected states and the rotate disc.
Run `python3 tools/ui/compare_hud_styles.py` to regenerate them at 2400×1080.

`test_hud_button_styles` checks style resolution, key sprite imports, and
filtering through `RoundHudStyle`.
