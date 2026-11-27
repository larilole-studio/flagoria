# Ranged bow

Drive: drives/ranged_bow.gd
Source: Scripts/ui/tool_wheel.gd
Source: Scripts/player/player.gd
Source: Scripts/player/player_combat.gd

The bow on the tool wheel arms the existing aim with key 2. Releasing an aim throws a [clay pot](./bomb-throw.md) in that direction. With the bow off, the combat tool swings the sword.

The live drive opens this input path and captures the aim, pot in flight, burning fuse, and explosion. Run it with `bin/launch.sh drives/ranged_bow.gd --display`.

The legacy bolt remains under `World/RangedShots` pending #759. The headless `test_ranged_shot` checks the segment's terrain collision, range, shooter exclusion, and host hit/cooldown rules through the bolt module. It takes about 0.5 s in `tools/verify.sh`.
