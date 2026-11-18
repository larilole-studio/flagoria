# HUD finals: Direction C (Castle Stone, icon-first)

These are the final art and layout spec for the in-game HUD, following Direction C (picked 2026-11-15). Every new control is code-drawn on palette v1.1 with a 1px `#2a2238` outline and Castle Stone volume (bevel highlight top-left, shade bottom-right). Attack and the joystick are the already-approved Castle Stone files, copied pixel-identical.

The maintainer implements and approves the change. Nothing here has been wired into the project. This document is a spec only: it does not include engine code.

## 1. Files

Copy the production PNGs from `art/` into `art/ui/` (or wherever the maintainer prefers). Import settings: filter **Nearest** (the project default), mipmaps off, compression **Lossless**.

The `preview/` folder is for review only and does not go into the game.

### 1.1 16px icons

The 24px and 32px discs paste these 1:1 into the face. Do not scale a 32px master down at runtime.

| File | Size | Source |
|-|-|-|
| `icon_mode_interact_16.png` | 16×16 | Centre crop of the existing 32px hand icon, palettized |
| `icon_mode_attack_16.png` | 16×16 | Centre crop of the existing 32px sword icon, palettized |
| `icon_map_16.png` | 16×16 | Centre crop of the existing 32px map icon, palettized |
| `icon_build_16.png` | 16×16 | Centre crop of the existing 32px buildings icon, palettized |
| `icon_menu_16.png` | 16×16 | New: three cloud bars |
| `icon_scores_16.png` | 16×16 | Centre crop of the existing 32px scores icon, palettized |
| `icon_run_16.png` | 16×16 | **Redrawn** so the mid-stride runner reads at 16px (blue tunic, leather boots, three speed-line dashes) |
| `icon_bow_16.png` | 16×16 | **Redrawn** side-view wooden bow with a nocked arrow |
| `icon_sword_16.png` | 16×16 | Same art as `icon_mode_attack_16.png` (see judgement calls) |

### 1.2 24px utility discs and the square menu

Each disc is 24×24. The selected and selected-pressed frames (gold ring just inside the outline) are for toggle controls.

| File | Size | Control | State |
|-|-|-|-|
| `ui_disc_mode_interact_{normal,pressed,disabled,selected,selected_pressed}.png` | 24×24 | Mode (interact) | see §4 |
| `ui_disc_mode_attack_{normal,pressed,disabled,selected,selected_pressed}.png` | 24×24 | Mode (combat) | see §4 |
| `ui_disc_map_{normal,pressed,disabled}.png` | 24×24 | Map | |
| `ui_disc_build_{normal,pressed,disabled}.png` | 24×24 | Buildings | |
| `ui_disc_scores_{normal,pressed,disabled,selected,selected_pressed}.png` | 24×24 | Scores toggle, sits beside the status plate | |
| `ui_menu_{normal,pressed,disabled}.png` | 24×24 | In-game menu (square, not a disc) | |

### 1.3 32px combat discs

| File | Size | Control |
|-|-|-|
| `ui_disc_weapon_bow_{normal,pressed,disabled,selected,selected_pressed}.png` | 32×32 | Weapon swap, bow equipped or offered |
| `ui_disc_weapon_sword_{normal,pressed,disabled,selected,selected_pressed}.png` | 32×32 | Weapon swap, sword equipped or offered |
| `ui_disc_run_{normal,pressed,disabled}.png` | 32×32 | Run |

### 1.4 Attack 40px and joystick 56px / 24px (approved art, pixel-identical)

| File | Size | Notes |
|-|-|-|
| `ui_attack_idle.png` | 40×40 | Pixel-identical to the approved Castle Stone idle. Use as **normal**. |
| `ui_attack_pressed.png` | 40×40 | Pixel-identical. Finger down, still inside the dead zone. |
| `ui_attack_aim.png` | 40×40 | Pixel-identical. Finger dragged past the dead zone. |
| `ui_attack_disabled.png` | 40×40 | New: a palettized, dimmed idle for a disabled attack. |
| `ui_aim_cone.png` | 22×42 | Pixel-identical reference. The game still draws the cone in code. |
| `ui_joystick_base.png` | 56×56 | Pixel-identical. Use as **normal**. |
| `ui_joystick_base_disabled.png` | 56×56 | New: dimmed base. |
| `ui_joystick_knob.png` | 24×24 | Pixel-identical. Use as **normal** (finger up). |
| `ui_joystick_knob_active.png` | 24×24 | Pixel-identical. Use as **pressed** (finger dragging). |
| `ui_joystick_knob_disabled.png` | 24×24 | New: dimmed knob. |

### 1.5 Status plate (nine-patch)

| File | Size | Nine-patch margins |
|-|-|-|
| `ui_status_plate.png` | 32×24 | **6px** on all four sides |

Godot: a `StyleBoxTexture` (or nine-patch rect) with `patch_margin_left/right/top/bottom = 6`. The bevel and the rounded outline live in that 6px border. The centre 20×12 fill stretches. Stretch width to fit the slots; keep height at **24**.

Content slots, in art px of the **stretched** plate (origin is the plate's top-left). Inner height is 12 (24 − 6 − 6):

| Slot | Position (x, y) | Size | Notes |
|-|-|-|-|
| Heart 0, 1, 2 | `(6 + i * 10, 7)` | 9×9, pitch 10 (9px art + 1px gap) | Reuse the existing `art/ui/hearts/ui_heart_*.png` |
| Points label | `(39, vertically centred)` | font size **8**, colour `cloud`, 1px `outline` drop shadow | e.g. `"16 pts"` |
| Wood icon | after the points label + 6px | 9×9 | Reuse `art/ui/ui_wood_icon.png` (snap to palette if needed; the current file's highlight is 2 values off `wood_hi`) |
| Wood count | after the icon + 2px, vertically centred | font size **8** | e.g. `"12"` |
| Right margin | 6px after the last glyph | | |

A plate that holds 3 hearts, `"16 pts"` and a two-digit wood count is **100×24** with those slots. Wider counts only stretch the mid fill.

The scores disc is **not** drawn into the plate; it sits 4px to the right (see §3).

---

## 2. Safe margins and hit areas

All numbers are UI pixels of the **480×270** viewport (`CanvasLayer1`).

- **Safe margin: 12 art px** from every viewport edge for the art box of a control. (`DisplayServer.get_display_safe_area()` should raise this on a notched phone.)
- **Gap: 4 art px** between sibling controls.
- Hit boxes are centred on the art box. A hit may extend 4px into the 12px margin, but it must stay at least 8px inside the 480×270 viewport.

| Control | Art size | Hit size | Meets 32 art px? | At integer ×4, approx. dp on a 400 dpi 1080p phone |
|-|-|-|-|-|
| Mode, map, build, menu, scores | 24×24 | **32×32** | yes | 32 art = 128 px ≈ 51 dp |
| Weapon (bow / sword), run | 32×32 | **36×36** | yes | 36 art = 144 px ≈ 58 dp |
| Attack | 40×40 | **48×48** (`CircleShape2D` radius 24, unchanged) | yes | already above 48 dp |
| Joystick | base 56×56, knob 24×24 | start radius **28** (the whole base); knob travel 20 | yes | unchanged |

Font for the plate: the project's `NormalFont.ttf` at size **8**, not the theme's Button size 16.

---

## 3. Layout in 480×270

Anchors are top-left of the **art** box. Positions below were composed on a 480×270 frame with a 12px safe margin.

### 3.1 Top-left status

| Node | Art box (x, y, w, h) | Hit box (centred) | Anchor |
|-|-|-|-|
| Status plate | (12, 12, 100, 24) | not a button | top-left, 12px in |
| Scores disc | (116, 12, 24, 24) | (112, 8, 32, 32) | 4px to the right of the plate, vertically aligned with it |

Stretch the plate's width if the points or wood strings grow; keep the scores disc `GAP` (4px) to its right, and do not let it collide with the right-hand column.

### 3.2 Top-right menu column

Stacked top-down, right-aligned, 4px gaps.

| Node | Art box (x, y, w, h) | Hit box |
|-|-|-|
| Menu (square) | (444, 12, 24, 24) | (440, 8, 32, 32) |
| Mode | (444, 40, 24, 24) | (440, 36, 32, 32) |
| Map | (444, 68, 24, 24) | (440, 64, 32, 32) |
| Build | (444, 96, 24, 24) | (440, 92, 32, 32) |

Mode shows `ui_disc_mode_interact_selected` or `ui_disc_mode_attack_selected` according to the current mode. Map and Build use the normal disc until pressed or disabled (map can use the selected frame while the map is open, if the maintainer wants that; it is not required).

### 3.3 Right-thumb combat arc

| Node | Art box (x, y, w, h) | Centre | Hit |
|-|-|-|-|
| Attack | (428, 218, 40, 40) | (448, 238) | circle, radius 24, centred |
| Run | (392, 222, 32, 32) | (408, 238) | 36×36, centred |
| Weapon | (406, 186, 32, 32) | (422, 202) | 36×36, centred |

Attack sits 12px in from the bottom and right. Run sits 4px to the left of attack, vertically centred on it (9 o'clock). Weapon sits on the thumb arc above and left of attack (about 10–11 o'clock), 4px clear of the attack rim. The equipped weapon uses the **selected** frame (gold ring); the other weapon texture is not on screen.

There is no Bow text plate.

### 3.4 Joystick

Keep the approved centre **(77, 201)**. The 56×56 base then occupies (49, 173, 56, 56). The 24×24 knob starts centred on (77, 201), top-left (65, 189). Travel and start radius stay as in the Castle Stone touch spec (boundary 20, start radius 28).

---

## 4. State mapping

Pressed art sinks the icon 1px and inverts the bevel (no raised highlight). Disabled art uses a darker stone face and a dimmed icon. Selected art adds a 2px gold ring (`gold_hi`, or `gold` while pressed) just inside the outline.

| Control | Normal | Pressed | Disabled | Selected / on |
|-|-|-|-|-|
| Mode interact | `ui_disc_mode_interact_normal` | `_pressed` | `_disabled` | `_selected` when interact is the current mode; `_selected_pressed` while the finger is down on it |
| Mode attack | `ui_disc_mode_attack_normal` | `_pressed` | `_disabled` | same, when combat is the current mode |
| Map | `ui_disc_map_normal` | `_pressed` | `_disabled` | optional: `_pressed` or a selected frame while the map is open |
| Build | `ui_disc_build_normal` | `_pressed` | `_disabled` | same, while the build picker is open |
| Scores | `ui_disc_scores_normal` | `_pressed` | `_disabled` | `_selected` while the scoreboard is open |
| Menu | `ui_menu_normal` | `ui_menu_pressed` | `ui_menu_disabled` | the pause overlay covers the HUD; no selected texture |
| Weapon bow | `ui_disc_weapon_bow_normal` | `_pressed` | `_disabled` | `_selected` while bow is the equipped weapon |
| Weapon sword | `ui_disc_weapon_sword_normal` | `_pressed` | `_disabled` | `_selected` while sword is the equipped weapon |
| Run | `ui_disc_run_normal` | `_pressed` | `_disabled` | a held run can stay on `_pressed` |
| Attack | `ui_attack_idle` | `ui_attack_pressed` | `ui_attack_disabled` | `ui_attack_aim` while aiming (already shipped) |
| Joystick base | `ui_joystick_base` | (no change while dragging) | `ui_joystick_base_disabled` | — |
| Joystick knob | `ui_joystick_knob` | `ui_joystick_knob_active` | `ui_joystick_knob_disabled` | — |

Only one mode texture and only one weapon texture are visible at a time.

---

## 5. Engine note (spec only, no code)

These settings are for the maintainer to apply in `project.godot` and the HUD scripts. They are not applied here.

1. Keep the 480×270 viewport and `display/window/stretch/mode="canvas_items"` with `aspect="keep"`.
2. Set `display/window/stretch/scale_mode="integer"`.
3. Set `display/window/size/window_width_override=1920` and `window_height_override=1080`, so the default editor and desktop window fills at a clean **×4**. A 960×540 override is the ×2 alternative.
4. Set the default clear colour to palette `sky_deep` (`#4a8fd6`), so a camera looking past the island does not drop mid-grey behind the top-right column.
5. Keep canvas texture filter **Nearest**, mipmaps off, lossless imports. No change is required to the existing `.import` settings.
6. Do not use `StyleBoxFlat` circles or the menu theme (font size 16, 10px side margins) for these in-game HUD buttons. Point each `Button` / `TouchScreenButton` at the textures in §1.
7. If a fractional window still occurs, either apply the hearts `_fit_pixel_scale` correction to **every** HUD control, or to none of them, so hearts and discs stay on one scale.
8. `HudLayout` user scales should snap so that `round(scale * stretch)` stays an integer.

---

## 6. Previews

Review images live in `preview/` and are not game assets.

| File | Size | What it is |
|-|-|-|
| `preview/scene_480x270.png` | 480×270 | The HUD on a flat top-down island built from `flagoria_tiles_v4` (grass, sand beach, water, trees). No cliff or brown elevation band. |
| `preview/phone_x1.png` | 1920×1080 | That frame at integer ×4 — a 1080p phone with the stretch fix in §5. |
| `preview/phone_x2.png` | 960×540 | The same frame at integer ×2 of the 480×270 viewport. |
| `preview/phone_hud_x2.png` | 1440×2160 | The right-hand HUD at ×8 of art, for inspecting bevels. |
| `preview/states_x4.png` | — | Every control in its states, at ×4. |
| `preview/before_after.png` | — | The in-game 1280×720 screenshot on the left; Direction C at integer ×2, letterboxed in the same window, on the right. |

---

## 7. Judgement calls for the maintainer

1. **Scores disc.** Direction C's brief named the 24px utility set as mode, map, build and the square menu. The current game also has a scores toggle beside the points label, so a 24px scores disc is included and laid out 4px to the right of the plate. It can be dropped if scores should live inside the plate or move into the menu.
2. **Selected frames.** The brief asked for normal, pressed and disabled. Toggle controls also have `selected` and `selected_pressed` (gold ring), because Mode, the equipped weapon and an open scores panel need an "on" look. Map and Build can reuse pressed, or gain a selected frame later.
3. **Weapon sword icon.** `icon_sword_16.png` is the same 16px sword as mode-attack. They live in different corners (mode is "combat vs interact"; weapon is "bow vs sword"). If that feels too similar, swap in a distinct side-view sword; the 32px frame stays the same.
4. **Attack and joystick disabled.** The approved set had no disabled textures. The new disabled files are a palettized dim of the approved idle/base/knob. Idle, pressed, aim, base and both knobs are otherwise pixel-identical to the approved art and should be used as-is.
5. **Joystick position.** The centre stays at (77, 201) from the approved touch spec, even though the new safe margin is 12. The base already clears that margin.
6. **Plate width 100.** That width fits 3 hearts, `"16 pts"` and a two-digit wood count with 6px nine-patch margins. Stretch it for longer strings; do not scale the plate texture as a whole.
7. **Wood icon highlight.** The existing `ui_wood_icon.png` uses `(224, 176, 112)`, two steps off palette `wood_hi` `#e0a96b`. The previews snap it to the palette. A one-pixel palettize on import is enough; this kit does not replace that file.
8. **Run and bow were redrawn at 16px** so they read on the 32px discs. The older 32px `icon_run.png` should not be scaled into the new disc.
9. **No Bow text button.** Weapon swap is the 32px bow/sword disc on the thumb arc.

---

## 8. Tests

The art kit was checked outside the repo for palette v1.1, file sizes, every listed state, pixel-identity of the reused Castle Stone art, valid 6px nine-patch corners and hit areas of at least 32 art px.
