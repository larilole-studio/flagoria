# Points scoreboard

Drive: drives/points_scoreboard.gd

Menu → Scores opens the scoreboard with every connected player's point total. Rows sort highest first and update when totals change or players join or leave.

## Sub-features

- `points-scoreboard-panel` `ScoreboardPanel` (`Scripts/ui/scoreboard_panel.gd`): lists connected peers using synced `Points` totals.
- The Scores action closes the in-game menu and opens the panel. Opening Menu again closes the scoreboard.

## How to get to it (user POV)

- Host or Join, open Menu, choose Scores, and read every player's total (colour swatch, `You` or `Player N` / display name).

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: about 2.5 s for the three `test_points_scoreboard_*` cases; the four-client drive about 25 s.

- **Run.** `./tools/verify.sh` or `--only=points_scoreboard_two_players,points_scoreboard_late_join,points_scoreboard_four_players`.
- **Proof.** `test_ingame_menu_open_resume` checks the Scores action and HUD. Expect `PASS test_points_scoreboard_two_players`, `PASS test_points_scoreboard_late_join`, and `PASS test_points_scoreboard_four_players` with no `FAIL` after them.
- **Drive (live).** `bin/launch.sh drives/points_scoreboard.gd --display` joins three peers (four players), walks the host for discovery points, captures `hud-before-scores.png` with the menu closed and `menu-open.png` with Scores visible, then chooses Scores and captures `phone-scoreboard.png`.

## Gotchas

- Offline play lists only peer 1. Stale totals for disconnected peer ids stay in `Points` but do not appear while they are offline.