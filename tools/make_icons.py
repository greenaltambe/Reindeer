"""Draws the Reindeer launcher and notification icons (needs Pillow) into android/app/src/main/res."""
import math, os
from PIL import Image, ImageDraw

GREEN = (46, 125, 91, 255)
FACE = (176, 120, 78, 255)
MUZZLE = (225, 190, 150, 255)
ANTLER = (244, 180, 60, 255)
INK = (59, 42, 37, 255)
RED = (229, 57, 53, 255)
CREAM = (255, 244, 224, 255)
SS = 4

def draw_deer(d, ox, oy, s, mono=False):
    """Draw the reindeer in 100-unit space, scaled by s, origin (ox, oy)."""
    P = lambda x, y: (ox + x * s, oy + y * s)
    white = (255, 255, 255, 255)
    ac = white if mono else ANTLER
    fc = white if mono else FACE
    w = max(1, int(5.5 * s))

    def line(a, b):
        d.line([P(*a), P(*b)], fill=ac, width=w)
        for q in (a, b):
            x, y = P(*q)
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=ac)

    for mirror in (False, True):
        X = (lambda v: 100 - v) if mirror else (lambda v: v)
        line((X(38), 42), (X(30), 26)); line((X(30), 26), (X(22), 8))
        line((X(30), 26), (X(15), 22)); line((X(26), 17), (X(14), 11)); line((X(24), 12), (X(31), 5))

    # ears
    for cx, ang in ((27, -0.6), (73, 0.6)):
        pts = []
        for t in range(0, 360, 10):
            a = math.radians(t)
            ex, ey = 9 * math.cos(a), 5 * math.sin(a)
            rx = ex * math.cos(ang) - ey * math.sin(ang)
            ry = ex * math.sin(ang) + ey * math.cos(ang)
            pts.append(P(cx + rx, 50 + ry))
        d.polygon(pts, fill=fc)
    # head
    d.ellipse([*P(27, 33), *P(73, 87)], fill=fc)
    if mono:
        return
    d.ellipse([*P(35, 70), *P(65, 90)], fill=MUZZLE)
    # cheeks
    for cx in (33, 67):
        d.ellipse([*P(cx - 5, 66), *P(cx + 5, 73)], fill=(214, 140, 112, 255))
    # eyes with sparkle
    for cx in (41, 59):
        d.ellipse([*P(cx - 4.2, 53.5), *P(cx + 4.2, 62.5)], fill=INK)
        d.ellipse([*P(cx - 2.6, 54.8), *P(cx - 0.2, 57.2)], fill=CREAM)
    # nose
    d.ellipse([*P(50 - 6.5, 74.5), *P(50 + 6.5, 87)], fill=RED)
    d.ellipse([*P(50 - 3.6, 76.5), *P(50 - 0.8, 79.2)], fill=(255, 190, 180, 255))

def render(px, deer_h, bg=None, rounded=0, mono=False, dy=0):
    """px: output size. deer_h: pixel height of the 0..90 deer area. bg: color or None."""
    big = px * SS
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg is not None:
        if rounded:
            d.rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * rounded), fill=bg)
        else:
            d.rectangle([0, 0, big, big], fill=bg)
    s = deer_h * SS / 85.0
    ox = big / 2 - 50 * s
    oy = big / 2 - 46 * s + dy * SS
    draw_deer(d, ox, oy, s, mono)
    return img.resize((px, px), Image.LANCZOS)

import pathlib
res = str(pathlib.Path(__file__).resolve().parent.parent / 'android/app/src/main/res')
def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)

dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for name, k in dens.items():
    # legacy square-ish launcher (48dp)
    px = int(48 * k)
    save(render(px, px * 0.84, bg=GREEN, rounded=0.22), f'{res}/mipmap-{name}/ic_launcher.png')
    # adaptive foreground (108dp, safe zone 66dp)
    px = int(108 * k)
    save(render(px, px * 0.62), f'{res}/mipmap-{name}/ic_launcher_foreground.png')
    # notification (24dp white silhouette)
    px = int(24 * k)
    save(render(px, px * 0.92, mono=True), f'{res}/drawable-{name}/ic_notification.png')

os.makedirs(f'{res}/mipmap-anydpi-v26', exist_ok=True)
open(f'{res}/mipmap-anydpi-v26/ic_launcher.xml', 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')
os.makedirs(f'{res}/values', exist_ok=True)
open(f'{res}/values/ic_launcher_background.xml', 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#2E7D5B</color>
</resources>
''')
# preview
prev = Image.new('RGBA', (1100, 560), (240, 240, 240, 255))
a = render(512, 512 * 0.84, bg=GREEN, rounded=0.22)
prev.paste(a, (20, 20), a)
fg = render(432, 432 * 0.62)
bgimg = Image.new('RGBA', (432, 432), GREEN)
bgimg.alpha_composite(fg)
m = Image.new('L', (432, 432), 0); ImageDraw.Draw(m).ellipse([0, 0, 431, 431], fill=255)
prev.paste(bgimg, (560, 20), m)
n = render(96, 96 * 0.92, mono=True)
dark = Image.new('RGBA', (120, 120), (60, 60, 60, 255)); dark.alpha_composite(n, (12, 12))
prev.paste(dark, (980, 20))
prev.convert('RGB').save('preview.png')
