"""Registra un pezzo ritagliato su R1: scala, rotazione, posizione che minimizzano
la differenza di colore dentro la sagoma del pezzo. Niente occhio: ricerca a griglia
grossolana poi fine."""
import sys, json
import numpy as np, cv2
from PIL import Image

def load_r1(path, k):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    return cv2.resize(a, None, fx=k, fy=k, interpolation=cv2.INTER_AREA)

def piece(path):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
    return a[..., :3], (a[..., 3] > 200).astype(np.float32)

def warp(rgb, m, s, th):
    h, w = m.shape
    c = (w / 2, h / 2)
    M = cv2.getRotationMatrix2D(c, th, s)
    # canvas big enough
    cs, sn = abs(M[0, 0]), abs(M[0, 1])
    W, H = int(w * cs + h * sn) + 2, int(w * sn + h * cs) + 2
    M[0, 2] += W / 2 - c[0]; M[1, 2] += H / 2 - c[1]
    r = cv2.warpAffine(rgb, M, (W, H), flags=cv2.INTER_LINEAR)
    mm = cv2.warpAffine(m, M, (W, H), flags=cv2.INTER_LINEAR)
    return r, (mm > 0.99).astype(np.float32), M

def best(R, rgb, m, scales, rots):
    out = None
    for s in scales:
        for th in rots:
            t, tm, M = warp(rgb, m, s, th)
            if t.shape[0] >= R.shape[0] or t.shape[1] >= R.shape[1] or tm.sum() < 50:
                continue
            tm3 = np.repeat(tm[..., None], 3, -1)
            res = cv2.matchTemplate(R, t, cv2.TM_SQDIFF, mask=tm3)
            res = res / tm.sum()
            v, _, loc, _ = cv2.minMaxLoc(res)
            if out is None or v < out[0]:
                out = (v, s, th, loc, M, t.shape)
    return out

def registra(r1, pz, smin, smax, rot):
    rgb, m = piece(pz)
    k = 0.25
    R = load_r1(r1, k)
    small = cv2.resize(rgb, None, fx=k, fy=k, interpolation=cv2.INTER_AREA)
    ms = cv2.resize(m, None, fx=k, fy=k, interpolation=cv2.INTER_AREA)
    c = best(R, small, ms, np.geomspace(smin, smax, 24 if smax > smin * 1.01 else 1), np.arange(-rot, rot + 1, 5))
    # fine at 0.5
    k2 = 0.5
    R2 = load_r1(r1, k2)
    small = cv2.resize(rgb, None, fx=k2, fy=k2, interpolation=cv2.INTER_AREA)
    ms = cv2.resize(m, None, fx=k2, fy=k2, interpolation=cv2.INTER_AREA)
    f = best(R2, small, ms, c[1] * (np.linspace(0.94, 1.06, 13) if smax > smin * 1.01 else np.array([1.0])), c[2] + np.arange(-4, 4.5, 1))
    v, s, th, loc, M, shp = f
    # transform from piece pixels to R1 pixels (full res): p_R1 = (M_scaled p_piece*k2 + loc)/k2
    A = M.copy()
    A[:, 2] += loc
    A[:, 2] /= k2      # M applies to piece scaled by k2; scale s stays (piece px -> R1 px)
    return {"errore": float(v) ** 0.5, "scala": float(s), "rot": float(th), "A": A.tolist()}

if __name__ == "__main__":
    r1, pz, smin, smax, rot = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
    print(json.dumps(registra(r1, pz, smin, smax, rot)))
