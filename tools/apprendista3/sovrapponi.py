import sys, json, numpy as np, cv2
from PIL import Image
r1 = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(np.float32)
out = r1 * 0.35 + 255 * 0.65
for pz, A in json.load(open(sys.argv[2])).items():
    a = np.asarray(Image.open(pz).convert("RGBA")).astype(np.float32)
    w = cv2.warpAffine(a, np.array(A, np.float32), (r1.shape[1], r1.shape[0]))
    al = w[..., 3:4] / 255 * 0.75
    out = out * (1 - al) + w[..., :3] * al
Image.fromarray(out.clip(0, 255).astype(np.uint8)).save(sys.argv[3])
