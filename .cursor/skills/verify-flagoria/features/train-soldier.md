# Train soldier

Drive: drives/train_soldier.gd
Source: Scripts/mechanics/npcs/soldier_requests.gd

## What it does

A player at an owned barracks spends eight wood to train a soldier, then toggles every living soldier they own between Follow and Hold. Soldiers persist across save and reload.

## Preconditions

Host a solo match on seed 11 with the barracks build path (#556).

## Screens

- `train-ready` — the player stands in reach of an owned barracks with eight wood; the Train button is visible.
- `soldier-following` — after the train timer completes, the owner walks and the soldier closes the gap in Follow.
- `soldier-holding` — after Hold is toggled, the owner walks and the soldier stays put.

## Proof

- **Unit.** `PASS test_soldier_train` in `tests/mechanics/npcs/test_soldier_train.gd`, about 0.8 s in `tools/verify.sh`.
- **Net.** `PASS test_soldier_train_two_players` in `tests/net/test_soldier_sync.gd`, probe `tests/soldier_sync_probe.gd`, about 10–15 s per stress run.
- **Drive.** `drives/train_soldier.gd` with `launch: --seed 11`, about 30–45 s under xvfb.