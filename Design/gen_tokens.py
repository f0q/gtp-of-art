#!/usr/bin/env python3
"""Design/Tokens.json (W3C DTCG 2025.10) -> Packages/ArtDesign/Sources/ArtDesign/Generated/Tokens.swift

Stdlib only. Output is deterministic (no timestamps) so the ArtDesign test-suite can regenerate into a
temp dir and diff against the committed file.

Usage:
  python3 Design/gen_tokens.py                      # write the Swift file (default paths)
  python3 Design/gen_tokens.py --out /tmp/T.swift   # write elsewhere (used by the sync test)
  python3 Design/gen_tokens.py --update-meta        # recompute meta.contrast_pairs ratios in Tokens.json
  python3 Design/gen_tokens.py --check              # exit 1 if any contrast pair < its minimum

Conventions read from Tokens.json:
  colour  $value = dark appearance; $extensions["app.artprice.modes"].light = light appearance
  spring / haptic tokens have no $type and carry $extensions["app.artprice.type"]
  typography extras (relativeTo, opsz, soft, italic, smallCaps, monospacedDigit) live in
  $extensions["app.artprice.text"]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_TOKENS = os.path.join(ROOT, "Design", "Tokens.json")
DEFAULT_OUT = os.path.join(ROOT, "Packages", "ArtDesign", "Sources", "ArtDesign", "Generated", "Tokens.swift")

MODES_KEY = "app.artprice.modes"
TYPE_KEY = "app.artprice.type"
TEXT_KEY = "app.artprice.text"
FONT_KEY = "app.artprice.font"


# ---------------------------------------------------------------- helpers

def load(path: str) -> OrderedDict:
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh, object_pairs_hook=OrderedDict)


def tokens_in(group: dict):
    """Yield (name, token) for direct children that are tokens or groups, skipping $-keys."""
    for key, value in group.items():
        if key.startswith("$"):
            continue
        yield key, value


def is_token(node) -> bool:
    return isinstance(node, dict) and "$value" in node


def camel(*parts: str) -> str:
    out = parts[0]
    for p in parts[1:]:
        out += p[0].upper() + p[1:]
    return out


def resolve(doc: dict, value):
    """Resolve a DTCG alias '{a.b.c}' to the referenced token's node."""
    if isinstance(value, str) and value.startswith("{") and value.endswith("}"):
        node = doc
        for part in value[1:-1].split("."):
            node = node[part]
        return node
    return None


def hex_of(color_value: dict) -> tuple[str, float]:
    h = color_value["hex"].lstrip("#").upper()
    if len(h) != 6:
        raise ValueError(f"hex must be #RRGGBB, got {color_value['hex']}")
    comps = [round(int(h[i:i + 2], 16) / 255, 4) for i in (0, 2, 4)]
    if [round(c, 4) for c in color_value["components"]] != comps:
        raise ValueError(f"components {color_value['components']} disagree with hex #{h}")
    if color_value.get("colorSpace") != "srgb":
        raise ValueError("only srgb colours are supported")
    return h, float(color_value.get("alpha", 1.0))


def rgba_literal(color_value: dict) -> str:
    h, a = hex_of(color_value)
    return f"0x{h}{round(a * 255):02X}"


def fmt_num(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int) or (isinstance(v, float) and v.is_integer()):
        return str(int(v))
    return repr(float(v))


def fmt_double(v) -> str:
    s = fmt_num(v)
    return s if "." in s else s + ".0"


def dim_pt(token: dict) -> float:
    val = token["$value"]
    if token.get("$type") == "dimension":
        if val["unit"] != "px":
            raise ValueError("dimensions must be px (= pt/dp)")
        return val["value"]
    return val


def dur_s(token: dict) -> float:
    val = token["$value"]
    if val["unit"] == "ms":
        return val["value"] / 1000
    if val["unit"] == "s":
        return val["value"]
    raise ValueError("duration unit must be ms or s")


# ---------------------------------------------------------------- WCAG contrast

def rel_luminance(h: str) -> float:
    def ch(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(a: str, b: str) -> float:
    la, lb = sorted((rel_luminance(a), rel_luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def color_hex(doc: dict, path: str, mode: str) -> str:
    node = doc
    for part in path.split("."):
        node = node[part]
    value = node["$value"] if mode == "dark" else node["$extensions"][MODES_KEY]["light"]
    h, a = hex_of(value)
    if a != 1.0:
        raise ValueError(f"{path}: contrast pairs must be opaque")
    return h


def update_meta(doc: dict) -> list[str]:
    failures = []
    for pair in doc["meta"]["contrast_pairs"]:
        ratios = OrderedDict()
        for mode in ("dark", "light"):
            r = contrast(color_hex(doc, pair["fg"], mode), color_hex(doc, pair["bg"], mode))
            ratios[mode] = round(r, 2)
            if r < pair["min"]:
                failures.append(f"{pair['fg']} on {pair['bg']} ({mode}): {r:.2f} < {pair['min']}")
        pair["ratio"] = ratios
    return failures


# ---------------------------------------------------------------- Swift emitters

HEADER = """// DO NOT EDIT. Generated by Design/gen_tokens.py from Design/Tokens.json.
// Regenerate: python3 Design/gen_tokens.py
// Source sha256: {sha}
// Tokens version: {version}
//
// swiftlint:disable all

import SwiftUI
"""


def emit_colors(doc: dict, out: list[str]):
    out.append("    /// Semantic colours. Each resolves to its light or dark value from the environment.")
    out.append("    public enum Color {")
    for group, gnode in tokens_in(doc["color"]):
        for name, tok in tokens_in(gnode):
            if tok.get("$type") != "color":
                raise ValueError(f"color.{group}.{name} is not a colour")
            dark = rgba_literal(tok["$value"])
            light = rgba_literal(tok["$extensions"][MODES_KEY]["light"])
            out.append(f"        /// {tok.get('$description', '')}")
            out.append(f"        public static let {camel(group, name)} = SwiftUI.Color.artDynamic(light: {light}, dark: {dark})")
    out.append("    }")


def emit_dims(doc: dict, key: str, enum: str, doc_line: str, out: list[str]):
    out.append(f"    /// {doc_line}")
    out.append(f"    public enum {enum} {{")
    for name, tok in tokens_in(doc[key]):
        if tok.get("$description"):
            out.append(f"        /// {tok['$description']}")
        out.append(f"        public static let {name}: CGFloat = {fmt_num(dim_pt(tok))}")
    out.append("    }")


TEXT_STYLE = {
    "largeTitle": ".largeTitle", "title": ".title", "title2": ".title2", "title3": ".title3",
    "headline": ".headline", "subheadline": ".subheadline", "body": ".body", "callout": ".callout",
    "footnote": ".footnote", "caption": ".caption", "caption2": ".caption2",
}


def emit_typography(doc: dict, out: list[str]):
    fam = doc["font"]["family"]
    disp = fam["display"]["$extensions"][FONT_KEY]
    out.append("    /// Font families and the type scale. Consumed by `ArtFont` / `.artTextStyle(_:)`.")
    out.append("    public enum Typography {")
    out.append(f"        /// PostScript name of the upright Fraunces variable font.")
    out.append(f"        public static let displayPostScriptName = \"{disp['postScriptName']}\"")
    out.append(f"        /// PostScript name of the italic Fraunces variable font.")
    out.append(f"        public static let displayItalicPostScriptName = \"{disp['italicPostScriptName']}\"")
    files = ", ".join(f'"{f}"' for f in disp["files"])
    out.append(f"        /// Bundled font files (Resources/Fonts).")
    out.append(f"        public static let displayFontFiles: [String] = [{files}]")
    for name, tok in tokens_in(doc["font"]["style"]):
        v = tok["$value"]
        ext = tok["$extensions"][TEXT_KEY]
        family_alias = v["fontFamily"]
        family = {"{font.family.display}": ".display", "{font.family.ui}": ".ui",
                  "{font.family.numeric}": ".numeric"}[family_alias]
        args = [
            f"family: {family}",
            f"size: {fmt_num(v['fontSize']['value'])}",
            f"weight: {fmt_num(v['fontWeight'])}",
            f"relativeTo: {TEXT_STYLE[ext['relativeTo']]}",
            f"lineHeight: {fmt_double(v['lineHeight'])}",
            f"tracking: {fmt_num(v['letterSpacing']['value'])}",
            f"italic: {fmt_num(bool(ext.get('italic', False)))}",
            f"smallCaps: {fmt_num(bool(ext.get('smallCaps', False)))}",
            f"monospacedDigit: {fmt_num(bool(ext.get('monospacedDigit', False)))}",
            f"opticalSize: {fmt_num(ext['opsz']) if 'opsz' in ext else 'nil'}",
            f"softness: {fmt_num(ext['soft']) if 'soft' in ext else 'nil'}",
        ]
        out.append(f"        /// {tok.get('$description', '')}")
        out.append(f"        public static let {name} = ArtTypeStyle(")
        out.append("            " + ",\n            ".join(args))
        out.append("        )")
    out.append("    }")


def emit_size(doc: dict, out: list[str]):
    out.append("    /// Component sizes (points) and layout ratios.")
    out.append("    public enum Size {")
    for name, tok in tokens_in(doc["size"]):
        out.append(f"        /// {tok.get('$description', '')}")
        out.append(f"        public static let {name}: CGFloat = {fmt_num(dim_pt(tok))}")
    out.append("    }")


def emit_layout(doc: dict, out: list[str]):
    out.append("    /// Layout fractions and emphasis constants (unitless).")
    out.append("    public enum Layout {")
    for name, tok in tokens_in(doc["layout"]):
        out.append(f"        /// {tok.get('$description', '')}")
        out.append(f"        public static let {name}: CGFloat = {fmt_num(tok['$value'])}")
    out.append("    }")


def emit_elevation(doc: dict, out: list[str]):
    out.append("    /// Shadows. Only artworks cast shadows.")
    out.append("    public enum Elevation {")
    for name, tok in tokens_in(doc["elevation"]):
        v = tok["$value"]
        color_node = resolve(doc, v["color"])
        path = v["color"][1:-1].split(".")
        color_ref = camel(path[1], path[2]) if path[0] == "color" else None
        if color_node is None or color_ref is None:
            raise ValueError("elevation colour must alias a color token")
        out.append(f"        /// {tok.get('$description', '')}")
        out.append(f"        public static let {name} = ArtShadow(")
        out.append(f"            color: Tokens.Color.{color_ref},")
        out.append(f"            x: {fmt_num(v['offsetX']['value'])},")
        out.append(f"            y: {fmt_num(v['offsetY']['value'])},")
        out.append(f"            blur: {fmt_num(v['blur']['value'])}")
        out.append("        )")
    out.append("    }")


def emit_motion(doc: dict, out: list[str]):
    m = doc["motion"]
    out.append("    /// Motion: durations in seconds, easing curves and springs as `Animation`.")
    out.append("    public enum Motion {")
    out.append("        /// Durations in seconds.")
    out.append("        public enum Duration {")
    for name, tok in tokens_in(m["duration"]):
        out.append(f"            public static let {name}: Double = {fmt_double(dur_s(tok))}")
    out.append("        }")
    out.append("        /// Cubic-bezier easing curves; pass a duration to get an `Animation`.")
    out.append("        public enum Easing {")
    for name, tok in tokens_in(m["easing"]):
        x1, y1, x2, y2 = (fmt_double(c) for c in tok["$value"])
        out.append(f"            /// {tok.get('$description', '')}")
        out.append(f"            public static func {name}(duration: Double) -> Animation {{")
        out.append(f"                .timingCurve({x1}, {y1}, {x2}, {y2}, duration: duration)")
        out.append("            }")
    out.append("        }")
    out.append("        /// Springs (response / dampingFraction).")
    out.append("        public enum Spring {")
    for name, tok in tokens_in(m["spring"]):
        if tok["$extensions"][TYPE_KEY] != "spring":
            raise ValueError(f"motion.spring.{name} must be a spring")
        v = tok["$value"]
        out.append(f"            /// {tok.get('$description', '')}")
        out.append(f"            public static let {name}: Animation = .spring(response: {fmt_double(v['response'])}, dampingFraction: {fmt_double(v['dampingFraction'])})")
        out.append(f"            public static let {name}Response: Double = {fmt_double(v['response'])}")
        out.append(f"            public static let {name}DampingFraction: Double = {fmt_double(v['dampingFraction'])}")
    out.append("        }")
    out.append("        /// Stagger between sequenced elements, in seconds.")
    out.append("        public enum Stagger {")
    for name, tok in tokens_in(m["stagger"]):
        out.append(f"            public static let {name}: Double = {fmt_double(dur_s(tok))}")
    out.append("        }")
    out.append("        /// Reduce Motion replacements.")
    out.append("        public enum Reduced {")
    for name, tok in tokens_in(m["reduced"]):
        out.append(f"            public static let {name}: Double = {fmt_double(dur_s(tok))}")
    out.append("        }")
    out.append("        /// Hammer-reveal timeline (seconds from input lock) and its visual constants.")
    out.append("        public enum Reveal {")
    for name, tok in tokens_in(m["reveal"]):
        if tok.get("$type") == "duration":
            out.append(f"            public static let {name}: Double = {fmt_double(dur_s(tok))}")
        else:
            out.append(f"            public static let {name}: CGFloat = {fmt_num(dim_pt(tok))}")
    out.append("        }")
    out.append("    }")


def swift_case(path: list[str]) -> str:
    return camel(*path)


def sensory(ios: dict) -> str:
    kind = ios["kind"]
    if kind == "impact":
        if "weight" in ios:
            return f".impact(weight: .{ios['weight']}, intensity: {fmt_double(ios.get('intensity', 1.0))})"
        return f".impact(flexibility: .{ios['flexibility']}, intensity: {fmt_double(ios.get('intensity', 1.0))})"
    if kind in ("success", "warning", "error", "selection", "increase", "decrease", "start", "stop", "alignment", "levelChange"):
        return f".{kind}"
    raise ValueError(f"unknown haptic kind {kind}")


def emit_haptics(doc: dict, out: list[str]):
    cases = []
    for group, gnode in tokens_in(doc["haptic"]):
        for name, tok in tokens_in(gnode):
            if tok["$extensions"][TYPE_KEY] != "haptic":
                raise ValueError(f"haptic.{group}.{name} must be a haptic")
            cases.append((swift_case([group, name]), f"{group}.{name}", tok))
    out.append("    /// Semantic haptics. Play with `.artHaptic(_:trigger:)`, which respects the Settings toggle.")
    out.append("    public enum Haptic: String, CaseIterable, Sendable {")
    for case, raw, tok in cases:
        out.append(f"        /// {tok.get('$description', '')}")
        out.append(f"        case {case} = \"{raw}\"")
    out.append("")
    out.append("        /// The `HapticFeedbackConstants` name the Android port uses for this token.")
    out.append("        public var androidConstant: String {")
    out.append("            switch self {")
    for case, _, tok in cases:
        out.append(f"            case .{case}: \"{tok['$value']['android']}\"")
    out.append("            }")
    out.append("        }")
    out.append("")
    out.append("        /// SwiftUI sensory feedback for this token.")
    out.append("        public var sensoryFeedback: SensoryFeedback {")
    out.append("            switch self {")
    for case, _, tok in cases:
        out.append(f"            case .{case}: {sensory(tok['$value']['ios'])}")
    out.append("            }")
    out.append("        }")
    out.append("    }")


def emit_gesture(doc: dict, out: list[str]):
    out.append("    /// Gesture constants (points, pt/s, degrees, ratios).")
    out.append("    public enum Gesture {")
    for name, tok in tokens_in(doc["gesture"]):
        out.append(f"        /// {tok.get('$description', '')}")
        out.append(f"        public static let {name}: CGFloat = {fmt_num(dim_pt(tok))}")
    out.append("    }")


def generate(doc: dict, raw: bytes) -> str:
    out: list[str] = []
    out.append(HEADER.format(sha=hashlib.sha256(raw).hexdigest(), version=doc["meta"]["version"]).rstrip("\n"))
    out.append("")
    out.append("/// Design tokens for direction \"Salon Noir\". Use these instead of literals in every component.")
    out.append("nonisolated public enum Tokens {")
    emit_colors(doc, out)
    out.append("")
    emit_typography(doc, out)
    out.append("")
    emit_dims(doc, "space", "Space", "Spacing on the 8pt grid (points).", out)
    out.append("")
    emit_dims(doc, "radius", "Radius", "Corner radii (points, continuous style).", out)
    out.append("")
    emit_size(doc, out)
    out.append("")
    emit_layout(doc, out)
    out.append("")
    emit_elevation(doc, out)
    out.append("")
    emit_motion(doc, out)
    out.append("")
    emit_haptics(doc, out)
    out.append("")
    emit_gesture(doc, out)
    out.append("}")
    return "\n".join(out) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tokens", default=DEFAULT_TOKENS)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--update-meta", action="store_true", help="recompute contrast ratios into Tokens.json")
    ap.add_argument("--check", action="store_true", help="only verify contrast pairs")
    args = ap.parse_args()

    doc = load(args.tokens)
    failures = update_meta(doc)
    if failures:
        print("Contrast failures:\n  " + "\n  ".join(failures), file=sys.stderr)
        return 1
    if args.check:
        print(f"{len(doc['meta']['contrast_pairs'])} contrast pairs OK")
        return 0
    if args.update_meta:
        with open(args.tokens, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        print(f"updated meta.contrast_pairs in {args.tokens}")
        return 0

    with open(args.tokens, "rb") as fh:
        raw = fh.read()
    swift = generate(doc, raw)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(swift)
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
