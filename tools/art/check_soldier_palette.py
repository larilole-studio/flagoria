#!/usr/bin/env python3
"""Check the shipped soldier art against palette v1.1 and its native grids."""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art" / "soldiers"
WHEEL = ROOT / "art" / "ui" / "hud_e4"
PALETTE = {
    tuple(bytes.fromhex(color))
    for color in """
    bfe9ff 7cc8f2 4a8fd6 ffffff d9e6f2 b6e04c 6fbf3a 3f8a3c
    24604a d79a5c a8683f 6e4130 c9cfd6 8e97a3 5b6270 e0a96b
    b06f3c 74452a e8c968 b8913e 3b6fe0 26439a e04a4a 992e3e
    ffe680 f2b632 ffcfa8 d9956b 2a2238 3d3a5c f57620 b03c14
    """.split()
}
TEAM_SWAP = {(59, 111, 224): (224, 74, 74), (38, 67, 154): (153, 46, 62)}
GRIDS = {
    "soldier_sheet": (144, 64),
    "squad_5": (96, 32),
    "company_20": (144, 48),
    "move_marker": (48, 16),
}
SINGLE = {"selection_ring": (32, 16), "cracks_sheet": (96, 32), "alert_icon": (32, 16)}
STATES = ("normal", "pressed", "selected", "selected_pressed", "disabled")


def inspect(path: Path, size: tuple[int, int]) -> Image.Image:
    with Image.open(path) as image:
        if image.size != size:
            raise ValueError(f"{path.name} has dimensions {image.size}, expected {size}")
        rgba = image.convert("RGBA")
    alpha_levels = {0, 24, 96, 140, 255} if path.stem == "selection_ring" else {0, 255}
    for _, pixel in rgba.getcolors(maxcolors=rgba.width * rgba.height):
        if pixel[3] not in alpha_levels or (pixel[3] and pixel[:3] not in PALETTE):
            raise ValueError(f"{path.name} contains an invalid pixel {pixel}")
    return rgba


def pixels(image: Image.Image):
    data = image.tobytes()
    return zip(data[::4], data[1::4], data[2::4], data[3::4], strict=True)


def main() -> None:
    for name, size in GRIDS.items():
        blue = inspect(ART / f"{name}.png", size)
        red = inspect(ART / f"{name}_red.png", size)
        expected = [
            (*TEAM_SWAP.get(pixel[:3], pixel[:3]), pixel[3]) for pixel in pixels(blue)
        ]
        if expected != list(pixels(red)):
            raise ValueError(f"{name} red team swap changes pixels outside the team ramp")
    for name, size in SINGLE.items():
        inspect(ART / f"{name}.png", size)
    for state in STATES:
        command = inspect(WHEEL / f"wheel_command_{state}.png", (96, 96))
        reduced = command.resize((24, 24), Image.Resampling.NEAREST)
        if command.tobytes() != reduced.resize((96, 96), Image.Resampling.NEAREST).tobytes():
            raise ValueError(f"wheel_command_{state} has subpixels inside the 4× grid")
    print("Soldier palette, frame grids, team swaps, and wheel scaling passed.")


if __name__ == "__main__":
    main()
