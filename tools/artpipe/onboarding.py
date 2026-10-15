"""Onboarding questionnaire exemplars (Part I2) -> Resources/onboarding.json.

Curated: 2-3 visually unmistakable artworks per choice, each with a one-line caption written for
this project. `check()` verifies every id exists, has its images, and actually matches the choice
(department / subject / mood / category group), so a dataset change cannot silently break it.
"""
from __future__ import annotations

from . import taxonomy

AVANT_GARDE = {"fauvism", "expressionism", "cubism", "early_abstraction"}
IMPRESSIONIST = {"impressionism", "post_impressionism", "pointillism"}

# (choice id, step, label, rule, [(artwork_id, caption)])
CHOICES = [
    ("classic", 1, "Classic", ("departments", {"old_masters", "nineteenth_century"}), [
        ("botticelli-young-man-roundel", "Renaissance poise: a Florentine youth, crisp and still."),
        ("vermeer-study-young-woman", "Vermeer's luminous face emerging from the dark."),
        ("leonardo-ginevra-de-benci", "Leonardo's pale sitter against a dark juniper."),
    ]),
    ("modern", 1, "Modern", ("departments", {"impressionist_modern"}), [
        ("vangogh-wheat-field-cypresses", "Van Gogh's swirling sky over golden wheat."),
        ("klimt-mada-primavesi", "Klimt's girl in white amid a field of ornament."),
        ("seurat-sunday-grande-jatte", "A Sunday afternoon built from millions of dots."),
    ]),
    ("old_masters", 2, "Old Masters", ("departments", {"old_masters"}), [
        ("bruegel-the-harvesters", "Bruegel's peasants at harvest in high summer."),
        ("rembrandt-standard-bearer", "Rembrandt in armour, lit against the dark."),
        ("heda-still-life-fruit-pie", "Silver, glass and pie on a Dutch table."),
    ]),
    ("nineteenth_century", 2, "19th Century", ("departments", {"nineteenth_century"}), [
        ("cabanel-birth-of-venus", "The Salon's ideal: Venus born on a wave."),
        ("rossetti-lady-lilith", "A Pre-Raphaelite beauty combing golden hair."),
        ("shishkin-pine-forest", "Sunlight through a Russian pine forest."),
    ]),
    ("impressionist_modern:impressionist", 2, "Impressionist", ("categories", IMPRESSIONIST), [
        ("monet-meules", "Monet's haystacks glowing in winter light."),
        ("renoir-bal-du-moulin-small", "Dappled sunlight on a Montmartre dance."),
        ("monet-water-lilies-aic", "Water lilies floating on a mirror of sky."),
    ]),
    ("impressionist_modern:avant_garde", 2, "Avant-garde", ("categories", AVANT_GARDE), [
        ("malevich-suprematist-composition", "Pure shapes floating free: Suprematism."),
        ("kandinsky-improvisation-30", "Kandinsky's colour explosion, cannons and all."),
        ("mondrian-lozenge-composition", "Mondrian's grid turned on its point."),
    ]),
    ("asian_art", 2, "Asian Art", ("departments", {"asian_art"}), [
        ("hokusai-under-the-wave", "Hokusai's Great Wave, claws of foam over Fuji."),
        ("hiroshige-sudden-shower-shin-ohashi", "Rain slanting across a bridge in Edo."),
        ("xia-chang-windblown-bamboo", "Bamboo bending in ink, never breaking."),
    ]),
    ("prints_multiples", 2, "Prints & Multiples", ("departments", {"prints_multiples"}), [
        ("durer-rhinoceros", "Dürer's armoured rhinoceros, cut in wood."),
        ("rembrandt-three-trees", "Rembrandt's three trees under a storm of etched lines."),
        ("cassatt-the-bath", "Cassatt's mother and child in soft colour."),
    ]),
    ("photographs", 2, "Photographs", ("departments", {"photographs"}), [
        ("le-gray-great-wave-sete", "An early photograph of a wave and a stormy sky."),
        ("cameron-julia-jackson", "A soft-focus face emerging from shadow."),
        ("atget-joueur-dorgue", "A Paris street organ-grinder, caught by Atget."),
    ]),
    ("posters", 2, "Vintage Posters", ("departments", {"posters"}), [
        ("lautrec-moulin-rouge-la-goulue-1891", "Lautrec's Moulin Rouge: La Goulue mid-kick."),
        ("mucha-job-1898", "Mucha's swirling hair and smoke for Job papers."),
        ("steinlen-tournee-du-chat-noir-1896", "Steinlen's black cat with a halo."),
    ]),
    ("subject:landscape", 3, "Landscapes", ("subjects", {"landscape"}), [
        ("cezanne-montagne-sainte-victoire", "Cézanne's mountain built from colour patches."),
        ("vangogh-wheat-field-cypresses", "Wheat, cypress and a restless sky."),
        ("shishkin-pine-forest", "Tall pines in a sunlit forest."),
    ]),
    ("subject:people", 3, "People", ("subjects", {"portrait", "figure"}), [
        ("leonardo-ginevra-de-benci", "A Renaissance face that never quite smiles."),
        ("modigliani-jeanne-hebuterne", "Modigliani's long neck and almond eyes."),
        ("klimt-elisabeth-lederer", "Klimt's portrait in white on a blue ground."),
    ]),
    ("subject:still_life", 3, "Still life & objects", ("subjects", {"still_life"}), [
        ("coorte-wild-strawberries", "A bowl of wild strawberries on a stone ledge."),
        ("chardin-basket-wild-strawberries", "Chardin's pyramid of strawberries."),
        ("bosschaert-flowers-wanli-vase", "An impossible bouquet in a stone niche."),
    ]),
    ("mood:serene", 4, "Serene & muted", ("moods", {"serene"}), [
        ("monet-water-lilies-aic", "Still water, drifting lilies."),
        ("liotard-dutch-girl-breakfast", "A quiet breakfast in morning light."),
        ("seurat-sunday-grande-jatte", "A calm riverside Sunday."),
    ]),
    ("mood:dramatic", 4, "Dramatic & vivid", ("moods", {"dramatic"}), [
        ("munch-scream-pastel", "Munch's scream under a blood-red sky."),
        ("rubens-massacre-innocents", "Rubens' storm of bodies and despair."),
        ("kirchner-berlin-street-scene", "Kirchner's jagged night street in Berlin."),
    ]),
]


def build(dataset_id: str) -> dict:
    return {"schema_version": 1, "dataset_id": dataset_id,
            "choices": [{"id": cid, "step": step, "label": label,
                         "exemplars": [{"artwork_id": a, "caption": c} for a, c in ex]}
                        for cid, step, label, _, ex in CHOICES]}


def check(doc: dict, onboarding: dict, artworks_dir) -> list[str]:
    by_id = {a["id"]: a for a in doc["artworks"]}
    errs = []
    ids = [c["id"] for c in onboarding["choices"]]
    if len(set(ids)) != len(ids):
        errs.append("onboarding: duplicate choice ids")
    rules = {cid: rule for cid, _, _, rule, _ in CHOICES}
    for ch in onboarding["choices"]:
        ex = ch["exemplars"]
        if not 2 <= len(ex) <= 3:
            errs.append(f"onboarding {ch['id']}: needs 2-3 exemplars, has {len(ex)}")
        if len({e["artwork_id"] for e in ex}) != len(ex):
            errs.append(f"onboarding {ch['id']}: duplicate exemplar")
        kind, allowed = rules.get(ch["id"], (None, set()))
        for e in ex:
            a = by_id.get(e["artwork_id"])
            if not a:
                errs.append(f"onboarding {ch['id']}: unknown artwork {e['artwork_id']}")
                continue
            for tag in ("lg", "sm"):
                f = artworks_dir / a["images"]["primary"][tag]["file"]
                if not f.exists():
                    errs.append(f"onboarding {ch['id']}: {e['artwork_id']} image {f.name} missing")
            val = {"departments": a.get("department_id"), "categories": a["category_id"],
                   "subjects": a["taste"]["subject"], "moods": a["taste"]["mood"]}.get(kind)
            if kind and val not in allowed:
                errs.append(f"onboarding {ch['id']}: {e['artwork_id']} has {kind[:-1]} {val}, expected {sorted(allowed)}")
            if not e["caption"].strip():
                errs.append(f"onboarding {ch['id']}: empty caption")
    return errs
