Drive: drives/two_player/tuning_sync_client.gd
Also driven by: drives/two_player/tuning_sync_host.gd
Source: Scripts/net/tuning_sync.gd

# Multiplayer tuning (#739)

The host's tuning overrides reach a joiner before their player spawns. Later
changes update the joiner's build prices and open Tuning panel. An admin
on either peer can open **Menu → Tuning**. Client steppers send requests to
the host and display the value the host returns.

Start the paired host drive, then start the client drive once the host has
opened Tuning and stepped Castle wood to 40. The client captures Building costs
with Castle wood at 40, taps **+** on Mine wood, and captures the returned value
of 16. The host drive checks that its Mine wood cost also reached 16. The client
then captures its Castle preview at 40 wood and 15 stone and returns to the
main menu.

```sh
VERIFY_WINDOW_SIZE=2400x1080 ./.cursor/skills/verify-flagoria/bin/launch.sh drives/two_player/tuning_sync_host.gd --display
VERIFY_WINDOW_SIZE=2400x1080 ./.cursor/skills/verify-flagoria/bin/launch.sh drives/two_player/tuning_sync_client.gd --display
```

The headless two-peer scenario `test_tuning_sync` covers snapshot ordering and
replacement, a live host change, client set and reset requests, host clamping,
and refusal when the host's admin policy denies the sender.
