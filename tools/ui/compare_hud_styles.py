#!/usr/bin/env python3
"""Capture and compose the HUD button style comparison at mobile landscape size."""

import os
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image, ImageDraw, ImageFont

from gen_hud_styles import OUT as PIXEL_SPRITES, main as generate_sprites

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/evidence/hud-button-styles"
DRIVE = "res://.cursor/skills/verify-flagoria/drives/hud_button_styles.gd"
RESOLUTION = (2400, 1080)
STYLES = {
    "current": "A · Candy Glass",
    "wood": "B · Carved Wood",
    "parchment": "C · Parchment",
    "stone": "D · Chiseled Stone",
    "pixel": "E · Flat Pixel",
    "banner": "F · Stitched Banner",
}
FONT = ROOT / "art/ui/fonts/LilitaOne-Regular.ttf"
SCREENS = ("match-start", "build-picker", "pressed", "tool-wheel")
BG, PANEL, TEXT = "#2a2238", "#3b1748", "#e7d7b1"


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
    """Arrange A–F in reading order with the same framing at native image size."""
    width, height = panels[0].size
    gap, header = 12, 36
    board = Image.new("RGB", (3 * width + 4 * gap, 2 * (height + header) + 3 * gap), BG)
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype(FONT, 23)
    for index, (title, panel) in enumerate(zip(STYLES.values(), panels, strict=True)):
        x = gap + index % 3 * (width + gap)
        y = gap + index // 3 * (height + header + gap)
        draw.text((x + 4, y + 4), title, font=font, fill=TEXT)
        board.paste(panel, (x, y + header))
    board.save(OUT / filename, optimize=True)


def hud_crop(image, screen):
    if screen == "build-picker":
        return image.crop((1666, 36, 2360, 1044))
    if screen == "tool-wheel":
        return image.crop((1706, 536, 2290, 1068))
    # Keep the separate touch zones at full size and remove the empty world between them.
    menu = image.crop((2084, 36, 2360, 148))
    stick = image.crop((190, 682, 466, 938))
    actions = image.crop((1796, 536, 2284, 946))
    panel = Image.new("RGB", (menu.width + 8 + actions.width, actions.height), BG)
    panel.paste(menu, (0, 0))
    panel.paste(stick, (0, actions.height - stick.height))
    panel.paste(actions, (menu.width + 8, 0))
    return panel


def compare(scratch, step, screen):
    panels = []
    for style in STYLES:
        with Image.open(scratch / style / f"{step:02d}-{screen}.png") as image:
            if image.size != RESOLUTION:
                raise ValueError(f"Unexpected capture size {image.size} for {style}/{screen}")
            panels.append(hud_crop(image, screen))
    sheet(panels, f"{screen}.png")


def state_strip():
    buttons = {"Attack": "attack", "Run": "run", "Buildings": "build", "Map": "map",
               "Plank": "pick_plank", "Rotate": "rotate"}
    columns = ("Idle", "Pressed", "Disabled", "Selected/Aim", "Sel. + Held")
    cell, label, header = 88, 94, 26
    font = ImageFont.truetype(FONT, 14)
    panels = []
    for style in STYLES:
        sprites = ROOT / "art/ui/hud_e4" if style == "current" else PIXEL_SPRITES / style
        panel = Image.new("RGB", (label + cell * len(columns), header + cell * len(buttons)),
                          PANEL)
        draw = ImageDraw.Draw(panel)
        for col, title in enumerate(columns):
            draw.text((label + col * cell + cell // 2, header // 2), title,
                      anchor="mm", font=font, fill=TEXT)
        for row, (title, stem) in enumerate(buttons.items()):
            y = header + row * cell
            draw.text((10, y + cell // 2), title, anchor="lm", font=font, fill=TEXT)
            states = ("idle", "pressed", "disabled", "aim", "selected_pressed") if stem == "attack" else (
                "normal", "pressed", "disabled", "selected", "selected_pressed"
            )
            for col, state in enumerate(states):
                path = sprites / f"{stem}_{state}.png"
                x = label + cell * col
                draw.rectangle((x + 1, y + 1, x + cell - 2, y + cell - 2), fill="#8e97a3")
                if not path.is_file():
                    draw.text((x + cell // 2, y + cell // 2), "—", anchor="mm", font=font, fill=BG)
                    continue
                with Image.open(path) as source:
                    resampling = Image.Resampling.LANCZOS if style == "current" else Image.Resampling.NEAREST
                    sprite = source.convert("RGBA").resize((72, 72), resampling)
                    panel.paste(sprite, (x + 8, y + 8), sprite)
        panels.append(panel)
    sheet(panels, "state-strip.png")


def main():
    generate_sprites()
    OUT.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="flagoria-hud-") as run:
        scratch = Path(run)
        godot(scratch / "import", ["--headless", "--import"])
        for style in STYLES:
            capture(scratch / style, style)
        for step, screen in enumerate(SCREENS, 1):
            compare(scratch, step, screen)
    state_strip()


if __name__ == "__main__":
    main()
