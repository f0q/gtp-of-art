"""Metadata + image-URL resolvers for each image source (Met, AIC, CMA, Rijksmuseum, Commons).

Each resolver returns a dict:
  {source, source_url (download), landing_url, licence, credit, width, height, raw}
or raises ValueError when the object is not openly licensed.
"""
from __future__ import annotations

import re
from urllib.parse import quote

from . import http

AIC_IIIF = "https://www.artic.edu/iiif/2/{id}/full/{w},/0/default.jpg"
AIC_MAX_W = 1686  # AIC serves at most 1686 px wide and refuses (403) widths above the source
_TAG = re.compile(r"<[^>]+>")


def strip_html(s: str | None) -> str:
    return re.sub(r"\s+", " ", _TAG.sub("", s or "")).strip()


def met(object_id: str) -> dict:
    d = http.get_json(f"https://collectionapi.metmuseum.org/public/collection/v1/objects/{object_id}")
    if not d.get("isPublicDomain"):
        raise ValueError(f"Met {object_id} is not marked public domain")
    if not d.get("primaryImage"):
        raise ValueError(f"Met {object_id} has no primaryImage")
    return {
        "source": "met", "source_url": d["primaryImage"], "landing_url": d["objectURL"],
        "licence": "CC0", "credit": "The Metropolitan Museum of Art, " + (d.get("creditLine") or "Open Access"),
        "width": None, "height": None, "raw": d,
        "holder": "The Metropolitan Museum of Art, New York",
        "dimensions": d.get("dimensions"), "medium": d.get("medium"),
    }


def aic(object_id: str) -> dict:
    d = http.get_json(f"https://api.artic.edu/api/v1/artworks/{object_id}",
                      {"fields": "id,title,is_public_domain,image_id,artist_display,date_display,"
                                 "medium_display,dimensions,credit_line,thumbnail,color"})["data"]
    if not d.get("is_public_domain"):
        raise ValueError(f"AIC {object_id} is not public domain")
    if not d.get("image_id"):
        raise ValueError(f"AIC {object_id} has no image")
    th = d.get("thumbnail") or {}
    w = min(AIC_MAX_W, int(th.get("width") or AIC_MAX_W))
    return {
        "source": "aic", "source_url": AIC_IIIF.format(id=d["image_id"], w=w),
        "landing_url": f"https://www.artic.edu/artworks/{object_id}",
        "licence": "CC0", "credit": "Art Institute of Chicago, " + (d.get("credit_line") or "CC0"),
        "width": th.get("width"), "height": th.get("height"), "raw": d,
        "holder": "Art Institute of Chicago", "dimensions": d.get("dimensions"),
        "medium": d.get("medium_display"),
    }


def cma(object_id: str) -> dict:
    d = http.get_json(f"https://openaccess-api.clevelandart.org/api/artworks/{object_id}")["data"]
    if d.get("share_license_status") != "CC0":
        raise ValueError(f"CMA {object_id} is not CC0")
    imgs = d.get("images") or {}
    best = imgs.get("print") or imgs.get("web")
    if not best:
        raise ValueError(f"CMA {object_id} has no image")
    return {
        "source": "cma", "source_url": best["url"], "landing_url": d.get("url"),
        "licence": "CC0", "credit": "The Cleveland Museum of Art, " + (d.get("creditline") or "CC0"),
        "width": int(best.get("width") or 0) or None, "height": int(best.get("height") or 0) or None,
        "raw": d, "holder": "The Cleveland Museum of Art", "dimensions": None,
        "medium": d.get("technique"),
    }


def rijks(object_number: str) -> dict:
    """Rijksmuseum: resolve via the public Linked Art search (no key) to a IIIF image."""
    prof = {"_profile": "la-framed", "_mediatype": "application/ld+json"}
    data = lambda uri: http.get_json(uri.replace("https://id.rijksmuseum.nl", "https://data.rijksmuseum.nl"), prof)
    s = http.get_json("https://data.rijksmuseum.nl/search/collection", {"objectNumber": object_number})
    items = s.get("orderedItems") or []
    if not items:
        raise ValueError(f"Rijks {object_number} not found")
    obj = data(items[0]["id"])
    img, rights = None, ""
    for vis in obj.get("shows", []):
        v = data(vis["id"])
        rights = " ".join(n.get("content", "") for r in v.get("subject_to", []) for n in r.get("identified_by", []))
        for dobj in v.get("digitally_shown_by", []):
            for ap in data(dobj["id"]).get("access_point", []):
                img = ap["id"]
                break
    if not img:
        raise ValueError(f"Rijks {object_number}: no image access point")
    if "public domain" not in rights.lower() and "cc0" not in rights.lower():
        raise ValueError(f"Rijks {object_number}: rights '{rights}' not PD/CC0")
    img = re.sub(r"/full/[^/]+/", "/full/!2400,2400/", img)
    return {
        "source": "rijks", "source_url": img,
        "landing_url": f"https://www.rijksmuseum.nl/en/collection/{object_number}",
        "licence": "CC0", "credit": "Rijksmuseum, Amsterdam (public domain)", "width": None, "height": None,
        "raw": {"object": items[0]["id"]}, "holder": "Rijksmuseum, Amsterdam", "dimensions": None,
        "medium": None,
    }


_PD_LICENCES = re.compile(r"^(pd|public domain|cc0|cc-zero|pd-art|pd-old)", re.I)


def commons(file_title: str) -> dict:
    title = file_title if file_title.startswith("File:") else "File:" + file_title
    d = http.get_json("https://commons.wikimedia.org/w/api.php", {
        "action": "query", "titles": title, "prop": "imageinfo", "format": "json",
        "iiprop": "url|size|extmetadata|sha1|mime", "iiurlwidth": "1920", "redirects": "1"})
    pages = list(d["query"]["pages"].values())
    if not pages or "imageinfo" not in pages[0]:
        raise ValueError(f"Commons file not found: {title}")
    ii = pages[0]["imageinfo"][0]
    em = ii.get("extmetadata", {})
    lic = strip_html(em.get("LicenseShortName", {}).get("value"))
    usage = strip_html(em.get("UsageTerms", {}).get("value"))
    cats = em.get("Categories", {}).get("value", "")
    if not (_PD_LICENCES.match(lic) or "public domain" in usage.lower()):
        raise ValueError(f"Commons {title}: licence not PD/CC0 ({lic})")
    if "PD-Art" in cats or "pd-art" in lic.lower() or "PD-Art" in usage:
        licence = "PD-Art"
    elif "cc0" in lic.lower() or "cc-zero" in lic.lower():
        licence = "CC0"
    else:
        licence = "PD"
    credit = strip_html(em.get("Credit", {}).get("value"))
    src = ii.get("thumburl") if ii["width"] > 1920 else ii["url"]
    return {
        "source": "commons", "source_url": src, "landing_url": ii["descriptionurl"],
        "licence": licence, "credit": credit, "width": ii["width"], "height": ii["height"],
        "raw": {"title": pages[0]["title"], "licence_short": lic, "artist": strip_html(em.get("Artist", {}).get("value")),
                "mime": ii.get("mime")},
        "holder": None, "dimensions": None, "medium": None,
    }


RESOLVERS = {"met": met, "aic": aic, "cma": cma, "rijks": rijks, "commons": commons}
