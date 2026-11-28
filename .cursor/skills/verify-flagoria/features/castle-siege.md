# Castle siege

Drive: drives/castle_siege.gd
Source: Scripts/mechanics/conquest/tower_capture.gd

Starting castle flags resist capture while the castle has any HP. A breach
lowers the flag and opens the normal five-second capture window. Taking the
flag restores full castle health and raises the new owner's colours.

## Screens

- `castle-under-siege` — soldiers wear down the enemy castle.
- `castle-flag-dropped` — the empty HP bar and lowered flag remain on the map.
- `castle-captured` — the hero took the flag and the castle recovered its HP.

## Proof

The fixture sets the opposing owner and deploys soldiers. The live host
simulates their hits and the drive uses movement input to capture the flag.
`test_start_castle_requires_breach` checks the capture gate. The two-process
`test_castle_siege_two_players` checks the dropped flag, new owner and full HP
on the host and client. The existing building health save proof checks saved zero HP.
