#!/usr/bin/env python3
"""Record the owner's contact-sheet sign-off in tools/curation/signoff.json.

The validator expects {"<work_id>": "<image sha256>"}; a work is signed off only while its
image hash matches, so a replaced image automatically needs a fresh look.

Usage:
  python3 tools/signoff.py                       # show current status
  python3 tools/signoff.py --approve-all         # approve every work in Resources/dataset.json
  python3 tools/signoff.py --approve-all --reject id1 id2   # approve all except these ids
  python3 tools/signoff.py --approve id1 id2     # approve only these (keeps earlier approvals)
  python3 tools/signoff.py --reject id1          # withdraw approval for these ids
  python3 tools/signoff.py --from-reviews        # apply tools/curation/reviews.json (make review)
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATASET = ROOT / "Resources" / "dataset.json"
SIGNOFF = ROOT / "tools" / "curation" / "signoff.json"
REVIEWS = ROOT / "tools" / "curation" / "reviews.json"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--approve-all", action="store_true")
    ap.add_argument("--approve", nargs="*", default=[], metavar="ID")
    ap.add_argument("--reject", nargs="*", default=[], metavar="ID")
    ap.add_argument("--from-reviews", action="store_true", help="apply verdicts recorded by tools/review_server.py")
    args = ap.parse_args()

    works = {a["id"]: a["images"]["primary"].get("sha256") for a in json.loads(DATASET.read_text())["artworks"]}
    current = json.loads(SIGNOFF.read_text()) if SIGNOFF.exists() else {}
    unknown = [i for i in args.approve + args.reject if i not in works]
    if unknown:
        print("unknown work id(s):", ", ".join(unknown), file=sys.stderr)
        print("ids look like 'turner-seascape-folkestone' (shown under each image on the contact sheet)", file=sys.stderr)
        return 2

    if args.from_reviews:
        reviews = json.loads(REVIEWS.read_text()) if REVIEWS.exists() else {}
        rejected = []
        for i, r in reviews.items():
            if i not in works:
                continue
            if r.get("status") == "approved" and r.get("sha") == works[i]:
                current[i] = works[i]
            else:
                current.pop(i, None)
                if r.get("status") == "rejected":
                    rejected.append(f"{i} ({r.get('reason', '?')}{': ' + r['note'] if r.get('note') else ''})")
        if rejected:
            print("rejected:\n  " + "\n  ".join(rejected))
    if args.approve_all:
        current = dict(works)
    for i in args.approve:
        current[i] = works[i]
    for i in args.reject:
        current.pop(i, None)

    if args.from_reviews or args.approve_all or args.approve or args.reject:
        SIGNOFF.parent.mkdir(parents=True, exist_ok=True)
        SIGNOFF.write_text(json.dumps(dict(sorted(current.items())), indent=2) + "\n")
        print(f"wrote {SIGNOFF.relative_to(ROOT)}")

    ok = [i for i, h in works.items() if current.get(i) == h]
    pending = [i for i in works if i not in ok]
    print(f"signed off: {len(ok)} / {len(works)}")
    if pending:
        print("not signed off:", ", ".join(pending))
    return 0


if __name__ == "__main__":
    sys.exit(main())
