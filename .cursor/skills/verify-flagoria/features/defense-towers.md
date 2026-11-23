# Defense towers

Drive: drives/defense_tower.gd
Source: Scripts/mechanics/defense/tower_guns.gd

A player-owned flag tower shoots other players (#37). Wooden towers, castles and guard posts already place and capture; this does not add a second tower. `World/TowerGuns` (`Scripts/mechanics/defense/tower_guns.gd`) ticks on the host only. Each tick, every tower whose `owner_of` is greater than 0 picks the nearest living player other than that owner inside the range, checks line of sight, then `PlayerHealth.take_damage`. A 0.2 s tracer follows a hit. There is no projectile. Neutral (`0`) and mob (`-1`) owners do not shoot. The owner is read live, so a captured tower shoots for the new peer on the next tick. Cooldown is not saved and is not sent on join. Damage uses the existing health RPC, so a late joiner sees the health.

The ray starts 12 px out from the flag toward the target. A ray that starts on the flag hits the tower ring. The target's own body is not cover. A wall on the ray does not spend the cooldown.

Range, damage and cooldown are host `GameSettings`, with menu rows under the mob spawn row: range 80 px (32–160, step 8), damage 1 (1–3), cooldown 1.5 s (0.5–5, step 0.1). The default cooldown is 1.5 s because a hit's invulnerability lasts 1.0 s. A client's settings file is not the match.

## Sub-features

- `tower-guns-target` the nearest other living player inside the range is hit; the owner is ignored even when closer; outside the range there is no shot.
- `tower-guns-cooldown` two ticks inside the cooldown drop health once.
- `tower-guns-sight` a wall between the ring and the target suppresses the shot and does not spend the cooldown.
- `tower-guns-owners` owners 0 and -1 do not shoot.
- `tower-gun-sync` the client places a tower with the existing request; the host, pinned inside 80 px, loses health on both peers; outside the range that health stays; the builder's health stays full; a late joiner sees the health.

## How to get to it (user POV)

1. On the main menu, the tower range, damage and cooldown rows sit under Mob spawns. They are saved with the other gameplay settings. Only the host's values are used.
2. Host a match. The starting castle is a flag tower you own, so it does not shoot you. Another player inside its range, with a clear line out of the ring, loses health and sees a short line from the tower.
3. Build a wooden tower from the build picker. It shoots for you. After someone captures it, it shoots for them.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`.

- **Run.** `./.cursor/skills/verify-flagoria/bin/drive-verify.sh` and read `artifacts/verify.log`.
- **Proof.** Headers `-- test_tower_guns` and `-- test_tower_gun_two_players` with no `FAIL` after them.
- **Time cost.** `test_tower_guns` is about 0.4 s in `tools/verify.sh`. `test_tower_gun_two_players` is about 10 s per run (about 8–12 s), once in `tools/verify.sh` and at the stress tier in the Netcode stress job.
- **Drive (live).** `./.cursor/skills/verify-flagoria/bin/launch.sh drives/defense_tower.gd --display`. Offline, the host castle shoots a body named `2` standing just south of the gate, then that body steps outside the range.
- **Look.** `tower-in-range.png` shows the second body at the gate and a short bright line from the castle flag. `tower-out-of-range.png` shows that body further south, with no new line, and its health unchanged.

## Gotchas

- Do not start the line-of-sight ray on the flag. The tower ring blocks it and the tower never fires.
- Do not cache the owner when the tower is placed. Capture changes who it shoots.
- The client's saved range, damage and cooldown are not the match. The host reads its own `GameSettings`.
