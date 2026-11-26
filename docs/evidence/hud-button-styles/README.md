# HUD button style comparison

| Panel | Style | `FLAGORIA_HUD_STYLE` | Idle colours |
| --- | --- | --- | --- |
| A | Candy Glass | `current` | Default glass sprites |
| B | Sage | `sage` | Normal menu sage with off-white marks |
| C | Sage light | `sage-light` | Hover sage with ink marks |
| D | Deep teal | `deep` | Pressed menu teal with off-white marks |
| E | Role colours | `role` | Gold Attack, sage Run and joystick, slider-teal Map, tan Buildings and picker, deep-teal wheel, gold-on-ink Menu |
| F | Soft-shadow sand | `shadow` | Original paper and ink discs |
| G | Ghost | `ghost` | Transparent fill, gold and ink ring, off-white marks |

- [Match start](match-start.png) shows the joystick, Attack, Run, tool wheel,
  Buildings, Map, and Menu in a two-column grid cropped from live 2400×1080
  seed 49 matches. The parchment and picker are closed.
- [State strip](state-strip.png) shows idle, pressed, disabled, and supported
  selected and aim states for Attack, Run, Buildings, Map, Plank, and Rotate.
  A dash marks an unavailable state.
- [Main-menu reference](menu-reference.png) crops the Worlds, Multiplayer, and
  Settings buttons from the live 2400×1080 main menu. The crop also appears on
  the match sheet.

Set `FLAGORIA_HUD_STYLE` before launch to preview a style. Run
`python3 tools/ui/compare_hud_styles.py` with Godot, Xvfb, CairoSVG, and Pillow
to regenerate the evidence.
