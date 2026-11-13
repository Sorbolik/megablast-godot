#!/usr/bin/env python3
"""Prepara i pezzi dell'APPRENDISTA per lo spike, dagli STESSI disegni di MegaBlast.

Uso: python3 tools/prepara_pezzi.py ../megablast

Scrive art/apprendista/: i pezzi copiati così come sono, la coda montata in un
solo disegno (in MegaBlast sono 5 pezzi, qui diventa una mesh unica piegata da 5
ossa), gli occhi staccati dalla testa (bianco dell'occhio e pupilla, per il
battito delle palpebre e lo sguardo) e rig.json: dove sta ogni pezzo e ogni perno
a riposo, in unità di disegno (altezza 200 dai piedi alla cima, y in su), presi
da client/battle/devil.lua, skins.lua e pivots.lua come fa il gioco.
"""
import json
import math
import os
import re
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.spatial import ConvexHull

MB = sys.argv[1] if len(sys.argv) > 1 else "../megablast"
OUT = "art/apprendista"
SKIN_DIR = os.path.join(MB, "client/assets/skins")
os.makedirs(OUT, exist_ok=True)


def lua_text(path):
    return open(os.path.join(MB, path), encoding="utf-8").read()


def lua_pairs(block):
    """Coppie numeriche { a, b } per nome in un blocco Lua."""
    return {m[0]: (float(m[1]), float(m[2])) for m in
            re.findall(r"(\w+)\s*=\s*\{\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\}", block)}


devil = lua_text("client/battle/devil.lua")
points = lua_pairs(devil.split("points = {")[1].split("\n\t}")[0])
pivots = lua_pairs(lua_text("client/battle/pivots.lua"))
skins = lua_text("client/battle/skins.lua")
app = re.split(r"\n\t\t[a-z_]+ = \{", skins.split("apprendista = {", 1)[1])[0]
tail_l = [float(v) for v in re.search(r"tail = \{([^}]*)\}", app).group(1).split(",")]
tail_rest = [float(v) for v in re.search(r"tail_rest = \{([^}]*)\}", app).group(1).split(",")]
pieces = {}
for m in re.finditer(r"(\w+) = \{ img = \"(\w+)\", tint = (nil|\"\w+\"), x = (-?[\d.]+), y = (-?[\d.]+), "
                     r"w = ([\d.]+), h = ([\d.]+)", app):
    pieces[m[1]] = dict(img=m[2], tint=None if m[3] == "nil" else m[3].strip('"'),
                        x=float(m[4]), y=float(m[5]), w=float(m[6]), h=float(m[7]))
cape_m = re.search(r"mantello_vuoto_prova = \{.*?cape = \{ img = \"(\w+)\", x = (-?[\d.]+), y = (-?[\d.]+), "
                   r"w = ([\d.]+), h = ([\d.]+), at = \{ (-?[\d.]+), (-?[\d.]+) \}", skins)


def piv(spot, base):
    d = pivots.get(spot, (0.0, 0.0))
    return (base[0] + d[0], base[1] + d[1])


P = points
rig = {"height": 200, "pieces": {}, "pivots": {}, "tail": {}, "eyes": [], "cape": None}
# where every piece sits at rest: its point (devil.lua) plus its offset; the
# pivot it turns around: the point moved by pivots.lua (the piece stays put)
spots = {
    "busto": P["bacino"], "testa": P["collo"], "braccio": P["spalle"],
    "braccio_dietro": (-P["spalle"][0], P["spalle"][1]), "gamba": P["anche"],
    "gamba_dietro": (-P["anche"][0], P["anche"][1]),
}
for spot, base in spots.items():
    p = pieces[spot]
    shutil.copy(os.path.join(SKIN_DIR, p["img"] + ".png"), os.path.join(OUT, spot + ".png"))
    if p["tint"]:
        shutil.copy(os.path.join(SKIN_DIR, p["tint"] + ".png"), os.path.join(OUT, spot + "_tinta.png"))
    rig["pieces"][spot] = {"img": spot, "tint": bool(p["tint"]), "cx": base[0] + p["x"], "cy": base[1] + p["y"],
                           "w": p["w"], "h": p["h"]}
    rig["pivots"][spot] = piv(spot, base)
# the faces: same frame as the head
for face in ["testa_felice", "testa_colpita", "testa_arrabbiata", "testa_paura", "testa_ko"]:
    p = pieces[face]
    shutil.copy(os.path.join(SKIN_DIR, p["img"] + ".png"), os.path.join(OUT, face + ".png"))
    rig["pieces"][face] = {"img": face, "tint": False, "cx": P["collo"][0] + p["x"], "cy": P["collo"][1] + p["y"],
                           "w": p["w"], "h": p["h"]}
# the flame: on the neck joint (moved by the head pivot) plus cima, as scoria.lua
neck = rig["pivots"]["testa"]
f = pieces["fiamma"]
shutil.copy(os.path.join(SKIN_DIR, f["img"] + ".png"), os.path.join(OUT, "fiamma.png"))
rig["pieces"]["fiamma"] = {"img": "fiamma", "tint": False, "cx": neck[0] + P["cima"][0] + f["x"],
                           "cy": neck[1] + P["cima"][1] + f["y"], "w": f["w"], "h": f["h"]}
rig["pivots"]["fiamma"] = (neck[0] + P["cima"][0], neck[1] + P["cima"][1] - f["h"] * 0.32)

# --- the tail: the 5 segments at rest, assembled into ONE drawing -----------------
PX = 4.0  # pixels per drawing unit of the assembled tail
root = piv("coda", P["coda"])
joints, a = [root], 0.0
x, y = root
for i, ln in enumerate(tail_l):
    a = tail_rest[i]
    x, y = x + math.cos(a) * ln, y + math.sin(a) * ln
    joints.append((x, y))
layers = []  # (image, center in units, size in units, angle)
for border in (True, False):
    for i in range(5):
        p = pieces["coda_%d%s" % (i + 1, "_bordo" if border else "")]
        a = tail_rest[i]
        jx, jy = joints[i]
        # offset in the joint frame, turned by the absolute angle
        cx = jx + p["x"] * math.cos(a) - p["y"] * math.sin(a)
        cy = jy + p["x"] * math.sin(a) + p["y"] * math.cos(a)
        layers.append((p, cx, cy, a))
xs = [c[1] for c in layers] + [j[0] for j in joints]
ys = [c[2] for c in layers] + [j[1] for j in joints]
pad = 30
x0, x1, y0, y1 = min(xs) - pad, max(xs) + pad, min(ys) - pad, max(ys) + pad
canvas = Image.new("RGBA", (int((x1 - x0) * PX), int((y1 - y0) * PX)), (0, 0, 0, 0))
for p, cx, cy, a in layers:
    im = Image.open(os.path.join(SKIN_DIR, p["img"] + ".png")).convert("RGBA")
    im = im.resize((max(1, round(p["w"] * PX)), max(1, round(p["h"] * PX))), Image.LANCZOS)
    im = im.rotate(math.degrees(a), resample=Image.BICUBIC, expand=True)
    px, py = (cx - x0) * PX, (y1 - cy) * PX
    canvas.alpha_composite(im, (round(px - im.width / 2), round(py - im.height / 2)))
bbox = canvas.getbbox()
canvas = canvas.crop(bbox)
canvas.save(os.path.join(OUT, "coda.png"))
cx0, cy1 = x0 + bbox[0] / PX, y1 - bbox[1] / PX
rig["tail"] = {"img": "coda", "left": cx0, "top": cy1, "w": canvas.width / PX, "h": canvas.height / PX,
               "joints": joints, "rest": tail_rest}

# --- the eyes: the white (yellow) of the eye without the pupil, and the pupil ------
head = rig["pieces"]["testa"]
im = Image.open(os.path.join(OUT, "testa.png")).convert("RGBA")
a = np.array(im).astype(int)
r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
yellow = (r > 215) & (g > 150) & (g < 215) & (b < 130) & (al > 200)
lab, n = ndimage.label(yellow)
sizes = ndimage.sum(yellow, lab, range(1, n + 1))
best = sorted(range(1, n + 1), key=lambda i: -sizes[i - 1])[:2]
u = head["w"] / im.width  # units per pixel
for k in sorted(best, key=lambda i: ndimage.center_of_mass(yellow, lab, i)[1]):
    ys_, xs_ = np.nonzero(lab == k)
    pts = np.stack([xs_, ys_], 1)
    hull = ConvexHull(pts)
    poly = [tuple(map(float, pts[v])) for v in hull.vertices]
    mask_im = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask_im).polygon(poly, fill=255)
    socket = (np.array(mask_im) > 0) | (lab == k)
    socket = ndimage.binary_dilation(socket, iterations=1) & (al > 200)
    dark = (r + g + b < 200)
    shine = (r > 225) & (g > 225) & (b > 225)
    pupil = socket & (dark | shine)
    pupil = ndimage.binary_opening(pupil)  # leaves out the thin lid line
    ys_, xs_ = np.nonzero(socket)
    bx0, bx1, by0, by1 = xs_.min(), xs_.max() + 1, ys_.min(), ys_.max() + 1
    white = a.copy()
    white[~socket] = 0
    fill = np.median(a[(lab == k)][:, :3], axis=0).astype(int)
    white[pupil, :3] = fill
    white[pupil, 3] = 255
    pup = a.copy()
    pup[~pupil] = 0
    idx = len(rig["eyes"])
    Image.fromarray(white[by0:by1, bx0:bx1].astype(np.uint8)).save(os.path.join(OUT, "occhio_%d.png" % idx))
    Image.fromarray(pup[by0:by1, bx0:bx1].astype(np.uint8)).save(os.path.join(OUT, "pupilla_%d.png" % idx))
    # the box of the eye, in units from the head center (y up)
    rig["eyes"].append({"img": "occhio_%d" % idx, "pupil": "pupilla_%d" % idx,
                        "cx": ((bx0 + bx1) / 2 - im.width / 2) * u, "cy": (im.height / 2 - (by0 + by1) / 2) * u,
                        "w": (bx1 - bx0) * u, "h": (by1 - by0) * u, "lid": [184, 67, 42]})

# --- the cape of the Vuoto (the one being tried in MegaBlast) -----------------------
if cape_m:
    img, cx, cy, w, h, ax, ay = cape_m.groups()
    shutil.copy(os.path.join(MB, "client/assets/capes", img + ".png"), os.path.join(OUT, "mantello.png"))
    rig["cape"] = {"img": "mantello", "x": float(cx), "y": float(cy), "w": float(w), "h": float(h),
                   "at": [float(ax), float(ay)]}

json.dump(rig, open(os.path.join(OUT, "rig.json"), "w"), indent=1)
print("pezzi:", ", ".join(sorted(rig["pieces"])), "| occhi:", len(rig["eyes"]), "| coda", canvas.size)
