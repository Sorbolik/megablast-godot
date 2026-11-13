"""Ritaglia i pezzi dei fogli di Codex (sfondo magenta) uno per uno.

Ogni pezzo è un'isola di pixel non magenta; le isole piccole (sopracciglia
spezzate, riflessi) si uniscono alla vicina se stanno a meno di UNISCI pixel.
Scrive art/<cartella>/<foglio>_<n>.png, ordinati per righe, e stampa
posizione e misura di ognuno.

    python3 tools/taglia_pezzi.py art/WB-033/corpo_2.png art/apprendista2
"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

UNISCI = 6


def taglia(foglio, uscita):
    im = np.asarray(Image.open(foglio).convert("RGBA")).astype(int)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    magenta = (r > 200) & (g < 90) & (b > 200)
    pieno = ~magenta
    pieno = ndimage.binary_opening(pieno, iterations=1)
    gruppi, n = ndimage.label(ndimage.binary_dilation(pieno, iterations=UNISCI))
    gruppi = gruppi * pieno
    pezzi = []
    for i, sl in enumerate(ndimage.find_objects(gruppi)):
        if sl is None:
            continue
        h = sl[0].stop - sl[0].start
        w = sl[1].stop - sl[1].start
        if w * h < 400:
            continue
        pezzi.append((sl, i + 1))
    righe = sorted(pezzi, key=lambda p: (p[0][0].start + p[0][0].stop) / 2)
    # in righe: pezzi il cui centro sta entro 1/6 dell'altezza del foglio
    ordinati = []
    fila = []
    for p in righe:
        cy = (p[0][0].start + p[0][0].stop) / 2
        if fila and cy - fila[0][2] > im.shape[0] / 6:
            ordinati += sorted(fila, key=lambda q: q[0][1].start)
            fila = []
        fila.append((p[0], p[1], cy))
    ordinati += sorted(fila, key=lambda q: q[0][1].start)
    os.makedirs(uscita, exist_ok=True)
    base = os.path.splitext(os.path.basename(foglio))[0]
    for k, (sl, i, _) in enumerate(ordinati):
        m = (gruppi[sl] == i)
        m = ndimage.binary_erosion(m, iterations=1) | (m & ~magenta[sl])
        pezzo = im[sl].copy().astype(np.uint8)
        # il bordo: via l'alone magenta (alfa morbido dove il colore tira al magenta)
        rr, gg, bb = [pezzo[..., c].astype(float) for c in range(3)]
        rosa = np.clip(((rr + bb) / 2 - gg - 60) / 120, 0, 1)
        alfa = (m * (1 - rosa) * 255).astype(np.uint8)
        pezzo[..., 3] = alfa
        pad = 4
        out = np.zeros((pezzo.shape[0] + 2 * pad, pezzo.shape[1] + 2 * pad, 4), np.uint8)
        out[pad:-pad, pad:-pad] = pezzo
        nome = "%s_%d.png" % (base, k)
        Image.fromarray(out, "RGBA").save(os.path.join(uscita, nome))
        print(nome, "x", sl[1].start, "y", sl[0].start, "w", sl[1].stop - sl[1].start, "h", sl[0].stop - sl[0].start)


for f in sys.argv[1:-1]:
    taglia(f, sys.argv[-1])
