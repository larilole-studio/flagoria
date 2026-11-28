# Soldier and Command visuals

Drive: drives/soldier_visuals.gd
Source: Scripts/mechanics/npcs/soldier.gd
Source: Scripts/player/soldier_command.gd
Source: Scripts/ui/round_hud_style.gd
Source: Scripts/mechanics/structures/building_health.gd
Source: Scripts/ui/building_alerts.gd

Single soldiers use 16 px facing frames, with idle, walk and strike poses.
Groups use 32 px squad and 48 px company frames with the 5 and 20 badges.
Host blue and opposing red share geometry and swap two team colours.
Command uses a flag icon, a flattened gold selection ellipse, and a
pulsing destination flag. Damaged structures show two stages of cracks
and their remaining HP. The building alert uses the same shield on
the HUD minimap and the parchment map.

## Screens

- `formation-command-range` — both teams, the formation counts and selection radius.
- `formation-command-moving` — live move with the destination flag and Command icon.
- `barracks-cracks-and-alert` — damaged barracks, soldier attack, and the HUD shield.
- `parchment-alert-art` — the shield on parchment.

## Proof

Run `python3 tools/art/check_soldier_palette.py` with Pillow for grid,
palette, team swap and wheel scale checks. The existing soldier fight
peer test verifies that the strike counter reaches the host, client,
and late joiner. The art fixture shows both team variants, the
formation sprites and the attack UI in the live game.
