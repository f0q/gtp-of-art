"""Cached, rate-limited HTTP GETs.

Every response body is stored under tools/cache/<host>/<sha256(url)>.{json,bin} with a small
.meta.json sidecar, so reruns are offline. `OFFLINE=True` turns a cache miss into an error.
"""
from __future__ import annotations

import hashlib
import json
import os
import random
import time
from pathlib import Path
from urllib.parse import urlencode, urlparse

import requests

TOOLS = Path(__file__).resolve().parent.parent
CACHE = TOOLS / "cache"
OFFLINE = False

UA = "ArtPriceGame-dev/0.1 (dataset pipeline; contact: {})".format(
    os.environ.get("AIC_CONTACT", "TODO_OWNER_EMAIL"))
AIC_UA = "ArtPriceGame-dev (contact: {})".format(os.environ.get("AIC_CONTACT", "TODO_OWNER_EMAIL"))

# minimum seconds between requests per host
_MIN_GAP = {
    "collectionapi.metmuseum.org": 0.3,
    "images.metmuseum.org": 0.11,
    "api.artic.edu": 1.05,
    "www.artic.edu": 1.05,
    "openaccess-api.clevelandart.org": 0.25,
    "query.wikidata.org": 1.0,
    "www.wikidata.org": 0.3,
    "commons.wikimedia.org": 0.3,
    "upload.wikimedia.org": 0.5,
    "en.wikipedia.org": 0.3,
    "web.archive.org": 1.5,
    "archive.org": 1.5,
}
_last: dict[str, float] = {}
_session = requests.Session()
stats = {"hit": 0, "miss": 0}
BROWSER_UA_HOSTS = {"fred.stlouisfed.org", "www.minneapolisfed.org"}


class OfflineMiss(RuntimeError):
    pass


def full_url(url: str, params: dict | None = None) -> str:
    if params:
        url = url + ("&" if "?" in url else "?") + urlencode(params)
    return url


def _key(url: str) -> tuple[Path, str]:
    host = urlparse(url).netloc or "misc"
    h = hashlib.sha256(url.encode()).hexdigest()
    return CACHE / host, h


def _headers_for(url: str) -> dict:
    host = urlparse(url).netloc
    h = {"User-Agent": UA}
    if host in BROWSER_UA_HOSTS:  # these tarpit non-browser agents
        h["User-Agent"] = "Mozilla/5.0 (Macintosh) " + UA
    if "artic.edu" in host:
        h["AIC-User-Agent"] = AIC_UA
    if host == "query.wikidata.org":
        h["Accept"] = "application/sparql-results+json"
    return h


def _throttle(host: str) -> None:
    gap = _MIN_GAP.get(host, 0.2)
    now = time.monotonic()
    wait = _last.get(host, 0) + gap - now
    if wait > 0:
        time.sleep(wait)
    _last[host] = time.monotonic()


def cached_path(url: str, params: dict | None = None) -> Path | None:
    url = full_url(url, params)
    d, h = _key(url)
    p = d / (h + ".bin")
    return p if p.exists() else None


def get_bytes(url: str, params: dict | None = None, *, retries: int = 6, timeout: int = 60,
              allow_404: bool = False) -> bytes | None:
    """GET with cache. Returns None for a cached/actual 404 when allow_404."""
    url = full_url(url, params)
    d, h = _key(url)
    body_p, meta_p = d / (h + ".bin"), d / (h + ".meta.json")
    if meta_p.exists():
        meta = json.loads(meta_p.read_text())
        if meta.get("status") == 404:
            stats["hit"] += 1
            if allow_404:
                return None
            raise RuntimeError(f"404 (cached) {url}")
        if body_p.exists():
            stats["hit"] += 1
            return body_p.read_bytes()
    if OFFLINE:
        raise OfflineMiss(url)
    stats["miss"] += 1
    host = urlparse(url).netloc
    delay = 2.0
    last_err = None
    for attempt in range(retries):
        _throttle(host)
        try:
            r = _session.get(url, headers=_headers_for(url), timeout=timeout, stream=True)
            started, chunks = time.monotonic(), []
            for chunk in r.iter_content(65536):
                chunks.append(chunk)
                if time.monotonic() - started > 4 * timeout:  # tarpits trickle bytes forever
                    raise requests.Timeout(f"total time > {4 * timeout}s")
            r._content = b"".join(chunks)
        except requests.RequestException as e:  # timeouts, resets
            last_err = e
        else:
            if r.status_code == 200:
                d.mkdir(parents=True, exist_ok=True)
                body_p.write_bytes(r.content)
                meta_p.write_text(json.dumps({"url": url, "status": 200,
                                              "content_type": r.headers.get("content-type"),
                                              "fetched": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}))
                return r.content
            if r.status_code == 404:
                d.mkdir(parents=True, exist_ok=True)
                meta_p.write_text(json.dumps({"url": url, "status": 404}))
                if allow_404:
                    return None
                raise RuntimeError(f"404 {url}")
            if r.status_code in (403, 429) and "metmuseum" in host or r.status_code == 429 or r.status_code >= 500:
                delay = max(delay, 10.0)
                last_err = RuntimeError(f"HTTP {r.status_code} {url}")
                ra = r.headers.get("retry-after")
                if ra and ra.isdigit():
                    delay = min(max(delay, float(ra)), 60.0)
            else:
                raise RuntimeError(f"HTTP {r.status_code} {url}: {r.text[:200]}")
        time.sleep(delay + random.random())
        delay = min(delay * 2, 120)
    raise RuntimeError(f"giving up on {url}: {last_err}")


def get_json(url: str, params: dict | None = None, **kw):
    b = get_bytes(url, params, **kw)
    return None if b is None else json.loads(b)


def sparql(query: str):
    return get_json("https://query.wikidata.org/sparql", {"query": query, "format": "json"},
                    timeout=90)
