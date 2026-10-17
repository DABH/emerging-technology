#!/usr/bin/env python3
"""Fill the speaker sections of the site from speakers.json.

The HTML pages stay plain static files. This script only rewrites the regions
between <!-- BEGIN name --> and <!-- END name --> markers, so everything else
in the pages can be edited by hand.

    python3 tools/build.py
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def esc(text):
    return html.escape(text, quote=True)


def face(s):
    return (
        f'<a class="face" href="speakers.html#{s["slug"]}">'
        f'<img src="images/thumbs/{s["slug"]}.webp" alt="{esc(s["name"])}" width="320" height="320" loading="lazy">'
        f'<span class="face-name">{esc(s["name"])}<span class="face-org">{esc(s["org"])}</span></span>'
        "</a>"
    )


def has_photo(s):
    return (ROOT / "images" / "speakers" / f'{s["slug"]}.webp').exists() and (ROOT / "images" / "thumbs" / f'{s["slug"]}.webp').exists()


def initials(s):
    return "".join(part[0] for part in s["name"].split() if part[:1].isalpha())[:2].upper()


def card(s):
    name = esc(s["name"])
    if s.get("link"):
        name = f'<a href="{esc(s["link"])}" rel="noopener">{name}</a>'
    role = f'{esc(s["title"])}<span class="org">{esc(s["org"])}</span>' if s.get("title") else f'<span class="org">{esc(s["org"])}</span>'
    return (
        f'<article class="card" id="{s["slug"]}">'
        + (f'<div class="card-photo"><img src="images/speakers/{s["slug"]}.webp" alt="{esc(s["name"])}" width="720" height="900" loading="lazy"></div>'
           if has_photo(s) else f'<div class="card-photo card-initials" aria-hidden="true">{initials(s)}</div>')
        +
        '<div class="card-body">'
        f'<p class="card-field">{esc(s["field"])}</p>'
        f'<h2 class="card-name">{name}</h2>'
        f'<p class="card-role">{role}</p>'
        "</div></article>"
    )


def roster_cta(n):
    """Closing tile that fills out the last row at each breakpoint (2, 3 and 4 columns)."""
    spans = ";".join(f"--span-{c}:{c - n % c if n % c else c}" for c in (2, 3, 4))
    return (
        f'<a class="roster-cta" href="speak.html" style="{spans}">'
        '<span class="eyebrow">Next speaker</span>'
        '<span class="roster-cta-title">Speak to the next class</span>'
        '<span class="roster-cta-link">What speaking involves <span class="arrow" aria-hidden="true">→</span></span>'
        "</a>"
    )


def face_count(available):
    """Show everyone with a photo on the homepage, up to 14 faces (two rows of 7)."""
    return min(available, 14)


def orgs(speakers, first):
    seen = [o for o in first if any(s["org"] == o for s in speakers)]
    for s in speakers:
        if s["org"] not in seen:
            seen.append(s["org"])
    # Each name carries its trailing slash and never breaks inside; lines break between names.
    sep = '<span class="sep" aria-hidden="true">/</span>'
    return " ".join(f'<span class="org">{esc(o)}{sep if i < len(seen) - 1 else ""}</span>' for i, o in enumerate(seen))


def fill(page, regions):
    path = ROOT / page
    text = path.read_text(encoding="utf-8")
    for name, body in regions.items():
        pattern = re.compile(rf"(<!-- BEGIN {name} -->)(.*?)(<!-- END {name} -->)", re.S)
        if not pattern.search(text):
            continue
        text = pattern.sub(lambda m: m.group(1) + body + m.group(3), text)
    path.write_text(text, encoding="utf-8")


def main():
    data = json.loads((ROOT / "speakers.json").read_text(encoding="utf-8"))
    speakers = sorted(data["speakers"], key=lambda s: (s["name"].split()[-1].lower(), s["name"].lower()))
    pictured = [s for s in speakers if s.get("featured", True) and has_photo(s)]
    featured = pictured[:face_count(len(pictured))]

    faces = f'<div class="face-grid" data-count="{len(featured)}">\n' + "\n".join(face(s) for s in featured) + "\n</div>"
    regions = {
        "faces": faces,
        "roster": "\n" + "\n".join(card(s) for s in speakers) + "\n" + roster_cta(len(speakers)) + "\n",
        "orgs": orgs(speakers, data.get("org_order", [])),
        "count": str(len(speakers)),
    }
    for page in ("index.html", "speakers.html", "speak.html"):
        fill(page, regions)
    print(f"Built {len(speakers)} speakers ({len(featured)} on the homepage).")


if __name__ == "__main__":
    main()
