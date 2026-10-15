#!/usr/bin/env python3
"""Local contact-sheet review: serves a click-to-approve page and writes verdicts into the repo.

    python3 tools/review_server.py            # http://localhost:8765 (also reachable on the LAN)
    make review                               # same, and opens the browser

Verdicts go to tools/curation/reviews.json as {"<work_id>": {"status", "reason", "note", "sha", "at"}}.
`python3 tools/signoff.py --from-reviews` turns the approvals into tools/curation/signoff.json.
Stdlib only; no network access beyond your own machine.
"""
from __future__ import annotations

import argparse
import json
import os
import socket
import sys
import threading
import webbrowser
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
DATASET = ROOT / "Resources" / "dataset.json"
TAXONOMY = ROOT / "Resources" / "taxonomy.json"
IMAGES = ROOT / "tools" / "out" / "images"
TEMPLATE = ROOT / "tools" / "review" / "template.html"
REVIEWS = ROOT / "tools" / "curation" / "reviews.json"
LOCK = threading.Lock()

TYPE = {"auction_premium": "auction, incl. premium", "auction_hammer": "hammer price",
        "private_sale": "private sale (reported)", "ask_price": "asking price"}


def money(usd: float) -> str:
    if usd >= 1e9:
        return f"${usd / 1e9:.2g}B".replace(".0B", "B")
    if usd >= 1e6:
        return f"${usd / 1e6:.3g}M"
    if usd >= 1e3:
        return f"${usd / 1e3:.3g}K"
    return f"${usd:,.0f}"


def build_page(mode: str = "server", only: set[str] | None = None) -> bytes:
    """Contact-sheet HTML. `only`: restrict to these artwork ids (e.g. works not yet signed off)."""
    d = json.loads(DATASET.read_text())
    tax = json.loads(TAXONOMY.read_text())
    cats = {c["id"]: c["label"] for c in tax["categories"]}
    deps = {c["id"]: c["label"] for c in tax.get("departments", [])}
    works = []
    for a in d["artworks"]:
        if only is not None and a["id"] not in only:
            continue
        im = a["images"]["primary"]
        prices = a["prices"]
        p = next((p for p in prices if p["id"] == a.get("game_price_id")), prices[0] if prices else None)
        price = None
        if p:
            price = {
                "line": f"{money(p['usd_nominal'])} · {p['date'][:4]} · {TYPE.get(p['type'], p['type'])}",
                "detail": f"{p['currency']} {p['amount_minor'] / (1 if p['currency'] in ('JPY', 'KRW', 'ITL', 'ESP') else 100):,.0f} · {p.get('venue') or 'venue not recorded'}"
                          f" · confidence {p.get('confidence', '?')}"
                          + ("" if p.get("game_eligible", True) else " · NOT used in play"),
                "src": p.get("primary_citation") or (p.get("source_urls") or [None])[0],
            }
        works.append({
            "id": a["id"], "title": a["title"], "artist": a["artist"]["display_name"],
            "date": a["date"]["display"], "medium": a["medium"]["display"],
            "category": cats.get(a["category_id"], a["category_id"]),
            "department": deps.get(a["department_id"], a["department_id"]),
            "sm": f"images/{a['id']}_sm.jpg", "lg": f"images/{a['id']}_lg.jpg",
            "w": im["lg"]["w"], "h": im["lg"]["h"],
            "licence": im["licence"], "attribution": im["attribution"], "landing": im.get("landing_url"),
            "depicts": im.get("depicts_scope"), "alt": im.get("alt_text", ""), "sha": im["sha256"], "price": price,
        })
    data = json.dumps(works, ensure_ascii=False).replace("</", "<\\/")
    html = (TEMPLATE.read_text().replace("__DATA__", data).replace("__COUNT__", str(len(works)))
            .replace("__MODE__", mode))
    return html.encode("utf-8")


def load_reviews() -> dict:
    return json.loads(REVIEWS.read_text()) if REVIEWS.exists() else {}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT / "tools" / "out"), **kwargs)

    def log_message(self, fmt, *args):  # quieter log: only API writes
        if self.command == "PUT":
            sys.stderr.write("%s %s\n" % (self.command, self.path))

    def _json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            body = build_page()
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/api/reviews":
            with LOCK:
                self._json(HTTPStatus.OK, load_reviews())
        elif self.path.startswith("/images/"):
            super().do_GET()  # served from tools/out/images
        else:
            self.send_error(HTTPStatus.NOT_FOUND)

    def do_PUT(self):
        if not self.path.startswith("/api/reviews/"):
            return self.send_error(HTTPStatus.NOT_FOUND)
        work_id = unquote(self.path[len("/api/reviews/"):])
        length = int(self.headers.get("Content-Length") or 0)
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
            assert body.get("status") in ("approved", "rejected")
            assert isinstance(body.get("sha"), str)
        except Exception:
            return self._json(HTTPStatus.BAD_REQUEST, {"error": "bad verdict"})
        keep = {k: body.get(k) for k in ("status", "reason", "note", "sha", "title", "at") if body.get(k) is not None}
        with LOCK:
            reviews = load_reviews()
            reviews[work_id] = keep
            REVIEWS.parent.mkdir(parents=True, exist_ok=True)
            tmp = REVIEWS.with_suffix(".json.tmp")
            tmp.write_text(json.dumps(dict(sorted(reviews.items())), indent=2, ensure_ascii=False) + "\n")
            os.replace(tmp, REVIEWS)
        self._json(HTTPStatus.OK, {"ok": True, "count": len(reviews)})


def lan_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("10.255.255.255", 1))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except OSError:
        return "127.0.0.1"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--open", action="store_true", help="open the page in the default browser")
    ap.add_argument("--local-only", action="store_true", help="bind 127.0.0.1 only (no iPhone access)")
    args = ap.parse_args()
    if not IMAGES.exists():
        print("tools/out/images is missing: run `make dataset` first", file=sys.stderr)
        return 1
    host = "127.0.0.1" if args.local_only else "0.0.0.0"
    srv = ThreadingHTTPServer((host, args.port), Handler)
    print(f"Review page:  http://localhost:{args.port}")
    if not args.local_only:
        print(f"On your iPhone (same Wi-Fi): http://{lan_ip()}:{args.port}")
    print("Verdicts are written to tools/curation/reviews.json. Press Ctrl-C to stop.")
    if args.open:
        threading.Timer(0.5, lambda: webbrowser.open(f"http://localhost:{args.port}")).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
