# Building attack alerts

Drive: drives/building_alert.gd
Source: Scripts/ui/building_alerts.gd
Source: Scripts/ui/map_chart.gd
Source: Scripts/ui/parchment_map.gd

When an owned building takes damage, its owner sees a short warning over
a local minimap centered on the attack. The open parchment map marks the
same cell. A repeated hit refreshes that building's marker. Each alert
expires five seconds after its last hit.

## Screens

- `barracks-alert-minimap` — an enemy soldier damages a barracks and the warning appears.
- `barracks-alert-parchment` — the same building is marked after opening Map.

## Proof

`test_building_alert_refresh` checks that ten hits leave one marker and that it
expires after the latest hit. `test_building_alert_owner_only` uses real host
and client peers to verify that only the remote owner receives the alert.
The drive uses a seeded combat fixture and the real Map button.
