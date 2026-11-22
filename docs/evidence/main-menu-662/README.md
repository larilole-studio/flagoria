# Main menu landscape check (#662)

Captured with Godot 4.7.2 under xvfb and OpenGL 3 at 2400 × 1080. The visible canvas was 600 × 270 logical pixels.

## Before

The flat list clipped the title and three raid sliders. The default join status was hidden.

| Control | Global position | Size | Visible | Fully inside viewport |
| --- | --- | --- | --- | --- |
| `Label` | (198.0, -29.0) | (204.0, 44.0) | true | false |
| `MapSettingsButton` | (198.0, 17.0) | (204.0, 28.0) | true | true |
| `HostButton` | (198.0, 47.0) | (204.0, 28.0) | true | true |
| `WorldsButton` | (198.0, 77.0) | (204.0, 28.0) | true | true |
| `JoinButton` | (198.0, 107.0) | (204.0, 28.0) | true | true |
| `AddressEntry` | (198.0, 137.0) | (204.0, 19.0) | true | true |
| `JoinStatus` | (198.0, -29.0) | (1.0, 11.0) | false | false |
| `MusicVolumeRow` | (198.0, 158.0) | (204.0, 11.0) | true | true |
| `SFXVolumeRow` | (198.0, 171.0) | (204.0, 11.0) | true | true |
| `MobRateRow` | (198.0, 184.0) | (204.0, 11.0) | true | true |
| `TowerRangeRow` | (198.0, 197.0) | (204.0, 11.0) | true | true |
| `TowerDamageRow` | (198.0, 210.0) | (204.0, 11.0) | true | true |
| `TowerCooldownRow` | (198.0, 223.0) | (204.0, 11.0) | true | true |
| `RaidsRow` | (198.0, 236.0) | (204.0, 24.0) | true | true |
| `RaidIntervalRow` | (198.0, 262.0) | (204.0, 11.0) | true | false |
| `RaidGroupRow` | (198.0, 275.0) | (204.0, 11.0) | true | false |
| `RaidRadiusRow` | (198.0, 288.0) | (204.0, 11.0) | true | false |

See [before.png](before.png). The regression test reported four out-of-bounds controls on the original layout.

## After

- [Top level](top-level.png) shows all play actions, the join address, Map Settings, and Settings.
- [Settings](settings.png) shows all audio and gameplay rows and the Back button. The settings list can scroll when space is constrained.
- [Back to top level](back-to-top-level.png) shows the main menu after clicking Back.
