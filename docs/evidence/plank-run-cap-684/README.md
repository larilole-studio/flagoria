# Plank run cap of 10 tiles (#684)

A plank drag that starts on the first reachable water cell can now preview and place up to 10 tiles in one action, at one wood per tile. The 11th cell stays red and is not placed. Far cells in that run may sit outside the 80 px building reach circle; the host still checks reach at the start of the run and refuses a request longer than 10 tiles.

`preview-10-tiles.png` shows a 10-tile green preview, a red overflow cell, and a cost of 10 wood.
