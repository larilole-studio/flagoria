# Hooded frame saw evidence

The native art is 48 × 32 px per frame. Idle and each of the seven working
frames measure 44 × 30 px through the alpha bounds. The 3×2 layout leaves the
south-center doorstep empty.

- [Native frames](native), [4× idle](idle_x4.png),
  [4× work strip](work_strip_x4.png), and [working loop](working_loop.gif).
  Work frame 1 holds the raised idle pose for the turnaround. The GIF shows
  the seven working frames at 130 ms each.
- [Scale lineup](scale_lineup_x4.png) and [atlas terrain mockup](island_mockup_x4.png).
  The mill matches the lumber mill's 30 px height and sits below the 31 px
  barracks. The castle has the largest plot at 7×5. Its 14 px wall ring
  still needs to grow.
- [Placed idle](placed_idle.png) and [idle detail](placed_idle_crop.png).
  A live seed 4 match placed the sawmill through Buildings directly north of
  a pine. Playback was held at frame 0 for this capture.
- [Raised and lowered sash](working_frames_in_game.png). These are unscaled
  crops of working frames 1 and 3 after playback resumed.
- [In-game scale](scale_in_game.png). The whole starting castle, mill, hero,
  and pine share the 1920 × 1080 capture. Camera zoom was held at 1.0, which
  draws each native pixel as a 4 × 4 block.

The live images were captured with the verify-flagoria display launcher under
Xvfb. The placed idle and working crops match the source sprite's opaque pixels
exactly at 4×. See the [ten-step self-review](REVIEW.md) for the art checks.

The existing placement and two-player animation drives also passed under Xvfb.
The two-player run showed the joiner placing the mill, the host seeing it work,
and the host reloading the idle mill after the joiner left.
