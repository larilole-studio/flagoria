# HUD button style comparison

Both sheets use a two-column, four-row grid with A first.

| Panel | Style | Preview value |
| --- | --- | --- |
| A | Candy Glass | `current` |
| B | Sea-teal glass | `teal` |
| C | Leaf-green glass | `leaf` |
| D | Sand-gold glass | `sand` |
| E | Flat | `flat` |
| F | Soft-shadow | `shadow` |
| G | Ghost | `ghost` |

- [Match start](match-start.png) crops the HUD zones from live 2400×1080 seed 49
  matches. The parchment map and Buildings picker are closed.
- [State strip](state-strip.png) shows Attack, Run, Buildings, Map, Plank and
  Rotate. A dash marks an unavailable state.

Set `FLAGORIA_HUD_STYLE` before launch to preview a style. Run
`python3 tools/ui/compare_hud_styles.py` with Godot, Xvfb, CairoSVG and Pillow
to regenerate both sheets. A is the shipped default.
