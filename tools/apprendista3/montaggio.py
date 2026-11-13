"""Il montaggio di riposo dell'apprendista nel riquadro di R1 (2x), dai pezzi
ricalcati e dalle trasformazioni calcolate (registra.py, perni, allineamento delle
teste). Scrive montaggio.json (per Godot) e il confronto con R1."""
import json, sys, numpy as np, cv2
from PIL import Image
t = json.load(open("t.json"))
K = 2.0                                     # il montaggio è R1 x2
def A_(m): return np.vstack([np.array(m, float), [0, 0, 1]])
def sc(k): return np.diag([1 / k, 1 / k, 1])
def tr(x, y): return np.array([[1, 0, x], [0, 1, y], [0, 0, 1.]])
Rk = np.diag([K, K, 1])
head = A_([[2.18884, 0, 189.541], [0, 2.18884, 113.185]]) @ tr(-27, -41)    # foglio teste -> R1
pezzi = []   # (nome, png, matrice pezzo-ricalcato -> montaggio)
def add(nome, png, M): pezzi.append((nome, png, Rk @ M))
add("braccio_dietro", "svg37/corpo_1_4.png", A_(t["pezzi37/corpo_1_4.png"]) @ sc(3.4))
add("gamba_dietro", "svg37/corpo_1_6.png", A_(t["pezzi37/corpo_1_6.png"]) @ sc(3.4))
add("coda", "svg37/corpo_1_2.png", A_(t["pezzi37/corpo_1_2.png"]) @ sc(3.4))
add("gamba", "svg37/corpo_1_5.png", A_(t["pezzi37/corpo_1_5.png"]) @ sc(3.4))
add("busto", "svg37/corpo_1_1.png", A_(t["pezzi37/corpo_1_1.png"]) @ sc(3.4))
add("fazzoletto", "svg37/corpo_1_0.png", A_(t["pezzi37/corpo_1_0.png"]) @ sc(3.4))
add("fazzoletto_tinta", "svg37/corpo_1_0_tinta.png", A_(t["pezzi37/corpo_1_0.png"]) @ sc(3.4))
add("testa", "svg39/teste_senza_corna_2_0.png", head @ tr(28, 98) @ sc(4.38))
add("corno_dietro", "svg39/corna_diff_0.png", head @ tr(81, 41) @ sc(4.38))
add("corno", "svg39/corna_diff_1.png", head @ tr(246, 51) @ sc(4.38))
add("fiamma", "svg37/fiamma_1_0.png", A_([[0.28667, 0.0352, 453.258], [-0.0352, 0.28667, 35.652]]) @ sc(0.6))
add("braccio", "svg37/corpo_1_3.png", A_(t["pezzi37/corpo_1_3.png"]) @ sc(3.4))
r1 = Image.open("R1.png").convert("RGB")
W, H = int(r1.width * K), int(r1.height * K)
tela = np.zeros((H, W, 4), np.float32); tela[..., :3] = 255; tela[..., 3] = 255
team = np.array([0, 255, 0], np.float32)
out = {}
for nome, png, M in pezzi:
    a = np.asarray(Image.open(png).convert("RGBA")).astype(np.float32)
    if nome.endswith("_tinta"):
        a[..., :3] = a[..., :3] / 255 * team
    w = cv2.warpAffine(a, M[:2].astype(np.float32), (W, H), flags=cv2.INTER_LINEAR)
    al = w[..., 3:] / 255
    tela[..., :3] = tela[..., :3] * (1 - al) + w[..., :3] * al
    out[nome] = {"png": png, "M": M[:2].tolist()}
json.dump(out, open("montaggio.json", "w"), indent=1)
m = Image.fromarray(tela[..., :3].clip(0, 255).astype(np.uint8))
r = r1.resize((W, H), Image.LANCZOS)
conf = Image.new("RGB", (W * 2 + 40, H), "white"); conf.paste(r, (0, 0)); conf.paste(m, (W + 40, 0))
conf.save("confronto_R1.png"); m.save("montaggio.png")
