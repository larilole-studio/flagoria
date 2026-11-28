# Flagoria verification map

Maintained recipes for proving user-facing and CI-facing behavior. Read this index only to pick the matching feature file, then open that file and stay on the paths, tests, and `Drive:` it names. Do not treat this index as a reason to open every feature.

## Baseline preconditions

- Working directory is the Flagoria repo root (`project.godot` present).
- Godot is the version in `project.godot` (currently **4.7.x**, check with `$GODOT --version`). `GODOT` points at the editor binary; when it is unset, `doctor.sh`, `drive-verify.sh` and `tools/verify.sh` use `godot` on `PATH`. If doctor reports Godot missing, run `./tools/ensure_godot.sh` once, then doctor again. Never download Godot with ad-hoc shells mid-task.
- Run `./.cursor/skills/verify-flagoria/bin/doctor.sh` and require exit `0`.
- Agent tasks use `brief.template.md` and `python3 tools/agent_budget.py` (`check-brief` / `check-receipt`). PR bodies keep `Verify: once` and `Drive: …` lines.
- Prefer disposable evidence under `.cursor/skills/verify-flagoria/artifacts/`.
- Never drive a long-lived game instance that was not started for this verification run.

## Driving conventions

- Every feature file starts with a `Drive:` line right under its title: `Drive: drives/<name>.gd` when an automated drive covers it, or `Drive: not player-facing` otherwise. Primary drives call `snapshot("<screen>")` for each promised screen. Use `Also driven by:` to name supplemental scripts without changing CI selection.
- Automated proof goes through `tools/verify.sh` via `bin/drive-verify.sh`.
- Visual proof uses `xvfb-run` and `--rendering-driver opengl3` when a display is required.
- Record skips with the unmet precondition; do not report a skipped path as verified through a different path.
- Every feature file, and every new test or drive added to one, states its expected time cost (for example `~5 s in tools/verify.sh`, `~2 min stress`). Time is weighed, not capped: a costly proof is fine when it is worth it. CI's "Job times" summary per workflow run shows the actual figures against recent main runs.

## Proof and skip reporting

- Keep verify logs and screenshots in `artifacts/`; cleanup must not delete them.
- UI proof for Map Settings includes a PNG with the panel title visible.
- Two-peer flows (dedicated server, mobs, health sync, cuts, points) are scripted headless; menu Host/Join has a two-launch drive; the two-GUI play checklist is still manual. See placeholders below.
- After adding or renaming a test or feature file, run `./.cursor/skills/verify-flagoria/bin/check-map.sh` (no Godot, under 1 s). It fails when a feature is missing or duplicated here, a relative Markdown link is broken, a drive is absent from the feature pages, a cited `test_<name>` does not exist, a test is cited by no feature file, or a feature file lacks a `Drive:` line (`Drive: drives/<name>.gd` pointing at an existing drive that calls `snapshot("…")`, or `Drive: not player-facing`). CI enforces the full map check in the required `tools/verify.sh` job only. On a gameplay pull request, `check-map.sh --gameplay --changed-files <paths>` locally also fails when a changed or added feature file lacks that line. Time cost: under 1 s.

## Features

- [Headless verify](./headless-verify.md) — `tools/verify.sh` file budget, load, parse, tests, biome, audio, generator and map render golden checks.
- [Map characterization](./map-characterization.md) — pinned map-output / golden atlas check, `tools/cli.gd` map render and stats.
- [Map Settings panel](./map-settings-panel.md) — map parameters before Host, five seeds and a noise selector, numeric and toggle rows, number pad, Generate building, and five pinned actions.
- [Two-player Host/Join](./two-player-host-join.md) — multiplayer boot (headless peers scripted; two-launch menu drive; GUI checklist manual).
- [Join failure returns to the main menu](./join-fail.md) — failed Join shows `Could not join …` on Multiplayer; host quit reloads to the menu (#348).
- [Join requires a host address](./join-no-ip.md) — a blank address keeps Multiplayer open and prompts for the host's IP address.
- [Join an address with an optional port](./join-port.md) — hostname or IPv4, optional `:port`, default UDP 9786; bad addresses rejected on the menu (#434).
- [Dedicated server](./dedicated-server.md) — `-- --server` headless host, `--params` generation params only, SIGTERM quit, a client joining it, `test_two_player_smoke` (two headless clients, input walk, server and the other client see the move), optional Docker image.
- [Dedicated cut-and-hit round](./dedicated-play-round.md) — two Join clients on a dedicated host with no player `1`: one plant cut, one mob killed (#436). Not the listen Host/Join pair.
- [Match HUD](./hud-direction-c.md) — thumb control layout and floating status row.
- [Player health](./player-health.md) — hearts, HUD, regen, death, respawn hold, rejoin, health sync.
- [Combat and aiming](./combat-and-aiming.md) — swing, 30 px reach, mid-swing hitbox, mouse and touch aim, exact-angle swing, cone, cancel, wall line-of-sight; live `combat_hud` drive.
- [Bomb throw](./bomb-throw.md) — clay pot arc, fuse, and host-resolved blast; live `ranged_bow` drive.
- [Tool wheel](./tool-wheel.md) — hold the button beside Run to arm sword, bomb or chop; a short tap swaps back; Customize HUD can move that button (#574, #575).
- [Mobs](./mobs.md) — seeded placement, spawn rate, wander, chase, contact damage, sword hits, hidden on ungenerated ground, sounds, sync.
- [Mob band](./mob-band.md) — server spawn and despawn around players, caps, late joiners see the same names.
- [Night mobs](./night-mobs.md) — ambient caps double at night and ramp at dusk and dawn; extras leave at dawn only out of view (#559).
- [Mob raids](./mob-raid.md) — host sends idle mobs at the nearest player city or owned tower; raids stay off until turned on (#529).
- [Player spawn](./player-spawn.md) — spawn on reachable land, a free spot per player within 64 px, late joiners.
- [Hero in front of walls](./hero-wall-draw.md) — the hero draws over a wall until about two thirds of the body is on the wall.
- [Tileset and collision](./tileset-and-collision.md) — tile catalog, water and forest walls.
- [Sky islands](./sky-islands.md) — open sea is sky, island edges on the coast, clouds off the walkable ground.
- [Biomes](./biomes.md) — biome terrain, plants, stones, island and archipelago shaping, biomes on by default, `render_biomes` coverage gate.
- [Day and night](./day-night.md) — shared 10 minute clock, world tint, Map Settings switch, save and host sync (#558).
- [Night lights](./night-lights.md) — gold pools on players, castles, towers and guard posts, fading with the clock, capped at 16, drawn locally (#560).
- [Map save files](./map-save.md) — versioned world saves (inputs plus cuts and plank bridges), v1 migration, Save from the in-game menu, saved-maps API.
- [Object removals save](./object-removals-save.md) — picked flowers and depleted rocks in `world.object_changes` (#198).
- [Player save](./player-save.md) — save and load position, health, wood, score and charted ground (#197).
- [Stone resource](./stone-resource.md) — per-player stone balance, status counter, save/load and targeted charges.
- [Mine walkable rocks](./hand-mine-stone.md) — hit generated walkable rocks with Chop to gather stone.
- [Map zoom](./map-zoom.md) — local pinch, wheel and Ctrl +/- zoom.
- [Chopping trees and bushes](./chop-trees-and-bushes.md) — interact-mode chop, broadleaf trees, birch, pine and bushes, their hit and fall frames, per-type wood and regrow delay, stumps, regrowth (held while a player or mob stands on the stump, one mob-cell set per pass), wood HUD, type checklist.
- [Chop trees (live drive)](./chop-trees.md) — chop tool, aimed attack-button sweeps, two hits per tree, stumps and wood.
- [Cut sync (two-player)](./cut-sync.md) — host-decided tree and bush cuts, same stump on every peer, wood to the cutter, late joiners get the exact set, sent in parts of at most 500 cuts.
- [Regrowth sync messages](./regrow-sync.md) — one `apply_regrow_cells` per regrowth tick, applied only when the host (peer 1) sent it.
- [Tree sprouts](./tree-sprouts.md) — trees, including birch trunks, sprout where a biome is below its target tree share, host-decided, batched `apply_sprout_cells`, kept in saves and join lists.
- [Dead player cuts nothing](./dead-player-cut.md) — interact-mode taps and drags ignored while the hero is dead, host refuses `request_cut` from a dead peer.
- [Cut request limit](./cut-rate-limit.md) — host-side per-peer bucket on `request_cut` (162 at once, 162.5 a second), drops a flood with no reply, never limits a real drag or walk.
- [Explored map](./explored-map.md) — parchment full map from Map or M; cells revealed within 10 cells of the hero.
- [Building attack alerts](./building-alert.md) — owner alerts on the minimap and parchment (#783).
- [Build costs](./build-costs.md) — the shared price table, affordability checks, and purchase rollback.
- [Stone building costs](./stone-costs.md) — split prices for castles, guard posts and barracks, targeted multiplayer charges, and split demolish refunds.
- [Construction placement](./construction-placement.md) — shared `can_place` / `cost` / `place` for six buildable kinds (plank, tower, castle, guard post, barracks, wall block) through `BuildCosts.buy`; live path is the build picker.
- [Building block pieces](./building-block-pieces.md) — WFC modular pieces and sockets (#23); debug scene; `test_building_block_sockets` and `test_wfc_solver` (#24).
- [Generated building](./generated-building.md) — host debug key and Map Settings button place one WFC building at the player; clients and a late joiner solve the same seed (#26).
- [Building merge](./building-merge.md) — full-edge neighbours share a wall; removal re-seals; two-player and late-joiner replay (#27).
- [Build placement](./build-placement.md) — interact-mode build picker (Plank, Tower, Castle, Guard post, Barracks, Wall) closed until Buildings is open; centered footprints and relative dragging for footprints, walls and planks (#711), green/red tint and resource costs; places through ConstructionPlacer (#225 / #273 / #276 / #527 / #528 / #556); nothing hides when a peer connects.
- [Build sync](./build-sync.md) — plank bridges decided by the host and synced to every peer; late joiner gets the list (#297).
- [Build tower](./build-tower.md) — wooden palisade tower for 10 wood, land only, builder-owned flag; multiplayer asks the host (#273, #497).
- [Build castle](./build-castle.md) — extra `castle.txt` for 35 wood and 15 stone with rotation, save/reload and multiplayer sync (#527).
- [Build guard post](./build-guard-post.md) — `guard_post.txt` for 14 wood and 6 stone from the build picker, save/reload and multiplayer sync (#528).
- [Demolish construction](./demolish-construction.md)
- [Build barracks](./build-barracks.md) — `barracks.txt` for 20 wood and 10 stone from the build picker, save/reload and multiplayer sync (#556).
- [Place a mine](./place-mine.md) — a 3×3 mine costs 15 wood and needs an orthogonally adjacent live rock (#722).
- [Place a sawmill](./place-sawmill.md) — a 3×2 sawmill costs 15 stone and needs an orthogonally adjacent live tree or pine (#749).
- [Produce wood at placed sawmills](./sawmill-production.md) — each sawmill credits its owner one wood per minute (#750).
- [Sawmill animation and sound](./sawmill-animation.md) — the placed sawmill strokes its blade and plays a positional wood-cutting sound while producing (#751).
- [Produce stone at placed mines](./mine-production.md) — each mine credits its owner one stone per minute (#723).
- [Mine cart animation](./mine-cart.md) — producing mines animate the cart and idle mines show the parked pose (#725).
- [Train soldier](./train-soldier.md) — train at an owned barracks for wood and stone with a tuned timer and cap (#778); Follow and Hold for every living soldier that peer owns; save/reload and multiplayer sync (#553).
- [Command tool](./command-tool.md) — select owned soldiers with the Attack drag and send them to a map position (#779).
- [Soldier sight and pursuit](./soldier-sight.md) — soldiers pursue enemy units and buildings, then resume their orders (#780).
- [Soldier formations](./soldier-formations.md) — five-member squads and twenty-member companies (#781).
- [Soldier fight](./soldier-fight.md) — trained soldiers strike nearby mobs; owner hits miss, bomb hits from other peers land; multiplayer hp sync (#554).
- [Soldier vs peer](./soldier-vs-peer.md) — trained soldiers on Follow or Hold strike living enemy players; owner is never a target; health sync (#555).
- [Footprint rotation](./footprint-rotation.md) — rotate tower, castle, guard post and barracks footprints before placing (#493).
- [Free-form walls](./free-form-walls.md) — connected palisade chain via Wall tip, 2 wood per block (#276, #498).
- [Wall health](./wall-health.md) — sword breaks on free-form palisades, hp sync and saves (#35).
- [Castle siege](./castle-siege.md) — breach a starting castle and capture its lowered flag (#782).
- [Building health](./building-health.md) — sword and bomb damage, building destruction, and saved HP (#763).
- [Wall and tower junctions](./wall-junctions.md) — mask pieces, collar overlays on stone, tower ring with the team flag, far corner flips when a loop closes.
- [Walls and bridges](./walls-and-bridges.md) — wall solver and plank bridges, live via the build picker.
- [Bridge joins](./bridge-joins.md) — adjoining plank placements share plain interior planks; rope and tips stay on shores and open ends (#416).
- [Audio](./audio.md) — buses, music, combat, UI and mob SFX, footsteps, `audio_check` gate.
- [Main menu](./main-menu.md) — menu theme, menu navigation and letter keyboard.
- [Client settings](./settings-client.md) — audio and HUD preview in Settings, host gameplay options in Worlds.
- [Main menu navigation](./menu-worlds-root.md) — Worlds, Multiplayer, Settings and Back (#708).
- [Saved servers](./saved-servers.md) — reuse and remove addresses from successful multiplayer connections.
- [Saved worlds](./saved-worlds.md) — main-menu list of every save, load, a new world in its own file, delete with a confirm.
- [In-game menu and quit prompt](./ingame-menu.md) — menu button, Pause panel (Resume, Save, Main menu), quit confirm.
- [Admin resource grants](./admin-grant-resources.md) — +100 wood and Max resources in the in-game menu, with host authorization in multiplayer (#717).
- [Tuning panel](./tuning-panel.md) — admin tabs and live touch steppers for the tuning registry (#737).
- [Multiplayer tuning](./tuning-sync.md) — host costs on join and authorized client tuning requests (#739).
- [Interact mode](./interact-mode.md) — chop on the tool wheel; Space still swings the sword in interact mode; aimed attacks stay combat-only (#351).
- [Points](./points.md) — discovery and mob-kill points, host-owned totals, score HUD.
- [Points scoreboard](./points-scoreboard.md) — every connected player's total, highest first, from Menu → Scores (#573).
- [Touch controls](./touch-controls.md) — joystick hold, sage attack button and stick, number pad and letter keyboard (`-` key; `Del` and `-` edit a selected value).
- [Run control](./run-control.md) — hold or tap Run (or hold Shift) to walk faster; chop reach, the sword and the joystick direction stay put (#449).
- [Round HUD buttons](./hud-round-buttons.md) — Map beside Menu opens parchment, Attack mirrored from the joystick, Run and the tool wheel around Attack, Buildings beside the cluster with two picker rings over a dimmed playfield, map panel clear of the controls (#480).
- [Sage HUD discs](./hud-button-styles.md) — idle, picker, pressed and disabled views in a live match.
- [Customize HUD layout](./hud-customize.md) — Settings preview and in-game edit mode; drag and resize touch controls, including the tool wheel; per-device user settings (#492, #575).
- [Gameplay tuning](./gameplay-tuning.md) — gameplay defaults and runtime overrides (#736).
- [Structures (data format)](./structures.md) — `flagoria-structure 1` text files.
- [Structure placement](./structure-placement.md) — place `castle.txt`, `tower_wood.txt`, `guard_post.txt` or `barracks.txt` at an anchor cell; refusal reasons, kept on redraw, a placed stump does not regrow; the host places the starting castle directly, clients use `StructureRequests`, joiners receive the host list.
- [Starting castle](./start-castle.md) — each player's castle next to the spawn, player starts outside the gate; placed by the host while alone, sent to joining peers.
- [Cities](./cities.md) — closed wall loop around a flag tower makes a city; world tint and parchment walls; capture transfers; the host decides in multiplayer (#277, #498).
- [Tower capture](./tower-capture.md) — flag towers taken by a lone other side or mobs standing by the flag for 5 s; the host decides, peers receive owner and progress (#274, #497).
- [Defense towers](./defense-towers.md) — a player-owned flag tower shoots the nearest other living player in range; the host applies damage and a short tracer (#37).
- [Flags held points](./flags-held-points.md) — 1 point per owned flag tower every 5 s (`flags_held`); the host awards, peers share the totals (#275, #497). The live timer is off while land score is on.
- [Land score](./land-score.md) — score is interior city cells inside an owned flag's range; the host sets it, the scoreboard shows it, a tap draws the ring (#279).
- [Conquest sync](./conquest-sync.md) — host-owned tower placement, capture progress and flag points in multiplayer; a late joiner matches (#497).
- [Walls and cities sync](./walls-cities-sync.md) — host-owned wall chains and cities; a late joiner matches free-form walls, auto junctions and city keys (#498).
- [Castle sync](./castle-sync.md) — the host places each peer's starting castle and every peer, including a late joiner, sees the same castles and owners (#278).
- [Hero sprites](./hero-sprites.md) — layered hero sheet generator, checked by the generator smoke.
- [App icon](./app-icon.md) — icon generator and wiring, checked by the generator smoke.

## Placeholders (not verified here yet)

- **#45 automated two-player smoke** — headless movement is `test_two_player_smoke`: a dedicated server and two headless clients, one walking with an input action, the server and the other client seeing the move (see Dedicated server and Two-player Host/Join). `./tools/verify.sh` runs that test. It does not click Host or Join. The two-launch drives `drives/two_player/two_player_host.gd` and `drives/two_player/two_player_client.gd` do click those buttons and are not in CI. Still missing: two GUI humans, a cut the other client sees, and a sword hit the other client sees. The Join-port drive is a separate one-client Join click (see Join an address with an optional port).
- **#48 CLI map renders** — partly covered: `tools/render_biomes.gd` renders a wide biome map (see Biomes), and verify compares the `tools/cli.gd map render --seed 42` text map to `tests/golden/map_render_seed42.txt` (see Headless verify). Still missing: golden image (PNG) diffs.
