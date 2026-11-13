"""Esporta l'apprendista di WB-037/039 per Godot: un PNG per pezzo, dritto (rotazione
del riposo già dentro), alla densità DENS px per unità, e rig.json nel formato di
art/apprendista2 (unità, y in su, 0 ai piedi). Tutte le posizioni vengono da t.json
(registrazione su R1), dai perni delle giunture e dall'allineamento delle teste."""
import json, os, sys, numpy as np, cv2
from PIL import Image
from scipy import ndimage
from skimage.morphology import skeletonize
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
t = json.load(open("t.json"))
U_PX = None                       # px di R1 per unità (si calcola sotto)
DENS = 12.0                       # px della texture per unità
S_CORPO = 1.64                    # px di R1 per px del foglio corpo (uguale per tutto il foglio)
def A_(m): return np.vstack([np.array(m, float), [0, 0, 1]])
def tr(x, y): return np.array([[1, 0, x], [0, 1, y], [0, 0, 1.]])
def rot(deg, s=1.0):
    r = np.radians(deg); c, n = np.cos(r) * s, np.sin(r) * s
    return np.array([[c, -n, 0], [n, c, 0], [0, 0, 1.]])
def ang(A): return np.degrees(np.arctan2(A[1, 0], A[0, 0]))
def app(M, p): return (M @ np.array([p[0], p[1], 1.0]))[:2]
HEAD = A_([[2.18884, 0, 189.541], [0, 2.18884, 113.185]]) @ tr(-27, -41)   # foglio teste -> R1

def corpo(nome, rot_keep=True, perno=None, fisso=None):
    """Trasformazione pezzo -> R1 per un pezzo del foglio corpo, a scala S_CORPO.
    perno: punto del pezzo che resta dov'è nella registrazione (o va su 'fisso')."""
    A = A_(t[f"pezzi37/{nome}.png"])
    th = ang(A) if rot_keep else 0.0
    p = perno if perno is not None else (0.0, 0.0)
    dove = fisso if fisso is not None else app(A, p)
    return tr(*dove) @ rot(th, S_CORPO) @ tr(-p[0], -p[1])

GIU = json.load(open("giunture.json"))
def g(n, i=0): return GIU[n][i]["c"]
busto = corpo("corpo_1_1")
spalla_a = app(busto, g("corpo_1_1", 1))          # spalla vicina (senza contorno)
collo = app(busto, g("corpo_1_1", 0))
far_arm = A_(t["pezzi37/corpo_1_4.png"])
spalla_d = app(far_arm, g("corpo_1_4"))
pezzi = {
    "braccio_dietro": ("svg37/corpo_1_4.png", 3.4, corpo("corpo_1_4", False, g("corpo_1_4"), spalla_d)),
    "gamba_dietro": ("svg37/corpo_1_6.png", 3.4, corpo("corpo_1_6", True, g("corpo_1_6"))),
    "gamba": ("svg37/corpo_1_5.png", 3.4, corpo("corpo_1_5", True, g("corpo_1_5"))),
    "busto": ("svg37/corpo_1_1.png", 3.4, busto),
    "sciarpa": ("svg37/corpo_1_0.png", 3.4, corpo("corpo_1_0")),
    "sciarpa_tinta": ("svg37/corpo_1_0_tinta.png", 3.4, corpo("corpo_1_0")),
    "braccio": ("svg37/corpo_1_3.png", 3.4, corpo("corpo_1_3", False, g("corpo_1_3"), spalla_a)),
    "corno_dietro": ("svg39/corna_diff_0.png", 4.38, HEAD @ tr(81, 41)),
    "corno": ("svg39/corna_diff_1.png", 4.38, HEAD @ tr(246, 51)),
}
coda = ("svg37/corpo_1_2.png", 3.4, corpo("corpo_1_2", True, g("corpo_1_2")))
# le teste: tutte nel riquadro della prima (spostamenti calcolati sulla sagoma)
SPOST = [(0, 0), (-1, -1), (-1, -1), (-1, -1), (0, 0), (-1, -1), (1, -1), (0, -1), (-1, -1)]
NOMI = ["testa", "testa_colpita", "testa_felice", "testa_ko", "testa_mira", "testa_arrabbiata",
        "testa_sconfitta", "testa_paura", "testa_sfotto"]
for i, n in enumerate(NOMI):
    pezzi[n] = (f"svg39/teste_senza_corna_2_{i}.png", 4.38, HEAD @ tr(28 + SPOST[i][0], 98 + SPOST[i][1]))
# la fiamma dritta, con la base (centro in basso, sopra lo sfumato) sul punto del cranio di R1
FL = A_([[0.28667, 0.0352, 453.258], [-0.0352, 0.28667, 35.652]])
base_pz = (283.0, 905.0)                       # centro della base nel pezzo (prima dello sfumato)
base_r1 = app(FL, base_pz)
pezzi["fiamma"] = ("svg37/fiamma_base.png", 0.6, tr(*base_r1) @ rot(0, 0.28737) @ tr(-base_pz[0], -base_pz[1]))

# unità: 200 dai piedi alla cima del cranio (come DISEGNO_H nel gioco)
def bbox_r1(png, k, M):
    a = np.asarray(Image.open(png).convert("RGBA"))[..., 3] > 128
    ys, xs = np.nonzero(a)
    pts = np.stack([xs / k, ys / k], 1)
    q = (M[:2, :2] @ pts.T).T + M[:2, 2]
    return q.min(0), q.max(0)
piedi = max(bbox_r1(*pezzi[n])[1][1] for n in ("gamba", "gamba_dietro"))
cima = bbox_r1(*pezzi["testa"])[0][1]
U_PX = (piedi - cima) / 200.0
bx0, bx1 = bbox_r1(*pezzi["busto"])
X0 = (bx0[0] + bx1[0]) / 2
def unit(p): return [float((p[0] - X0) / U_PX), float((piedi - p[1]) / U_PX)]

def esporta(nome, png, k, M):
    """Il pezzo ridisegnato dritto alla densità DENS: la rotazione del riposo è nel PNG."""
    a = np.asarray(Image.open(png).convert("RGBA")).astype(np.float32)
    # pezzo -> R1 -> texture (DENS / U_PX px per px di R1)
    f = DENS / U_PX
    T = np.diag([f, f, 1]) @ M @ np.diag([1 / k, 1 / k, 1])
    h, w = a.shape[:2]
    cs = np.array([[0, 0], [w, 0], [0, h], [w, h]], float)
    q = (T[:2, :2] @ cs.T).T + T[:2, 2]
    lo = np.floor(q.min(0)) - 2; hi = np.ceil(q.max(0)) + 2
    T2 = tr(-lo[0], -lo[1]) @ T
    W, H = int(hi[0] - lo[0]), int(hi[1] - lo[1])
    # alfa premoltiplicato per non avere aloni scuri ai bordi
    pm = a.copy(); pm[..., :3] *= a[..., 3:] / 255
    o = cv2.warpAffine(pm, T2[:2].astype(np.float32), (W, H), flags=cv2.INTER_CUBIC)
    al = np.clip(o[..., 3:], 0, 255)
    o[..., :3] = np.where(al > 0, o[..., :3] * 255 / np.maximum(al, 1e-3), 0)
    o = np.clip(o, 0, 255).astype(np.uint8)
    Image.fromarray(o).save(f"{OUT}/{nome}.png")
    # centro e misura in unità (y in su)
    c_tex = np.array([W / 2, H / 2]) + lo
    c_r1 = c_tex / f
    cu = unit(c_r1)
    return {"img": nome, "tint": False, "cx": cu[0], "cy": cu[1], "w": W / DENS, "h": H / DENS}

rig = {"height": 200, "new": True, "wb037": True, "pieces": {}, "pivots": {}}
for n, (png, k, M) in pezzi.items():
    rig["pieces"][n] = esporta(n, png, k, M)
rig["pieces"]["busto"]["tint"] = False
# i perni (unità): spalle, anche, collo, fiamma, busto (in basso al centro)
rig["pivots"]["braccio"] = unit(spalla_a)
rig["pivots"]["braccio_dietro"] = unit(spalla_d)
rig["pivots"]["gamba"] = unit(app(pezzi["gamba"][2], g("corpo_1_5")))
rig["pivots"]["gamba_dietro"] = unit(app(pezzi["gamba_dietro"][2], g("corpo_1_6")))
rig["pivots"]["testa"] = unit(collo)
rig["pivots"]["fiamma"] = unit(base_r1)
lo, hi = bbox_r1(*pezzi["busto"])
rig["pivots"]["busto"] = unit(((lo[0] + hi[0]) / 2, hi[1] - (hi[1] - lo[1]) * 0.3))
def base_pezzo(png, k):
    """Il centro della base di un pezzo (le righe più basse della sagoma), in px del pezzo."""
    a = np.asarray(Image.open(png).convert("RGBA"))[..., 3] > 128
    ys, xs = np.nonzero(a)
    sel = ys >= ys.max() - (ys.max() - ys.min()) * 0.12
    return (xs[sel].mean() / k, ys[sel].mean() / k)
for n in ("corno", "corno_dietro"):
    png, k, M = pezzi[n]
    rig["pivots"][n] = unit(app(M, base_pezzo(png, k)))
# la coda: la linea di mezzo dal piede (giuntura) alla punta, 6 giunture
png, k, M = coda
tp = esporta("coda", png, k, M)
a = np.asarray(Image.open(f"{OUT}/coda.png"))[..., 3] > 128
sk = skeletonize(ndimage.binary_opening(a, iterations=3))
ys, xs = np.nonzero(sk)
root = app(M, g("corpo_1_2"))
f = DENS / U_PX
lo_tex = np.array([tp["cx"] - tp["w"] / 2, tp["cy"] + tp["h"] / 2])  # unità angolo in alto a sinistra
def tex2unit(x, y): return [lo_tex[0] + x / DENS, lo_tex[1] - y / DENS]
pts = np.array([tex2unit(x, y) for x, y in zip(xs, ys)])
ru = np.array(unit(root))
# percorso: dal punto dello scheletro più vicino alla radice, un passo alla volta
import heapq
idx = {(int(x), int(y)): i for i, (x, y) in enumerate(zip(xs, ys))}
start = int(np.argmin(((pts - ru) ** 2).sum(1)))
dist = {start: 0}; prev = {}
pq = [(0, start)]
while pq:
    d, i = heapq.heappop(pq)
    x, y = xs[i], ys[i]
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            j = idx.get((int(x + dx), int(y + dy)))
            if j is None or j == i: continue
            nd = d + (dx * dx + dy * dy) ** .5
            if nd < dist.get(j, 1e9):
                dist[j] = nd; prev[j] = i; heapq.heappush(pq, (nd, j))
end = max(dist, key=dist.get)
path = [end]
while path[-1] != start: path.append(prev[path[-1]])
path = pts[path[::-1]]
L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))]
# la punta della freccia non si piega: le giunture fino all'85%, l'ultima alla punta
cuts = np.r_[np.linspace(0, 0.85, 5), 0.97] * L[-1]
joints = [list(map(float, path[np.searchsorted(L, c).clip(0, len(path) - 1)])) for c in cuts]
joints[0] = list(map(float, ru))
rest = [float(np.arctan2(joints[i + 1][1] - joints[i][1], joints[i + 1][0] - joints[i][0])) for i in range(5)]
rig["tail"] = {"img": "coda", "left": tp["cx"] - tp["w"] / 2, "top": tp["cy"] + tp["h"] / 2,
               "w": tp["w"], "h": tp["h"], "joints": joints, "rest": rest}
rig["eyes"] = []
rig["faces_whole"] = NOMI
rig["u_px"] = U_PX
json.dump(rig, open(f"{OUT}/rig.json", "w"), indent=1)
print("u_px", U_PX, "pezzi", len(rig["pieces"]))
