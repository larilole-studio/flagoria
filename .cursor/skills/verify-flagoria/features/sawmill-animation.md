# Sawmill animation and sound

Drive: drives/sawmill_anim.gd
Source: Scripts/mechanics/structures/sawmill_anim.gd
Source: Scripts/mechanics/structures/structure_placer.gd
Source: Scripts/mechanics/building/build_preview.gd

The Buildings picker and preview use the idle pose. The placed sawmill uses a
transparent 48 × 32 sprite over the generated ground. When the sawmill can
deliver wood, the sash and blade stroke through the log, chips fly, a plank
starts to separate, and a positional wood-cutting sound plays once per loop.
A disconnected owner leaves the still pose and silences the sound.
Demolition removes the artwork and sound together.

- The display drive starts a localhost joiner, opens Buildings and places a
  sawmill via the preview. Inspect both idle picker and preview, the raised
  and lowered sash during production, and the joiner's view of that same mill.
  The host then captures the idle pose after the joiner leaves and again after
  saving and reloading through Worlds.
- `test_sawmill_animation_lifecycle` checks footprint alignment, invisible
  collision tiles, animation, sound, and removal through construction.
- `test_sawmill_animation_late_join` checks that both peers show matching art
  and producing playback on an existing sawmill, and that disconnect restores
  the idle pose and stops the audio.
