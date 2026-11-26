# Button style comparison

Each sheet is a 2×3 grid of the same screen at 2400×1080, labelled A–F.

| Letter | Style |
| --- | --- |
| A | Current sage bevel, the default |
| B | Warm carved wood with a light top edge |
| C | Parchment tab with an ink border |
| D | Stone slab with a light chisel edge |
| E | Gold pixel face with an ink bevel |
| F | Deep leaf cloth with a gold hem |

[Main menu](main-menu.png) · [Worlds](worlds.png) · [Multiplayer](multiplayer.png) ·
[Settings](settings.png) · [In-match Menu](ingame-menu.png) ·
[Tuning](tuning.png) · [Parchment toolbar](parchment.png)

After importing the project in Godot, run `python3 tools/render_button_styles.py`
with Pillow and xvfb available. Multiplayer and Settings use two crop strips
to show their top content and bottom actions together.
