# Soldier sight and pursuit

Drive: drives/soldier_sight.gd
Source: Scripts/mechanics/npcs/soldier.gd
Source: Scripts/mechanics/npcs/soldier_target.gd
Source: Scripts/mechanics/structures/building_health.gd

Soldiers look for hostile units and buildings within the tuned sight radius of 96 px. They move to striking range, deal damage on the host, and resume their orders when the target leaves or is defeated. A soldier in Hold returns to its original post.

## Screens

- `soldiers-engaged` — a defending soldier has taken a hit.
- `enemy-barracks-hit` — a soldier at the enemy barracks reduces its health.
- `returned-to-post` — the attacker returns after the target is cleared.

## Proof

The seeded fixture drives real host simulation through hostile contact, building damage and Hold return. `test_soldier_building_targets` checks enemy, neutral and friendly footprint selection through the public building health API. The soldier fight and building health peer tests cover replicated health and removal.
