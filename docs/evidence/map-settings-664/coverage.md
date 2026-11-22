# Biome coverage and Map Settings evidence

Coverage is sampled by `tools/render_biomes.gd` at a biome frequency of 0.003 over a 4096×4096 tile area with an 8-tile stride. The renderer uses biome seed N + 7.

| Seed | Oceanic | Temperate | Continental | Dense archipelago |
| --- | ---: | ---: | ---: | ---: |
| [11](biomes_seed_11.png) | 23.07% | 26.70% | 27.31% | 22.92% |
| [42](biomes_seed_42.png) | 23.17% | 26.51% | 26.80% | 23.52% |
| [99](biomes_seed_99.png) | 21.74% | 28.12% | 28.26% | 21.87% |

The 2400×1080 screenshots show the [common view](map-settings-common.png), the [Advanced view](map-settings-advanced.png), and [seed 42 at the host spawn](spawn.png) with choppable bushes just outside the castle gate.

The host-start test checks Small, Medium, and Big, all four named spawn biomes, and nearby reachable wood on seeds 11, 42, and 99. A separate case disables naturally generated wood and verifies the fallback grove regenerates from serialized inputs.
