#!/usr/bin/env python3
"""Capture and compose the HUD button style comparison at mobile landscape size."""

import os
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image, ImageDraw, ImageFont

from gen_hud_styles import OUT as VARIANT_SPRITES, main as generate_sprites

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/evidence/hud-button-styles"
DRIVE = "res://.cursor/skills/verify-flagoria/drives/hud_button_styles.gd"
RESOLUTION = (2400, 1080)
STYLES = {
    "current": "A · Candy Glass",
    "teal": "B · Sea-teal glass",
    "leaf": "C · Leaf-green glass",
    "sand": "D · Sand-gold glass",
    "flat": "E · Flat",
    "shadow": "F · Soft-shadow",
    "ghost": "G · Ghost",
}
FONT = ROOT / "art/ui/fonts/LilitaOne-Regular.ttf"
BG, PANEL, TEXT = "#2a2238", "#24604a", "#e7d7b1"


def godot(scratch, args, *, display=False, env=None):
    for name in ("data", "config", "cache"):
        (scratch / name).mkdir(parents=True, exist_ok=True)
    overrides = {
        f"XDG_{name.upper()}_HOME": str(scratch / name) for name in ("data", "config", "cache")
    }
    overrides.update(env or {})
    command = ["env", *(f"{key}={value}" for key, value in overrides.items()),
               os.environ.get("GODOT", "godot"), "--path", ".", *args]
    if display:
        command = ["xvfb-run", "-a", "-s", "-screen 0 2400x1080x24", *command]
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True)
    if result.returncode or "SCRIPT ERROR:" in result.stdout:
        raise RuntimeError(result.stdout)
    return result.stdout


def capture(scratch, style):
    # Same map seed fields as the drive launcher.
    user = scratch / "data/godot/app_userdata/Flagoria"
    user.mkdir(parents=True)
    keys = ("altitude", "moisture", "temperature", "items", "biome")
    config = "[map_gen]\n" + "".join(f"{key}_seed={seed}\n" for seed, key in enumerate(keys, 49))
    (user / "map_gen_params.cfg").write_text(config)
    args = ["--rendering-driver", "opengl3", "--resolution", "2400x1080", "--script", DRIVE]
    log = godot(scratch, args, display=True,
                env={"FLAGORIA_HUD_STYLE": style, "VERIFY_EVIDENCE_DIR": str(scratch)})
    if "VERIFY_DONE ok" not in log:
        raise RuntimeError(log)
    print(f"{style}: VERIFY_DONE ok", flush=True)


def sheet(panels, filename):
    """Arrange A–G in reading order at native panel size."""
    width, height = panels[0].size
    gap, header = 12, 36
    columns = 2
    rows = (len(panels) + columns - 1) // columns
    board = Image.new("RGB", (columns * (width + gap) + gap,
                              rows * (height + header + gap) + gap), BG)
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype(FONT, 23)
    for index, (title, panel) in enumerate(zip(STYLES.values(), panels, strict=True)):
        x = gap + index % columns * (width + gap)
        y = gap + index // columns * (height + header + gap)
        draw.text((x + 4, y + 4), title, font=font, fill=TEXT)
        board.paste(panel, (x, y + header))
    board.save(OUT / filename, optimize=True)


def hud_crop(image):
    # Keep the separate touch zones at full size and remove the empty world between them.
    menu = image.crop((2084, 36, 2360, 148))
    stick = image.crop((190, 682, 466, 938))
    actions = image.crop((1796, 536, 2284, 946))
    panel = Image.new("RGB", (menu.width + 8 + actions.width, actions.height), BG)
    panel.paste(menu, (0, 0))
    panel.paste(stick, (0, actions.height - stick.height))
    panel.paste(actions, (menu.width + 8, 0))
    return panel


def match_start(scratch):
    panels = []
    for style in STYLES:
        with Image.open(scratch / style / "01-match-start.png") as image:
            if image.size != RESOLUTION:
                raise ValueError(f"Unexpected capture size {image.size} for {style}")
            panels.append(hud_crop(image))
    sheet(panels, "match-start.png")


def state_strip():
    basic = ("normal", "pressed", "disabled")
    toggle = basic + ("selected", "selected_pressed")
    buttons = (
        ("Attack", "attack", ("idle", "pressed", "disabled", "aim")),
        ("Run", "run", basic),
        ("Buildings", "build", toggle),
        ("Map", "map", toggle),
        ("Plank", "pick_plank", toggle),
        ("Rotate", "rotate", basic),
    )
    columns = ("Idle", "Pressed", "Disabled", "Selected/Aim", "Selected + Held")
    cell, label, header = 92, 92, 30
    font = ImageFont.truetype(FONT, 13)
    panels = []
    for style in STYLES:
        sprites = ROOT / "art/ui/hud_e4" if style == "current" else VARIANT_SPRITES / style
        panel = Image.new("RGB", (label + cell * len(columns), header + cell * len(buttons)),
                          PANEL)
        draw = ImageDraw.Draw(panel)
        for col, title in enumerate(columns):
            draw.text((label + col * cell + cell // 2, header // 2), title,
                      anchor="mm", font=font, fill=TEXT)
        for row, (title, stem, states) in enumerate(buttons):
            y = header + row * cell
            draw.text((10, y + cell // 2), title, anchor="lm", font=font, fill=TEXT)
            for col in range(len(columns)):
                x = label + cell * col
                draw.rectangle((x + 1, y + 1, x + cell - 2, y + cell - 2), fill="#8e97a3")
                if col >= len(states):
                    draw.text((x + cell // 2, y + cell // 2), "—", anchor="mm", font=font, fill=BG)
                    continue
                with Image.open(sprites / f"{stem}_{states[col]}.png") as source:
                    size = source.width // 2
                    sprite = source.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
                    inset = (cell - size) // 2
                    panel.paste(sprite, (x + inset, y + inset), sprite)
        panels.append(panel)
    sheet(panels, "state-strip.png")


def main():
    generate_sprites()
    OUT.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="flagoria-hud-", dir="/tmp") as run:
        scratch = Path(run)
        godot(scratch / "import", ["--headless", "--import"])
        for style in STYLES:
            capture(scratch / style, style)
        match_start(scratch)
    state_strip()


if __name__ == "__main__":
    main()
