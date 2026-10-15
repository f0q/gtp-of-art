#!/usr/bin/env python3
"""Render the GTP of Art app-icon candidates ("Salon Noir", plan Part C1).

Usage:
    tools/.venv/bin/python tools/make_icon.py                     # all candidates -> tools/out/icon/
    tools/.venv/bin/python tools/make_icon.py --only frame        # one candidate
    tools/.venv/bin/python tools/make_icon.py --only monogram --install
        # also writes App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

Output: 1024x1024 opaque RGB PNGs, square corners (iOS applies the mask), no transparency.
Colours come from the Salon Noir palette; gilt is used sparingly.
Candidates: monogram (Fraunces "G"), frame (gilt frame, dark canvas, picture light),
gavel (auction gavel silhouette).
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT_UPRIGHT = ROOT / "Design/fonts/Fraunces-Variable.ttf"
FONT_ITALIC = ROOT / "Design/fonts/Fraunces-Italic-Variable.ttf"
OUT_DIR = ROOT / "tools/out/icon"
APPICON = ROOT / "App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

SIZE = 1024
SS = 2  # supersampling factor
S = SIZE * SS

# Salon Noir palette (dark), plan Part C1 / Design/Tokens.json.
CANVAS = (0x0E, 0x0D, 0x0C)
SURFACE = (0x1A, 0x18, 0x16)
ELEVATED = (0x24, 0x21, 0x1E)
GILT = (0xC9, 0xA5, 0x5C)
GILT_DEEP = (0x8C, 0x6E, 0x34)  # shadowed gilt for moulding depth
CREAM = (0xF4, 0xEF, 0xE6)


def px(v: float) -> int:
    """Design units (1024 grid) -> supersampled pixels."""
    return round(v * SS)


def ground() -> Image.Image:
    return Image.new("RGB", (S, S), CANVAS)


def glow(img: Image.Image, center: tuple[float, float], radius: tuple[float, float],
         color: tuple[int, int, int], strength: float) -> Image.Image:
    """Adds a soft elliptical light (picture-light spill) centred at `center` (1024 grid)."""
    g = Image.radial_gradient("L")  # 256x256, 0 at centre -> 255 at edge
    g = g.point(lambda v: max(0, 255 - v))  # bright centre
    g = g.point(lambda v: int(255 * (v / 255) ** 2.2 * strength))  # smooth falloff
    w, h = px(radius[0] * 2), px(radius[1] * 2)
    g = g.resize((w, h), Image.BICUBIC)
    mask = Image.new("L", (S, S), 0)
    mask.paste(g, (px(center[0]) - w // 2, px(center[1]) - h // 2))
    mask = mask.filter(ImageFilter.GaussianBlur(px(24)))
    return Image.composite(Image.new("RGB", (S, S), color), img, mask)


def fraunces(path: Path, size: float, weight: int, opsz: int, soft: int) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(path), px(size))
    axes = {a["name"]: a for a in font.get_variation_axes()}
    values = []
    for name in axes:
        values.append({b"Optical Size": opsz, b"Weight": weight, b"Softness": soft, b"Wonky": 0}.get(
            name, axes[name]["default"]))
    font.set_variation_by_axes(values)
    return font


def finish(img: Image.Image) -> Image.Image:
    out = img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")
    assert out.mode == "RGB" and out.size == (SIZE, SIZE)
    return out


# --- Candidate 1: monogram -------------------------------------------------------------------

def monogram() -> Image.Image:
    img = ground()
    img = glow(img, (512, 300), (460, 420), (0x3A, 0x30, 0x22), 1.0)
    d = ImageDraw.Draw(img)
    font = fraunces(FONT_ITALIC, 700, weight=500, opsz=144, soft=50)
    # Centre on the glyph's ink box, not the advance box.
    l, t, r, b = d.textbbox((0, 0), "G", font=font)
    x = (S - (r - l)) / 2 - l + px(6)
    y = (S - (b - t)) / 2 - t + px(4)
    d.text((x, y), "G", font=font, fill=GILT)
    # A short gilt rule under the letter: the "lot line".
    d.rectangle([px(412), px(842), px(612), px(842 + 6)], fill=GILT_DEEP)
    return finish(img)


# --- Candidate 2: small gilt frame, dark canvas, lit from above -------------------------------

def frame() -> Image.Image:
    img = ground()
    # A gallery spot from above: a soft cone down the wall, brightest just above the frame.
    cone = Image.new("L", (S, S), 0)
    ImageDraw.Draw(cone).polygon([(px(430), px(-40)), (px(594), px(-40)),
                                  (px(860), px(900)), (px(164), px(900))], fill=34)
    cone = cone.filter(ImageFilter.GaussianBlur(px(70)))
    img = Image.composite(Image.new("RGB", (S, S), (0x3A, 0x31, 0x24)), img, cone)
    img = glow(img, (512, 330), (380, 300), (0x33, 0x2B, 0x20), 1.0)
    x0, y0, x1, y1 = 232, 318, 792, 758  # outer frame (landscape, ~4:3)
    bw = 34  # moulding width
    # Shadow cast on the wall below the frame (drawn first so the moulding sits on top).
    sh = Image.new("L", (S, S), 0)
    ImageDraw.Draw(sh).rectangle([px(x0 + 16), px(y1 - 10), px(x1 - 16), px(y1 + 26)], fill=140)
    sh = sh.filter(ImageFilter.GaussianBlur(px(16)))
    img = Image.composite(Image.new("RGB", (S, S), (0x06, 0x05, 0x05)), img, sh)
    d = ImageDraw.Draw(img)
    # Bevelled moulding: lit top/left faces, shadowed bottom/right faces.
    outer = [(px(x0), px(y0)), (px(x1), px(y0)), (px(x1), px(y1)), (px(x0), px(y1))]
    inner = [(px(x0 + bw), px(y0 + bw)), (px(x1 - bw), px(y0 + bw)),
             (px(x1 - bw), px(y1 - bw)), (px(x0 + bw), px(y1 - bw))]
    d.polygon([outer[0], outer[1], inner[1], inner[0]], fill=GILT)          # top
    d.polygon([outer[0], inner[0], inner[3], outer[3]], fill=GILT)          # left
    d.polygon([outer[1], outer[2], inner[2], inner[1]], fill=GILT_DEEP)     # right
    d.polygon([outer[3], inner[3], inner[2], outer[2]], fill=GILT_DEEP)     # bottom
    # Canvas: dark, with the light pooling at the top edge.
    cx0, cy0, cx1, cy1 = x0 + bw, y0 + bw, x1 - bw, y1 - bw
    lit = glow(Image.new("RGB", (S, S), SURFACE), (512, cy0 - 30), (300, 260), (0x4A, 0x3F, 0x2E), 1.0)
    img.paste(lit.crop((px(cx0), px(cy0), px(cx1), px(cy1))), (px(cx0), px(cy0)))
    d = ImageDraw.Draw(img)
    d.rectangle([px(cx0), px(cy0), px(cx1), px(cy0 + 5)], fill=CANVAS)      # rebate shadow
    return finish(img)


# --- Candidate 3: auction gavel ----------------------------------------------------------------

def gavel() -> Image.Image:
    img = ground()
    img = glow(img, (512, 470), (440, 440), (0x33, 0x2B, 0x20), 1.0)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = S // 2
    # Drawn upright (head on top, handle down), then rotated into a striking pose.
    hw, hh = px(320), px(140)  # head length, diameter
    hx0, hy0 = c - hw // 2, c - px(300)
    d.rounded_rectangle([hx0, hy0, hx0 + hw, hy0 + hh], radius=px(22), fill=GILT)
    band = px(30)
    for bx in (hx0 + px(26), hx0 + hw - px(26) - band):
        d.rectangle([bx, hy0 - px(10), bx + band, hy0 + hh + px(10)], fill=GILT)
        d.rectangle([bx + px(7), hy0 - px(10), bx + px(11), hy0 + hh + px(10)], fill=GILT_DEEP)
    top_w, bot_w = px(42), px(56)
    hy1 = hy0 + hh
    length = px(440)
    d.polygon([(c - top_w // 2, hy1), (c + top_w // 2, hy1),
               (c + bot_w // 2, hy1 + length), (c - bot_w // 2, hy1 + length)], fill=GILT)
    d.ellipse([c - px(38), hy1 + length - px(28), c + px(38), hy1 + length + px(48)], fill=GILT)
    layer = layer.rotate(120, resample=Image.BICUBIC, center=(c, c))
    # Sounding block under the lowest point of the head; then centre gavel + block together.
    alpha = layer.getchannel("A")
    l, t, r, b = alpha.getbbox()
    row = alpha.crop((l, b - px(4), r, b)).getbbox()
    strike_x = l + (row[0] + row[2]) // 2
    block_w, block_h = px(360), px(56)
    block = [strike_x - block_w // 2, b, strike_x + block_w // 2, b + block_h]
    gl, gt, gr, gb = min(l, block[0]), t, max(r, block[2]), block[3]
    dx, dy = (S - (gr - gl)) // 2 - gl, (S - (gb - gt)) // 2 - gt
    img.paste(layer, (dx, dy), layer)
    d2 = ImageDraw.Draw(img)
    d2.rounded_rectangle([block[0] + dx, block[1] + dy, block[2] + dx, block[3] + dy], radius=px(12), fill=ELEVATED)
    d2.rectangle([block[0] + dx, block[1] + dy, block[2] + dx, block[1] + dy + px(6)], fill=GILT_DEEP)
    return finish(img)


CANDIDATES = {"monogram": monogram, "frame": frame, "gavel": gavel}
ORDER = ["monogram", "frame", "gavel"]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", choices=ORDER)
    ap.add_argument("--install", action="store_true", help="copy the (single) candidate into AppIcon.appiconset")
    ap.add_argument("--out", type=Path, default=OUT_DIR)
    args = ap.parse_args()
    names = [args.only] if args.only else ORDER
    if args.install and len(names) != 1:
        ap.error("--install needs --only <candidate>")
    args.out.mkdir(parents=True, exist_ok=True)
    for i, name in enumerate(names, start=1):
        number = ORDER.index(name) + 1
        img = CANDIDATES[name]()
        path = args.out / f"icon-{number}-{name}.png"
        img.save(path, optimize=True)
        print(path.relative_to(ROOT) if path.is_relative_to(ROOT) else path)
        if args.install:
            img.save(APPICON, optimize=True)
            print(f"installed -> {APPICON.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
