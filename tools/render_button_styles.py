#!/usr/bin/env python3
"""Drive the six button styles and write seven cropped comparison sheets."""

import os
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DRIVE = ".cursor/skills/verify-flagoria/drives/button_styles.gd"
EVIDENCE = ROOT / "docs/evidence/button-styles"
STYLES = ("current", "wood", "parchment", "stone", "pixel", "banner")

# Pixel rectangles from the 2400×1080 drive. Two-strip crops omit the empty
# space between the upper form and the bottom action row.
SCREENS = {
    "main-menu": (2, [(780, 298, 1620, 810)]),
    "worlds": (3, [(18, 46, 2382, 1078)]),
    "multiplayer": (2, [(42, 42, 1560, 360), (660, 904, 2358, 1058)]),
    "settings": (2, [(608, 48, 1792, 444), (608, 914, 1792, 1064)]),
    "ingame-menu": (2, [(590, 12, 1810, 1072)]),
    "tuning": (3, [(8, 10, 2392, 1070)]),
    "parchment": (1, [(1934, 0, 2400, 134)]),
}


def capture(style, scratch):
    data = scratch / "data"
    userdata = data / "godot/app_userdata/Flagoria"
    userdata.mkdir(parents=True)
    keys = ("altitude_seed", "moisture_seed", "temperature_seed", "items_seed", "biome_seed")
    (userdata / "map_gen_params.cfg").write_text(
        "[map_gen]\n" + "\n".join(f"{key}={42 + i}" for i, key in enumerate(keys)) + "\n"
    )
    captures = scratch / "captures"
    env = [
        f"XDG_DATA_HOME={data}",
        f"XDG_CONFIG_HOME={scratch / 'config'}",
        f"XDG_CACHE_HOME={scratch / 'cache'}",
        f"FLAGORIA_BUTTON_STYLE={style}",
        f"VERIFY_EVIDENCE_DIR={captures}",
    ]
    command = [
        "xvfb-run", "-a", "-s", "-screen 0 2400x1080x24", "env", *env,
        os.environ.get("GODOT") or "godot",
        "--path", ".", "--rendering-driver", "opengl3", "--script", DRIVE,
    ]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
    if result.returncode or "VERIFY_DONE ok" not in result.stdout or "SCRIPT ERROR" in result.stderr:
        raise RuntimeError(f"{style} drive failed\n{result.stdout}\n{result.stderr}")
    print(f"{style}: VERIFY_DONE ok", flush=True)
    return captures


def compose(screen, captures):
    factor, boxes = SCREENS[screen]
    gap, header, cols = 8, 28, 3
    sizes = [
        ((right - left) // factor, (bottom - top) // factor)
        for left, top, right, bottom in boxes
    ]
    width = max(w for w, _ in sizes)
    content_h = sum(h + gap for _, h in sizes)
    cell_h = header + content_h
    rows = (len(STYLES) + cols - 1) // cols
    sheet = Image.new(
        "RGB",
        (gap + cols * (width + gap), gap + rows * (cell_h + gap)),
        "#2a2238",
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=18)
    for index, (style, directory) in enumerate(zip(STYLES, captures, strict=True)):
        x = gap + (index % cols) * (width + gap)
        y = gap + (index // cols) * (cell_h + gap)
        draw.text((x, y + 4), f"{chr(65 + index)} {style}", fill="#e7d7b1", font=font)
        path, = directory.glob(f"*-{screen}.png")
        with Image.open(path) as image:
            if image.size != (2400, 1080):
                raise ValueError(f"{style} {screen} capture has size {image.size}")
            paste_y = y + header
            for box, size in zip(boxes, sizes, strict=True):
                sheet.paste(
                    image.crop(box).resize(size, Image.Resampling.NEAREST),
                    (x, paste_y),
                )
                paste_y += size[1] + gap
    sheet.save(EVIDENCE / f"{screen}.png", optimize=True)


def main():
    with TemporaryDirectory(prefix="flagoria-button-styles-", dir="/tmp") as directory:
        captures = [capture(style, Path(directory) / style) for style in STYLES]
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        for screen in SCREENS:
            compose(screen, captures)


if __name__ == "__main__":
    main()
