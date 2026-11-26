# Join requires a host address

Drive: drives/join_no_ip.gd
Source: Scripts/shell/menu_join_flow.gd
Source: Scripts/net/join_address.gd

Assertion owner for blank-address UI and offline state is `drives/join_no_ip.gd`. The existing `test_join_port_button` checks that blank and whitespace-only retries emit no join request and that an explicit `localhost` retry requests port `9786`. A blank or whitespace-only Join leaves [saved servers](./saved-servers.md) untouched.

## How to get to it (user POV)

- Launch, open Multiplayer and press Join with the address field blank. Multiplayer stays visible, the HUD stays hidden, and the status under the address field reads `Enter the host's IP address`.
- To join a host running on the same machine, enter `localhost` before pressing Join.

## Driving it with verify-flagoria helpers

Preconditions: `doctor.sh` exits `0`. No server is needed.

- **Drive (live).** Run `bin/launch.sh drives/join_no_ip.gd --display`. The drive opens Multiplayer, captures `before-join`, clicks Join with a blank field, waits 1.5 s, and captures `join-no-ip`.
- **Proof.** The second screenshot shows Multiplayer and the status under the blank field. The drive checks the exact prompt, hidden HUD, offline peer, and unset join host and port, then prints `VERIFY_DONE ok`.
