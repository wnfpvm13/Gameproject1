"""The game's logo and store icon in the sticker look (thick black outline, bright colours). Name picked by the owner
on 2026-10-26: "의자에서 살아남기!" (not one of the drafts in docs/LAUNCH_2026-10-26.md). Writes HTML and
renders it to PNG with headless Edge into the folder given (default: .qa/logos):
- logo.png 1024x576 (16:9, store page and posts), logo_screen.png and logo_podium.png in the shapes of the map's far
  LED screen and podium front (decals `IMAGES.screenLogo` / `IMAGES.podiumLogo` in tools/build_pool_hall.luau)
- icon.png 512x512, the store icon draft: the flying chair and a "펑!" sticker, no name (it must read when small)
Font: Black Han Sans (Google Fonts, SIL Open Font License — fine in images and logos), loaded online, so this needs
the network.

usage: python -I tools/art/make_logos.py [outdir]"""
import os, subprocess, sys

HERE = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), ".qa", "logos")
os.makedirs(HERE, exist_ok=True)
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

LINE1, LINE2 = "의자에서", "살아남기!"

# The flying chair on a burst, drawn around (0, 0); each picture places and scales it.
CHAIR = """
<g transform="{place}">
  <!-- burst behind -->
  <polygon points="0,-150 32,-62 120,-96 70,-18 150,22 60,44 92,128 14,76 -40,150 -46,62 -138,80 -78,10 -150,-40 -60,-52 -96,-136 -20,-70"
    fill="#FFD43B" stroke="#222326" stroke-width="10" stroke-linejoin="round"/>
  <!-- the game's chair (tools/build_pool_hall.luau) seen from the side, facing right: blue box base with a white
       stripe, white seat cushion, blue back shell with a white cushion on its front and a blue roll on top -->
  <rect x="-52" y="22" width="104" height="80" rx="10" fill="#1C70E2" stroke="#222326" stroke-width="10"/>
  <rect x="-52" y="34" width="104" height="12" fill="#FFFFFF" stroke="#222326" stroke-width="6"/>
  <rect x="-66" y="-118" width="30" height="146" rx="10" fill="#1C70E2" stroke="#222326" stroke-width="10"/>
  <circle cx="-51" cy="-120" r="19" fill="#1C70E2" stroke="#222326" stroke-width="10"/>
  <rect x="-40" y="-100" width="18" height="104" rx="8" fill="#FFFFFF" stroke="#222326" stroke-width="8"/>
  <rect x="-42" y="-2" width="110" height="30" rx="15" fill="#FFFFFF" stroke="#222326" stroke-width="10"/>
  <!-- speed lines -->
  <path d="M -150 120 L -210 150 M -120 150 L -170 190 M -175 80 L -240 98" stroke="#222326" stroke-width="10" stroke-linecap="round"/>
</g>
"""

# A word as a sticker: white edge, then black outline, then colour.
STICKER = """
  <text class="t edge" x="{x}" y="{y}" font-size="{s}" fill="#FFFFFF" stroke-width="{edge}" text-anchor="middle"{extra}>{text}</text>
  <text class="t ink" x="{x}" y="{y}" font-size="{s}" fill="{c}" stroke-width="{ink}" text-anchor="middle"{extra}>{text}</text>
"""

PAGE = """<!DOCTYPE html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Black+Han+Sans&display=block" rel="stylesheet">
<style>
html,body{{margin:0;padding:0;width:{w}px;height:{h}px;overflow:hidden;background:#59C3F0}}
svg{{display:block}}
.t{{font-family:'Black Han Sans',sans-serif;paint-order:stroke fill;stroke-linejoin:round}}
.edge{{stroke:#FFFFFF}}
.ink{{stroke:#222326}}
</style></head><body>
<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <defs>
    <pattern id="dots" width="28" height="28" patternUnits="userSpaceOnUse">
      <circle cx="14" cy="14" r="5" fill="#FFFFFF" opacity="0.22"/>
    </pattern>
  </defs>
  <rect width="{w}" height="{h}" fill="#59C3F0"/>
  <rect width="{w}" height="{h}" fill="url(#dots)"/>
  <!-- pool water strip -->
  <path d="M0 {water} Q 128 {wave} 256 {water} T 512 {water} T 768 {water} T 1024 {water} V{h} H0 Z" fill="#2F80ED" stroke="#222326" stroke-width="8"/>
  {body}
</svg></body></html>
"""


def sticker(text, x, y, size, colour, edge=44, ink=16, extra=""):
    return STICKER.format(text=text, x=x, y=y, s=size, c=colour, edge=edge, ink=ink, extra=extra)


def render(name, w, h, water, body):
    path = os.path.join(HERE, f"{name}.html")
    with open(path, "w", encoding="utf-8") as f:
        f.write(PAGE.format(w=w, h=h, water=water, wave=water - 30, body=body))
    out = os.path.join(HERE, f"{name}.png")
    if os.path.exists(out):
        os.remove(out)  # so a failed render (no Edge, no network) shows as False instead of keeping the old picture
    subprocess.run([EDGE, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                    f"--window-size={w},{h}", "--virtual-time-budget=6000", f"--screenshot={out}",
                    "file:///" + path.replace("\\", "/")], capture_output=True, timeout=90)
    print(name, os.path.exists(out))


# The logo: the name on the left, the chair flying off on the right. A Decal stretches its image over the whole face,
# so each surface gets a copy drawn in that face's shape: (name, height for width 1024, water line, chair x, chair y,
# chair scale, text x, text size, baseline 1, baseline 2).
LOGOS = [
    ("logo", 576, 470, 820, 240, 0.95, 340, 140, 235, 400),  # 16:9, for the store page and posts
    ("logo_screen", 387, 340, 805, 170, 0.7, 330, 118, 165, 300),  # far LED screen, 28.6 x 10.8 studs
    ("logo_podium", 465, 405, 815, 200, 0.8, 335, 128, 195, 345),  # podium front, 4.4 x 2 studs
]
for name, h, water, cx, cy, cs, tx, ts, y1, y2 in LOGOS:
    render(name, 1024, h, water,
           CHAIR.format(place=f"translate({cx},{cy}) rotate(-22) scale({cs})")
           + sticker(LINE1, tx, y1, ts, "#FF5A5F")
           + sticker(LINE2, tx, y2, ts, "#FFD43B"))

# Store icon: only the chair and the bang, big.
render("icon", 512, 512, 462,
       CHAIR.format(place="translate(322,236) rotate(-22) scale(1.12)")
       + sticker("펑!", 116, 128, 112, "#FF5A5F", edge=36, ink=14, extra=' transform="rotate(-12 116 128)"'))
