# Soldier vs peer

Drive: drives/soldier_vs_peer.gd

## What it does

A trained soldier on Hold strikes a nearby living player who is not its owner. Health replicates to every peer without a new RPC.

## Preconditions

Host a solo match on seed 11 with the barracks build path (#556). A second player body stands in attack range.

## Screens

- `soldier-vs-peer` — the victim's health is below full while the soldier stands beside them.

## Proof

- **Unit.** `PASS test_soldier_player` in `tests/mechanics/npcs/test_soldier_player.gd`, about 0.5 s in `tools/verify.sh`.
- **Net.** `PASS test_soldier_player_two_players` in `tests/net/test_soldier_player_sync.gd`, probe `tests/soldier_player_probe.gd`, about 12–18 s per stress run.
- **Drive.** `drives/soldier_vs_peer.gd` with `launch: --seed 11`, about 25–40 s under xvfb.