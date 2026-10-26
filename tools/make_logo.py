"""Generates the Moonpull logo, app icon and Google Play store graphics (SVG + PNG).
Letters are converted to paths so the SVGs render identically everywhere (Godot included)."""
import math, os, cairosvg
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = TTFont(os.path.join(ROOT, "game/fonts/LilitaOne.ttf"))
GS, CMAP, UPM = FONT.getGlyphSet(), FONT.getBestCmap(), FONT["head"].unitsPerEm

def word(text, size, cx, base_y, arc=0.0, spacing=0.0):
    """Returns list of (path_d) for each letter, centred on cx, following an upward arc."""
    s = size / UPM
    adv = [GS[CMAP[ord(c)]].width * s + spacing for c in text]
    total = sum(adv) - spacing
    x = cx - total / 2
    out = []
    n = len(text)
    for i, c in enumerate(text):
        g = GS[CMAP[ord(c)]]
        u = (i + 0.5) / n - 0.5
        lift = arc * (1 - (2 * u) ** 2)           # parabola: middle letters higher
        rot = math.degrees(math.atan(-arc * 8 * u / max(total, 1) * 1.0)) * 0.9
        pen = SVGPathPen(GS)
        g.draw(TransformPen(pen, (s, 0, 0, -s, x, base_y - lift)))
        w = g.width * s
        out.append((pen.getCommands(), x + w / 2, base_y - lift - size * 0.35, rot))
        x += adv[i]
    return out

def letters_svg(letters, fill, outline=26, shadow=10, outline_col="#16123a"):
    parts = []
    for d, px, py, rot in letters:
        tr = f'rotate({rot:.2f} {px:.1f} {py:.1f})'
        parts.append(f'<path d="{d}" transform="translate(0 {shadow}) {tr}" fill="{outline_col}" stroke="{outline_col}" stroke-width="{outline}" stroke-linejoin="round"/>')
    for d, px, py, rot in letters:
        tr = f'rotate({rot:.2f} {px:.1f} {py:.1f})'
        parts.append(f'<path d="{d}" transform="{tr}" fill="{outline_col}" stroke="{outline_col}" stroke-width="{outline}" stroke-linejoin="round"/>')
    for i, (d, px, py, rot) in enumerate(letters):
        tr = f'rotate({rot:.2f} {px:.1f} {py:.1f})'
        parts.append(f'<path d="{d}" transform="{tr}" fill="{fill(i)}"/>')
    return "\n".join(parts)

DEFS = '''<defs>
  <radialGradient id="moonglow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0.55" stop-color="#fff3d6" stop-opacity="0.55"/>
    <stop offset="1" stop-color="#fff3d6" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="moon" cx="0.4" cy="0.35" r="0.75">
    <stop offset="0" stop-color="#fffdf5"/><stop offset="0.7" stop-color="#ffeec4"/><stop offset="1" stop-color="#f3d79a"/>
  </radialGradient>
  <linearGradient id="sea1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4fd2ee"/><stop offset="1" stop-color="#1b7fc4"/></linearGradient>
  <linearGradient id="sea2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2a8fd6"/><stop offset="1" stop-color="#0f3f86"/></linearGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff2a8"/><stop offset="0.5" stop-color="#ffc531"/><stop offset="1" stop-color="#ff8a1f"/></linearGradient>
  <linearGradient id="white" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#cfe9ff"/></linearGradient>
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1b1d4a"/><stop offset="0.6" stop-color="#6a4a8a"/><stop offset="1" stop-color="#f2a07b"/></linearGradient>
  <linearGradient id="hull" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff6b5e"/><stop offset="1" stop-color="#d63a2f"/></linearGradient>
</defs>'''

def wave_path(y, amp, length, w, h_bottom, phase=0.0):
    pts = [f"M0 {h_bottom}", f"L0 {y}"]
    x = 0.0
    k = 0
    while x < w:
        x2 = x + length
        cy = y + (-amp if (k % 2 == 0) else amp)
        pts.append(f"Q{x + length/2 + phase:.1f} {cy:.1f} {x2:.1f} {y:.1f}")
        x = x2; k += 1
    pts.append(f"L{w} {h_bottom} Z")
    return " ".join(pts)

def boat(x, y, s):
    return f'''<g transform="translate({x} {y}) scale({s}) rotate(-6)">
  <path d="M-60 0 L60 0 L42 26 L-44 26 Z" fill="url(#hull)" stroke="#16123a" stroke-width="6" stroke-linejoin="round"/>
  <rect x="-3" y="-82" width="7" height="84" fill="#6e4b33" stroke="#16123a" stroke-width="3"/>
  <path d="M-6 -76 L-6 -6 L-52 -6 Z" fill="#ffffff" stroke="#16123a" stroke-width="5" stroke-linejoin="round"/>
  <path d="M8 -60 L8 -6 L40 -6 Z" fill="#ffffff" stroke="#16123a" stroke-width="5" stroke-linejoin="round"/>
  <path d="M4 -82 L30 -74 L4 -66 Z" fill="#ffd23f" stroke="#16123a" stroke-width="3" stroke-linejoin="round"/>
</g>'''

def emblem(cx, cy, r, w):
    sea_y = cy + r * 0.55
    return f'''<circle cx="{cx}" cy="{cy}" r="{r*1.45:.0f}" fill="url(#moonglow)"/>
<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#moon)" stroke="#16123a" stroke-width="10"/>
<circle cx="{cx - r*0.35:.0f}" cy="{cy - r*0.25:.0f}" r="{r*0.16:.0f}" fill="#f0dca8"/>
<circle cx="{cx + r*0.3:.0f}" cy="{cy + r*0.05:.0f}" r="{r*0.1:.0f}" fill="#f0dca8"/>
<circle cx="{cx + r*0.05:.0f}" cy="{cy - r*0.5:.0f}" r="{r*0.07:.0f}" fill="#f0dca8"/>
<path d="{wave_path(sea_y, 22, 90, w, sea_y + 400)}" fill="url(#sea1)" stroke="#16123a" stroke-width="10" stroke-linejoin="round"/>
{boat(cx - r*0.15, sea_y - 14, r/170)}
<path d="{wave_path(sea_y + 60, 20, 110, w, sea_y + 400, 20)}" fill="url(#sea2)" stroke="#16123a" stroke-width="10" stroke-linejoin="round"/>
<path d="M{cx - r*0.9:.0f} {sea_y + 25:.0f} q20 -14 40 0 M{cx + r*0.6:.0f} {sea_y + 30:.0f} q20 -14 40 0" stroke="#e8fbff" stroke-width="8" fill="none" stroke-linecap="round"/>'''

def logo_svg(W=1200, H=760, with_bg=False):
    letters = word("MOONPULL", 196, W / 2, 680, arc=30, spacing=6)
    fill = lambda i: "url(#white)" if i < 4 else "url(#gold)"
    bg = f'<rect width="{W}" height="{H}" fill="url(#sky)"/>' if with_bg else ""
    cx, cy, R = W / 2, 285, 255
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
{DEFS}
{bg}
<circle cx="{cx}" cy="{cy + 8}" r="{R + 14}" fill="#16123a" opacity="0.45"/>
<clipPath id="badge"><circle cx="{cx}" cy="{cy}" r="{R}"/></clipPath>
<g clip-path="url(#badge)">
  <rect x="{cx - R}" y="{cy - R}" width="{2 * R}" height="{2 * R}" fill="url(#sky)"/>
  <g transform="translate({cx - 600 * 0.95:.1f} {cy - 255 * 0.95 + 18:.1f}) scale(0.95)">{emblem(600, 230, 165, 1200)}</g>
</g>
<circle cx="{cx}" cy="{cy}" r="{R}" fill="none" stroke="#16123a" stroke-width="16"/>
<circle cx="{cx}" cy="{cy}" r="{R - 14}" fill="none" stroke="#ffd166" stroke-width="6" opacity="0.8"/>
{letters_svg(letters, fill, outline=28, shadow=12)}
</svg>'''


def icon_svg(S=512):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 512 512">
{DEFS}
<rect width="512" height="512" rx="0" fill="url(#sky)"/>
{emblem(256, 205, 150, 512)}
</svg>'''

def feature_svg():
    W, H = 1024, 500
    letters = word("MOONPULL", 116, 672, 245, arc=14, spacing=3)
    fill = lambda i: "url(#white)" if i < 4 else "url(#gold)"
    tag = word("YOU STEER THE SEA", 40, 672, 322, spacing=2)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
{DEFS}
<rect width="{W}" height="{H}" fill="url(#sky)"/>
<g transform="translate(-60 70) scale(0.8)">{emblem(330, 230, 170, 1600)}</g>
{letters_svg(letters, fill, outline=18, shadow=7)}
{letters_svg(tag, lambda i: "#ffe9b0", outline=10, shadow=4)}
</svg>'''


def write(name, svg, png=None, size=None):
    p = os.path.join(ROOT, name)
    open(p, "w").write(svg)
    if png:
        cairosvg.svg2png(bytestring=svg.encode(), write_to=os.path.join(ROOT, png), output_width=size[0], output_height=size[1])

write("game/logo.svg", logo_svg())
write("game/icon.svg", icon_svg(), "store/icon-512.png", (512, 512))
write("store/logo.svg", logo_svg(with_bg=False), "store/logo.png", (1200, 760))
write("store/feature-graphic.svg", feature_svg(), "store/feature-graphic-1024x500.png", (1024, 500))
cairosvg.svg2png(bytestring=logo_svg(with_bg=True).encode(), write_to=os.path.join(ROOT, "store/logo-on-sky.png"), output_width=1200, output_height=760)
print("ok")
