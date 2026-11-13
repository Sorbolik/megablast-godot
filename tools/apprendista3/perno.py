"""Ruota un pezzo attorno al suo perno messo su un punto di R1 (scala fissa),
cerca l'angolo (e un piccolo spostamento del perno) che combacia di più."""
import sys, json, numpy as np, cv2
from PIL import Image
def main(r1, pz, px, py, qx, qy, s, amin, amax, slack=0):
    R = np.asarray(Image.open(r1).convert("RGB")).astype(np.float32)
    X0, Y0 = int(qx) - 200, int(qy) - 60
    R = R[Y0:Y0 + 520, X0:X0 + 400]
    a = np.asarray(Image.open(pz).convert("RGBA")).astype(np.float32)
    best = None
    for dx in range(-slack, slack + 1, 5):
        for dy in range(-slack, slack + 1, 5):
            for th in np.arange(amin, amax + 0.1, 1.0):
                t = np.radians(th); c, sn = np.cos(t) * s, np.sin(t) * s
                A = np.array([[c, -sn, 0], [sn, c, 0]], np.float32)
                A[:, 2] = np.array([qx + dx - X0, qy + dy - Y0]) - A[:, :2] @ np.array([px, py])
                w = cv2.warpAffine(a, A, (R.shape[1], R.shape[0]))
                m = w[..., 3] > 250
                if m.sum() < 100: continue
                e = (((w[..., :3] - R) ** 2).sum(-1)[m]).mean()
                if best is None or e < best[0]:
                    B = A.copy(); B[:, 2] += [X0, Y0]
                    best = (float(e), float(th), dx, dy, B.tolist())
    print(json.dumps({"errore": best[0] ** .5, "angolo": best[1], "spost": best[2:4], "A": best[4]}))
if __name__ == "__main__":
    v = sys.argv
    main(v[1], v[2], *map(float, v[3:10]), int(v[10]) if len(v) > 10 else 0)
