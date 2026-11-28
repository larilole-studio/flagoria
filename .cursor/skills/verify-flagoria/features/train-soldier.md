# Train soldier

Drive: drives/train_soldier.gd
Source: Scripts/mechanics/npcs/soldier_requests.gd
Source: Scripts/mechanics/npcs/soldier_stats.gd

## What it does

An owned barracks charges both resources when training starts. The Soldiers
tuning group defaults to 8 wood, 4 stone, 4 seconds, and 20 soldiers per
barracks. Pending jobs and living soldiers both count toward the cap. If the
host cannot spawn a soldier, it returns the wood and stone paid for that job.
The player can toggle all their living soldiers between Follow and Hold.
Host saves preserve the training queue, completed soldiers and tuning overrides.

## Preconditions

Host a solo match on seed 11. Grant resources through the in-game menu and
place a barracks through the Buildings picker.

## Screens

- `train-ready` shows an owned barracks within reach and the Train 8w 4s button.
- `training-paid` shows the wood and stone balances immediately after payment.
- `soldier-following` shows the spawned soldier and its Hold button.
- `soldier-holding` shows the Follow button after the player selects Hold.

## Proof

- **Unit.** `PASS test_soldier_train` in `tests/mechanics/npcs/test_soldier_train.gd` checks
  that insufficient stone charges nothing and queues no soldier. It also
  covers the tuned cap, saving the remaining time, and a failed spawn
  refunding the original price.
- **Net.** `PASS test_soldier_train_two_players` in `tests/net/test_soldier_sync.gd`
  uses `tests/soldier_sync_probe.gd`. The requesting client pays both resources
  at the host's saved price and the soldier reaches both peers and a late joiner.
- **Drive.** `drives/train_soldier.gd` checks the HUD price, the two inventory
  deductions, and the timed spawn through player input.
