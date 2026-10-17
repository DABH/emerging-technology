# Theory and Practice of Emerging Technology Innovation — course site

Static site for ENGM 3890 / 5890 at Vanderbilt. Three pages, no framework:

- `index.html` — course overview, face grid of past speakers, CET Summit callout, instructor
- `speakers.html` — the full speaker roster
- `speak.html` — what a guest-speaker visit involves, plus contact

Shared styles live in `assets/site.css`. Speaker data lives in `speakers.json`; the
build script fills the regions marked `<!-- BEGIN … -->` / `<!-- END … -->` in the pages.
Everything outside those markers is hand-edited HTML.

## Adding a speaker

1. Add an entry to `speakers.json` (`slug`, `name`, `title`, `org`, `field`).
   Title and organization are as of the talk.
2. Drop a headshot at `photos/originals/<slug>.jpg` (or `.png`). Any size; the
   face is detected and cropped automatically.
3. Run the two scripts:

   ```sh
   tools/photos.sh          # crops to images/speakers (4:5) and images/thumbs (1:1)
   python3 tools/build.py   # rewrites the speaker sections of the pages
   ```

A speaker without a photo gets an initials tile on the roster and is left off the
homepage face grid. To nudge a crop, add a line to `photos/framing.txt`.

The instructor photo goes in `photos/instructor/` and is written to `images/`.

## Previewing

```sh
python3 -m http.server 8765 --bind 127.0.0.1
```

Then open http://127.0.0.1:8765/. The pages work as plain files too, but fonts load from
Google Fonts, so an internet connection is needed for the intended typography.

## Hosting

The site is served by GitHub Pages from the `main` branch of this repository at
https://emergingtech.dabh.io. The `CNAME` file holds the custom domain and `.nojekyll`
keeps Pages from running Jekyll. DNS for `dabh.io` is managed at Namecheap, where
`emergingtech` is a CNAME to `dabh.github.io`. Pushing to `main` redeploys the site
within a minute or two.

## Requirements

macOS with Xcode command-line tools (the crop tool is Swift and uses Apple's Vision
framework), `cwebp` (`brew install webp`), and Python 3. `tools/photos.sh` compiles the
crop tool on first run.
