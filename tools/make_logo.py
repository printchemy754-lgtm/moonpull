"""Moonpull logo, app icon and Google Play graphics (futuristic / neon style).
Letters are converted to paths so the SVGs render identically everywhere (Godot included)."""
import math, os, cairosvg
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = TTFont(os.path.join(ROOT, "game/fonts/Exo2-BlackItalic.ttf"))
GS, CMAP, UPM = FONT.getGlyphSet(), FONT.getBestCmap(), FONT["head"].unitsPerEm
INK = "#070a1f"
CYAN, MAGENTA, ORANGE = "#00e5ff", "#ff2fd0", "#ff8a3d"


def word(text, size, cx, base_y, spacing=0.0):
    s = size / UPM
    adv = [GS[CMAP[ord(c)]].width * s + spacing for c in text]
    x = cx - (sum(adv) - spacing) / 2
    out = []
    for i, c in enumerate(text):
        pen = SVGPathPen(GS)
        GS[CMAP[ord(c)]].draw(TransformPen(pen, (s, 0, 0, -s, x, base_y)))
        out.append(pen.getCommands())
        x += adv[i]
    return out


def letters_svg(paths, fills, glow, outline=22):
    parts = []
    for d in paths:   # neon glow halo
        parts.append(f'<path d="{d}" fill="none" stroke="{glow}" stroke-opacity="0.35" stroke-width="{outline * 2.2}" stroke-linejoin="round"/>')
    for d in paths:   # dark outline
        parts.append(f'<path d="{d}" fill="{INK}" stroke="{INK}" stroke-width="{outline}" stroke-linejoin="round"/>')
    for i, d in enumerate(paths):
        parts.append(f'<path d="{d}" fill="{fills(i)}"/>')
    return "\n".join(parts)


DEFS = f'''<defs>
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#070a2a"/><stop offset="0.65" stop-color="#3a0f5a"/><stop offset="1" stop-color="#ff3fa4"/></linearGradient>
  <linearGradient id="disc" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0b0b35"/><stop offset="0.62" stop-color="#3a0f5a"/><stop offset="0.63" stop-color="#14062e"/><stop offset="1" stop-color="#0a0320"/></linearGradient>
  <linearGradient id="cy" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="{CYAN}"/></linearGradient>
  <linearGradient id="mg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd0f4"/><stop offset="0.5" stop-color="{MAGENTA}"/><stop offset="1" stop-color="{ORANGE}"/></linearGradient>
  <linearGradient id="moon" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff6ff"/><stop offset="1" stop-color="#ffb8e8"/></linearGradient>
</defs>'''


def hover_boat(x, y, s):
    return f'''<g transform="translate({x} {y}) scale({s})">
  <ellipse cx="0" cy="40" rx="190" ry="16" fill="{CYAN}" opacity="0.45"/>
  <path d="M-170 20 L150 20 Q205 10 215 -6 L-120 -22 Q-165 -18 -170 20 Z" fill="#eef2ff" stroke="{INK}" stroke-width="9" stroke-linejoin="round"/>
  <path d="M-150 8 L170 8" stroke="{CYAN}" stroke-width="8" stroke-linecap="round"/>
  <path d="M-40 -18 Q0 -78 70 -14 Z" fill="#7fe8ff" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>
  <path d="M-150 -18 L-176 -70 L-118 -22 Z" fill="{MAGENTA}" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>
  <rect x="-196" y="-6" width="28" height="22" rx="6" fill="#3a3f5a" stroke="{INK}" stroke-width="6"/>
  <ellipse cx="-206" cy="5" rx="22" ry="9" fill="{CYAN}" opacity="0.9"/>
  <ellipse cx="-240" cy="5" rx="34" ry="6" fill="{CYAN}" opacity="0.45"/>
</g>'''


def mark(cx, cy, R):
    hy = cy + R * 0.26   # horizon
    grid = []
    for k in range(-8, 9):
        grid.append(f'<line x1="{cx + k * R * 0.09:.1f}" y1="{hy:.1f}" x2="{cx + k * R * 0.42:.1f}" y2="{cy + R:.1f}" stroke="{MAGENTA}" stroke-width="4" opacity="0.8"/>')
    for k in range(1, 7):
        yy = hy + (R * 0.74) * (k / 6) ** 1.8
        grid.append(f'<line x1="{cx - R}" y1="{yy:.1f}" x2="{cx + R}" y2="{yy:.1f}" stroke="{MAGENTA}" stroke-width="4" opacity="0.8"/>')
    mx, my, mr = cx - R * 0.05, cy - R * 0.22, R * 0.42
    return f'''<clipPath id="dc"><circle cx="{cx}" cy="{cy}" r="{R}"/></clipPath>
<circle cx="{cx}" cy="{cy}" r="{R + 26}" fill="{CYAN}" opacity="0.18"/>
<circle cx="{cx}" cy="{cy}" r="{R}" fill="url(#disc)"/>
<g clip-path="url(#dc)">
  <circle cx="{mx:.0f}" cy="{my:.0f}" r="{mr:.0f}" fill="url(#moon)" stroke="{INK}" stroke-width="10"/>
  <line x1="{mx - mr*0.8:.0f}" y1="{my - mr*0.25:.0f}" x2="{mx + mr*0.8:.0f}" y2="{my - mr*0.25:.0f}" stroke="#3a0f5a" stroke-width="{mr*0.07:.0f}" opacity="0.6"/>
  <line x1="{mx - mr*0.9:.0f}" y1="{my + mr*0.05:.0f}" x2="{mx + mr*0.9:.0f}" y2="{my + mr*0.05:.0f}" stroke="#3a0f5a" stroke-width="{mr*0.09:.0f}" opacity="0.6"/>
  <line x1="{mx - mr*0.85:.0f}" y1="{my + mr*0.38:.0f}" x2="{mx + mr*0.85:.0f}" y2="{my + mr*0.38:.0f}" stroke="#3a0f5a" stroke-width="{mr*0.12:.0f}" opacity="0.6"/>
  <ellipse cx="{mx:.0f}" cy="{my:.0f}" rx="{mr*1.55:.0f}" ry="{mr*0.32:.0f}" fill="none" stroke="{CYAN}" stroke-width="9" transform="rotate(-14 {mx:.0f} {my:.0f})"/>
  <rect x="{cx - R}" y="{hy:.0f}" width="{2*R}" height="{R}" fill="#14062e"/>
  {"".join(grid)}
  <line x1="{cx - R}" y1="{hy:.0f}" x2="{cx + R}" y2="{hy:.0f}" stroke="{CYAN}" stroke-width="6"/>
  {hover_boat(cx + R*0.08, hy + R*0.12, R/290)}
  <circle cx="{cx + R*0.58:.0f}" cy="{cy - R*0.55:.0f}" r="6" fill="#ffffff"/>
  <circle cx="{cx - R*0.62:.0f}" cy="{cy - R*0.4:.0f}" r="5" fill="#ffffff"/>
  <circle cx="{cx + R*0.35:.0f}" cy="{cy - R*0.75:.0f}" r="4" fill="#ffffff"/>
</g>
<circle cx="{cx}" cy="{cy}" r="{R}" fill="none" stroke="{INK}" stroke-width="20"/>
<circle cx="{cx}" cy="{cy}" r="{R - 4}" fill="none" stroke="{CYAN}" stroke-width="7"/>'''


def logo_svg(W=1200, H=760, with_bg=False):
    letters = word("MOONPULL", 168, W / 2, 690, spacing=4)
    moon, pull = letters[:4], letters[4:]
    bg = f'<rect width="{W}" height="{H}" fill="url(#sky)"/>' if with_bg else ""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
{DEFS}
{bg}
{mark(W / 2, 270, 245)}
{letters_svg(moon, lambda i: "url(#cy)", CYAN)}
{letters_svg(pull, lambda i: "url(#mg)", MAGENTA)}
</svg>'''


def icon_svg():
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
{DEFS}
<rect width="512" height="512" fill="#070a2a"/>
{mark(256, 256, 226)}
</svg>'''


def feature_svg():
    W, H = 1024, 500
    letters = word("MOONPULL", 104, 690, 250, spacing=2)
    moon, pull = letters[:4], letters[4:]
    tag = word("YOU STEER THE SEA", 40, 690, 330, spacing=3)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
{DEFS}
<rect width="{W}" height="{H}" fill="url(#sky)"/>
{mark(215, 250, 185)}
{letters_svg(moon, lambda i: "url(#cy)", CYAN, 16)}
{letters_svg(pull, lambda i: "url(#mg)", MAGENTA, 16)}
{letters_svg(tag, lambda i: "#ffffff", CYAN, 9)}
</svg>'''


def write(name, svg, png=None, size=None):
    open(os.path.join(ROOT, name), "w").write(svg)
    if png:
        cairosvg.svg2png(bytestring=svg.encode(), write_to=os.path.join(ROOT, png), output_width=size[0], output_height=size[1])


write("game/logo.svg", logo_svg())
write("game/icon.svg", icon_svg(), "store/icon-512.png", (512, 512))
write("store/logo.svg", logo_svg(), "store/logo.png", (1200, 760))
write("store/feature-graphic.svg", feature_svg(), "store/feature-graphic-1024x500.png", (1024, 500))
cairosvg.svg2png(bytestring=logo_svg(with_bg=True).encode(), write_to=os.path.join(ROOT, "store/logo-on-sky.png"), output_width=1200, output_height=760)
from PIL import Image
cairosvg.svg2png(bytestring=icon_svg().encode(), write_to=os.path.join(ROOT, "game/ios_icon_1024.png"), output_width=1024, output_height=1024)
Image.open(os.path.join(ROOT, "game/ios_icon_1024.png")).convert("RGB").save(os.path.join(ROOT, "game/ios_icon_1024.png"))
print("ok")
