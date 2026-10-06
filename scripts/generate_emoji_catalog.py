#!/usr/bin/env python3
"""
Generate touchtime/Models/EmojiCatalog+Data.swift, the full emoji set behind
the countdown cover picker (CoverPickerSheet), from Unicode's emoji-test.txt.

Every fully-qualified emoji is kept, in the file's CLDR order (the order the
emoji keyboard uses), grouped into the keyboard's categories: Unicode's
"Smileys & Emotion" and "People & Body" make up Smileys & People, and its
"Component" group (bare skin tones and hair styles) is left out.

Skin tone variants stay out of the category lists; they are listed under
their default-tone emoji for its long-press menu instead. They are sorted by
the first person's tone, and for two people, each tone starts with both
people in it, followed by the second person's other tones, so the app can
split them into one submenu per tone of the first person.

Emojis newer than DEPLOYMENT_EMOJI_VERSION, the newest set the app's minimum
iOS draws, are also listed in `recentEmojis`; the app shows those only once
the running system's emoji font draws them.

Usage: python3 scripts/generate_emoji_catalog.py
Requires: network access to unicode.org.
"""

import re
import urllib.request
from collections import defaultdict
from pathlib import Path

EMOJI_VERSION = "18.0"
SOURCE_URL = f"https://www.unicode.org/Public/{EMOJI_VERSION}.0/emoji/emoji-test.txt"

# iOS 26.0, the deployment target, ships Emoji 16.0 (added in iOS 18.4).
DEPLOYMENT_EMOJI_VERSION = 16.0

REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT = REPO_ROOT / "touchtime" / "Models" / "EmojiCatalog+Data.swift"

# EmojiCatalog.Category cases in keyboard order, with the Unicode groups each
# one is made of.
CATEGORIES = [
    ("smileysAndPeople", ["Smileys & Emotion", "People & Body"]),
    ("animalsAndNature", ["Animals & Nature"]),
    ("foodAndDrink", ["Food & Drink"]),
    ("activity", ["Activities"]),
    ("travelAndPlaces", ["Travel & Places"]),
    ("objects", ["Objects"]),
    ("symbols", ["Symbols"]),
    ("flags", ["Flags"]),
]
SKIPPED_GROUPS = {"Component"}

SKIN_TONES = ["1F3FB", "1F3FC", "1F3FD", "1F3FE", "1F3FF"]
EMOJIS_PER_LINE = 10

LINE_PATTERN = re.compile(
    r"^(?P<code_points>[0-9A-F ]+?)\s*;\s*(?P<status>[a-z-]+)\s*"
    r"#\s*(?P<emoji>\S+)\s+E(?P<version>\d+\.\d+)\s+(?P<name>.+)$"
)


class Emoji:
    def __init__(self, code_points, emoji, version, name):
        self.emoji = emoji
        self.version = version
        self.name = name
        self.tones = [point for point in code_points if point in SKIN_TONES]
        self.variants = []

    @property
    def is_recent(self):
        return self.version > DEPLOYMENT_EMOJI_VERSION

    def variant_order(self):
        """First person's tone, both people in it first, then the second person's tone."""
        is_uniform = len(set(self.tones)) == 1
        return SKIN_TONES.index(self.tones[0]), 0 if is_uniform else 1, SKIN_TONES.index(self.tones[-1])


def download():
    request = urllib.request.Request(SOURCE_URL, headers={"User-Agent": "touchtime-emoji-catalog"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def name_without_skin_tones(name):
    """'person: light skin tone, blond hair' -> 'person: blond hair'."""
    head, _, tail = name.partition(": ")
    attributes = [part for part in tail.split(", ") if part and not part.endswith("skin tone")]
    return f"{head}: {', '.join(attributes)}" if attributes else head


def parse(text):
    """Default-tone emojis by Unicode group, each holding its skin tone variants."""
    groups = defaultdict(list)
    bases_by_name = {}
    group = None
    latest_base = None
    for line in text.splitlines():
        if line.startswith("# group:"):
            group = line.split(":", 1)[1].strip()
            continue
        if not line or line.startswith("#"):
            continue
        match = LINE_PATTERN.match(line)
        if not match:
            raise ValueError(f"Unparsed line: {line}")
        if match["status"] != "fully-qualified" or group in SKIPPED_GROUPS:
            continue

        emoji = Emoji(match["code_points"].split(), match["emoji"], float(match["version"]), match["name"])
        if not emoji.tones:
            assert emoji.name not in bases_by_name, f"Duplicate name: {emoji.name}"
            bases_by_name[emoji.name] = emoji
            groups[group].append(emoji)
            latest_base = emoji
            continue

        # A variant follows its default-tone emoji, except the mixed tones
        # of families toned later (people, men and women with bunny ears,
        # and wrestling), which come after all three; those are matched by
        # name. Mixed couples named "kiss: person, person, ..." have no
        # base of that name and stay with "kiss" itself.
        base = bases_by_name.get(name_without_skin_tones(emoji.name), latest_base)
        base.variants.append(emoji)
    return groups


def quoted(emojis):
    return ", ".join(f'"{emoji}"' for emoji in emojis)


def swift_lines(emojis, indent, per_line=EMOJIS_PER_LINE):
    return [indent + quoted(emojis[start:start + per_line]) + "," for start in range(0, len(emojis), per_line)]


def render(groups):
    unmapped = set(groups) - {group for _, names in CATEGORIES for group in names}
    assert not unmapped, f"Unmapped Unicode groups: {unmapped}"

    categories = [(case, [emoji for group in names for emoji in groups[group]]) for case, names in CATEGORIES]
    bases = [emoji for _, emojis in categories for emoji in emojis]
    toned = [emoji for emoji in bases if emoji.variants]
    for emoji in toned:
        emoji.variants.sort(key=Emoji.variant_order)
        assert len(emoji.variants) in (5, 25), f"{emoji.name} has {len(emoji.variants)} skin tones"
    recent = [emoji.emoji for emoji in bases if emoji.is_recent]
    recent += [variant.emoji for emoji in toned for variant in emoji.variants if variant.is_recent]

    out = [
        "//",
        "//  EmojiCatalog+Data.swift",
        "//  touchtime",
        "//",
        "//  Generated by scripts/generate_emoji_catalog.py from Unicode's",
        f"//  emoji-test.txt (Emoji {EMOJI_VERSION}). Do not edit by hand; rerun the script.",
        "//",
        "",
        "extension EmojiCatalog.Category {",
        "    /// Every emoji of the category in keyboard order, in its default",
        "    /// skin tone.",
        "    var allEmojis: [String] {",
        "        switch self {",
    ]
    out += [f"        case .{case}: EmojiCatalog.{case}" for case, _ in CATEGORIES]
    out += [
        "        }",
        "    }",
        "}",
        "",
        "extension EmojiCatalog {",
    ]
    for case, emojis in categories:
        out.append(f"    fileprivate static let {case}: [String] = [")
        out += swift_lines([emoji.emoji for emoji in emojis], " " * 8)
        out += ["    ]", ""]
    out += [
        "    /// The skin tone variants of every emoji that has them, by its",
        "    /// default-tone form. Sorted by the first person's tone; for two",
        "    /// people, each tone starts with both people in it, followed by the",
        "    /// second person's other tones.",
        "    static let skinToneVariants: [String: [String]] = [",
    ]
    for emoji in toned:
        variants = [variant.emoji for variant in emoji.variants]
        if len(variants) == 5:
            out.append(f'        "{emoji.emoji}": [{quoted(variants)}],')
        else:
            out.append(f'        "{emoji.emoji}": [')
            out += swift_lines(variants, " " * 12, per_line=5)
            out.append("        ],")
    out += [
        "    ]",
        "",
        f"    /// Emojis newer than Emoji {DEPLOYMENT_EMOJI_VERSION}, the newest set iOS 26.0 draws.",
        "    static let recentEmojis: Set<String> = [",
    ]
    out += swift_lines(recent, " " * 8)
    out += [
        "    ]",
        "}",
        "",
    ]

    variant_count = sum(len(emoji.variants) for emoji in toned)
    print(f"{len(bases)} emojis in {len(categories)} categories, {variant_count} skin tone variants "
          f"of {len(toned)} emojis, {len(recent)} newer than Emoji {DEPLOYMENT_EMOJI_VERSION}")
    return "\n".join(out)


def main():
    OUTPUT.write_text(render(parse(download())), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
