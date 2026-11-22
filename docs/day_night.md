# Day and night

A shared 10-minute clock tints the world with a `CanvasModulate`, then
fades cheap `PointLight2D` pools in at dusk and out at dawn. A 16 px
clock icon on the Direction C status plate follows the same clock.
Night-specific art is limited to two emissive overlays: the respawn-camp
torch and the watchtower window. Everything else is the existing atlas
under the tint.

This document is the production art spec. It does not change engine code.
Machine-readable values live in `docs/day_night.json`.

## Clock

The host owns the clock. Clients and late joiners follow it. The cycle
is on by default; Map Settings can turn it off. With the cycle off, the
world stays in daytime and the clock icon is hidden. Old saves load in
daytime with the cycle on.

Total length: 600 seconds (10 minutes).

| Segment | Seconds | Tint | Kind |
| --- | ---: | --- | --- |
| day hold | 360 | day → day | hold |
| day to dusk | 15 | day → dusk | ease |
| dusk hold | 30 | dusk → dusk | hold |
| dusk to night | 15 | dusk → night | ease |
| night hold | 120 | night → night | hold |
| night to dawn | 15 | night → dawn | ease |
| dawn hold | 30 | dawn → dawn | hold |
| dawn to day | 15 | dawn → day | ease |

Day is a 6-minute hold, night a 2-minute hold, dusk and dawn one minute
each. Each of those one-minute windows is split 15 + 30 + 15: a short
`smoothstep` ease, a 30-second hold on the dusk or dawn key so that icon
has time on the plate, then an ease into the next key. If a single
continuous lerp is preferred, keep the 60-second windows and switch the
icon at the window boundary; the four icons then spend less time at rest.

Interpolate in sRGB with Godot's `Color.lerp`, using
`smoothstep(t) = t * t * (3 - 2 * t)` as the ease factor. Linear-space
lerp is slightly nicer on paper and is not required.

Light energy uses the same factor as the blend from day (energy 0) to
night (full energy): 0 through the day hold, ramps up across dusk, 1
through the night hold, ramps down across dawn.

## Tints

`CanvasModulate.color` is an RGB multiplier on every world canvas pixel.

| Phase | Hex | RGB multipliers | Min channel | Luminance multiplier |
| --- | --- | --- | ---: | ---: |
| Day | `#ffffff` | (1.000, 1.000, 1.000) | 1.000 | 1.000 |
| Dusk | `#eba684` | (0.922, 0.651, 0.518) | 0.518 | 0.699 |
| Night | `#808cc8` | (0.502, 0.549, 0.784) | 0.502 | 0.556 |
| Dawn | `#e8b4c8` | (0.910, 0.706, 0.784) | 0.706 | 0.755 |

Day is identity, so existing art is unchanged. Night is blue-violet and
keeps every channel at or above 0.502 so the hero, team blue, team red
and the water stay distinguishable on a phone. The luminance multiplier
column is the Rec. 709 weights applied to the multipliers themselves;
night sits at 0.556. Dusk is a warm peach. Dawn is a cool rose. Do not
lower the night multipliers further without a new contrast pass.

### HUD is not tinted

Put the `CanvasModulate` on the world canvas only (the default canvas,
or a `CanvasLayer` that holds the tilemaps, actors and props). The HUD
already lives on a `CanvasLayer`; leave that layer without a
`CanvasModulate` so hearts, scores, wood, the clock icon and the
Direction C controls stay at full brightness.

## Contrast

Contrast ratios below use the WCAG 2 relative-luminance formula
`(L1 + 0.05) / (L2 + 0.05)` on palette or atlas colours after the tint
multiply. They describe readability, not a legal UI requirement.

| Pair | Day | Dusk | Night | Dawn |
| --- | ---: | ---: | ---: | ---: |
| hero skin vs grass | 1.60 | 1.82 | 1.44 | 1.75 |
| outline vs grass | 6.64 | 3.67 | 2.78 | 4.05 |
| team blue vs grass | 2.03 | 1.91 | 1.37 | 1.76 |
| team red vs grass | 1.75 | 1.09 | 1.56 | 1.23 |
| team blue vs team red | 1.16 | 1.76 | 1.14 | 1.43 |
| team blue vs team blue dark | 1.93 | 1.51 | 1.50 | 1.64 |
| water sparkle vs water body | 2.63 | 2.52 | 1.96 | 2.44 |
| water mid vs water body | 1.84 | 1.71 | 1.51 | 1.71 |
| gold flame vs wood dark | 4.38 | 3.35 | 2.48 | 3.45 |
| gold_hi flame vs wood | 3.26 | 2.58 | 2.40 | 2.70 |
| gold window vs wood dark | 4.38 | 3.35 | 2.48 | 3.45 |
| gold vs grass (flag finial / trim) | 1.25 | 1.51 | 1.14 | 1.42 |

At dusk, team red versus grass drops to about 1.09:1 in luminance
(the warm tint pulls both toward a mid terracotta/olive). The hue
split still holds; check the dusk pane rather than the number alone.

Team blue versus team red stays clearly split by hue even when the
luminance contrast between them is modest (they are both mid-bright).
Under the night tint, blue is pushed slightly bluer and red becomes a
deeper rose, which still reads as the two sides on a phone.

Water sparkle versus water body holds at 1.96:1 at night (2.63:1 by
day), so the existing WATER tile does not need a night variant. Flame
and the watchtower window lose their gold and go muddy khaki under the
tint; those two cases are handled as overlays, not as a second tileset.
See Night variants.

## Lights

One shared radial texture on every `PointLight2D`. The production
texture is `art/day_night/light_radial_smooth_128.png`: 128×128, white,
with quadratic falloff `(1 - d)^2` in the alpha channel. `color` and
`energy` do the rest. A `PointLight2D` texture is a light mask, not a
world sprite; Godot samples it with a soft filter.

Light colour: palette `gold` `#f2b632`. It reads as a warm lantern or
ember. One colour for every source; per-owner colours are out of scope.

A 128 px texture at `texture_scale` 1.0 covers 128 art px (radius 64).

| Source | Radius (art px) | `texture_scale` | Energy at night |
| --- | ---: | ---: | ---: |
| player | 64 | 1.00 | 1.10 |
| castle | 96 | 1.50 | 1.20 |
| tower | 56 | 0.875 | 0.90 |
| guard post | 48 | 0.75 | 0.75 |

Energy is 0 during the day hold, follows the dusk/dawn ease, and uses
the table values during the night hold. Shadows, placeable torches and
per-owner colours are out of scope.

Mobile: cap active lights at 16. Keep the local player and the nearest
castles, towers and guard posts; drop the rest by distance to the
camera. That cap is a budget, not an art constraint.

Preview lighting in this pack uses

```
out = albedo * (canvas_modulate + sum(light_color * energy * att))
out = clip(out, 0, 1)
```

The HUD is composited after that, at full brightness. Confirm the look
in-engine; if a light sits under the `CanvasModulate` and comes out
dimmer than the preview, raise energy slightly rather than changing
the tint.

## Clock icons

Four 16×16 icons, palette v1.1, 1 px outline `#2a2238`, no anti-alias.
The 16×16 masters are the plate-slot art; there is no second size.

| File | Phase | Motif |
| --- | --- | --- |
| `art/day_night/icon_sun_16.png` | Day | 8-ray gold sun, `gold_hi` highlight |
| `art/day_night/icon_dusk_16.png` | Dusk | Half-sun on a horizon, orange and gold |
| `art/day_night/icon_moon_16.png` | Night | Cool cloud crescent |
| `art/day_night/icon_dawn_16.png` | Dawn | Half-sun on a horizon, gold with a skin-pink band, slightly higher than dusk |

The Direction C status plate is 24 px tall with 6 px nine-patch
margins, so the inner well is only 12 px and a 16 px icon will not sit
inside the well. Centre the icon on the 24 px height (4 px from the top
and bottom, 2 px into the bevel) and widen the stretched plate by
20 px (a 4 px gap after the wood count, plus the 16 px slot). The
stretched plate is 120×24. The icon slot is at local pixel (98, 4)
on that plate (16×16). Hide the icon when the cycle is off; do not
leave an empty slot. No numeric countdown and no dusk sound cue.

## Night variants

The official atlas is `art/flagoria/flagoria_tiles_v4.png`. Existing
tiles and sprites are tinted, not swapped, except for the two overlays
below. There is no second tileset.

A `CanvasModulate` cannot keep a gold flame looking like fire. Under
the night multiplier (0.502, 0.549, 0.784), even a white pixel becomes
`rgb(128, 140, 200)`, and palette gold `#f2b632` becomes
`rgb(121, 100, 39)` (muddy khaki). Palette `gold_hi` becomes
`rgb(128, 126, 100)`. There is no 8-bit source colour that restores
gold after this multiply, so a night-swap tile cannot fix it. The
overlays have to be drawn without the canvas tint.

In Godot, `light_mode = LIGHT_MODE_UNSHADED` ignores `PointLight2D` but
does **not** ignore `CanvasModulate`. Cancel the tint on the overlay
item by setting `self_modulate` to the reciprocal of the current canvas
modulate each frame (`Color(1/r, 1/g, 1/b, 1)`), or use a canvas-item
shader that multiplies `COLOR.rgb` by the same reciprocal. Keep the
overlays Y-sorted with the prop they belong to.

| Overlay | Size | Targets | Why |
| --- | --- | --- | --- |
| `art/day_night/overlay_torch.png` | 16×16 | `RESPAWN_CAMP_1_1_BLUE` (22, 4) and `RESPAWN_CAMP_1_1_RED` (15, 4) | Camp torch. Gold / `gold_hi` flame goes khaki under the night tint (gold vs wood-dark contrast falls; the hue is no longer fire). The overlay is the flame only; the bowl and tent stay tinted. |
| `art/day_night/overlay_watchtower_window.png` | 16×16 | `WATCHTOWER_TOP_BLUE` (16, 4) and `WATCHTOWER_TOP_RED` (17, 4) | The 2×2 gold lantern window at local pixels (7–8, 7–8) has the same problem. The overlay is those four window pixels only, punched to gold_hi / gold. |

Not given a variant, with a measured reason:

- **Castle, barracks, walls, gates.** No lit window exists in the current
  atlas. Dark doorways stay dark and do not need to start glowing.
- **Flags** (`PROP_FLAG_BLUE` / `RED` / `GREY`). They are dyed cloth, not
  lamps. Team blue vs team red and each flag vs grass stay readable
  under the night tint; see the contrast table.
- **Water sparkle** on `WATER` (5, 6). Sparkle vs body holds at 1.96:1 at
  night. Leave the tile alone.
- **Gold tent stripe, flag finials, trading-post merchandise, autumn
  trees, sand, thatch.** Decorative gold or warm fill, not light
  sources. Tinting them is correct.
- **Watchtower door slits** on `WATCHTOWER_BASE`. Already dark openings.

## File list

| File | Size | Notes |
| --- | --- | --- |
| `art/day_night/light_radial_smooth_128.png` | 128×128 | PointLight2D texture, white + alpha |
| `art/day_night/icon_sun_16.png` | 16×16 | Day; also the plate-slot art |
| `art/day_night/icon_dusk_16.png` | 16×16 | Dusk; also the plate-slot art |
| `art/day_night/icon_moon_16.png` | 16×16 | Night; also the plate-slot art |
| `art/day_night/icon_dawn_16.png` | 16×16 | Dawn; also the plate-slot art |
| `art/day_night/overlay_torch.png` | 16×16 | Emissive flame, on palette |
| `art/day_night/overlay_watchtower_window.png` | 16×16 | Emissive window, on palette |
| `docs/day_night.md` | — | This spec |
| `docs/day_night.json` | — | Machine-readable tints, lights, overlays, plate |
| `preview/four_up_x2.png` | 1920×1152 | Day, dusk, night, dawn at ×2 on the phone layout |
| `preview/night_lights_x2.png` | 960×540 | Night with lights and overlays, ×2 |
| `preview/icons_plate_x4.png` | 1980×260 | Clock icons and plates at ×4 |
| `preview/contrast_table.png` | 1220×384 | Measured contrast ratios |
| `preview/tint_swatches.png` | 256×76 | Phase colour chips |
| `preview/light_smooth_x2.png` | 272×272 | Smooth light texture on a dark field, ×2 |
| `preview/phone_day_x1.png` | 480×270 | Day, phone layout |
| `preview/phone_dusk_x1.png` | 480×270 | Dusk, phone layout |
| `preview/phone_night_x1.png` | 480×270 | Night, phone layout |
| `preview/phone_dawn_x1.png` | 480×270 | Dawn, phone layout |
| `preview/phone_night_lights_x1.png` | 480×270 | Night with lights, phone layout |

Production art is palette v1.1 with outline `#2a2238` where it is a
sprite or overlay. The light texture is white with alpha and is not
palette-bound. The tints are multipliers, not palette colours.

## Out of scope

- Placeable torches, per-owner light colour, and shadows.
- A numeric countdown or dusk sound cue on the plate.
- New mob art or night spawn rates.
- A full second tileset.
