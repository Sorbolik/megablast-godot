"""L'apprendista nuovo (WB-033, disegnato per piegarsi) per la prova in Godot.

Ritaglia i pezzi dai fogli di Codex (tools/taglia_pezzi.py), li mette in
posa nello stesso spazio dell'apprendista di oggi (unità, piedi a 0, y in su)
e scrive art/apprendista2/ con lo stesso rig.json, più quello che c'è di
nuovo: sciarpa, sopracciglia e bocche per le espressioni, corna e orecchie
montate sulla testa. La fiammella è ancora quella di prima (WB-034 la rifà
attaccata allo squarcio).

    python3 tools/prepara_apprendista2.py
"""
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.dirname(QUI)
FOGLI = os.path.join(RADICE, "art", "WB-033")
OUT = os.path.join(RADICE, "art", "apprendista2")
VECCHIO = os.path.join(RADICE, "art", "apprendista")
PX = 4.95          # pixel dei fogli del corpo per unità (busto alto come quello di oggi)
SH = 0.9           # testa: scala del foglio della testa rispetto al corpo
SV = 0.68          # viso: scala del foglio del viso rispetto al corpo

# la posa: centro di ogni pezzo in pixel del foglio del corpo, piedi a (0, 0), y in giù
POSA = {
    "coda": ("corpo_1_4", -240, -340, 0.95, 35),
    "gamba_dietro": ("corpo_2_5", -55, -214 * 0.85, 0.85, 0),
    "braccio_dietro": ("corpo_2_3", -120, -430 + 64, 0.85, 0),
    "busto": ("corpo_2_0", 0, -450 + 64, 1, 0),
    "gamba": ("corpo_2_4", 55, -214 * 0.85, 0.85, 0),
    "braccio": ("corpo_2_2", 125, -430 + 64, 0.85, 0),
    "sciarpa": ("corpo_2_1", 40, -640 + 64, 0.95, 0),
}
TESTA = [  # dietro alla testa, poi la testa (stessa posa del provino)
    ("testa_2_3", -200, -880, SH),
    ("testa_2_4", 270, -910, SH * 0.8),
    ("testa_2_2", 165, -1085, SH * 1.25),
    ("testa_2_1", -55, -1090, SH * 1.25),
    ("testa_2_0", 30, -850, SH),
]
OCCHI = [("viso_1_0", "viso_1_1", 60, -880, 10), ("viso_1_2", "viso_1_3", 190, -880, 5)]
SOPRA = [("viso_1_%d" % (4 + 2 * i), "viso_1_%d" % (5 + 2 * i)) for i in range(5)]
SOPRA_XY = [(50, -980), (180, -980)]
BOCCHE = ["viso_1_%d" % i for i in range(14, 22)]
BOCCA_XY = (150, -770)
# espressione -> (bocca, sopracciglia), come i volti di oggi
VOLTI = {"testa": (0, 0), "testa_felice": (1, 0), "testa_colpita": (7, 2),
         "testa_arrabbiata": (2, 1), "testa_paura": (5, 3), "testa_ko": (4, 3)}


ZT = 1.2          # la testa più grande del provino, come quella di oggi (attorno al mento)
GAMBE = 0.85      # gambe più corte del foglio
DY = 428 * (1 - GAMBE)   # di quanto scende tutto quello che sta sopra le gambe
MENTO = (30, -623)


def testa_xy(x, y):
    """posa della testa e del viso: ingrandita attorno al mento, poi abbassata"""
    return MENTO[0] + (x - MENTO[0]) * ZT, MENTO[1] + (y - MENTO[1]) * ZT + DY


def u(x, y):
    """pixel del corpo (y in giù) -> unità (y in su)"""
    return x / PX, -y / PX


def pezzo(nome, s=1.0, rot=0):
    im = Image.open(os.path.join(TAGLIO, nome + ".png")).convert("RGBA")
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    if rot:
        im = im.rotate(rot, expand=True, resample=Image.BICUBIC)
    return im


def salva(im, nome):
    im.save(os.path.join(OUT, nome + ".png"))


def voce(im, cx, cy, nome):
    x, y = u(cx, cy)
    return {"img": nome, "tint": False, "cx": round(x, 2), "cy": round(y, 2),
            "w": round(im.width / PX, 2), "h": round(im.height / PX, 2)}


TAGLIO = tempfile.mkdtemp()
subprocess.run([sys.executable, os.path.join(QUI, "taglia_pezzi.py")] +
               [os.path.join(FOGLI, f + ".png") for f in ("corpo_1", "corpo_2", "testa_2", "viso_1")] +
               [TAGLIO], check=True, stdout=subprocess.DEVNULL)
os.makedirs(OUT, exist_ok=True)
rig = {"height": 200, "pieces": {}, "pivots": {}, "new": True}

for nome in ("busto", "braccio", "braccio_dietro", "gamba", "gamba_dietro", "sciarpa"):
    f, cx, cy, s, _ = POSA[nome]
    im = pezzo(f, s)
    salva(im, nome)
    rig["pieces"][nome] = voce(im, cx, cy, nome)

# la testa: corna e orecchie dietro, poi la testa, in un disegno solo (senza faccia)
strati = [(pezzo(f, s * ZT),) + testa_xy(cx, cy) for f, cx, cy, s in TESTA]
x0 = min(cx - im.width / 2 for im, cx, cy in strati)
x1 = max(cx + im.width / 2 for im, cx, cy in strati)
y0 = min(cy - im.height / 2 for im, cx, cy in strati)
y1 = max(cy + im.height / 2 for im, cx, cy in strati)
testa = Image.new("RGBA", (round(x1 - x0), round(y1 - y0)))
for im, cx, cy in strati:
    testa.alpha_composite(im, (round(cx - im.width / 2 - x0), round(cy - im.height / 2 - y0)))
salva(testa, "testa")
tc = ((x0 + x1) / 2, (y0 + y1) / 2)
rig["pieces"]["testa"] = voce(testa, tc[0], tc[1], "testa")
for v in VOLTI:
    if v != "testa":
        shutil.copy(os.path.join(OUT, "testa.png"), os.path.join(OUT, v + ".png"))

# i perni: dove i pezzi si attaccano (in pixel del corpo, poi unità)
PERNI = {"busto": (0, -266), "testa": (25, -576), "braccio": (125, -516),
         "braccio_dietro": (-120, -516), "gamba": (55, -320), "gamba_dietro": (-55, -320)}
for k, (x, y) in PERNI.items():
    rig["pivots"][k] = list(u(x, y))

# la fiammella: per ora quella di prima, in cima alla testa
vecchio = json.load(open(os.path.join(VECCHIO, "rig.json")))
shutil.copy(os.path.join(VECCHIO, "fiamma.png"), os.path.join(OUT, "fiamma.png"))
fv = vecchio["pieces"]["fiamma"]
cima = u(*testa_xy(40, -1070))
rig["pieces"]["fiamma"] = {"img": "fiamma", "tint": False, "cx": cima[0], "cy": cima[1] + fv["h"] * 0.45,
                           "w": fv["w"], "h": fv["h"]}
rig["pivots"]["fiamma"] = list(cima)

# la coda: dritta nel foglio (punta in alto), girata di 35 gradi; le giunture
# sulla linea di mezzo, dalla radice (in basso) alla base della punta
f, cx, cy, s, rot = POSA["coda"]
dritta = pezzo(f, s)
a = np.asarray(dritta)[..., 3] > 128
righe = [r for r in range(a.shape[0]) if a[r].any()]
basso, alto = righe[-1] - 8, righe[0] + dritta.height * 0.12
punti = []
for k in range(6):
    r = int(basso + (alto - basso) * k / 5)
    xs = np.nonzero(a[r])[0]
    punti.append((xs.mean(), r))
im = pezzo(f, s, rot)
salva(im, "coda")
ang = math.radians(rot)
joints = []
for px_, py_ in punti:
    dx, dy = px_ - dritta.width / 2, py_ - dritta.height / 2
    rx = dx * math.cos(ang) + dy * math.sin(ang)
    ry = -dx * math.sin(ang) + dy * math.cos(ang)
    joints.append(list(u(cx + rx, cy + ry)))
rest = [math.atan2(joints[i + 1][1] - joints[i][1], joints[i + 1][0] - joints[i][0]) for i in range(5)]
left, top = u(cx - im.width / 2, cy - im.height / 2)
rig["tail"] = {"img": "coda", "left": left, "top": top, "w": im.width / PX, "h": im.height / PX,
               "joints": joints, "rest": rest}

# gli occhi: il bianco (giallo) e la pupilla nella stessa cornice, rispetto al centro della testa
neck = rig["pivots"]["testa"]
hc = rig["pieces"]["testa"]
rig["eyes"] = []
for i, (fb, fp, ex, ey, dx) in enumerate(OCCHI):
    bianco = pezzo(fb, SV * ZT)
    pup = pezzo(fp, SV * ZT)
    tela = Image.new("RGBA", bianco.size)
    tela.alpha_composite(pup, (round((bianco.width - pup.width) / 2 + dx * SV * ZT), round((bianco.height - pup.height) / 2)))
    salva(bianco, "occhio_%d" % i)
    salva(tela, "pupilla_%d" % i)
    x, y = u(*testa_xy(ex, ey))
    rig["eyes"].append({"img": "occhio_%d" % i, "pupil": "pupilla_%d" % i, "cx": x - hc["cx"], "cy": y - hc["cy"],
                        "w": bianco.width / PX, "h": bianco.height / PX, "lid": [199, 72, 40]})

# sopracciglia e bocche: sullo stesso nodo degli occhi, cambiano con l'espressione
rig["brows"] = []
for i, coppia in enumerate(SOPRA):
    paio = []
    for j, f in enumerate(coppia):
        im = pezzo(f, SV * ZT)
        salva(im, "sopracciglio_%d_%d" % (i, j))
        x, y = u(*testa_xy(*SOPRA_XY[j]))
        paio.append({"img": "sopracciglio_%d_%d" % (i, j), "cx": x - hc["cx"], "cy": y - hc["cy"],
                     "w": im.width / PX, "h": im.height / PX})
    rig["brows"].append(paio)
rig["mouths"] = []
for i, f in enumerate(BOCCHE):
    im = pezzo(f, SV * ZT)
    salva(im, "bocca_%d" % i)
    x, y = u(*testa_xy(*BOCCA_XY))
    rig["mouths"].append({"img": "bocca_%d" % i, "cx": x - hc["cx"], "cy": y - hc["cy"],
                          "w": im.width / PX, "h": im.height / PX})
rig["faces"] = {k: {"mouth": m, "brows": b} for k, (m, b) in VOLTI.items()}

# il mantello come oggi, attaccato alle spalle
rig["cape"] = vecchio.get("cape")
shutil.copy(os.path.join(VECCHIO, "mantello.png"), os.path.join(OUT, "mantello.png"))
rig["pieces"]["busto"]["tint"] = False

json.dump(rig, open(os.path.join(OUT, "rig.json"), "w"), indent=1)
shutil.rmtree(TAGLIO)
print("scritto", OUT)
