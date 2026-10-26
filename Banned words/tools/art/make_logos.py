"""Logo drafts (sticker look: thick black outline, bright colours) for the game's new name (owner 2026-10-26: a name
about the flying chairs, picked from candidates). Writes one HTML per name into the folder given (default: .qa/logos)
and renders it to PNG (1024x576, the LED screen's shape) with headless Edge. Font: Black Han Sans (Google Fonts, SIL
Open Font License — fine in images and logos), loaded online, so this needs the network.

usage: python -I tools/art/make_logos.py [outdir]"""
import os, subprocess, sys

HERE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), ".qa", "logos")
os.makedirs(HERE, exist_ok=True)
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

NAMES = {
    "A": ["의자가", "날아간다"],
    "B": ["펑!", "의자쇼"],
    "C": ["펑!", "플라잉 체어"],
}

CHAIR = """
<g transform="translate(790,250) rotate(-22)">
  <!-- burst behind -->
  <polygon points="0,-150 32,-62 120,-96 70,-18 150,22 60,44 92,128 14,76 -40,150 -46,62 -138,80 -78,10 -150,-40 -60,-52 -96,-136 -20,-70"
    fill="#FFD43B" stroke="#222326" stroke-width="10" stroke-linejoin="round"/>
  <!-- the chair: a white seat and back on a blue frame -->
  <rect x="-58" y="-78" width="92" height="104" rx="16" fill="#FFFFFF" stroke="#222326" stroke-width="10"/>
  <rect x="-70" y="22" width="132" height="34" rx="12" fill="#FFFFFF" stroke="#222326" stroke-width="10"/>
  <rect x="-62" y="56" width="18" height="52" rx="6" fill="#2F80ED" stroke="#222326" stroke-width="8"/>
  <rect x="34" y="56" width="18" height="52" rx="6" fill="#2F80ED" stroke="#222326" stroke-width="8"/>
  <!-- speed lines -->
  <path d="M -150 120 L -210 150 M -120 150 L -170 190 M -175 80 L -240 98" stroke="#222326" stroke-width="10" stroke-linecap="round"/>
</g>
"""

TEMPLATE = """<!DOCTYPE html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Black+Han+Sans&display=block" rel="stylesheet">
<style>
html,body{{margin:0;padding:0;width:1024px;height:576px;overflow:hidden;background:#59C3F0}}
svg{{display:block}}
.t{{font-family:'Black Han Sans',sans-serif;paint-order:stroke fill;stroke-linejoin:round}}
.edge{{stroke:#FFFFFF}}
.ink{{stroke:#222326}}
</style></head><body>
<svg width="1024" height="576" viewBox="0 0 1024 576">
  <defs>
    <pattern id="dots" width="28" height="28" patternUnits="userSpaceOnUse">
      <circle cx="14" cy="14" r="5" fill="#FFFFFF" opacity="0.22"/>
    </pattern>
  </defs>
  <rect width="1024" height="576" fill="#59C3F0"/>
  <rect width="1024" height="576" fill="url(#dots)"/>
  <!-- pool water strip -->
  <path d="M0 470 Q 128 440 256 470 T 512 470 T 768 470 T 1024 470 V576 H0 Z" fill="#2F80ED" stroke="#222326" stroke-width="8"/>
  {chair}
  <!-- the name: white sticker edge, then black outline, then colour -->
  <text class="t edge" x="{x}" y="{y1}" font-size="{s1}" fill="#FFFFFF" stroke-width="44" text-anchor="middle">{l1}</text>
  <text class="t ink" x="{x}" y="{y1}" font-size="{s1}" fill="{c1}" stroke-width="16" text-anchor="middle">{l1}</text>
  <text class="t edge" x="{x}" y="{y2}" font-size="{s2}" fill="#FFFFFF" stroke-width="44" text-anchor="middle">{l2}</text>
  <text class="t ink" x="{x}" y="{y2}" font-size="{s2}" fill="{c2}" stroke-width="16" text-anchor="middle">{l2}</text>
</svg></body></html>
"""

for key, (l1, l2) in NAMES.items():
    long2 = len(l2) >= 5
    html = TEMPLATE.format(chair=CHAIR, x=360, y1=230, y2=400 if not long2 else 390,
                           s1=150 if len(l1) <= 3 else 130, s2=170 if not long2 else 112,
                           l1=l1, l2=l2, c1="#FF5A5F", c2="#FFD43B")
    path = os.path.join(HERE, f"logo_{key}.html")
    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    out = os.path.join(HERE, f"logo_{key}.png")
    subprocess.run([EDGE, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                    "--window-size=1024,576", "--virtual-time-budget=6000", f"--screenshot={out}",
                    "file:///" + path.replace("\\", "/")], capture_output=True, timeout=90)
    print(key, os.path.exists(out))
