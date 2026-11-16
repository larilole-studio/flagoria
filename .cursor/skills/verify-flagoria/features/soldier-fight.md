# Soldier fight

Drive: drives/soldier_fight.gd

## What it does

A trained soldier exchanges blows with nearby living mobs on the host. Kill credit for the mob goes to the soldier owner. The owner's sword and bow never hurt that soldier; another peer's bow can.

## Preconditions

Host a solo match on seed 11 with the barracks build path (#556).

## Screens

- `soldier-striking` — soldier and slime both still alive after the first hits land.
- `soldier-down` — the soldier is dying or the slime is gone.

## Proof

- **Unit.** `PASS test_soldier_fight` and `PASS test_soldier_bow` in `tests/mechanics/npcs/test_soldier_fight.gd`, about 0.9 s in `tools/verify.sh`.
- **Net.** `PASS test_soldier_fight_two_players` in `tests/net/test_soldier_fight_sync.gd`, probe `tests/soldier_fight_probe.gd`, about 12–18 s per stress run.
- **Drive.** `drives/soldier_fight.gd` with `launch: --seed 11`, about 25–40 s under xvfb.