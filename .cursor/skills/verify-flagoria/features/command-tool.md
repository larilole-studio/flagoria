# Command tool

Drive: drives/command_soldiers.gd
Source: Scripts/player/soldier_command.gd
Source: Scripts/mechanics/npcs/soldier.gd
Source: Scripts/mechanics/npcs/soldier_requests.gd
Source: Scripts/mechanics/npcs/soldier_saves.gd

Choose Command on the tool wheel or press 4. Drag from Attack to preview your
soldiers inside a growing ellipse, then release to select them. Use Space with
mouse movement or drag with the mouse from the Attack button on desktop.
Tapping Attack selects all owned soldiers in range. The Command section of
Tuning controls the maximum selection radius, which defaults to 160 px.

Tap or click the map to move the selection. The host assigns distinct walkable
destinations near the tap. A team-coloured marker pulses at the tap on the
commanding peer. Troops hold when they arrive or after prolonged blockage.
Follow overrides a move. Saves made during a move restore those troops in Hold
at their saved positions.

## Screens

- `command-range` shows the preview ellipse and two highlighted soldiers.
- `command-moving` shows those soldiers walking toward the pulsing cross.
- `command-arrived` shows the selected soldiers holding near the target and
  the third soldier still in its original position.

## Proof

- Drive `bin/launch.sh drives/command_soldiers.gd --display` uses a seeded fixture
  to spawn three soldiers in Hold and real input for selection and orders.
- Unit `test_soldier_command_range` checks flattened geometry and excludes foreign
  and dead soldiers.
- Unit `test_soldier_command_host_rules` checks host validation, save capture,
  and the Follow override.
- Network `test_soldier_move_two_players` checks a client's move, replicated
  destinations, and agreement on the final held position.
