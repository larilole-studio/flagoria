# Demolish construction

Drive: drives/demolish_construction.gd
Source: Scripts/mechanics/building/construction_remover.gd
Source: Scripts/mechanics/building/build_placement.gd
Source: Scripts/mechanics/building/build_tool_row.gd
Source: Scripts/mechanics/building/build_preview.gd
Source: Scripts/mechanics/building/structure_requests.gd
Source: Scripts/mechanics/structures/structure_placer.gd
Source: Scripts/mechanics/interact/interaction.gd
Source: Scripts/ui/hud_tool_row.gd

Demolish (#701) removes one reachable plank or free-form wall cell, or the
whole footprint of an owned tower, castle, guard post, or barracks. The
refund is 50% of each resource's cost, rounded down independently. Starting castles and
structures held by another peer, mobs, or nobody are protected.

## Sub-features

- `demolish-picker` The round Demolish button is last in Buildings and has the
  same hit area as its siblings. The drive checks the picker and tap flow.
- `demolish-preview` Pressing shows the red footprint and resource refund or the
  refusal reason. A tap removes on release. A drag leaves the construction
  in place.
- `demolish-save` `test_construction_remove` covers ownership, protected
  castles, refunds, restored ground and the save changes for surviving cells.
- `demolish-sync` `test_tower_place_two_players` covers the host refusing a
  foreign tower, applying the builder's own removal, and syncing a late joiner.

## How to get to it (user POV)

1. Place or stand near a construction, then open Buildings.
2. Tap Demolish and press the construction. Check the red preview and refund.
3. Release without dragging. The construction disappears and the resource counters
   increase by the quoted amount when the refund is positive.

## Driving it with verify-flagoria helpers

Time cost: `test_construction_remove` about 1 s. The existing tower sync
scenario adds one bounded step and reuses its peers. Drive under 45 s.

- **Run (headless).** `godot --headless --path . --script res://tests/run_tests.gd -- --only=construction_remove,tower_place_two_players,build_picker_buttons` with scratch XDG directories.
- **Drive (live).** `bin/launch.sh drives/demolish_construction.gd --display`. The fixture adds 10 wood. The drive places a tower with the picker, then taps Demolish and the tower using real input.
- **Proof.** `demolish-picker` shows Demolish with the tower in place,
  `demolish-before` shows the red footprint and `+5 wood`, and `demolish-after`
  shows the cleared footprint and updated wood counter.
