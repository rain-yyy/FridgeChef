"""Generate FridgeChef's color sets and SVG image sets from the design mockups in Design/.

Usage (from the repo root):  python3 scripts/gen_assets.py

Regenerates Assets.xcassets/{Colors,Icons,TabIcons,Illustrations} and AccentColor.colorset.
Edit COLORS below to tweak a light/dark value, then re-run; other asset folders are left untouched.
"""
import json, os, re, shutil, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESIGN = os.path.join(ROOT, 'Design')
XC = os.path.join(ROOT, 'FridgeChef', 'Assets.xcassets')
INFO = {"author": "xcode", "version": 1}

def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        json.dump(obj, f, indent=2)
        f.write('\n')

def folder(name):
    path = os.path.join(XC, name)
    if os.path.isdir(path):
        shutil.rmtree(path)
    write_json(os.path.join(path, 'Contents.json'), {"info": INFO, "properties": {"provides-namespace": False}})
    return path

# ---------- Colors (light, dark) ----------
COLORS = {
    "Cream":        ("#FBF6EC", "#1F1915"),  # page background
    "Paper":        ("#FFFDF8", "#2B231E"),  # card background
    "Ink":          ("#3A2E28", "#EFE4D3"),  # outlines, primary text, tint
    "Cocoa":        ("#76675C", "#B3A493"),  # secondary text
    "Honey":        ("#F4C95D", "#E2B64E"),  # primary button
    "HoneySoft":    ("#FBEBC4", "#4A3D22"),  # notice card background (e.g. "API key not set")
    "InkSoft":      ("#5E5148", "#D8CBB9"),  # body text on HoneySoft
    "OnPastel":     ("#3A2E28", "#2A211C"),  # text/icons drawn on pastel or honey fills
    "Expired":      ("#EE8C7E", "#C9695C"),
    "Soon":         ("#F9C79A", "#D9A574"),
    "Frozen":       ("#C7DDF0", "#9DB8D1"),
    "CatMeat":      ("#F6CFCB", "#C99B97"),
    "CatSemi":      ("#F7E6B0", "#C9B67E"),
    "CatVeg":       ("#D3E8CB", "#9DB894"),
    "CatDairy":     ("#E2D8F0", "#AFA2C4"),
    "ControlFill":  ("#EFE7DC", "#3A302A"),  # segmented / stepper / disabled fill
    "WeakStroke":   ("#B9AA9C", "#6E6158"),  # neutral tag border
    "Hairline":     ("#D9CDBF", "#4A3F38"),  # dashed dividers
    "DisabledText": ("#8A7C70", "#7C6E62"),
    "DisabledStroke": ("#CDBFB0", "#55493F"),
}

def comp(hexstr):
    h = hexstr.lstrip('#')
    return {"red": "0x" + h[0:2], "green": "0x" + h[2:4], "blue": "0x" + h[4:6], "alpha": "1.000"}

def colorset(path, light, dark):
    write_json(os.path.join(path, 'Contents.json'), {
        "colors": [
            {"color": {"color-space": "srgb", "components": comp(light)}, "idiom": "universal"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}],
             "color": {"color-space": "srgb", "components": comp(dark)}, "idiom": "universal"},
        ],
        "info": INFO,
    })

colors_dir = folder('Colors')
for name, (light, dark) in COLORS.items():
    colorset(os.path.join(colors_dir, name + '.colorset'), light, dark)
colorset(os.path.join(XC, 'AccentColor.colorset'), *COLORS["Ink"])

# ---------- Icons ----------
MAIN = '视觉风格样板-html/Main.dc.html'
def svg_from(file, signature):
    src = open(os.path.join(DESIGN, file)).read()
    for m in re.finditer(r'<svg[^>]*>.*?</svg>', src, re.S):
        # In the style tile, only the 42px icon grid holds the plain glyphs (the header logo is filled).
        if file == MAIN and 'width="42"' not in m.group(0):
            continue
        if signature in m.group(0):
            return m.group(0)
    raise SystemExit(f'not found: {signature} in {file}')

def clean(svg, size, stroke_width=None):
    svg = re.sub(r'\s(aria-hidden|style)="[^"]*"', '', svg)
    svg = re.sub(r'\swidth="\d+"', f' width="{size}"', svg, count=1)
    svg = re.sub(r'\sheight="\d+"', f' height="{size}"', svg, count=1)
    if stroke_width:
        svg = re.sub(r'stroke-width="[\d.]+"', f'stroke-width="{stroke_width}"', svg, count=1)
    svg = svg.replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ', 1)
    return re.sub(r'\s+', ' ', svg).replace('> <', '><').strip() + '\n'

def template(svg):
    # Single-color glyph: everything black, SwiftUI tints it via foregroundStyle.
    return re.sub(r'(stroke|fill)="#[0-9A-Fa-f]{6}"', r'\1="#000000"', svg)

DARK_MAP = {k: v for k, v in [(COLORS[n][0], COLORS[n][1]) for n in
            ("Ink", "Paper", "Honey", "CatMeat", "CatSemi", "CatVeg", "CatDairy", "Expired", "Soon", "Frozen")]}

def darken(svg):
    return re.sub(r'#[0-9A-Fa-f]{6}', lambda m: DARK_MAP.get(m.group(0).upper(), m.group(0)), svg)

def imageset(dir_, name, svg, rendering, dark_svg=None):
    path = os.path.join(dir_, name + '.imageset')
    os.makedirs(path)
    images = [{"filename": name + '.svg', "idiom": "universal"}]
    open(os.path.join(path, name + '.svg'), 'w').write(svg)
    if dark_svg:
        open(os.path.join(path, name + '-dark.svg'), 'w').write(dark_svg)
        images.append({"appearances": [{"appearance": "luminosity", "value": "dark"}],
                       "filename": name + '-dark.svg', "idiom": "universal"})
    write_json(os.path.join(path, 'Contents.json'), {
        "images": images, "info": INFO,
        "properties": {"preserves-vector-representation": True, "template-rendering-intent": rendering},
    })

MAIN = '视觉风格样板-html/Main.dc.html'
GLYPHS = {
    # name: (file, signature, stroke width)
    "iconFridge":  (MAIN, 'M12.1 16L12 20.5', 2),
    "iconCook":    (MAIN, 'M12.5 9Q11.3 7 12.8 5', 2),
    "iconSettings": (MAIN, 'cx="10" cy="22.9"', 2),
    "iconAdd":     (MAIN, 'M16 6.5Q16.5 16 15.8 25.5', 2),
    "iconSearch":  (MAIN, 'M19.6 19.4L26 25.8', 2),
    "iconRetry":   (MAIN, 'M25.8 6.5L25.6 12.2', 2),
    "iconSoon":    (MAIN, 'M11 25L9.4 27.4', 2.4),
    "iconMeat":    (MAIN, 'M15.6 17L10 22.6', 2.2),
    "iconReady":   (MAIN, 'M16 9.8Q16.7 12.6', 2.2),
    "iconVeggie":  (MAIN, 'M14 16.8L16.2 18.6', 2.2),
    "iconDairy":   (MAIN, 'M11.8 13Q12.2 10.4', 2.2),
    "iconChill":   (MAIN, 'M16 11L16 22.5', 2),
    "iconFrozen":  (MAIN, 'M13.4 6.6L16 9L18.6 6.6', 2.4),
    "iconUpDown":  ('2 添加 编辑食材-html/ItemSheet.dc.html', 'M10 12L16 6L22 12', 2.6),
    "iconCheck":   ('7 设置-html/Settings.dc.html', 'M6 16.5L13 23.5L26.5 8.5', 3.6),
    "iconBack":    ('4 推荐结果-html/Results.dc.html', 'M20 6L10 16L20 26', 2.6),
    "iconForward": ('4 推荐结果-html/Results.dc.html', 'M12 6L22 16L12 26', 2.6),
    "iconSparkle": ('3 做饭设置-html/Cook.dc.html', 'M16 4Q17 14 28 16', 2),
    "iconEye":     ('7 设置-html/Settings.dc.html', 'r="3.6"></circle></svg>', 2.3),
    "iconEyeSlash": ('7 设置-html/Settings.dc.html', 'M6 26L26 6', 2.3),
}
icons_dir = folder('Icons')
for name, (file, sig, sw) in GLYPHS.items():
    imageset(icons_dir, name, template(clean(svg_from(file, sig), 32, sw)), "template")

# Selected tab icons: honey-filled versions, full color, with a dark-mode variant.
INK, HONEY = COLORS["Ink"][0], COLORS["Honey"][0]
fridge_sel = svg_from('7 设置-html/Settings.dc.html', 'M12.1 16L12 20.5')  # any fridge glyph; we recolor
fridge_sel = clean(fridge_sel, 28, 2.1)
fridge_sel = re.sub(r'stroke="#[0-9A-Fa-f]{6}"', f'stroke="{INK}"', fridge_sel)
fridge_sel = fridge_sel.replace('<path d="M9 4.5', f'<path fill="{HONEY}" d="M9 4.5', 1)
cook_sel = clean(svg_from('3 做饭设置-html/Cook.dc.html', 'M7 14.6Q6.6 24 9.6 26Q16 27.3 22.6 26Q25.5 24 25 14.6Z" fill="#F4C95D"'), 28, 2.1)
settings_sel = clean(svg_from('7 设置-html/Settings.dc.html', 'cx="10" cy="22.9" r="2.8" fill="#F4C95D"'), 28, 2.1)
tabs_dir = folder('TabIcons')
for name, svg in (("tabFridgeSelected", fridge_sel), ("tabCookSelected", cook_sel), ("tabSettingsSelected", settings_sel)):
    imageset(tabs_dir, name, svg, "original", darken(svg))

# Illustrations: full color with a dark-mode variant.
ILLUS = {
    "illusEmptyFridge":  ('1b 冰箱 · 空状态-html/FridgeEmpty.dc.html', 'M38.2 8.4L52 12.6', 150),
    "illusCooking":      ('4a 生成中-html/Loading.dc.html', 'fill="#F7E6B0"', 76),
    "illusNetworkError": ('4b 出错了-html/ResultsError.dc.html', 'M18 44Q8 44 8.5 35', None),
    "illusAIError":      ('4b 出错了-html/ResultsError.dc.html', 'M14 30Q13.2 48 19 52', None),
    "illusKey":          ('3 做饭设置-html/Cook.dc.html', 'M17.4 13.2L28 13', 34),
}
illus_dir = folder('Illustrations')
for name, (file, sig, size) in ILLUS.items():
    raw = svg_from(file, sig)
    size = size or int(re.search(r'width="(\d+)"', raw).group(1))
    svg = clean(raw, size)
    imageset(illus_dir, name, svg, "original", darken(svg))

print('ok', len(COLORS), 'colors,', len(GLYPHS), 'glyphs, 3 tab icons,', len(ILLUS), 'illustrations')
