# Architecture map and folder convention

Where each part of the game lives today, how data moves between the parts, and where new code goes. The script inventory is generated from the tracked tree and checked by `tools/verify.sh`. After adding, moving or removing a tracked production script, run `python3 tools/architecture_inventory.py --write`.

## Entry points

| Entry | What starts there |
|---|---|
| `project.godot` | Main scene `flagoria_main.tscn`, and seven autoloads: `MapGen` (`Scripts/world/map_gen.gd`), `AudioSettings` (`Scripts/audio/audio_settings.gd`), `GameSettings` (`Scripts/shell/game_settings.gd`), `HudLayout` (`Scripts/ui/hud_layout.gd`), `MusicPlayer` (`Scripts/audio/music_player.gd`), `UiSfx` (`Scripts/audio/ui_sfx.gd`), `DayNight` (`Scripts/mechanics/day_night/day_night.gd`). |
| `flagoria_main.tscn` + `flagoria_main.gd` | The game: main menu, HUD, `World/worldMap` (the `TileMap`), `World/Mobs`, `World/Interaction`, `World/RangedShots`, `World/TowerGuns`, `Inventory`, `Points`, `Discovery`. Host, join, the dedicated server (`-- --server`), player spawn and the map-parameter sync. Join re-dials in `Scripts/net/join_dial.gd`. |
| `tests/run_tests.gd` | Headless test runner (`--only`, `--list`). It finds every `tests/**/test_*.gd` file; see `tests/README.md`. |
| `tools/verify.sh` | What CI's verify job runs: import, parse every script in one process (`tools/parse_scripts.gd`), run every test. |
| `tools/cli.gd` | Headless map commands (`map render`, `map stats`, in `tools/map_cli.gd`) and HUD snapshots (`hud layout`, in `tools/hud_layout_dump.gd`). |

## Main data flows

- **Map generation.** `Scripts/ui/MapAdminPanel.gd` edits `MapGen.params` (a `MapGenParams`, saved to `user://map_gen_params.cfg`). Host emits `MainMenu.new_server_created`; `flagoria_main.gd` `setup_server` applies the params to `Scripts/world/TileMap.gd` (`apply_map_params`). Every `chunk_refresh_frames` frames (default 15) `Scripts/world/TileMap.gd` draws a chunk (default 32 x 32 cells) around the local player (`generate_chunk`): biome (`Scripts/world/BiomeCatalog.gd`), altitude (island and archipelago shaping in `Scripts/world/terrain_shape.gd`), then ground, plants and stones (plants and stones picked in `Scripts/world/plant_picker.gd`), named through `Scripts/world/tile_catalog.gd`. `predict_cell` gives the same answer for cells not drawn yet. Each draw emits `ground_changed`. The map node delegates generation settings and reset to `Scripts/world/world_map_params.gd`, chunk refresh, painting and prediction to `Scripts/world/world_chunks.gd`, and cell occupancy, collision and spawn lookup to `Scripts/world/world_cell_queries.gd`.
- **Spawn.** `Scripts/world/TileMap.gd` `resolve_player_spawn` finds reachable land; `free_spawn_position` keeps players apart. The cached spawn lookup lives in `Scripts/world/world_cell_queries.gd`, and the search and spacing rules live in `Scripts/world/spawn_finder.gd`. `flagoria_main.gd` places each player there. A host that plays first places its starting castle next to the spawn (`place_start_castle`, forwarding to `Scripts/world/start_castle.gd`), and the land outside the castle gate becomes the spawn.
- **Player and interaction.** `Scripts/player/character_body_2d.tscn` (`Scripts/player/player.gd`) owns the player actor and its RPCs. It delegates movement to `Scripts/player/player_input.gd`, swings and bow routing to `Scripts/player/player_combat.gd`, and zoom setup to `Scripts/player/player_camera.gd` (`Scripts/player/map_zoom.gd` handles zoom). `Scripts/player/player_hud.gd` binds the local HUD, and `Scripts/player/player_wall_draw.gd` handles draw order at walls. Aim is handled by `Scripts/player/attack_aim.gd` and styled by `Scripts/player/aim_cone_style.gd`. The run control (`Scripts/mechanics/run/run_control.gd`) scales that walk while its button is held or latched, or while the run action is down. With the bow armed on the tool wheel (`Scripts/ui/tool_wheel.gd`, #574), that aim fires one shot instead of the sword (`World/RangedShots`, `Scripts/mechanics/combat/ranged_shots.gd`); `Scripts/mechanics/combat/ranged_shot.gd` is the flight. Health is `Scripts/player/player_health.gd`. `Scripts/mechanics/interact/interaction.gd` switches combat and interact mode. In interact mode the attack button aims a chop cone (`Scripts/mechanics/interact/chop_stick.gd`) at choppable cells (types from `Scripts/mechanics/interactables/` and `data/interactables/`; adding one: `docs/interactables.md`), and the chop runs through `Scripts/mechanics/trees/chop_action.gd`, calls `Scripts/world/TileMap.gd` `cut_choppable` (which forwards to `Scripts/mechanics/trees/tree_cuts.gd`) and adds the yield to `Scripts/mechanics/trees/inventory.gd`, which `Scripts/ui/resource_hud.gd` shows. Stumps regrow through `Scripts/world/TileMap.gd` `regrow_due` (also in `tree_cuts.gd`).
- **Structures.** `Scripts/world/TileMap.gd` `place_structure` forwards to `Scripts/mechanics/structures/structure_placer.gd`, which reads `Scripts/mechanics/structures/structure.gd` files. Auto walls and tower rings are solved together with free-form palisades by `Scripts/mechanics/walls/wall_solver.gd` (`WallBuilder.resolve`). In play the starting castle, the buildable wooden tower (#273), extra castles (#527), guard posts (#528), and sawmills (#749) use it. `World/TowerCapture` (`Scripts/mechanics/conquest/tower_capture.gd`) treats each placement's team flag as a tower that players and mobs capture by standing next to it, and hands it over with `StructurePlacer.set_owner`. In multiplayer the host advances capture and sends owner and progress (#497). `World/TowerGuns` (`Scripts/mechanics/defense/tower_guns.gd`) is the host tick for those flags: a player-owned tower shoots the nearest other living player in range, then draws a short tracer (#37). `Scripts/world/TileMap.gd` `build_bridge` (which forwards to `Scripts/mechanics/bridges/bridge_builder.gd`) is only called from tests so far. Wood and stone prices live in `Scripts/mechanics/building/build_costs.gd` (#272), whose `buy` spends through `Scripts/mechanics/trees/inventory.gd` `spend`. The shared building seam is `Scripts/mechanics/building/construction_placer.gd` (#296, #610). `can_place` and `cost` serve the preview, `place` handles local builds, and `place_for_peer` handles host-approved builds. Both placement paths use the same resource transaction, refunding a failed write. `StructureRequests` applies live named building updates through `apply_replica`; peers read the resulting placement through `TileMap`. The build tools are `Scripts/mechanics/building/build_placement.gd` (#225 / #273 / #276): two labelled rings around Buildings, with Plank / Wall / Tower inside and Castle / Guard post / Barracks / Mine / Sawmill / Demolish outside, Cut when none is selected, H/V snap, footprint previews with rotation (#493), wall tip chain, green/red preview; `Interaction` wires it. Free-form walls live in `Scripts/mechanics/walls/wall_builder.gd` (#276). `World/Cities` (`Scripts/mechanics/conquest/cities.gd`) flood-fills from each flag through wall barriers to make a city (world tint and parchment walls; capture transfers ownership). In multiplayer the host runs that fill and sends the list (#498). `World/LandScore` (`Scripts/mechanics/conquest/land_score.gd`) counts interior cells inside each owner's flag range and the host sets that count on `Points` (#279). A tap on a flag draws the range ring.
- **Mobs.** The server runs `Scripts/mechanics/mobs/mob_spawner.gd` `spawn_for_world` (types and sheets from `Scripts/mechanics/mobs/mob_catalog.gd`) for the opening wave, then `plan_tick` to spawn and despawn around living players. Ambient caps follow the host clock (#559): night is twice the day cap, dusk and dawn ramp between, and a surplus despawns only past the despawn radius. The cycle off keeps the day caps. The scale is read from `DayNight.spawn_scale()` on a tick, the same call a joiner makes. Each mob runs `Scripts/mechanics/mobs/mob.gd` on the server, and the other peers receive its state through the `MultiplayerSynchronizer` in `Mobs/mob.tscn`. A chasing mob is kept when it is far from every player. When raids are on, `World/RaidDirector` (`Scripts/mechanics/mobs/raid_director.gd`) sends a few idle mobs toward the nearest player city, or the nearest owned tower when none is in range; those mobs stay pinned and damage free-form walls in reach (#529). Raids stay off until the host turns them on. Kills and discoveries pay out through `Scripts/mechanics/conquest/points.gd` and `Scripts/mechanics/conquest/discovery_points.gd`, and `Scripts/ui/score_hud.gd` shows them.
- **Netcode.** ENet on UDP 9786 in `flagoria_main.gd`. The server owns the map params, mobs, health and points. A joining peer gets the full params, the host's tree and bush cuts and its placed structures through the `receive_map_params` RPC (cuts past the first 500 follow in `receive_join_cuts`, #354) and builds the same map locally. A tower or free-form wall placed after the join is a request to the host (`StructureRequests`, #497, #498), which writes it and sends it to every peer. A joining peer's starting castle is placed by the host outside the shared spawn and sent the same way (#278). Capture progress and cities ride with that join. A late joiner also receives the solved auto junction cells. A building the host generates after the match starts is a seed, size, style and cell (`GeneratedBuildings`, #26); every peer, including one that joins later, runs the same solver and paints that building on its own map layer. Players spawn through the `MultiplayerSpawner` under `World`. A cut during play is asked of the host (`Interaction.request_cut`, limited per peer by `CutRateLimit`, #355), which decides it and sends the stump to every peer (`apply_cut`) and the wood to the cutter; the host also decides regrowth and sends the plants that regrew in each tick to every peer in one message (`apply_regrow_cells`, #298, #353). The multiplayer tests are stress-run by `tools/stress_netcode.py`. The day/night clock (`DayNight`) is host-owned: clients and a late joiner are sent the host's elapsed time (#558).
- **UI and menus.** `Scripts/shell/MainMenu.gd` owns the menu scene entry points and opens `Scripts/ui/map_admin_panel.tscn`. It delegates Host/Join to `menu_join_flow.gd`, the saved-world picker to `menu_worlds.gd`, volume controls to `menu_volume.gd`, and mob, tower and raid controls to `menu_gameplay_settings.gd`. `Scripts/ui/number_pad.tscn` gives touch keys for number fields. In play: `Scripts/shell/ingame_menu.tscn`, `Scripts/shell/quit_prompt.tscn`, `Scripts/ui/hearts_hud.gd`, `Scripts/ui/hud_tool_row.gd` (Map beside Menu, Attack mirrored from the joystick, Run and the tool wheel around Attack, and Buildings beside that cluster with a two-ring picker over a dimmed playfield, #480, #574, #575), `Scripts/ui/tool_wheel.gd` (hold to arm sword, bow or chop; the arc stays on screen), `Scripts/ui/hud_layout.gd` (per-device touch control layout in `user://`, #492, #575), `Scripts/ui/map_chart.gd` (tracks explored cells and paints chart textures), `Scripts/ui/parchment_map.gd` (the full parchment sheet) and `Scripts/ui/map_wood_button.gd` (those wood controls). The theme is `art/ui/main_menu_theme.tres`.
- **Saves.** `Scripts/saves/map_save.gd` reads and writes versioned saves in `user://saves/` (gzip of one JSON document; older plain JSON still loads), written by the in-game menu's Save through `MapGen.save_world`. Each match has its own file: the main menu lists them and loads one, and Save replaces that file. `Scripts/saves/world_save.gd` is one save in memory: the generation inputs plus the world's changes. The dedicated server loads one with `--params`. The day/night elapsed time is the `clock` object (#558). See `docs/world-saves.md`.
- **Audio.** Buses are in `default_bus_layout.tres` and volumes in `Scripts/audio/audio_settings.gd`. Music comes from `Scripts/audio/music_player.gd` and UI sounds from `Scripts/audio/ui_sfx.gd`. Per-instance sounds come from `Scripts/audio/combat_sfx.gd`, `Scripts/audio/footsteps.gd` and `Scripts/audio/mob_sfx.gd`, with files in `art/audio/` (made by `tools/audio/`). See `docs/audio.md`.

## Production script inventory

<!-- BEGIN GENERATED SCRIPT INVENTORY -->

### `Scripts/audio/`

- `Scripts/audio/audio_settings.gd`
- `Scripts/audio/combat_sfx.gd`
- `Scripts/audio/footsteps.gd`
- `Scripts/audio/mob_sfx.gd`
- `Scripts/audio/music_player.gd`
- `Scripts/audio/ui_sfx.gd`

### `Scripts/mechanics/`

#### `bridges/`

- `Scripts/mechanics/bridges/bridge_builder.gd`

#### `building/`

- `Scripts/mechanics/building/admin_resource_grants.gd`
- `Scripts/mechanics/building/build_costs.gd`
- `Scripts/mechanics/building/build_placement.gd`
- `Scripts/mechanics/building/build_placement_rotate.gd`
- `Scripts/mechanics/building/build_preview.gd`
- `Scripts/mechanics/building/build_tool_row.gd`
- `Scripts/mechanics/building/construction_placer.gd`
- `Scripts/mechanics/building/construction_remover.gd`
- `Scripts/mechanics/building/footprint_orientation.gd`
- `Scripts/mechanics/building/structure_requests.gd`

#### `building_blocks/`

- `Scripts/mechanics/building_blocks/building_block_catalog.gd`
- `Scripts/mechanics/building_blocks/building_block_piece.gd`
- `Scripts/mechanics/building_blocks/building_merge.gd`
- `Scripts/mechanics/building_blocks/generated_buildings.gd`
- `Scripts/mechanics/building_blocks/wfc_building_constraints.gd`
- `Scripts/mechanics/building_blocks/wfc_solver.gd`

#### `combat/`

- `Scripts/mechanics/combat/ranged_shot.gd`
- `Scripts/mechanics/combat/ranged_shots.gd`

#### `conquest/`

- `Scripts/mechanics/conquest/cities.gd`
- `Scripts/mechanics/conquest/discovery_points.gd`
- `Scripts/mechanics/conquest/flags_held_points.gd`
- `Scripts/mechanics/conquest/land_score.gd`
- `Scripts/mechanics/conquest/points.gd`
- `Scripts/mechanics/conquest/tower_capture.gd`

#### `day_night/`

- `Scripts/mechanics/day_night/day_night.gd`
- `Scripts/mechanics/day_night/night_lights.gd`

#### `defense/`

- `Scripts/mechanics/defense/tower_guns.gd`

#### `interact/`

- `Scripts/mechanics/interact/chop_stick.gd`
- `Scripts/mechanics/interact/cut_rate_limit.gd`
- `Scripts/mechanics/interact/interaction.gd`

#### `interactables/`

- `Scripts/mechanics/interactables/chop_sprites.gd`
- `Scripts/mechanics/interactables/interactable_catalog.gd`
- `Scripts/mechanics/interactables/interactable_type.gd`

#### `mobs/`

- `Scripts/mechanics/mobs/mob.gd`
- `Scripts/mechanics/mobs/mob_catalog.gd`
- `Scripts/mechanics/mobs/mob_spawner.gd`
- `Scripts/mechanics/mobs/raid_director.gd`
- `Scripts/mechanics/mobs/raid_step.gd`

#### `npcs/`

- `Scripts/mechanics/npcs/soldier.gd`
- `Scripts/mechanics/npcs/soldier_requests.gd`
- `Scripts/mechanics/npcs/soldier_saves.gd`
- `Scripts/mechanics/npcs/soldier_stats.gd`
- `Scripts/mechanics/npcs/soldier_target.gd`

#### `run/`

- `Scripts/mechanics/run/run_control.gd`

#### `structures/`

- `Scripts/mechanics/structures/mine_cart.gd`
- `Scripts/mechanics/structures/mine_production.gd`
- `Scripts/mechanics/structures/sawmill_anim.gd`
- `Scripts/mechanics/structures/sawmill_production.gd`
- `Scripts/mechanics/structures/structure.gd`
- `Scripts/mechanics/structures/structure_placer.gd`
- `Scripts/mechanics/structures/structure_saves.gd`

#### `trees/`

- `Scripts/mechanics/trees/chop_action.gd`
- `Scripts/mechanics/trees/inventory.gd`
- `Scripts/mechanics/trees/sprout_scheduler.gd`
- `Scripts/mechanics/trees/tree_cuts.gd`
- `Scripts/mechanics/trees/tree_sprouts.gd`

#### `tuning/`

- `Scripts/mechanics/tuning/tuning.gd`

#### `walls/`

- `Scripts/mechanics/walls/wall_builder.gd`
- `Scripts/mechanics/walls/wall_solver.gd`

### `Scripts/net/`

- `Scripts/net/join_address.gd`
- `Scripts/net/join_dial.gd`
- `Scripts/net/join_enet_timeout.gd`
- `Scripts/net/tuning_sync.gd`

### `Scripts/player/`

- `Scripts/player/aim_cone_style.gd`
- `Scripts/player/attack_aim.gd`
- `Scripts/player/map_zoom.gd`
- `Scripts/player/player.gd`
- `Scripts/player/player_camera.gd`
- `Scripts/player/player_combat.gd`
- `Scripts/player/player_health.gd`
- `Scripts/player/player_hud.gd`
- `Scripts/player/player_input.gd`
- `Scripts/player/player_wall_draw.gd`

### `Scripts/saves/`

- `Scripts/saves/map_save.gd`
- `Scripts/saves/player_save.gd`
- `Scripts/saves/world_save.gd`

### `Scripts/shell/`

- `Scripts/shell/MainMenu.gd`
- `Scripts/shell/game_settings.gd`
- `Scripts/shell/ingame_menu.gd`
- `Scripts/shell/menu_gameplay_settings.gd`
- `Scripts/shell/menu_join_flow.gd`
- `Scripts/shell/menu_saved_servers.gd`
- `Scripts/shell/menu_volume.gd`
- `Scripts/shell/menu_worlds.gd`
- `Scripts/shell/quit_prompt.gd`
- `Scripts/shell/saved_servers.gd`
- `Scripts/shell/worlds_save_list.gd`

### `Scripts/ui/`

- `Scripts/ui/MapAdminPanel.gd`
- `Scripts/ui/hearts_hud.gd`
- `Scripts/ui/hud_layout.gd`
- `Scripts/ui/hud_layout_defaults.gd`
- `Scripts/ui/hud_layout_edit.gd`
- `Scripts/ui/hud_layout_visual.gd`
- `Scripts/ui/hud_tool_row.gd`
- `Scripts/ui/map_chart.gd`
- `Scripts/ui/map_wood_button.gd`
- `Scripts/ui/number_pad.gd`
- `Scripts/ui/parchment_map.gd`
- `Scripts/ui/resource_hud.gd`
- `Scripts/ui/round_hud_style.gd`
- `Scripts/ui/score_hud.gd`
- `Scripts/ui/scoreboard_panel.gd`
- `Scripts/ui/status_plate_hud.gd`
- `Scripts/ui/tool_wheel.gd`
- `Scripts/ui/tuning_panel.gd`
- `Scripts/ui/world_save_preview.gd`

### `Scripts/world/`

- `Scripts/world/BiomeCatalog.gd`
- `Scripts/world/MapGenParams.gd`
- `Scripts/world/TileMap.gd`
- `Scripts/world/birch_trees.gd`
- `Scripts/world/cloud_motion.gd`
- `Scripts/world/explored_map.gd`
- `Scripts/world/map_gen.gd`
- `Scripts/world/object_removals.gd`
- `Scripts/world/plant_picker.gd`
- `Scripts/world/sky_islands.gd`
- `Scripts/world/spawn_finder.gd`
- `Scripts/world/start_castle.gd`
- `Scripts/world/terrain_shape.gd`
- `Scripts/world/tile_catalog.gd`
- `Scripts/world/world_cell_queries.gd`
- `Scripts/world/world_chunks.gd`
- `Scripts/world/world_map_params.gd`

### Root and other

- `TouchScreenButton.gd`
- `flagoria_main.gd`

<!-- END GENERATED SCRIPT INVENTORY -->

## Scenes, resources and tooling

| Location | Holds |
|---|---|
| Repository root | Main scene and top-level UI scenes. |
| `Scripts/player/` | Player and sword scenes (`character_body_2d.tscn` and `sword.tscn`). |
| `Mobs/` | Mob and soldier scenes. |
| `data/` | Resource files a mechanic loads (`data/interactables/tree.tres`, `pine.tres`, `bush.tres`). |
| `art/` | Tiles, sprites, sounds, theme and their credits. |
| `assets/ui/hud/` | HUD button icons for Buildings, Map, Run and the two mode states. Imported without mipmaps; the buttons draw them nearest-neighbour. |
| `structures/` | Hand-drawn structure text files (`structures/guard_post.txt`, `structures/castle.txt`) in the format `Scripts/mechanics/structures/structure.gd` parses. |
| `addons/virtual_joystick/` | Vendored touch joystick. |
| `addons/server_shutdown/` | Linux SIGTERM helper for `-- --server` only. |
| `Dockerfile`, `docker-compose.yml`, `docker/` | Non-root dedicated-server image. The game is not rebuilt there beyond Godot's import. |
| `tests/` | Runner (`tests/run_tests.gd`, plus its own self-checks), area test files (`tests/<area>/test_*.gd`), shared helpers (`tests/helpers/test_helpers.gd`), probes started as separate processes, `tests/fixtures/`, `tests/golden/`. |
| `tools/` | Verify, CLI, renders, asset generators, CI helpers (`tools/pr_hygiene.py`, `tools/private_server_doc.py`, `tools/architecture_inventory.py`, `tools/file_budget.py`, `tools/play_review_paths.py`, `tools/verify_drive_picks.py`, `tools/stress_netcode.py`, `tools/stress_scenario_lint.py`, `tools/ci_job_times.py`, `tools/issue_triage.py`, `tools/required_checks.py`, `tools/parse_scripts.gd`), and local git hooks (`tools/commit_identity_hook.py`, `tools/staged_import_hook.py`). |
| `.github/workflows/` | verify, pr-hygiene, play-review-label, play-review, pr-debug-apk, android-apk, job-times, issue-triage. |
| `.cursor/skills/verify-flagoria/` | Launch, doctor and drive scripts, and one feature file per feature under `.cursor/skills/verify-flagoria/features/`. |
| `docs/` | Feature and process notes, e.g. `docs/interactables.md` (checklist for a new choppable type). |

## Layout conventions

- `Scripts/world/`: map generation helpers (terrain shape, plant picking, spawn search, starting castle).
- `Scripts/mechanics/<mechanic>/`: one folder per mechanic: `trees/`, `bridges/`, `walls/`, `structures/`, `interact/`, `interactables/`, `building/` and `conquest/`.
- `tests/<area>/test_*.gd`: tests per area (`world/`, `saves/`, `mobs/`, `combat/`, `player/`, `points/`, `ui/`, `audio/`, `net/`) or per mechanic (`tests/mechanics/<mechanic>/`), with shared helpers in `tests/helpers/test_helpers.gd`. The runner finds these files (#255). `tests/run_tests.gd` keeps only its own self-checks.

## Rules

- A mechanic owns its logic, data and tests: scripts in `Scripts/mechanics/<mechanic>/`, resources in `data/<mechanic>/`, tests in `tests/mechanics/<mechanic>/`.
- File size budget: a script under `Scripts/` or `flagoria_main.gd` stays within 500 lines and a test file within 1,500. `tools/verify.sh` runs `tools/file_budget.py`, and only files listed in `tools/file_budget_allow.txt`, each with a reason and a cap, may be larger.
- Shared catalogues stay where they are: `Scripts/world/tile_catalog.gd` (a data table, allowed to stay large), `Scripts/world/BiomeCatalog.gd`, `Scripts/mechanics/mobs/mob_catalog.gd`, `Scripts/world/MapGenParams.gd`.
- Autoloads stay in `Scripts/` unless a pull request moves one on purpose and updates `project.godot`.
- Moving a script: `git mv` the `.gd` and its `.gd.uid` together, so the uid stays next to the script. Scenes here load scripts by `path=` without a `uid=`, so the same pull request also updates every `res://` path to the script: scenes, `preload`/`load` calls, tests, and the path lists in `tools/play_review_paths.py`. `test_tile_catalog` scans `Scripts/` and its subfolders.
- No behaviour change in a move pull request. Keep thin wrappers with the old names until callers move.
- Each new test or verify step states its time cost in the pull request ("Time cost" line). CI reports each job's time per run (#294).
- Netcode stress scenarios are deterministic and the stress job stops at the first failed run. The rule is [Writing netcode stress scenarios](../AGENTS.md#writing-netcode-stress-scenarios). `tools/verify.sh` runs `tools/stress_scenario_lint.py`.
- Every new player-facing mechanic (a new choppable, a tower, a wall type, a city rule) adds its feature file, `.cursor/skills/verify-flagoria/features/<feature>.md`, and its index line in `features/README.md` in the same pull request. When a player can reach the feature in a running game, the same pull request also adds a drive under `.cursor/skills/verify-flagoria/drives/`. A change that is not player-facing says so on the pull request template's feature-file line (#291).
- Before each checkpoint in #253's gate, a verification maintenance pass runs over `.cursor/skills/verify-flagoria/`. The pass covers index hygiene (every feature file is in the index, and every index line points at a file that exists), one source read per feature file (its paths, names and steps still match the code), and one live drive per reachable feature. Its outcome goes in a short comment on #253: clean, changed (with the PR link), or blocked (with the reason). The pass edits only the skill directory; any product bug it finds gets its own issue.

## Where does X go

| New thing | Goes in |
|---|---|
| A new mechanic (logic) | `Scripts/mechanics/<mechanic>/` |
| Its resources (`.tres`) | `data/<mechanic>/` |
| Its tests | `tests/mechanics/<mechanic>/test_<topic>.gd` |
| Its verify recipe | `.cursor/skills/verify-flagoria/features/<feature>.md`, plus its line in `features/README.md` (#291) |
| Its live drive, when a player can reach it | `.cursor/skills/verify-flagoria/drives/<feature>.gd` (#291) |
| Map generation helper | `Scripts/world/` |
| A new tile name | `Scripts/world/tile_catalog.gd` |
| A new biome table entry | `Scripts/world/BiomeCatalog.gd` |
| A new map parameter | `Scripts/world/MapGenParams.gd` |
| A new mob type | `Scripts/mechanics/mobs/mob_catalog.gd` |
| Test helper shared by several files | `tests/helpers/test_helpers.gd` |
| Dev or CI tool | `tools/` (asset generators under `tools/audio/`, `tools/hero/`, `tools/icon/`) |
| CI workflow | `.github/workflows/` |
| Art and sound | `art/`, with credits next to the files (for example `art/audio/CREDITS.md`) |
| Feature or process notes | `docs/` |
