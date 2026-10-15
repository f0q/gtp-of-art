"""Taxonomy: 29 active categories (20 movements + 9 media) in 7 departments + sculpture reserved inactive.

All teaching copy is original to this project. Emitted to Resources/taxonomy.json.
Fields per spec §8.3 / Part E5: id, label, axis, era{start,end}, parent, teach, tells[3],
neighbours, confusers, min_quiz_items, active.
"""
from __future__ import annotations

MIN_QUIZ_V0 = 4      # v0 setting (Part I4): 91-work dataset
MIN_QUIZ_V1_TARGET = 8
MIN_QUIZ = MIN_QUIZ_V1_TARGET   # v1 (Part J3): back to 8 ...
MIN_QUIZ_LOW: dict[str, int] = {}  # ... except categories that cannot reach 8 works yet (filled below)

# Part J2: seven departments, each category in exactly one (sculpture is reserved/inactive and unassigned)
DEPARTMENTS = [
    ("old_masters", "Old Masters", ["byzantine_gothic", "renaissance_it", "renaissance_north", "baroque",
                                    "dutch_golden_age", "rococo", "old_master_drawing"]),
    ("nineteenth_century", "19th Century", ["neoclassicism", "romanticism", "realism", "academic", "pre_raphaelite",
                                            "watercolour_drawing"]),
    ("impressionist_modern", "Impressionist & Modern", ["impressionism", "post_impressionism", "pointillism",
                                                         "symbolism", "art_nouveau", "fauvism", "expressionism",
                                                         "cubism", "early_abstraction", "school_of_paris"]),
    ("asian_art", "Asian Art", ["ukiyo_e", "chinese_ink"]),
    ("prints_multiples", "Prints & Multiples", ["print", "modern_print"]),
    ("photographs", "Photographs", ["early_photography"]),
    ("posters", "Vintage Posters", ["poster"]),
]
DEPT_OF = {c: d for d, _, cs in DEPARTMENTS for c in cs}


def departments() -> list[dict]:
    return [{"id": d, "label": label, "categories": cs} for d, label, cs in DEPARTMENTS]

# id: (label, axis, start, end, parent, teach, tells, neighbours, confusers)
CATS = {
 "byzantine_gothic": ("Byzantine & Gothic", "movement", 1100, 1450, None,
   "Sacred images made to glow in candlelight: gold grounds, flat bodies and size that signals importance.",
   ["Gold-leaf background", "Flat, elongated figures", "Holy figures drawn larger than others"],
   ["renaissance_it", "renaissance_north"], ["symbolism", "art_nouveau"]),
 "renaissance_it": ("Italian Renaissance", "movement", 1400, 1600, None,
   "Painters rebuilt space with geometry and modelled faces in soft light, reviving classical ideals.",
   ["One-point perspective", "Stable pyramid compositions", "Sfumato: smoky, soft transitions"],
   ["renaissance_north", "byzantine_gothic", "baroque"], ["neoclassicism", "academic"]),
 "renaissance_north": ("Northern Renaissance", "movement", 1420, 1600, None,
   "Flemish and German painters used oil glazes for microscopic detail and everyday symbolism.",
   ["Jewel-like detail", "Crisp outlines", "Domestic objects carrying symbols"],
   ["renaissance_it", "dutch_golden_age", "byzantine_gothic"], ["pre_raphaelite", "old_master_drawing"]),
 "baroque": ("Baroque", "movement", 1600, 1750, None,
   "Drama for the senses: deep shadows, sudden light and bodies caught mid-action.",
   ["Strong chiaroscuro", "Diagonal, surging action", "Theatrical gestures"],
   ["dutch_golden_age", "rococo", "renaissance_it"], ["romanticism", "academic"]),
 "dutch_golden_age": ("Dutch Golden Age", "movement", 1600, 1700, "baroque",
   "A merchant republic bought pictures of its own world: quiet rooms, laden tables, flat horizons.",
   ["Quiet domestic interiors", "Still lifes with glinting reflections", "Low horizons under big skies"],
   ["baroque", "renaissance_north", "rococo"], ["realism", "romanticism"]),
 "rococo": ("Rococo", "movement", 1720, 1790, None,
   "Lightness after Baroque grandeur: pastel colour, curling forms and aristocrats at leisure.",
   ["Pastel palette", "Frothy, curving forms", "Scenes of aristocratic leisure"],
   ["baroque", "neoclassicism", "dutch_golden_age"], ["academic", "impressionism"]),
 "neoclassicism": ("Neoclassicism", "movement", 1760, 1840, None,
   "A return to ancient Greece and Rome: clear outlines, noble poses and smooth, cool surfaces.",
   ["Crisp contours", "Frieze-like poses", "Cool, polished surfaces"],
   ["romanticism", "rococo", "academic"], ["renaissance_it", "pre_raphaelite"]),
 "romanticism": ("Romanticism", "movement", 1790, 1860, None,
   "Feeling over reason: storms, struggle and nature too big for people to master.",
   ["Stormy skies and seas", "Heroic struggle", "Expressive, dramatic light"],
   ["neoclassicism", "realism", "academic"], ["baroque", "symbolism", "expressionism"]),
 "realism": ("Realism", "movement", 1840, 1890, None,
   "Painting the world as it is: ordinary work, plain people and no idealising.",
   ["Labourers and peasants", "Earthy palette", "Unglamorous subjects"],
   ["romanticism", "impressionism", "academic"], ["dutch_golden_age", "post_impressionism"]),
 "academic": ("Academic art", "movement", 1830, 1910, None,
   "The official style of the art schools and Salons: flawless finish and classical subjects.",
   ["Invisible brushwork", "Mythological nudes", "Porcelain-smooth skin"],
   ["neoclassicism", "realism", "pre_raphaelite", "romanticism"], ["rococo", "renaissance_it"]),
 "pre_raphaelite": ("Pre-Raphaelite", "movement", 1848, 1900, None,
   "Young British painters looked back before Raphael for truth to nature and vivid colour.",
   ["Jewel greens and reds", "Flowing, abundant hair", "Botanical detail"],
   ["academic", "symbolism", "romanticism"], ["renaissance_north", "art_nouveau"]),
 "impressionism": ("Impressionism", "movement", 1865, 1910, None,
   "Painting the moment: quick strokes of pure colour to catch outdoor light and modern life.",
   ["Broken, visible strokes", "Outdoor light and shadow in colour", "Cropped modern-life scenes"],
   ["post_impressionism", "realism", "pointillism"], ["fauvism", "expressionism"]),
 "post_impressionism": ("Post-Impressionism", "movement", 1885, 1910, None,
   "After Impressionism, painters pushed colour and form toward structure, symbol and emotion.",
   ["Bold outlines and thick impasto", "Non-natural colour", "Simplified, solid forms"],
   ["impressionism", "pointillism", "fauvism", "symbolism"], ["expressionism", "cubism"]),
 "pointillism": ("Pointillism", "movement", 1884, 1910, "post_impressionism",
   "Colour built from separate dots that mix in the viewer's eye, applied almost scientifically.",
   ["Uniform dots of pure colour", "Shimmering haloes around edges", "Still, geometric figures"],
   ["post_impressionism", "impressionism"], ["fauvism", "early_abstraction"]),
 "symbolism": ("Symbolism", "movement", 1870, 1915, None,
   "Art of dreams and ideas: mysterious figures and moods that point beyond what is shown.",
   ["Enigmatic figures", "Muted or eerie light", "Allegory and myth"],
   ["art_nouveau", "pre_raphaelite", "post_impressionism"], ["romanticism", "expressionism"]),
 "art_nouveau": ("Art Nouveau & Secession", "movement", 1890, 1915, None,
   "Decoration as art: flowing lines, gold patterns and flat ornamental fields, from Paris to Vienna.",
   ["Gold patterning", "Whiplash curves", "Flattened decorative fields"],
   ["symbolism", "expressionism", "post_impressionism"], ["byzantine_gothic", "pre_raphaelite"]),
 "fauvism": ("Fauvism", "movement", 1904, 1910, None,
   "The 'wild beasts' freed colour from description and used it at full strength.",
   ["Arbitrary, saturated colour", "Loose, flat patches", "Little or no shading"],
   ["expressionism", "post_impressionism"], ["impressionism", "pointillism"]),
 "expressionism": ("Expressionism", "movement", 1905, 1930, None,
   "Inner feeling forced onto the outer world: distortion, acid colour and raw strokes.",
   ["Distorted, angular figures", "Acid colour", "Harsh, rapid strokes"],
   ["fauvism", "art_nouveau", "early_abstraction"], ["post_impressionism", "symbolism", "romanticism"]),
 "cubism": ("Cubism (to 1930)", "movement", 1907, 1930, None,
   "Objects broken into planes and seen from several sides at once, in a restrained palette.",
   ["Faceted planes", "Muted browns and greys", "Fragmented objects"],
   ["early_abstraction", "school_of_paris"], ["post_impressionism", "expressionism"]),
 "early_abstraction": ("Early abstraction (to 1930)", "movement", 1910, 1930, None,
   "The first fully non-objective pictures: shape and colour with nothing left to recognise.",
   ["Geometric shapes", "No recognisable objects", "Flat colour fields"],
   ["cubism", "expressionism"], ["pointillism", "fauvism"]),
 "school_of_paris": ("School of Paris", "movement", 1905, 1930, None,
   "Artists from across Europe in Montparnasse, sharing cafés more than a single style.",
   ["Elongated faces and necks", "Almond-shaped eyes", "Warm, flat backgrounds"],
   ["cubism", "expressionism", "fauvism"], ["post_impressionism", "art_nouveau"]),
 "ukiyo_e": ("Ukiyo-e", "medium", 1650, 1930, None,
   "Japanese woodblock prints of the 'floating world': actors, beauties and famous views.",
   ["Flat areas of colour", "Bold outlines", "Cartouches with text"],
   ["print", "chinese_ink"], ["art_nouveau", "post_impressionism"]),
 "chinese_ink": ("Chinese ink painting", "medium", 900, 1930, None,
   "Brush and ink on silk or paper, where empty space and the stroke itself carry meaning.",
   ["Ink washes in greys and blacks", "Red seals and inscriptions", "Hanging or hand-scroll format"],
   ["ukiyo_e", "old_master_drawing"], ["print", "early_photography"]),
 "old_master_drawing": ("Old Master drawing", "medium", 1400, 1800, None,
   "Studies on paper by the great painters, where you can watch an idea take shape.",
   ["Chalk or ink on toned paper", "Hatching for shadow", "Studies and repeated details"],
   ["print", "watercolour_drawing", "chinese_ink"], ["renaissance_it", "renaissance_north"]),
 "print": ("Old Master print", "medium", 1450, 1850, None,
   "Engravings, etchings and woodcuts: images cut into plates or blocks and printed in multiples.",
   ["Dense hatching lines", "Mostly monochrome", "Plate mark or paper margin"],
   ["old_master_drawing", "modern_print", "ukiyo_e"], ["early_photography", "chinese_ink"]),
 "modern_print": ("Modern print", "medium", 1850, 1930, None,
   "Painters took up etching, lithography and the woodcut again and made prints as personal as their canvases.",
   ["Free, sketchy etched line or gouged wood", "Signed in pencil in the margin", "Limited colours or stark black and white"],
   ["print", "poster", "ukiyo_e"], ["watercolour_drawing", "early_photography"]),
 "poster": ("Vintage poster", "medium", 1880, 1930, None,
   "Colour lithography put art on the street: bold lettering, flat colour and something to sell.",
   ["Lettering built into the picture", "Flat, bright areas of colour", "Large sheets made for walls and kiosks"],
   ["modern_print", "ukiyo_e"], ["print", "watercolour_drawing"]),
 "watercolour_drawing": ("19th-century watercolour & drawing", "medium", 1780, 1910, None,
   "Works on paper from the 1800s: transparent washes, pencil and chalk, often made outdoors or as studies.",
   ["Washes with the paper glowing through", "Visible pencil underdrawing", "Small, intimate scale"],
   ["old_master_drawing", "modern_print"], ["print", "early_photography"]),
 "early_photography": ("Early photography", "medium", 1839, 1930, None,
   "From the first cameras to the 1920s, when long exposures and hand-made prints shaped the look.",
   ["Sepia, albumen or platinum tones", "Long-exposure stillness", "Soft edges and focus"],
   ["print", "modern_print", "old_master_drawing"], ["realism", "symbolism"]),
 "sculpture": ("Sculpture", "medium", 1400, 1930, None,
   "Reserved: posthumous casts make sculpture prices hard to compare.",
   ["Three-dimensional form", "Bronze or marble", "Seen in the round"],
   [], [], ),
}
INACTIVE = {"sculpture"}


def categories() -> list[dict]:
    out = []
    for cid, (label, axis, s, e, parent, teach, tells, nb, cf) in CATS.items():
        d = {"id": cid, "label": label, "axis": axis, "era": {"start": s, "end": e},
             "teach": teach, "tells": tells, "neighbours": nb, "confusers": cf,
             "min_quiz_items": MIN_QUIZ_LOW.get(cid, MIN_QUIZ), "active": cid not in INACTIVE}
        if parent:
            d["parent"] = parent
        d["department_id"] = DEPT_OF.get(cid)
        out.append(d)
    return sorted(out, key=lambda c: c["id"])


def check() -> list[str]:
    errs = []
    ids = set(CATS)
    for cid, v in CATS.items():
        if len(v[6]) != 3:
            errs.append(f"{cid}: needs exactly 3 tells")
        for ref in list(v[7]) + list(v[8]) + ([v[4]] if v[4] else []):
            if ref not in ids:
                errs.append(f"{cid}: unknown reference {ref}")
        if cid in v[7] or cid in v[8]:
            errs.append(f"{cid}: references itself")
    seen = [c for _, _, cs in DEPARTMENTS for c in cs]
    for c in set(seen):
        if seen.count(c) > 1:
            errs.append(f"category {c} in more than one department")
        if c not in ids:
            errs.append(f"department lists unknown category {c}")
        if c in INACTIVE:
            errs.append(f"department lists inactive category {c}")
    for c in ids - set(seen) - INACTIVE:
        errs.append(f"active category {c} not in any department")
    if len(DEPARTMENTS) != 7:
        errs.append("expected exactly 7 departments")
    active = [c for c in ids if c not in INACTIVE]
    if len(active) != 29:
        errs.append(f"expected 29 active categories, found {len(active)}")
    return errs
