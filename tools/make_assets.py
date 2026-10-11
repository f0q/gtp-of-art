#!/usr/bin/env python3
"""Convert JPEG masters (tools/out/images) into the app's HEIC bundle (Resources/Artworks) with sips.

For each artwork in Resources/dataset.json:
  priced pool   -> {id}_full.heic (1440 long edge) + {id}_thumb.heic (480)
  unpriced pool -> {id}_card.heic (1080 long edge) + {id}_thumb.heic (480)
Never upscales. Then patches w/h/bytes in dataset.json, removes stale HEIC files, re-runs the
validator with byte checks, and reports total bundle bytes.

Usage: tools/.venv/bin/python tools/make_assets.py [--src tools/out/images] [--dst Resources/Artworks]
       [--quality 60] [--force]
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
from artpipe import emit, validate  # noqa: E402

ROOT = TOOLS.parent


def sips_dims(p: Path) -> tuple[int, int]:
    o = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(p)], capture_output=True, text=True,
                       check=True).stdout
    return int(re.search(r"pixelWidth: (\d+)", o).group(1)), int(re.search(r"pixelHeight: (\d+)", o).group(1))


def convert(src: Path, dst: Path, edge: int, quality: int, force: bool) -> None:
    if dst.exists() and not force and dst.stat().st_mtime >= src.stat().st_mtime:
        return
    w, h = sips_dims(src)
    tmp = dst.with_suffix(".tmp.heic")
    cmd = ["sips", "-s", "format", "heic", "-s", "formatOptions", str(quality)]
    if max(w, h) > edge:
        cmd += ["-Z", str(edge)]
    subprocess.run(cmd + [str(src), "--out", str(tmp)], check=True, capture_output=True)
    # strip metadata sips may carry over (none expected: masters have no EXIF); keep sRGB profile
    tmp.replace(dst)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=str(TOOLS / "out" / "images"))
    ap.add_argument("--dst", default=str(ROOT / "Resources" / "Artworks"))
    ap.add_argument("--dataset", default=str(ROOT / "Resources" / "dataset.json"))
    ap.add_argument("--quality", type=int, default=60)
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    src, dst = Path(a.src), Path(a.dst)
    dst.mkdir(parents=True, exist_ok=True)
    doc = json.loads(Path(a.dataset).read_text())
    wanted = set()
    totals = {"full": 0, "card": 0, "thumb": 0}
    for w in doc["artworks"]:
        im = w["images"]["primary"]
        for tag, master in (("lg", f"{w['id']}_lg.jpg"), ("sm", f"{w['id']}_sm.jpg")):
            rend = im[tag]
            kind = rend["file"].rsplit("_", 1)[1].split(".")[0]
            edge = {"full": 1440, "card": 1080, "thumb": 480}[kind]
            m = src / master
            if not m.exists():
                print(f"missing master {m} (run make dataset)"); return 2
            out = dst / rend["file"]
            convert(m, out, edge, a.quality, a.force)
            rend["w"], rend["h"] = sips_dims(out)
            rend["bytes"] = out.stat().st_size
            totals[kind] += rend["bytes"]
            wanted.add(rend["file"])
    for f in dst.glob("*.heic"):
        if f.name not in wanted:
            print(f"removing stale {f.name}"); f.unlink()
    emit.write_json(Path(a.dataset), doc)
    manifest = {f.name: dict(zip(("w", "h"), sips_dims(f)), bytes=f.stat().st_size)
                for f in sorted(dst.glob("*.heic"))}
    emit.write_json(TOOLS / "out" / "heic_manifest.json", manifest)
    cred = json.loads((ROOT / "Resources" / "credits.json").read_text())
    rep = validate.run(doc, cred, check_bytes=True)
    for e in rep.errors:
        print("ERROR", e)
    over = [x for x in rep.warnings if "bytes >" in x]
    for x in over:
        print("WARN", x)
    total = sum(totals.values())
    print(f"HEIC files: {len(wanted)}  full {totals['full']:,} B  card {totals['card']:,} B  "
          f"thumb {totals['thumb']:,} B  TOTAL {total:,} B ({total / 1e6:.1f} MB)")
    print(f"validator: {len(rep.errors)} errors, {len(rep.warnings)} warnings")
    return 1 if rep.errors else 0


if __name__ == "__main__":
    sys.exit(main())
