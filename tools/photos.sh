#!/bin/sh
# Crop every original in photos/originals/ around the face and write the web images:
#   images/speakers/<slug>.webp  720x900 portrait for the roster
#   images/thumbs/<slug>.webp    320x320 square for the face grids
# and the instructor photo(s) in photos/instructor/ as images/<slug>.webp (400x500).
# Name originals by slug (e.g. photos/originals/jane-doe.jpg). Optional per-photo framing
# overrides live in photos/framing.txt as: slug portraitFace portraitCenter thumbFace thumbCenter
set -eu
cd "$(dirname "$0")/.."
bin=tools/.bin/facecrop
if [ ! -x "$bin" ] || [ tools/facecrop.swift -nt "$bin" ]; then
  mkdir -p tools/.bin
  swiftc -O tools/facecrop.swift -o "$bin"
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p images/speakers images/thumbs
for src in photos/originals/*; do
  [ -f "$src" ] || continue
  slug=$(basename "$src"); slug=${slug%.*}
  pf=0.34; pc=0.40; tf=0.46; tc=0.47
  if [ -f photos/framing.txt ]; then
    line=$(grep "^$slug " photos/framing.txt || true)
    if [ -n "$line" ]; then set -- $line; pf=$2; pc=$3; tf=$4; tc=$5; fi
  fi
  echo "$slug"
  "$bin" "$src" "$tmp/p.png" 4 5 720 "$pf" "$pc" | sed 's/^/  portrait /'
  "$bin" "$src" "$tmp/t.png" 1 1 320 "$tf" "$tc" | sed 's/^/  thumb    /'
  cwebp -quiet -q 80 -m 6 -metadata none "$tmp/p.png" -o "images/speakers/$slug.webp"
  cwebp -quiet -q 78 -m 6 -metadata none "$tmp/t.png" -o "images/thumbs/$slug.webp"
done
for src in photos/instructor/*; do
  [ -f "$src" ] || continue
  slug=$(basename "$src"); slug=${slug%.*}
  echo "$slug (instructor)"
  "$bin" "$src" "$tmp/i.png" 4 5 400 0.36 0.42 | sed 's/^/  portrait /'
  cwebp -quiet -q 82 -m 6 -metadata none "$tmp/i.png" -o "images/$slug.webp"
done
