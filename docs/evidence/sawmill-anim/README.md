# Sawmill animation and sound (#751)

The eight-frame, 48 × 48 strip is placeholder art assembled from the original
timber structure tiles and the existing Ninja Adventure WaterMill wheel
frames, with a small pixel-art saw, log, and sawdust. The transparent base
lets the generated terrain show through. The picker and preview use frame
zero. The sound is the existing `tree_chop_02.wav` on the positional SFX bus.

The localhost drive ran under xvfb with seed 4. The joiner placed the
sawmill through Buildings, then left through the in-game menu. The host
saved and loaded the same world through Worlds.

- [Buildings picker](01-picker.png) and [valid placement preview](02-preview.png)
  show the idle still.
- [Retracted blade](03-saw-retracted.png), [extended blade](04-saw-extended.png),
  and [the joiner's view](05-joiner-sawing.png) show the placed mill during production.
- [After the owner leaves](06-placed-idle.png) and [after reloading](07-reloaded-idle.png),
  the host sees the same still pose.

Full-frame images are 1920×1080. The `-crop` files are tighter views of the same frames.
