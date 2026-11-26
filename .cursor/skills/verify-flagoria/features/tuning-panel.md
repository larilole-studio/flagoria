Drive: drives/tuning_panel.gd
Source: Scripts/shell/MainMenu.gd
Source: Scripts/shell/ingame_menu.gd
Source: Scripts/ui/tuning_panel.gd
Source: Scripts/mechanics/tuning/tuning.gd
Source: Scripts/saves/world_save.gd
Source: Scripts/world/map_gen.gd

# Tuning panel (#737)

In a match, open **Menu → Tuning** beside the resource grants. The button is
available to local admins in a solo match or on the host. A joining client still
has the resource grants. Close or Android back returns to Menu.

The panel opens on **Building costs**. The tabs also show Mine, Hand mining,
Chopping, Soldiers, Movement and Visuals. Drag the rows to scroll, and tap
**−** or **+** to step a value within its registry bounds. Changes apply in
the current game immediately.

Changed rows show a **Reset to** button with that row's default value.
**Reset all** asks for confirmation and restores defaults across every tab.
Save keeps the world's overrides. New worlds and saves without overrides use
the registry defaults.

The player-path drive checks the category rows, button heights, touch drag,
the minimum clamp, and the live castle price. For #738 it saves and reloads a
world through the menus, checks the Mine preview at 20 wood, and shows the
changed row, the Reset all confirmation, and the panel after clearing overrides.
It checks that cancel preserves the changes and that confirming also resets a
value on another tab.

The save test `_test_tuning_save_round_trip` checks the sparse save document
and missing and invalid overrides. `_test_tuning_save_legacy` checks older
world saves.
