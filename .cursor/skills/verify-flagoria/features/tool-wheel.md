# Tool wheel

Drive: drives/tool_wheel.gd

One button beside Run arms sword, bow or chop (#574). A press shorter than 200 ms with less than 6 px of movement swaps to the previous tool. A longer press, or any drag, opens a half-moon that fans from the button toward the centre of the screen. Dragging up or down highlights a tool. Releasing selects it and closes the wheel. Sword is combat with the bow off, bow is combat with the bow armed, and chop is interact mode. Hold Q and aim with the mouse, the scroll wheel, or up/down, then release. Keys 1, 2 and 3 select sword, bow and chop directly. The button follows Run when a saved HUD layout moves Run. It is not a Customize HUD slot (#575). Sword and chop use the existing mode icons. Bow uses a drawn stand-in until the wheel art (#576).

## Sub-features

- `tool-wheel-hold` a drag highlights sword, bow or chop and release sets combat mode, bow-armed state, or interact mode. A hold with no drag opens on the current tool and release keeps it (`-- test_tool_wheel_hold`).
- `tool-wheel-keys` hold Q, move the highlight with the mouse, up/down and the scroll wheel, and release. Keys 1, 2 and 3 select directly. A mouse hold on the button does the same (`-- test_tool_wheel_keys`).
- `tool-wheel-tap` a tap under 200 ms with no drag swaps to the previous tool. The first tap, with no earlier tool, leaves sword armed. A drag selects instead of swapping (`-- test_tool_wheel_quick_tap`).
- `tool-wheel-host` a headless `--server` host does not build the wheel, and the wheel node does not run `_process`. `BowButton` and `ModeButton` are gone (`-- test_tool_wheel_headless_host`).

## How to get to it (user POV)

- Host or join. The round button just left of Run shows the armed tool (sword at the start). Tap it to swap back to the previous tool. Press and hold, then drag up or down, and release on sword, bow or chop. On a keyboard, hold Q or press 1, 2 or 3.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: the four headless tests add about 1.6 s to `tools/verify.sh`. The live drive is about 15 s under xvfb.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=tool_wheel_hold,tool_wheel_keys,tool_wheel_quick_tap,tool_wheel_headless_host`, or the full `tools/verify.sh`.
- **Drive (live).** `bin/launch.sh drives/tool_wheel.gd --seed 11 --display`. The window is 844×390. Snapshots: `tool-closed` (sword icon, wheel shut), `tool-open` (half-moon toward the centre), `tool-selected` (chop icon, interact mode).
- **Proof.** Headers `-- test_tool_wheel_hold`, `-- test_tool_wheel_keys`, `-- test_tool_wheel_quick_tap` and `-- test_tool_wheel_headless_host` with no `FAIL` after them. Aimed sword, bow shot and chop stay on their existing tests.

## Gotchas

- A tap swaps only after some other tool has been armed. Until then sword stays armed.
- Releasing a hold without leaving the button keeps the current tool. The wheel opened, and the highlight was already that tool.
- The wheel node has no `_process`. A headless `--server` host does not create it, and `HudToolRow` skips its layout pass there.
- Customize HUD still edits joystick, attack, Run, Buildings, Map and Scores. The wheel button is placed from Run's position (#575 is the slot for the button itself).
