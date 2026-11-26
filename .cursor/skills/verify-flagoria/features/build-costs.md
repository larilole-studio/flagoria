# Build costs

Drive: not player-facing

`BuildCosts` defines construction prices, checks affordability, and charges
before calling the placement writer. A writer refusal restores the full price.

| Kind | Wood per unit | Stone per unit |
|---|---:|---:|
| `plank` | 1 | 0 |
| `wall_block` | 2 | 0 |
| `tower` | 10 | 0 |
| `castle` | 35 | 15 |
| `guard_post` | 14 | 6 |
| `barracks` | 20 | 10 |
| `mine` | 15 | 0 |
| `start_castle` | 0 | 0 |

Demolish returns half of each resource, rounded down independently. See
[Stone building costs](./stone-costs.md) for the player-facing drive and
two-peer coverage. The starting castle is free and the host places it directly.

## Sub-features

- `build-cost-table` the costs and refunds above, and -1 cost for an unknown kind.
- `inventory-spend` `spend` takes the amount and emits `changed` when there is enough; too little or a negative amount takes nothing and emits nothing. The wood HUD shows the new count.
- `build-buy` insufficient resources leave the site and balances intact; sufficient resources pay for the placement; a writer refusal spends nothing; the starting castle needs no resources; multiplayer on refuses before the writer runs.

## How to get to it (user POV)

- Interact mode → Plank places through `ConstructionPlacer` → `BuildCosts.buy` (#225 / `build-placement.md`). The starting castle is still placed without going through `buy`.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. Time cost: `test_build_cost_table` and `test_inventory_spend` under 0.05 s each in `tools/verify.sh`; `test_build_costs_buy` about 0.2 s (~1.9 s alone with `--only=`, against ~1.7 s for runner start-up). The spend check added to `test_resource_hud_in_scene` adds no measurable time.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=build_cost_table,inventory_spend,build_costs_buy,resource_hud_in_scene`, or the full `tools/verify.sh`.
- **Proof.** Headers `-- test_build_cost_table`, `-- test_inventory_spend`, `-- test_build_costs_buy` and `-- test_resource_hud_in_scene` in `artifacts/verify.log` with no `FAIL` after them. Live spend is driven through the build picker; see [Build placement](./build-placement.md).

## Gotchas

- Never add wood from a drive to make a purchase pass in a live game; a drive that can't reach the feature reports that.
- `buy` must be the only place that spends resources for a local build, so the check, the spend and the placement stay in one order (spend before write).
