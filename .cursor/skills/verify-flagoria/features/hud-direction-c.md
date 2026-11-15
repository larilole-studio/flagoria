# HUD Direction C (Castle Stone finals)

Drive: drives/hud_direction_c.gd

In-match HUD uses `art/ui/hud_c/` texture discs, the status nine-patch plate, integer stretch, and the 480x270 default layout in `art/ui/hud_c/layout.json`.

## How to get to it (user POV)

- Host a match. The top-left status plate, right-hand column, thumb arc, and joystick show Castle Stone art at crisp integer scale.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: about 25 s for this drive plus existing HUD drives in CI gameplay matrix.

- **Run (headless).** `tools/verify.sh` (`test_hud_round_buttons`, layout and bow tests).
- **Drive (live).** `bin/launch.sh drives/hud_direction_c.gd --display --seed 49`, and `hud_round_buttons`, `hud_customize`, `combat_hud`, `ranged_bow` for regression.
- **Proof.** Snapshots: `hud-1280`, `scores-selected`, `mode-interact`, `weapon-bow-1280`, `hud-disabled-edit`, `hud-1920`.