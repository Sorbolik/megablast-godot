"""Le corna per differenza: quello che in teste_1 c'è e nella testa senza corna no,
più i pixel color corno (e il loro contorno) attaccati a quella zona. Scrive il foglio
delle corna e il foglio delle teste senza corna, su magenta, stessa tela."""
import sys, numpy as np
from PIL import Image
from scipy import ndimage
r = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(int)
h = np.asarray(Image.open(sys.argv[2]).convert("RGB")).astype(int)
def mag(a): return (a[..., 0] > 200) & (a[..., 1] < 90) & (a[..., 2] > 200)
diff = ~mag(r) & mag(h)
diff = ndimage.binary_opening(diff, iterations=1)
lum = r @ np.array([.3, .59, .11])
corno = ~mag(r) & (lum > 175) & (r[..., 1] > 170)        # crema chiara e ombra delle corna
semi = ndimage.binary_dilation(diff, iterations=2)
lab, n = ndimage.label(corno)
tieni = np.unique(lab[semi & corno]); tieni = tieni[tieni > 0]
zona = diff | np.isin(lab, tieni)
# il contorno nero e le righe attorno alle corna
zona |= ndimage.binary_dilation(zona, iterations=7) & (lum < 90) & ~mag(r) & ndimage.binary_dilation(np.isin(lab, tieni) | diff, iterations=7)
zona = ndimage.binary_closing(zona, iterations=2) & ~mag(r)
pelle = (r[..., 0] > 120) & (r[..., 1] < 110) & (r[..., 0] - r[..., 2] > 60)
zona &= ~pelle
zona = ndimage.binary_opening(zona, iterations=1)
out = np.where(zona[..., None], r, [255, 0, 255]).astype(np.uint8)
Image.fromarray(out).save(sys.argv[3])
print("corna px", zona.sum())
