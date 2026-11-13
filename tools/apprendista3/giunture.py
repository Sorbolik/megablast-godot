"""Le estremità senza contorno (giunture) di un pezzo: bordo della sagoma dove
dentro c'è pelle e non nero. Stampa i gruppi con centro e numero di pixel."""
import sys, json, numpy as np
from PIL import Image
from scipy import ndimage
def giunture(path):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(int)
    m = a[..., 3] > 128
    bordo = m & ~ndimage.binary_erosion(m, iterations=3)
    rgb = a[..., :3]
    lum = rgb @ np.array([.3, .59, .11])
    chiaro = lum > 70
    g = bordo & chiaro
    g = ndimage.binary_opening(g, iterations=1)
    lab, n = ndimage.label(ndimage.binary_dilation(g, iterations=4))
    out = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero((lab == i) & g)
        if len(xs) < 40: continue
        out.append({"c": [float(xs.mean()), float(ys.mean())], "n": int(len(xs)), "x": [int(xs.min()), int(xs.max())], "y": [int(ys.min()), int(ys.max())]})
    return out
if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(p, json.dumps(giunture(p)))
