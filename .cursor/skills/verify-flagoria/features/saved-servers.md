# Saved servers

Drive: drives/saved_servers.gd
Source: Scripts/shell/menu_saved_servers.gd
Source: Scripts/shell/saved_servers.gd

Open **Multiplayer** to see saved servers. Each successful connection saves the address as entered, with surrounding whitespace removed and the optional port retained. The most recent connection appears first. Rejoining the same address keeps one entry.

Tap an address to fill the field, then press **Join**. To remove a selected address, press **Delete** and confirm with **Yes**. **No** cancels.

- **Peer test.** `test_join_port_dedicated` checks saving after a real connection, seeing the saved row after returning to Multiplayer, joining through that row, and keeping a single copy. `test_join_port_button` checks that rejected, failed and blank joins leave storage unchanged.
- **Drive.** Run `VERIFY_WINDOW_SIZE=2400x1080 ./.cursor/skills/verify-flagoria/bin/launch.sh drives/saved_servers.gd --display`. Review `01-multiplayer-empty.png` for the empty list and `02-multiplayer-saved.png` for the seeded address, address field and Join. The drive also checks the blank prompt, tap-to-fill, both confirmation choices and removal after a scene reload. It prints `VERIFY_DONE ok`.
