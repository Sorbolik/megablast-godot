"""Ricalca i pezzi ritagliati in SVG coi colori esatti (vettoriale.py di MegaBlast)
e li esporta in PNG grandi. uso: traccia.py TAVOLOZZA USCITA ingrandimento_foglio px_per_pixel pezzo.png..."""
import sys, os, io
sys.path.insert(0, "/home/user/megablast/tools/stampino")
import numpy as np
from PIL import Image
import vettoriale as V, cairosvg
tav = V.leggi_tavolozza(sys.argv[1]); out = sys.argv[2]; up = float(sys.argv[3]); k = float(sys.argv[4])
os.makedirs(out, exist_ok=True)

def calibra(a, tav):
    """I colori di Codex sono un po' fuori tavolozza (pelle più chiara, ombra che
    cade sulla pelle): k-means partendo dalla tavolozza trova il colore vero di
    ogni voce sul foglio, poi ogni pixel si sposta della differenza."""
    pal = np.stack([V.rgb(c) for _, c in tav])
    m = a[..., 3] > 250
    px = a[..., :3][m]
    if len(px) > 60000:
        px = px[np.random.default_rng(0).choice(len(px), 60000, replace=False)]
    c = pal.copy()
    for _ in range(8):
        lab = ((px[:, None] - c[None]) ** 2).sum(-1).argmin(1)
        for i in range(len(c)):
            sel = px[lab == i]
            if len(sel) > 200:
                c[i] = 0.5 * pal[i] + 0.5 * sel.mean(0) if i == len(c) - 1 else sel.mean(0)
    full = a[..., :3]
    lab = ((full[..., None, :] - c) ** 2).sum(-1).argmin(-1)
    a = a.copy()
    a[..., :3] = np.clip(full + (pal - c)[lab], 0, 255)
    return a
for p in sys.argv[5:]:
    im = Image.open(p).convert("RGBA")
    im = im.resize((round(im.width * up), round(im.height * up)), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32)
    a = calibra(a, tav)
    W, H = round(im.width / up * k), round(im.height / up * k)
    base, tinta = V.svg_pezzo(a, tav, (W, H))
    n = os.path.splitext(os.path.basename(p))[0]
    for suf, svg in (("", base), ("_tinta", tinta)):
        if svg is None: continue
        open(f"{out}/{n}{suf}.svg", "w").write(svg)
        png = cairosvg.svg2png(bytestring=svg.encode(), output_width=W, output_height=H)
        open(f"{out}/{n}{suf}.png", "wb").write(png)
    print(n, W, H, "tinta" if tinta else "")
