# Map Settings headers

Captured from the game under xvfb at a 480×270 window and logical viewport. The drive opens Worlds → Map Settings → Advanced using pointer input.

- [Seeds open](seeds-open.png) shows all five seed fields, the collapsed Noise header, and the pinned action buttons.
- [Chunks open](chunks-open.png) shows the three chunk fields after closing Seeds, opening Chunks, and scrolling down.
- [Groups closed](groups-closed.png) shows the lower headers with their rows hidden.

The drive reported `VERIFY_DONE ok` after checking the visibility of the groups, reopening the panel with Seeds open, and hosting from Map Settings.

```sh
VERIFY_WINDOW_SIZE=480x270 ./.cursor/skills/verify-flagoria/bin/launch.sh drives/map_settings_random.gd --display
```
