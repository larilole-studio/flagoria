# Map zoom

Drive: drives/map_zoom.gd

After hosting or joining, spread two fingers on the world to zoom in and bring them together to zoom out. The camera stays between 0.75× and 2× of its default. Zoom is local to each player.

- Touches that begin on a HUD control, including the joystick and Attack, stay with that control. A world pinch can cross a HUD control without grabbing it.
- Double-tap the world, or press Ctrl+0, to reset. Wheel and Ctrl+Plus and Ctrl+Minus step the camera zoom.
- Map or M opens the [parchment map](./explored-map.md). Pinching on the sheet zooms the chart while the world camera keeps its current setting.

## Verification

- `-- test_map_zoom` sends two touch contacts and drags through the stretched 2400×1080 viewport. It checks both limits, overlaps at the start of a pinch, HUD exclusion and desktop controls.
- `bin/launch.sh drives/map_zoom.gd --seed 42 --display` hosts and sends touch contacts through the window input path. Expect `default`, `zoomed-in`, `zoomed-out` and `parchment` screenshots. The log reports the camera factor and confirms the sheet zooms independently. The [2400×1080 captures](../../../../docs/evidence/pinch-minimap-660/) cover the phone-landscape framing. Physical touchscreen delivery needs a device check.
