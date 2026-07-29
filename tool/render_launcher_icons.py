#!/usr/bin/env python3
"""Render the launcher-icon source images in tool/launcher_icons/.

Run this whenever the icon design changes, then regenerate the per-platform
icons from its output:

    python3 tool/render_launcher_icons.py
    fvm dart run flutter_launcher_icons

Requires Pillow (`python3 -m pip install pillow`) and the system Didot font,
which ships with macOS.

Why this script exists instead of rasterising the SVGs
------------------------------------------------------
tool/launcher_icons/*.svg are the design reference, but they cannot be turned
into the shipped PNGs on a stock macOS box. The only SVG rasteriser available
without extra native libraries is `qlmanage`, and it flattens alpha onto an
opaque white background — rasterising logo_foreground.svg that way yields an
Android adaptive foreground that is a solid white block, which then renders as
a white square on every launcher. cairosvg needs libcairo, which is not
installed. So the artwork is drawn here in PIL instead, taking the letter from
the same Didot Italic font file the SVG names. Keep the two in sync by hand:
edit the SVG to match anything changed here.

Outputs
-------
app_icon.png
    1024x1024, opaque RGB with no alpha channel at all. Feeds `image_path`;
    the App Store rejects icons that carry transparency.
app_icon_foreground.png
    1024x1024 RGBA, artwork only, occupying 96% of the canvas. Feeds
    `adaptive_icon_foreground`. The `android:inset="16%"` in
    android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml then lands it at
    ~65% of Android's 108dp adaptive canvas, inside the 66.7% safe zone that
    every launcher mask is guaranteed to leave visible.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - dependency hint
    sys.exit("Pillow is required: python3 -m pip install pillow")

DIDOT = Path("/System/Library/Fonts/Supplemental/Didot.ttc")
DIDOT_ITALIC = 1

GRADIENT_TOP = (0x14, 0x39, 0x5E)
GRADIENT_BOTTOM = (0x06, 0x0F, 0x1C)
CARD = (0x0D, 0x47, 0xA1)

SUPERSAMPLE = 4
OUTPUT_SIZE = 1024
FOREGROUND_FILL = 0.96

# Geometry is authored on the 64-unit grid the SVGs use, as
# (box, corner_radius, fill, rotation_degrees, rotation_pivot).
CARDS = [
    ((16, 16, 50, 44), 4.5, (255, 255, 255, 77), 14, (33, 30)),
    ((16, 17, 50, 45), 4.5, (255, 255, 255, 184), 7, (33, 31)),
    ((13, 20, 51, 49), 5.0, CARD + (255,), None, None),
]
LETTER_HEIGHT = 21.0
LETTER_CENTRE = (32.0, 34.6)


def _gradient(size: int) -> Image.Image:
    column = Image.new("RGB", (1, size))
    pixels = column.load()
    for y in range(size):
        t = y / (size - 1)
        pixels[0, y] = tuple(
            round(a + (b - a) * t) for a, b in zip(GRADIENT_TOP, GRADIENT_BOTTOM)
        )
    return column.resize((size, size), Image.BILINEAR).convert("RGBA")


def _card_layer(size, k, box, radius, fill, angle, pivot) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        [v * k for v in box], radius=radius * k, fill=fill
    )
    if angle:
        layer = layer.rotate(
            angle, resample=Image.BICUBIC, center=(pivot[0] * k, pivot[1] * k)
        )
    return layer


def _letter_layer(size: int, k: float) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    target = LETTER_HEIGHT * k

    # Point size and cap height are not proportional across the whole range, so
    # converge on the size that yields the wanted height rather than guessing.
    points = target
    for _ in range(4):
        font = ImageFont.truetype(str(DIDOT), round(points), index=DIDOT_ITALIC)
        box = draw.textbbox((0, 0), "L", font=font)
        height = box[3] - box[1]
        if height <= 0:
            break
        points *= target / height

    font = ImageFont.truetype(str(DIDOT), round(points), index=DIDOT_ITALIC)
    box = draw.textbbox((0, 0), "L", font=font)
    draw.text(
        (
            LETTER_CENTRE[0] * k - (box[0] + box[2]) / 2,
            LETTER_CENTRE[1] * k - (box[1] + box[3]) / 2,
        ),
        "L",
        font=font,
        fill=(255, 255, 255, 255),
    )
    return layer


def render(out_size: int, *, background: bool) -> Image.Image:
    """Draw the icon at `out_size`, with or without the gradient field."""
    size = out_size * SUPERSAMPLE
    k = size / 64.0
    image = (
        _gradient(size)
        if background
        else Image.new("RGBA", (size, size), (0, 0, 0, 0))
    )
    for box, radius, fill, angle, pivot in CARDS:
        image = Image.alpha_composite(
            image, _card_layer(size, k, box, radius, fill, angle, pivot)
        )
    image = Image.alpha_composite(image, _letter_layer(size, k))
    return image.resize((out_size, out_size), Image.LANCZOS)


def main() -> None:
    if not DIDOT.exists():
        sys.exit(f"missing font: {DIDOT}")
    out_dir = Path(__file__).resolve().parent / "launcher_icons"
    out_dir.mkdir(parents=True, exist_ok=True)

    full = render(OUTPUT_SIZE, background=True)
    flat = Image.new("RGB", (OUTPUT_SIZE, OUTPUT_SIZE))
    flat.paste(full, mask=full.split()[3])
    flat.save(out_dir / "app_icon.png")

    # Rendered at 2x so the crop-and-rescale below resamples down, never up.
    foreground = render(OUTPUT_SIZE * 2, background=False)
    art = foreground.crop(foreground.split()[3].getbbox())
    scale = OUTPUT_SIZE * FOREGROUND_FILL / max(art.size)
    art = art.resize(
        (round(art.width * scale), round(art.height * scale)), Image.LANCZOS
    )
    canvas = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    canvas.paste(
        art, ((OUTPUT_SIZE - art.width) // 2, (OUTPUT_SIZE - art.height) // 2), art
    )
    canvas.save(out_dir / "app_icon_foreground.png")

    print(f"wrote {out_dir / 'app_icon.png'} ({flat.mode})")
    print(f"wrote {out_dir / 'app_icon_foreground.png'} ({canvas.mode})")
    print("now run: fvm dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
