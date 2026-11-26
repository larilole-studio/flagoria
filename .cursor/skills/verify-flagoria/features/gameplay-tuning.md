# Gameplay tuning

Drive: not player-facing
Source: Scripts/mechanics/tuning/tuning.gd

The in-memory registry supplies gameplay defaults and runtime overrides. Plant defaults come from the interactable resources.

Headless verification uses `test_tuning_defaults_and_live_price` to check the literal defaults and confirm that the public registry changes the castle price and restores it on reset.
