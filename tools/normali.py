"""Mappe delle normali dei pezzi dell'apprendista, per le luci 2D di Godot.

Ogni pezzo diventa un cuscino: l'altezza sale dal bordo (alfa) verso
l'interno, poi la pendenza dà la normale. Le linee nere del disegno
scavano un poco, così i contorni interni prendono luce anche loro.
Scrive art/apprendista/<pezzo>_n.png accanto a ogni pezzo.

    python3 tools/normali.py [apprendista | apprendista2]
"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

CARTELLA = os.path.join(os.path.dirname(__file__), "..", "art", sys.argv[1] if len(sys.argv) > 1 else "apprendista")
PEZZI = ["busto", "busto_tinta", "braccio", "braccio_dietro", "gamba", "gamba_dietro",
         "coda", "mantello", "testa", "testa_felice", "testa_colpita", "testa_arrabbiata",
         "testa_paura", "testa_ko", "sciarpa"]
CUSCINO = 0.18   # quanto è largo il bordo arrotondato, rispetto al pezzo
FORZA = 2.2      # quanto sono inclinate le normali
SOLCHI = 0.25    # quanto scavano le linee nere


def normali(nome):
    im = np.asarray(Image.open(os.path.join(CARTELLA, nome + ".png")).convert("RGBA")).astype(float) / 255
    alfa = im[..., 3] > 0.5
    dentro = ndimage.distance_transform_edt(alfa)
    largo = max(2.0, CUSCINO * min(alfa.shape))
    h = np.sqrt(np.clip(dentro / largo, 0, 1) * (2 - np.clip(dentro / largo, 0, 1)))  # quarto di cerchio
    scuro = 1 - im[..., :3].mean(axis=2)
    h = h - SOLCHI * np.clip((scuro - 0.75) * 4, 0, 1) * alfa
    h = ndimage.gaussian_filter(h, 1.2)
    gy, gx = np.gradient(h)
    n = np.dstack([-gx * FORZA * largo / 4, gy * FORZA * largo / 4, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    out = np.dstack([(n + 1) / 2, alfa.astype(float)])
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(os.path.join(CARTELLA, nome + "_n.png"))


for p in PEZZI:
    if not os.path.exists(os.path.join(CARTELLA, p + ".png")):
        continue
    normali(p)
    print(p + "_n.png")
