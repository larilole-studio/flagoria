Drive: drives/admin_grant_resources.gd
Source: Scripts/mechanics/building/admin_resource_grants.gd

# Admin resource grants (#717)

During a match, open Menu and tap **+100 wood** to add 100 wood or **Max resources** to
bring wood up to 999. The existing HUD updates as soon as the grant arrives. All
players currently pass the shared admin check. In multiplayer the host checks the
requesting peer and returns a grant only to that peer.

- Scene test `test_admin_resource_menu` exercises both buttons, the resource HUD and the local admin gate.
- Two-peer test `test_admin_resource_host` checks request timing and host refusal.
- The seed 11 drive captures the starting wood count, grant buttons, updated wood
  count and a placed tower with the remaining wood visible.
