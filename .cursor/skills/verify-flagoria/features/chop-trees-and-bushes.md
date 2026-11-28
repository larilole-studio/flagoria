# Chopping trees and bushes

Drive: drives/chop_tree_variants.gd

Source: Scripts/mechanics/interactables/chop_sprites.gd
Source: Scripts/mechanics/interactables/interactable_catalog.gd
Source: Scripts/mechanics/interactables/interactable_type.gd

The map node delegates `player_on_cell` and `mob_cells` to `Scripts/world/world_cell_queries.gd`.

In interact mode the hero chops trees and bushes for wood. Each choppable kind is a data file (`data/interactables/tree.tres`, `pine.tres`, `bush.tres`, script `Scripts/mechanics/interactables/interactable_type.gd`) that sets its sprite variants, hits, `yields` (wood), what it leaves (STUMP, BUSH_STUMP), `regrow_delay`, `save_key`, sounds and effect frames. The pine (`TREE_PINE_SMALL`, generated as `PINE`) is its own type with the tree's values (#266). `InteractableCatalog` (a preload list) maps a foliage tile to its type. A birch trunk uses the standard tree type for gameplay. Each tree variant supplies its own idle tiles, hit row and fall sheet. Birch uses both its trunk and canopy tiles in the hit animation, and chopping it clears the canopy one cell north.

## Sub-features

- `chop-tap` a short press on the attack button chops in the facing direction at full reach: two hits (140 ms and 460 ms), it falls at 560 ms (`ChopAction.step_chop`, `fell_at` in `Scripts/mechanics/trees/chop_action.gd`, driven by `Interaction`). A drag of more than 6 viewport pixels from the button centre aims the cone (`Interaction._release_drag`).
- `chop-range` that drag aims a cone (`CHOP_REACH` 240 px, 135°). Reach is the drag's world length, clamped to `CHOP_REACH`. Every choppable in that cone is queued and each plays a full chop, nearest first (`ChopAction.enqueue`). The map itself does not start a chop, and the range circle is not drawn.
- `chop-yield` a fallen plant gives its type's `yields` (tree and pine 3 wood, bush 1, tunable in the `.tres`).
- `bush-effects` a bush hit draws `art/flagoria/fx/bush_hit.png` in place of the bush tile (the tile switches to its invisible alternative 1 with the same collision) and `fx_leaves.png` frames 0-1; the fall plays frames 2-3, the bush break sound, and no puff.
- `hit-sheet-reference` `InteractableCatalog.sprites_at` resolves the sprite set by the chop target's atlas. Unknown tiles have no sprite set. The three generated hit sheets match the SHA-256 hashes and dimensions in `tests/golden/hit_sheets.txt`.
- `tree-effects` a hit hides the idle tiles while keeping collision and plays two sway frames at 50 ms each. The canopy shifts 2 px right on impact. In the return frame the top shifts 2 px left of idle and the lower canopy returns to idle. The trunk stays put. `TREE` and `TREE_BUSHY` use rows 0 and 1 of `tree_hit.png`. Birch uses two 16×32 frames from `birch_hit.png`, and pine uses `pine_hit.png`. Each variant has its own FX sheet. Frames 0–1 show chips and foliage during a hit, and frames 2–3 show falling foliage over the stump. `tools/art/gen_tree_chop_frames.py` draws the frames from the atlas tiles and palette.
- `chop-sounds` each type's sound slots (`hit_sounds`, `hit_layer_sounds`, `last_hit_sounds`, `fell_sounds`, `pickup_sounds`, `hit_no_repeat`); the tree fills all of them, the bush only `hit_sounds` and `fell_sounds` (`docs/audio.md`, Chop sounds).
- `chop-death` the hero dying before the fall cancels the chop with no stump and no wood (`ChopAction.step_chop`). A dead hero's taps and drags cut nothing ([Dead player cuts nothing](./dead-player-cut.md)).
- `stump-kept` the stump stays when the chunk is drawn again and is open ground for mobs. Repainting or predicting the canopy cell above a cut birch keeps the canopy gone (`TileMap.cut_choppable`, kept in `TreeCuts._cut_cells` in `Scripts/mechanics/trees/tree_cuts.gd`).
- `wood-hud` the wood counter (`ResourceHud`) sits in the top-left status row, starts at 0 and follows the inventory.
- `type-checklist` every `.tres` in `data/interactables/` is in `InteractableCatalog.TYPES` and passes each machine-checkable step of the `docs/interactables.md` checklist (#269, #326); a broken copy fails naming the type and step.
- `regrow` after its type's `regrow_delay` seconds of play (300 for every type; 0 = never) the stump turns back into the same tree or bush (`TileMap.regrow_due`, forwards to `TreeCuts`). Setting `TileMap.regrow_delay` (default -1) overrides it for every type; tests set 30. A due stump waits while a player's body box or a mob's feet box (`Mob.add_feet_cells`, the cells `Mob.can_stand_at` checks) covers it, and regrows on a later check once the cell is free (`TileMap.player_on_cell`, `TileMap.mob_cells`, #232), so a regrown tree never traps a mob. The cells under mobs are gathered into one set per `regrow_due` pass, on its first due stump, and each stump is looked up in it (#354), so a pass costs stumps + mobs rather than stumps × mobs. Only the host (or a single-player game) runs this check.

## How to get to it (user POV)

- Start or join a game, select chop on the tool wheel, then tap or drag Attack to sweep trees and bushes in reach. The wood count on the HUD goes up when it falls.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `-- test_catalog_resolves_cells` and `-- test_regrow_delay_per_type` (#266) each add under 0.1 s to `tools/verify.sh` (~1.3–1.4 s alone with `--only=`, mostly engine start). `-- test_tree_regrows_under_mob` (#232) adds about 0.1 s (~1.5 s alone with `--only=`, mostly engine start). `-- test_chop_tree_frames` (#333) adds about 0.1 s (~1.5 s alone with `--only=`, mostly engine start). `-- test_chop_sprites_unknown_atlas` and `-- test_hit_sheets_match_golden` each add under 0.1 s (~1.4–1.5 s alone with `--only=`, mostly engine start).

- **Run.** Run `./.cursor/skills/verify-flagoria/bin/drive-verify.sh` (or `./tools/verify.sh`) and read `artifacts/verify.log`. One test: `godot --headless --path . --script res://tests/run_tests.gd -- --only=chop_bush` with scratch `XDG_*` dirs.
- **Proof.** Headers `-- test_interact_cut_trees`, `-- test_chop_tree_two_hits`, `-- test_chop_birch_clears_both_cells`, `-- test_chop_sheet_on_single_cut`, `-- test_chop_bush`, `-- test_chop_tree_frames`, `-- test_tree_variant_sprites`, `-- test_chop_sprites_unknown_atlas`, `-- test_hit_sheets_match_golden`, `-- test_chop_tree_sounds`, `-- test_chop_cancel_on_death`, `-- test_cut_bush_stays_stump_and_regrows`, `-- test_cut_tree_stays_stump`, `-- test_tree_regrows`, `-- test_tree_regrows_under_mob`, `-- test_catalog_resolves_cells`, `-- test_regrow_delay_per_type`, `-- test_resource_hud_in_scene`, `-- test_checklist_types_on_main`, `-- test_checklist_fixtures_fail` appear with no `FAIL` line after them, and the run ends with `All tests passed.` `-- test_chop_sheet_on_single_cut` adds about 0.3 s.
- **End state.** The chopped cell has no foliage tile, a STUMP or BUSH_STUMP on `GROUND_DECOR_LAYER`, the wood count rose by the type's yield, and the hero can walk through the cell.
- **Visual.** Launch `bin/launch.sh drives/chop_tree_variants.gd --display` from the skill directory. The fixture paints both trees and chops them with touch input. Review `regular-hit` and `birch-hit` for the variant sway frames, then `regular-fall` and `birch-fall` for the distinct foliage effects over the stumps. The birch's canopy is gone in `birch-fall`.

## Gotchas

- Cuts are saved in world saves (`world.object_changes`, `tests/saves/test_cut_save.gd`) and synced in two-player play: the host decides each cut and every peer shows the stump ([Cut sync](./cut-sync.md)). Regrowth is the host's too (#298): a client's `regrow_due` does nothing while connected, and the host sends each tick's regrowths to every peer in one message (#353).
- `has_tree` is true for the tree and pine types; use `choppable(cell)` for any choppable.
- A saved cut names its type by `save_key` and stores its age in seconds of play, so nothing regrows while the game is closed.
- Every idle tile in a variant needs the invisible alternative `ChopAction.HIDDEN_ALT` with matching collision. Each hit frame is as tall as the variant’s stacked idle tiles.
- Headless, played sounds never finish, so a run that chops a tree or bush ends with its streams listed as "still in use at exit"; that is not a failure.
