# Mine cart animation evidence

The player-path drive ran under xvfb on seed 4 and finished with
`VERIFY_DONE ok`. It granted wood from the in-game menu, placed a mine
beside a rock through the Buildings picker, and captured known frames of
the 20-frame, 5 fps loop. After a save and a load from Worlds, it captured
the restored mine.

| Screenshot | Frame | Observed state |
|---|---:|---|
| [Picker](01-picker.png) | 12 (still) | The Mine tool shows the parked boulder and cart. |
| [Preview](02-preview.png) | 12 (still) | The 3×3 preview uses the parked pose and costs 15 wood. |
| [Outbound](03-outbound.png) | 7 | The cart is mid-track, rolling out. |
| [Parked](04-parked.png) | 12 | The cart waits at the end of the track. |
| [Inbound](05-inbound.png) | 18 | The cart is mid-track, rolling back in. It sits closer to the entrance than in the outbound capture. |
| [Reloaded](06-reloaded.png) | 9 | After loading the saved world, the same mine is present and the cart is at the arrival pose. |

Crops of the mine and a three-panel row of the outbound, parked and inbound
poses are in the same folder.
