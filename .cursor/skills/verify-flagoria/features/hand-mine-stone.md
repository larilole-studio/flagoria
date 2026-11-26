# Mine walkable rocks

Drive: drives/hand_mine_stone.gd
Source: Scripts/mechanics/interact/interaction.gd
Source: Scripts/mechanics/trees/chop_action.gd
Source: Scripts/player/player_combat.gd
Source: Scripts/world/object_removals.gd
Source: Scripts/world/TileMap.gd

Arm Chop with the tool wheel or press **3**. Tap the attack button while facing
a walkable rock, or drag the button to aim. Each impact throws up dust. Two
hits deplete the rock and give two stone to the player who lands the last hit.
A sword swing leaves the rock intact.

The host counts hits while the world is running and sends accepted impacts and
depletion to both peers. Depleted rocks stay gone across chunk redraws, joins,
and save reloads using the existing `world.object_changes` entry
`{"removed": true}`. A partially mined rock starts fresh after a reload.

- **Player-path drive.** Approach a generated rock on seed 4 and aim a sword
  swing at it. Arm Chop and aim at the same rock. `rock-hit` shows the first
  impact with the rock present and zero stone. `rock-depleted` shows empty
  ground and two stone in the HUD.
- **Two-peer test.** `test_hand_mine_sync` covers host and joiner awards, contested
  depletion, and out-of-reach requests.
- **Save test.** `test_object_removals_round_trip` checks new depletion and an
  existing stone removal through chunk redraw and save/load.
