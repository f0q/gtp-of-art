#!/usr/bin/env python3
"""Export the click-to-approve contact sheet as a folder you can open from any disk or computer.

    python3 tools/export_review.py             # -> tools/out/review/ (index.html + images/) and tools/out/GTP-review.zip
    python3 tools/export_review.py --dest ~/Desktop/GTP-review
    python3 tools/export_review.py --only-unsigned --dest tools/out/review-v1 --zip-name GTP-review-v1
        # only works missing from tools/curation/signoff.json or whose image sha256 changed

Open index.html in a browser. Taps are remembered in that browser; "Save decisions" writes reviews.json.
Put that file at tools/curation/reviews.json and run `make signoff`.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from review_server import DATASET, IMAGES, ROOT, build_page  # noqa: E402

SIGNOFF = ROOT / "tools" / "curation" / "signoff.json"


def unsigned_ids() -> set[str]:
    """Artwork ids not in signoff.json, or signed off for a different image (sha256 changed)."""
    signed = json.loads(SIGNOFF.read_text()) if SIGNOFF.exists() else {}
    d = json.loads(DATASET.read_text())
    return {a["id"] for a in d["artworks"] if signed.get(a["id"]) != a["images"]["primary"]["sha256"]}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dest", type=Path, default=ROOT / "tools" / "out" / "review")
    ap.add_argument("--no-zip", action="store_true")
    ap.add_argument("--only-unsigned", action="store_true",
                    help="include only works missing from signoff.json (or whose image changed)")
    ap.add_argument("--zip-name", help="zip base name (default: derived from --dest)")
    args = ap.parse_args()
    if not IMAGES.exists():
        print("tools/out/images is missing: run `make dataset` first", file=sys.stderr)
        return 1
    dest = args.dest.expanduser()
    if dest.exists():
        shutil.rmtree(dest)
    (dest / "images").mkdir(parents=True)
    only = unsigned_ids() if args.only_unsigned else None
    n = 0
    for f in IMAGES.glob("*.jpg"):
        if only is not None and f.name.rsplit("_", 1)[0] not in only:
            continue
        shutil.copy2(f, dest / "images" / f.name)
        n += 1
    (dest / "index.html").write_bytes(build_page(mode="static", only=only))
    extra = f" ({len(only)} unsigned works)" if only is not None else ""
    print(f"wrote {dest}/index.html + {n} images{extra}")
    if not args.no_zip:
        base = args.zip_name or dest.name.replace('review', 'GTP-review')
        z = shutil.make_archive(str(dest.parent / base), "zip", dest.parent, dest.name)
        print(f"zip: {z} ({Path(z).stat().st_size / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
