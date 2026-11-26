#!/usr/bin/env python3
"""Render the Candy Glass HUD sprites with CairoSVG and Pillow."""

import io
import math
from pathlib import Path

import cairosvg
from PIL import Image, ImageEnhance

# Texture pixels per HUD unit. Keep in sync with RoundHudStyle.DENSITY.
DENSITY = 4
OUT = Path(__file__).resolve().parents[2] / "art" / "ui" / "hud_e4"

E4 = dict(out='#3B1748', depth=0.09, ow=0.06,
   faces=dict(attack=('#FFB3D1', '#FF5C9A', '#E0357A', '#8E1A4E'),
              run=('#B8FFE4', '#4ADBB0', '#25B38D', '#1B6E5A'),
              wheel=('#FFE9A8', '#FFC24D', '#E89A1F', '#94580E'),
              build=('#D9C8FF', '#9A7BFF', '#7556E0', '#3E2A8C'),
              map=('#BFE6FF', '#6AB8FF', '#3D8DEB', '#1F4F96'),
              menu=('#D9C8FF', '#9A7BFF', '#7556E0', '#3E2A8C'),
              pick=('#D9C8FF', '#9A7BFF', '#7556E0', '#3E2A8C'),
              close=('#FFB3D1', '#FF5C9A', '#E0357A', '#8E1A4E')),
   face_a=0.88, gloss=0.55, rimlight='#FFFFFF', rimlight_a=0.8,
   ic=dict(main='#FFFFFF', shade='#F1E6FF', acc='#FFE27A', acc2='#FF8FB8', wood='#E8A66A', wood2='#B8733A', red='#FF6FA0', out='#3B1748'),
   ring=('#3B1748', '#FFFFFF'), sel='#FFF4B8',
   joy=dict(base='#FFFFFF', base_a=0.22, ring='#FFFFFF', ring_a=0.85, edge='#3B1748', knob=('#FFD6E8', '#FF8FB8', '#E0357A', '#8E1A4E'), mode='glassdot'),
)

# ---------- SVG helpers ----------
class Doc:
    def __init__(self):
        self.defs = []
        self.body = []
    def grad(self, stops, x1=0, y1=0, x2=0, y2=1):
        i = f'lg{len(self.defs)}'
        s = ''.join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.defs.append(f'<linearGradient id="{i}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>')
        return f'url(#{i})'
    def clip_circle(self, cx, cy, r):
        i = f'cp{len(self.defs)}'
        self.defs.append(f'<clipPath id="{i}"><circle cx="{cx}" cy="{cy}" r="{r}"/></clipPath>')
        return f'url(#{i})'
    def add(self, shape):
        self.body.append(shape)
    def svg(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.body)}</svg>')

# ---------- icons (100x100 box, centred at 50,50) ----------
# element: ('f', svg-shape-without-style, colour_key)  filled shape
#          ('s', path-d, colour_key, width)            stroked path (round caps)
#          ('d', svg-shape, colour_key|'#hex', width)  detail stroke drawn after fill, no outline pass
def star_pts(cx, cy, R, r, n=5, rot=-90):
    pts = []
    for k in range(2 * n):
        a = math.radians(rot + k * 180 / n)
        rr = R if k % 2 == 0 else r
        pts.append(f'{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}')
    return ' '.join(pts)

HEART = 'M50 88 C50 88 10 62 10 36 C10 20 22 12 33 12 C42 12 48 18 50 24 C52 18 58 12 67 12 C78 12 90 20 90 36 C90 62 50 88 50 88 Z'

def icon_shapes(name):
    E = []
    if name == 'sword':
        g = 'transform="rotate(45 50 50)"'
        E += [('f', f'<g {g}><path d="M50 2 L61 15 L61 62 L39 62 L39 15 Z"/></g>', 'main'),
              ('f', f'<g {g}><rect x="26" y="60" width="48" height="11" rx="5"/></g>', 'acc'),
              ('f', f'<g {g}><rect x="44.5" y="70" width="11" height="17"/></g>', 'wood'),
              ('f', f'<g {g}><circle cx="50" cy="91" r="7"/></g>', 'acc'),
              ('d', f'<g {g}><path d="M50 16 L50 56"/></g>', 'shade', 4)]
    elif name == 'run':
        E += [('s', 'M14 34 L30 34 M8 48 L26 48 M14 62 L28 62', 'shade', 7),
              ('f', '<circle cx="64" cy="18" r="11"/>', 'main'),
              ('s', 'M58 34 L46 60', 'main', 15),
              ('s', 'M57 38 L70 48 L82 42', 'main', 10),
              ('s', 'M55 38 L42 42 L34 54', 'main', 10),
              ('s', 'M46 60 L62 70 L58 88', 'main', 11),
              ('s', 'M46 60 L36 76 L22 78', 'main', 11)]
    elif name == 'chop':
        ax = 'transform="translate(-8 0) rotate(30 56 50)"'
        E += [('f', f'<g {ax}><rect x="50" y="12" width="12" height="84" rx="6"/></g>', 'wood'),
              ('f', f'<g {ax}><path d="M58 14 L70 14 C74 6 86 0 96 4 C102 20 102 42 96 58 C84 54 74 48 70 42 L58 42 Z"/></g>', 'shade'),
              ('d', f'<g {ax}><path d="M92 10 C96 24 96 40 92 52" fill="none"/></g>', '#FFFFFF', 4)]
    elif name == 'bow':
        E += [('s', 'M22 74 Q15 12 77 19', 'wood', 10),
              ('s', 'M22 74 L77 19', 'shade', 4),
              ('s', 'M35 61 L80 81', 'main', 6),
              ('f', '<path d="M82 68 L91 86 L71 89 Z"/>', 'acc')]
    elif name == 'rotate':
        E += [('s', 'M77 46 A28 28 0 1 0 69 72', 'main', 11),
              ('f', '<path d="M58 42 L91 38 L79 64 Z"/>', 'acc')]
    elif name == 'build':
        E += [('f', '<path d="M8 52 L36 26 L64 52 Z"/>', 'acc2'),
              ('f', '<rect x="15" y="50" width="42" height="36" rx="3"/>', 'main'),
              ('f', '<rect x="29" y="64" width="14" height="22" rx="2"/>', 'wood'),
              ('s', 'M66 90 L84 50', 'wood', 9),
              ('f', '<g transform="rotate(24 80 40)"><rect x="62" y="28" width="36" height="20" rx="4"/></g>', 'shade')]
    elif name == 'map':
        E += [('f', '<path d="M10 24 L36 14 L64 24 L90 14 L90 76 L64 86 L36 76 L10 86 Z"/>', 'main'),
              ('f', '<path d="M36 14 L64 24 L64 86 L36 76 Z"/>', 'shade'),
              ('d', '<path d="M20 70 C30 56 44 66 52 52 C58 42 66 46 72 38" fill="none" stroke-dasharray="6 6"/>', 'acc2', 5),
              ('d', '<path d="M68 30 L80 42 M80 30 L68 42" fill="none"/>', 'red', 6)]
    elif name == 'menu':
        E += [('f', '<rect x="14" y="18" width="72" height="16" rx="8"/>', 'main'),
              ('f', '<rect x="14" y="42" width="72" height="16" rx="8"/>', 'main'),
              ('f', '<rect x="14" y="66" width="72" height="16" rx="8"/>', 'main')]
    elif name == 'close':
        E += [('s', 'M24 24 L76 76 M76 24 L24 76', 'main', 18)]
    elif name == 'trophy':
        E += [('s', 'M28 30 C8 30 10 56 34 58 M72 30 C92 30 90 56 66 58', 'acc', 8),
              ('f', '<path d="M24 12 L76 12 L74 40 C72 58 60 66 50 66 C40 66 28 58 26 40 Z"/>', 'acc'),
              ('f', '<rect x="44" y="64" width="12" height="14"/>', 'acc'),
              ('f', '<rect x="28" y="76" width="44" height="14" rx="4"/>', 'wood'),
              ('d', '<path d="M36 20 L36 40" fill="none"/>', '#FFFFFF', 5)]
    elif name == 'heart':
        E += [('f', f'<path d="{HEART}"/>', 'red'), ('d', '<path d="M24 30 C24 24 28 22 32 22" fill="none"/>', '#FFFFFF', 6)]
    elif name == 'star':
        E += [('f', f'<polygon points="{star_pts(50,52,44,20)}"/>', 'acc'), ('d', '<path d="M40 40 L46 30" fill="none"/>', '#FFFFFF', 5)]
    elif name == 'log':
        E += [('f', '<rect x="10" y="28" width="70" height="44" rx="10"/>', 'wood'),
              ('f', '<ellipse cx="78" cy="50" rx="14" ry="22"/>', 'shade'),
              ('d', '<ellipse cx="78" cy="50" rx="6" ry="11" fill="none"/>', 'wood', 4),
              ('d', '<path d="M22 42 L54 42 M30 58 L62 58" fill="none"/>', 'wood2', 4)]
    elif name == 'castle':
        E += [('f', '<path d="M10 88 L10 30 L16 30 L16 22 L24 22 L24 30 L30 30 L30 22 L38 22 L38 40 L62 40 L62 22 L70 22 L70 30 L76 30 L76 22 L84 22 L84 30 L90 30 L90 88 Z"/>', 'main'),
              ('f', '<path d="M38 40 L38 32 L44 32 L44 40 M56 40 L56 32 L62 32 L62 40 Z"/>', 'main'),
              ('f', '<path d="M40 88 L40 66 C40 56 60 56 60 66 L60 88 Z"/>', 'wood'),
              ('s', 'M50 40 L50 8', 'shade', 4),
              ('f', '<path d="M50 8 L68 14 L50 20 Z"/>', 'red'),
              ('d', '<path d="M20 48 L20 58 M80 48 L80 58" fill="none"/>', 'wood2', 5)]
    elif name == 'guard':   # knight helmet
        E += [('f', '<path d="M18 86 L18 46 C18 22 32 10 50 10 C68 10 82 22 82 46 L82 86 Z"/>', 'main'),
              ('f', '<rect x="26" y="44" width="48" height="10" rx="4"/>', 'wood2'),
              ('d', '<path d="M50 58 L50 80 M40 64 L40 78 M60 64 L60 78" fill="none"/>', 'wood2', 5),
              ('s', 'M50 10 C52 0 66 -2 74 4', 'red', 9)]
    elif name == 'wall':
        E += [('f', '<path d="M8 86 L8 34 L20 34 L20 24 L32 24 L32 34 L44 34 L44 24 L56 24 L56 34 L68 34 L68 24 L80 24 L80 34 L92 34 L92 86 Z"/>', 'main'),
              ('d', '<path d="M8 52 L92 52 M8 70 L92 70 M30 34 L30 52 M60 34 L60 52 M44 52 L44 70 M76 52 L76 70 M24 70 L24 86 M58 70 L58 86" fill="none"/>', 'wood2', 4)]
    elif name == 'plank':
        E += [('f', '<g transform="rotate(-20 50 50)"><rect x="6" y="34" width="88" height="32" rx="6"/></g>', 'plank'),
              ('d', '<g transform="rotate(-20 50 50)"><path d="M16 46 L60 46 M30 56 L82 56" fill="none"/></g>', 'wood2', 4),
              ('f', '<g transform="rotate(-20 50 50)"><circle cx="16" cy="50" r="4.5"/><circle cx="84" cy="50" r="4.5"/></g>', 'shade')]
    elif name == 'demolish':
        E += [('f', '<path d="M25 12 L50 37 L75 12 L88 25 L63 50 L88 75 L75 88 L50 63 L25 88 L12 75 L37 50 L12 25 Z"/>', 'red')]
    elif name == 'barracks':   # tent with flag
        E += [('s', 'M50 34 L50 6', 'shade', 4),
              ('f', '<path d="M50 6 L68 12 L50 18 Z"/>', 'red'),
              ('f', '<path d="M6 86 L50 26 L94 86 Z"/>', 'acc2'),
              ('f', '<path d="M50 26 L94 86 L64 86 Z"/>', 'wood'),
              ('f', '<path d="M38 86 L50 56 L62 86 Z"/>', 'wood2')]
    elif name == 'mine':
        E += [('f', '<path d="M7 84 L17 43 L35 22 L63 17 L83 38 L94 84 Z"/>', 'shade'),
              ('f', '<path d="M29 84 L29 50 L71 50 L71 84 Z"/>', 'out'),
              ('s', 'M27 83 L33 49 L67 49 L73 83', 'wood', 10)]
    elif name == 'tower':
        E += [('f', '<path d="M24 92 L28 38 L72 38 L76 92 Z"/>', 'main'),
              ('f', '<path d="M18 40 L18 12 L30 12 L30 22 L44 22 L44 12 L56 12 L56 22 L70 22 L70 12 L82 12 L82 40 Z"/>', 'main'),
              ('f', '<path d="M40 92 L40 74 C40 64 60 64 60 74 L60 92 Z"/>', 'wood'),
              ('f', '<rect x="43" y="46" width="14" height="14" rx="5"/>', 'wood2')]
    return E

def icon_svg(doc, name, cx, cy, size, ic, ow=7.0):
    """Sticker icon: one thick outline pass under everything, then fills, then details."""
    s = size / 100.0
    def col(k):
        if k.startswith('#'):
            return ic.get(k, k)
        return ic['wood' if k == 'plank' else k]
    out = ic['out']
    parts = [f'<g transform="translate({cx - 50*s:.2f},{cy - 50*s:.2f}) scale({s:.4f})" stroke-linejoin="round" stroke-linecap="round">']
    shapes = icon_shapes(name)
    # outline pass
    for e in shapes:
        if e[0] == 'f':
            parts.append(f'<g fill="{out}" stroke="{out}" stroke-width="{ow*2}">{e[1]}</g>')
        elif e[0] == 's':
            parts.append(f'<path d="{e[1]}" fill="none" stroke="{out}" stroke-width="{e[3] + ow*2}"/>')
    # fill pass
    for e in shapes:
        if e[0] == 'f':
            parts.append(f'<g fill="{col(e[2])}">{e[1]}</g>')
        elif e[0] == 's':
            parts.append(f'<path d="{e[1]}" fill="none" stroke="{col(e[2])}" stroke-width="{e[3]}"/>')
        elif e[0] == 'd':
            c = col(e[2])
            parts.append(f'<g fill="none" stroke="{c}" stroke-width="{e[3]}">{e[1]}</g>')
    parts.append('</g>')
    doc.add(''.join(parts))

def button(doc, st, cx, cy, r, face_key, icon, icon_scale=1.25, pressed=False, selected=False, charge=None):
    top, mid, low, lip = st['faces'][face_key]
    out = st['out']
    d = r * st['depth']
    ow = r * st['ow']
    if pressed:
        cy += d * 0.6
        d *= 0.4
    # hard drop shadow
    doc.add(f'<ellipse cx="{cx}" cy="{cy + d + r*0.10:.1f}" rx="{r*0.98:.1f}" ry="{r*0.92:.1f}" fill="#000" opacity="0.28"/>')
    if charge is not None:
        rr = r + ow * 1.25
        doc.add(f'<circle cx="{cx}" cy="{cy}" r="{rr:.1f}" fill="none" stroke="{out}" stroke-width="{ow*1.8:.1f}"/>')
        doc.add(f'<circle cx="{cx}" cy="{cy}" r="{rr:.1f}" fill="none" stroke="{st["ring"][0]}" stroke-width="{ow*1.2:.1f}"/>')
        a0 = -90
        a1 = a0 + 360 * charge
        x0, y0 = cx + rr*math.cos(math.radians(a0)), cy + rr*math.sin(math.radians(a0))
        x1, y1 = cx + rr*math.cos(math.radians(a1)), cy + rr*math.sin(math.radians(a1))
        doc.add(f'<path d="M{x0:.1f} {y0:.1f} A{rr:.1f} {rr:.1f} 0 {1 if charge > .5 else 0} 1 {x1:.1f} {y1:.1f}" fill="none" stroke="{st["ring"][1]}" stroke-width="{ow*1.2:.1f}" stroke-linecap="round"/>')
    if selected:
        doc.add(f'<circle cx="{cx}" cy="{cy + d/2:.1f}" r="{r + ow*1.15:.1f}" fill="none" stroke="{out}" stroke-width="{ow*1.5:.1f}"/>')
        doc.add(f'<circle cx="{cx}" cy="{cy + d/2:.1f}" r="{r + ow*1.15:.1f}" fill="none" stroke="{st["sel"]}" stroke-width="{ow*1.2:.1f}"/>')
    # Two crescents form the lip without filling behind the translucent face.
    rf = r - ow
    for radius, color in ((r, out), (rf, lip)):
        half_chord = math.sqrt(radius * radius - (d / 2) ** 2)
        y = cy + d / 2
        doc.add(f'<path d="M{cx-half_chord},{y} A{radius},{radius} 0 1 0 {cx+half_chord},{y}'
                f' A{radius},{radius} 0 0 1 {cx-half_chord},{y}Z" fill="{color}"/>')
    fill = doc.grad([(0, top, st['face_a']), (0.55, mid, st['face_a']), (1, low, st['face_a'])])
    doc.add(f'<circle cx="{cx}" cy="{cy}" r="{r-ow/2}" fill="{fill}" stroke="{out}" stroke-width="{ow}"/>')
    clip = doc.clip_circle(cx, cy, rf)
    # bottom inner shade
    doc.add(f'<g clip-path="{clip}"><circle cx="{cx}" cy="{cy - rf*0.18:.1f}" r="{rf*1.12:.1f}" fill="none" stroke="{low}" stroke-opacity="0.55" stroke-width="{rf*0.36:.1f}"/></g>')
    # inner light rim (top)
    if st['rimlight_a'] > 0:
        rl = doc.grad([(0, st['rimlight'], st['rimlight_a']), (0.45, st['rimlight'], 0), (1, st['rimlight'], 0)])
        doc.add(f'<circle cx="{cx}" cy="{cy:.1f}" r="{rf - max(2, rf*0.05):.1f}" fill="none" stroke="{rl}" stroke-width="{max(3, rf*0.08):.1f}"/>')
    gl = doc.grad([(0, '#FFFFFF', st['gloss']), (1, '#FFFFFF', 0.0)])
    doc.add(f'<g clip-path="{clip}"><ellipse cx="{cx}" cy="{cy - rf*0.42:.1f}" rx="{rf*0.80:.1f}" ry="{rf*0.48:.1f}" fill="{gl}"/></g>')
    doc.add(f'<circle cx="{cx + rf*0.52:.1f}" cy="{cy + rf*0.42:.1f}" r="{rf*0.10:.1f}" fill="#fff" opacity="0.65"/>')
    if icon:
        icon_svg(doc, icon, cx, cy + rf*0.02, rf * icon_scale, st['ic'], ow=7.5 if rf > 30 else 8.5)

def joystick(doc, knob=False, active=False, style=E4):
    j = style['joy']
    out = j['edge']
    if knob:
        knob_style = dict(style, faces={'knob': j['knob']})
        button(doc, knob_style, 50, 47, 45, 'knob', None, pressed=active)
        y = 49.5 if active else 47
        doc.add(f'<circle cx="50" cy="{y}" r="12" fill="white" opacity=".7"/>')
        return
    doc.add('<circle cx="50" cy="52" r="46" fill="black" opacity=".18"/>')
    doc.add(f'<circle cx="50" cy="49" r="46" fill="{j["base"]}" fill-opacity="{j["base_a"]}" stroke="{out}" stroke-opacity=".85" stroke-width="2.6"/>')
    doc.add(f'<circle cx="50" cy="49" r="42.5" fill="none" stroke="{j["ring"]}" stroke-opacity="{j["ring_a"]}" stroke-width="3"/>')
    doc.add(f'<circle cx="50" cy="49" r="40" fill="none" stroke="{out}" stroke-opacity=".35" stroke-width="1.1"/>')
    for angle in (0, 90, 180, 270):
        doc.add(f'<path transform="rotate({angle} 50 49)" d="M50 11 L46.5 16 L53.5 16 Z" fill="white" fill-opacity=".9" stroke="{out}" stroke-width="1.3" stroke-linejoin="round"/>')


def save(doc, name, units, disabled=False, out=OUT):
    pixels = units * DENSITY
    png = cairosvg.svg2png(bytestring=doc.svg().encode(), output_width=pixels, output_height=pixels)
    image = Image.open(io.BytesIO(png)).convert('RGBA')
    if disabled:
        alpha = image.getchannel('A').point(lambda value: round(value * .65))
        image = ImageEnhance.Color(image).enhance(.18)
        image = ImageEnhance.Brightness(image).enhance(.77)
        image.putalpha(alpha)
    image.save(out / f'{name}.png')


def disc(name, units, face, icon, scale, states, *, style, out, draw_button):
    for state in states:
        doc = Doc()
        close = name == 'build' and state.startswith('selected')
        ring = state.startswith('selected') and not close
        charge = (.88 if state == 'aim' else .68) if name == 'attack' else None
        radius = 41 if charge is not None else (42 if ring else 45)
        disabled = state == 'disabled'
        draw_style = style.get('disabled_style', style) if disabled else style
        draw_button(doc, draw_style, 50, 47, radius, 'close' if close else face,
                    'close' if close else icon, icon_scale=1.2 if close else scale,
                    pressed='pressed' in state, selected=ring, charge=charge)
        save(doc, f'{name}_{state}', units, disabled and draw_style is style, out=out)


def sticker(name, icon, state='normal'):
    doc = Doc()
    colors = E4['ic']
    if state in ('empty', 'half'):
        colors = dict(colors, red='#67465E')
    elif state.startswith('flash'):
        colors = dict(colors, red='#FFF2F8' if state.endswith('0') else '#FFB3D1')
    y = 52 if state == 'pressed' else 50
    if state == 'selected':
        doc.add('<circle cx="50" cy="50" r="45" fill="#FFF4B8" opacity=".76"/>')
    icon_svg(doc, icon, 50, y, 94, colors, ow=7.5)
    if state == 'half':
        doc.add('<clipPath id="half"><rect width="50" height="100"/></clipPath><g clip-path="url(#half)">')
        icon_svg(doc, icon, 50, y, 94, E4['ic'], ow=7.5)
        doc.add('</g>')
    save(doc, name, 11)


def render_discs(out=OUT, style=E4, draw_button=button, draw_joystick=joystick):
    out.mkdir(parents=True, exist_ok=True)
    options = dict(style=style, out=out, draw_button=draw_button)
    basic = ('normal', 'pressed', 'disabled')
    toggle = basic + ('selected', 'selected_pressed')
    disc('map', 24, 'map', 'map', 1.42, toggle, **options)
    disc('menu', 24, 'menu', 'menu', 1.20, basic, **options)
    disc('build', 24, 'build', 'build', 1.50, toggle, **options)
    disc('rotate', 24, 'build', 'rotate', 1.42, basic, **options)
    for icon in ('sword', 'chop', 'bow'):
        disc(f'wheel_{icon}', 24, 'wheel', icon, 1.4, toggle, **options)
    for icon in ('plank', 'wall', 'tower', 'castle', 'guard', 'barracks', 'mine', 'demolish'):
        disc(f'pick_{icon}', 24, 'pick', icon, 1.72, toggle, **options)
    disc('run', 32, 'run', 'run', 1.45, basic, **options)
    disc('attack', 40, 'attack', 'sword', 1.40, ('idle', 'pressed', 'aim', 'disabled'), **options)
    for part, states in [('base', ('normal', 'disabled')), ('knob', ('normal', 'active', 'disabled'))]:
        for state in states:
            doc = Doc()
            disabled = state == 'disabled'
            draw_style = style.get('disabled_style', style) if disabled else style
            draw_joystick(doc, knob=part == 'knob', active=state == 'active', style=draw_style)
            units = 56 if part == 'base' else 24
            save(doc, f'joystick_{part}_{state}', units, disabled and draw_style is style, out=out)


def main():
    render_discs()
    for state in ('full', 'half', 'empty', 'flash_0', 'flash_1'):
        sticker(f'heart_{state}', 'heart', state)
    for icon in ('star', 'log'):
        sticker(icon, icon)
    for state in ('normal', 'pressed', 'selected'):
        sticker(f'scores_{state}', 'trophy', state)


if __name__ == '__main__':
    main()
