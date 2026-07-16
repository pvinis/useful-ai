# Prompt: add my own icons to a font (mini nerd-font for SwiftBar & friends)

Copy everything below the line and give it to your AI coding agent on macOS.
It builds a copy of a font you already use with a handful of extra icon glyphs
merged in — like Nerd Fonts, but only the icons you actually need, at
codepoints that never move. Build happens in a scratch folder; installing the
font and touching whatever app uses it should be confirmed with you first.

---

I want my own mini nerd-font: take a font I already use and merge in a few
icons at fixed private-use codepoints, so they render inline anywhere I can
name that font — a SwiftBar/xbar menu bar item, a terminal, an editor. Only
the icons I need. Build everything in a scratch directory and show me a
preview; ask before installing the font or editing any config/plugin.

## Check the shortcuts first

- If every icon I want already exists in **Nerd Fonts**, stop — install the
  official patched build of my font instead (e.g. `brew install --cask
  font-<name>-nerd-font`) and use those codepoints. Many brand icons (AI
  companies, newer products) are *not* in it though.
- Don't rely on font fallback: macOS does **not** substitute PUA codepoints
  from other installed fonts (a menu bar renders them as blank/tofu). The
  glyphs must live in the font that's actually set.
- Don't hardcode **simple-icons-font** codepoints: they shift between
  releases, and some icons are missing from its font build entirely. Use
  simple-icons only as the SVG source.

## Recipe

1. **Icons**: [simple-icons](https://simpleicons.org/) has 3000+ brand SVGs
   (CC0), one path, 24×24 viewBox — perfect input. Fetch
   `https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/<slug>.svg` for
   each. Any other single-path SVG works too. If a brand is missing
   (trademark takedowns happen — OpenAI's mark, for one), try
   `@lobehub/icons-static-svg` on npm, which covers AI brands well.
2. **Base font**: one TTF face. If the font is installed as a `.ttc`
   collection, extract the face first (snippet below).
3. **Codepoints**: pick a PUA block and treat it as append-only — never
   renumber, so strings in configs stay valid forever. `U+E900–EA5F` is empty
   in both Iosevka and Nerd Fonts.
4. **Build** with fontTools (`python3 -m venv venv && pip install fonttools`,
   no FontForge needed):

```python
#!/usr/bin/env python
"""Merge SVG icons into a font copy at pinned PUA codepoints."""
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.svgLib.path import SVGPath
from fontTools.misc.transform import Transform

SRC = "MyFont-Regular.ttf"       # single face; see ttc extraction below
OUT = "MyFontIcons-Regular.ttf"
OLD_FAMILY, NEW_FAMILY = "MyFont", "MyFont Icons"
ICONS = [  # (svg, glyph name, codepoint) — append only, never renumber
    ("icon-claude.svg", "si_claude", 0xE900),
]
VIEWBOX = 24.0   # simple-icons are 24x24
TARGET_H = 800   # icon height in font units (assumes 1000 upm; ~cap height + a bit)
ADVANCE = 1000   # two cells of a 500-advance monospace

font = TTFont(SRC)
glyf, hmtx = font["glyf"], font["hmtx"]
scale = TARGET_H / VIEWBOX
# SVG is y-down from top-left; flip to y-up, center, sit on the baseline
transform = Transform(scale, 0, 0, -scale, (ADVANCE - TARGET_H) / 2, TARGET_H)

order = list(font.getGlyphOrder())  # snapshot: glyf.__setitem__ mutates the live list
new_names = []
for svg_file, gname, cp in ICONS:
    ttpen = TTGlyphPen(font.getGlyphSet())
    SVGPath(svg_file).draw(TransformPen(Cu2QuPen(ttpen, max_err=1.0), transform))
    glyph = ttpen.glyph()
    glyph.recalcBounds(glyf)
    glyf[gname] = glyph
    hmtx[gname] = (ADVANCE, glyph.xMin)
    new_names.append(gname)
    for table in font["cmap"].tables:
        if table.isUnicode():
            table.cmap[cp] = gname
new_order = order + new_names
font.setGlyphOrder(new_order)
glyf.setGlyphOrder(new_order)

for rec in font["name"].names:  # rename so it installs alongside the original
    if rec.nameID in (1, 3, 4, 16):
        rec.string = str(rec).replace(OLD_FAMILY, NEW_FAMILY)
    elif rec.nameID == 6:
        rec.string = str(rec).replace(OLD_FAMILY, NEW_FAMILY.replace(" ", ""))

font.save(OUT)
```

   Extracting a face from a `.ttc` first:

```python
from fontTools.ttLib import TTCollection
for f in TTCollection("MyFont.ttc", lazy=False).fonts:
    name = f["name"]
    if (name.getDebugName(16) or name.getDebugName(1)) == "MyFont" \
            and (name.getDebugName(17) or name.getDebugName(2)) == "Regular":
        f.save("MyFont-Regular.ttf")
```

5. **Preview before installing**: draw the new glyphs (plus a few letters for
   scale) through `fontTools.pens.svgPathPen.SVGPathPen` into an SVG,
   rasterize with `qlmanage -t`, and show me. Verify the cmap maps each
   codepoint and the bboxes look sane.
6. **Install** (with my OK): copy the TTF to `~/Library/Fonts/`. Apps that
   were already running need a restart to see the new font.

## Gotchas

- **SwiftBar/xbar quoting**: line parameters split on bare spaces. A font
  name with a space must be quoted — `| font="MyFont Icons"` — or SwiftBar
  silently uses the base name and every icon renders as tofu.
- Emit icons in scripts as escapes (`"\ue900"`), not literal chars — literal
  PUA characters look like empty strings in editors.
- Rebuilding after the base font updates: rerun the same script against the
  new version; pinned codepoints mean nothing else changes.

## Worked example

Menu-bar usage gauges for AI accounts, one jar per vendor, each fronted by
its logo — a SwiftBar plugin whose title line is rendered in the patched
font: `P ▕█▏▕▅▏` became `P <claude-logo>▕█▏<openai-logo>▕▅▏`.

- Base font: **Iosevka** 34.7.0 (Regular face extracted from `Iosevka.ttc`)
  → family **"Iosevka Icons"**.
- Icons from simple-icons: `claude` → `U+E900`, `anthropic` → `U+E901`
  (spare), `openai` → `U+E902`.
- Plugin line: `... | font="Iosevka Icons"`, icons emitted as `"\ue900"` / `"\ue902"`
  constants next to the block-element gauge glyphs, which align
  because the base font is the same Iosevka the rest of the line uses.
