"""Stages: download, process_images, palette_features.

Masters: tools/out/images/{id}_lg.jpg (1600 long edge) and {id}_sm.jpg (600), sRGB, JPEG q85
progressive, EXIF/ICC metadata stripped (sRGB implied), never upscaled. `make assets` turns them
into HEIC for the app bundle.
"""
from __future__ import annotations

import colorsys
import hashlib
import io
from pathlib import Path

from PIL import Image, ImageCms, ImageFilter, ImageOps

from . import http

Image.MAX_IMAGE_PIXELS = 400_000_000
TOOLS = Path(__file__).resolve().parent.parent
OUT = TOOLS / "out"
ORIG = OUT / "originals"
MASTERS = OUT / "images"
LG, SM = 1600, 600
_SRGB = ImageCms.createProfile("sRGB")


def download(source_url: str) -> tuple[bytes, str]:
    """Return (bytes, sha256). Cached by URL in tools/cache/."""
    b = http.get_bytes(source_url, timeout=180)
    return b, hashlib.sha256(b).hexdigest()


def _to_srgb(im: Image.Image) -> Image.Image:
    icc = im.info.get("icc_profile")
    if im.mode in ("I;16", "I", "F"):
        im = im.point(lambda v: v / 256).convert("L")
    if icc:
        try:
            src = ImageCms.ImageCmsProfile(io.BytesIO(icc))
            if im.mode not in ("RGB", "RGBA", "L", "CMYK"):
                im = im.convert("RGB")
            out_mode = "RGB"
            im = ImageCms.profileToProfile(im, src, _SRGB, outputMode=out_mode,
                                           renderingIntent=ImageCms.Intent.PERCEPTUAL)
        except Exception:
            im = im.convert("RGB")
    return im.convert("RGB")


def open_rgb(data: bytes) -> Image.Image:
    im = Image.open(io.BytesIO(data))
    im = ImageOps.exif_transpose(im)
    return _to_srgb(im)


def _fit(im: Image.Image, long_edge: int) -> Image.Image:
    w, h = im.size
    if max(w, h) <= long_edge:
        return im.copy()
    s = long_edge / max(w, h)
    return im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)


def process(work_id: str, data: bytes) -> dict:
    """Write lg/sm masters (idempotent: skipped if already newer than nothing changed)."""
    MASTERS.mkdir(parents=True, exist_ok=True)
    im = open_rgb(data)
    out = {"source_w": im.size[0], "source_h": im.size[1]}
    for tag, edge in (("lg", LG), ("sm", SM)):
        p = MASTERS / f"{work_id}_{tag}.jpg"
        r = _fit(im, edge)
        buf = io.BytesIO()
        r.save(buf, "JPEG", quality=85, progressive=True, optimize=True)  # no exif/icc passed => stripped
        b = buf.getvalue()
        if not p.exists() or p.read_bytes() != b:
            p.write_bytes(b)
        out[tag] = {"path": str(p), "w": r.size[0], "h": r.size[1], "bytes": len(b)}
    out["lg_missing"] = max(im.size) < LG
    out["image"] = im
    return out


def features(im: Image.Image) -> dict:
    """Raw image features on a 64x64 thumbnail (HSV) + edge density on 256 px grey."""
    small = im.copy()
    small.thumbnail((64, 64), Image.LANCZOS)
    px = list(small.getdata())
    hs = [colorsys.rgb_to_hsv(r / 255, g / 255, b / 255) for r, g, b in px]
    n = len(hs)
    sat = sum(s for _, s, _ in hs) / n
    val = sum(v for _, _, v in hs) / n
    wsum = sum(s for _, s, _ in hs) or 1e-9
    warm = sum(s for h, s, _ in hs if (h * 360 >= 330 or h * 360 <= 70)) / wsum
    g = im.convert("L")
    g.thumbnail((256, 256), Image.LANCZOS)
    e = g.filter(ImageFilter.FIND_EDGES)
    ed = sum(1 for v in e.getdata() if v > 40) / (e.size[0] * e.size[1])
    q = small.quantize(colors=5, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()[:15]
    counts = sorted(q.getcolors(), reverse=True)
    palette = []
    for _, idx in counts:
        r, gg, b = pal[idx * 3: idx * 3 + 3]
        palette.append(f"#{r:02X}{gg:02X}{b:02X}")
    return {"saturation_raw": sat, "brightness_raw": val, "warmth_raw": warm, "edge_density": ed,
            "palette": palette, "dominant_hex": palette[0]}


def to_100(x: float) -> int:
    return max(0, min(100, round(x)))


def scale_scalars(raw: dict, edge_rank_pct: float) -> dict:
    """Map raw features to the integer 0-100 scales of spec §16.1.

    warmth: saturation-weighted share of warm hues (x100).
    saturation: mean S mapped so 0.25 -> 33.5 and 0.45 -> 66.5 (paintings rarely exceed 0.7).
    brightness: mean V mapped so 0.38 (the 'dark' cut-off of Part E7) -> 33.5 and 0.62 -> 66.5.
    complexity: dataset percentile of edge density.
    """
    sat = 33.5 + (raw["saturation_raw"] - 0.25) / 0.20 * 33
    bri = 33.5 + (raw["brightness_raw"] - 0.38) / 0.24 * 33
    return {"warmth": to_100(raw["warmth_raw"] * 100), "saturation": to_100(sat),
            "brightness": to_100(bri), "complexity": to_100(edge_rank_pct)}
