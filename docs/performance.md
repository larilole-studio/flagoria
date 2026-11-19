# Frame benchmark

`tools/bench_frame.gd` loads the main scene, hosts a single-player world for a
seed, walks the hero on a fixed right, down, left, up loop and prints one
`BENCH key=value` line. Use it to compare a change against `main` on the same
machine.

```bash
run="$(mktemp -d)"
XDG_DATA_HOME="$run/data" XDG_CONFIG_HOME="$run/config" XDG_CACHE_HOME="$run/cache" \
  godot --headless --fixed-fps 45 --path . --script res://tools/bench_frame.gd -- \
  --seed=42 --frames=1200 --size=default
```

- `--size=large` turns on a 12-island archipelago.
- Fresh XDG dirs keep the Host flow from writing map settings into a shared user dir.
- `frame_wall_us_*` is the wall time of each process frame: the number to compare.
- `process_us_*` and `physics_us_*` are Godot's monitors, which only update
  about once a second and hold their peak in between. Treat them as rough peaks.

## Headless versus displayed

Headless skips display-only work: terrain painting passes, clouds, night lights
and all rendering. To include that work, run the same command under a display
instead of `--headless`, for example `xvfb-run -a godot --resolution 960x540 ...`.
That adds `draw_calls_*` and `render_objects_*`. A software display (llvmpipe)
uses the Compatibility renderer, so its draw numbers show trends only.

Neither mode measures mobile GPU fill rate, shader cost or frame pacing. Use
an on-device profile for those.
