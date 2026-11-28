# Soldier formations

Drive: drives/soldier_formations.gd
Source: Scripts/mechanics/npcs/soldier_formations.gd
Source: Scripts/mechanics/npcs/soldier_requests.gd
Source: Scripts/mechanics/npcs/soldier_saves.gd

Idle troops with the same owner and order can combine within two tiles.
Five soldiers form a squad. Four squads form a company of 20. A formation
uses one movement and combat entity and shows its member count. A squad
deals one HP per strike and a company deals four.

Each formation pools health from its members. A company below 20 members
splits into surviving squads and individuals, and a squad below five splits
into individuals. A recruit still counts against its original barracks
wherever its formation goes. Saves and late-join snapshots retain those
origins and counts.

## Screens

- `squad-ready` — five trained soldiers are represented by one squad and a 5 badge.
- `squad-moving` — the squad obeys the selected Command order.
- `squad-arrived` — the squad holds at its destination.

## Proof

`test_soldier_formation_losses_and_save` uses a company of 20 to check
pooled health, strike damage, member origins after reload, and partial-loss
splits. `test_soldier_formation_two_players` checks the same five-member
badge value and one entity on the host, client, and late joiner.
