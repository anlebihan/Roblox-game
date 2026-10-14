# Finition 2D du logo (après le rendu Blender en 3 couches : logo_titre / logo_bandeau / logo_sous) :
# contours noirs bien ronds, reflets blancs sur le haut des lettres, ombre portée, étincelles,
# puis réduction en taille Roblox (1024 px max).
# Usage : python finition_logo.py <dossier_rendus> <logo_final.png>      (pip install pillow numpy scipy)
import sys, os, math
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

dossier, dst = sys.argv[1], sys.argv[2]
def charger(n):
    return np.asarray(Image.open(os.path.join(dossier, n + ".png")).convert("RGBA")).astype(np.float32) / 255
titre, bandeau, sous = charger("logo_titre"), charger("logo_bandeau"), charger("logo_sous")
h, w = titre.shape[:2]
PAD = 120
def pad(x):
    b = np.zeros((h + 2 * PAD, w + 2 * PAD, 4), np.float32); b[PAD:PAD + h, PAD:PAD + w] = x; return b
titre, bandeau, sous = pad(titre), pad(bandeau), pad(sous)

def disque(r):
    y, x = np.ogrid[-r:r + 1, -r:r + 1]
    return x * x + y * y <= r * r

def sur(dessous, dessus):
    ad = dessus[..., 3:4]; ab = dessous[..., 3:4]
    ao = ad + ab * (1 - ad)
    rgb = (dessus[..., :3] * ad + dessous[..., :3] * ab * (1 - ad)) / np.maximum(ao, 1e-6)
    return np.concatenate([rgb, ao], -1)

def reflet(img, dec, force):
    m = img[..., 3] > 0.5
    d = np.zeros_like(m); d[dec:] = m[:-dec]
    r = ndi.gaussian_filter((m & ~d).astype(np.float32), dec * 0.25) * force
    out = img.copy(); out[..., :3] = img[..., :3] * (1 - r[..., None]) + r[..., None]
    return out

def contour(img, r, couleur=(0.04, 0.02, 0.08), ombre=True):
    m = img[..., 3] > 0.4
    c = np.clip(ndi.gaussian_filter(ndi.binary_dilation(m, disque(r)).astype(np.float32), 1.3) * 1.3, 0, 1)
    lay = np.zeros_like(img); lay[..., :3] = couleur; lay[..., 3] = c
    if ombre:
        o = np.zeros_like(c); d = int(r * 0.9); o[d:] = c[:-d]
        sh = np.zeros_like(img); sh[..., 3] = ndi.gaussian_filter(o, r * 0.7) * 0.6
        lay = sur(sh, lay)
    return lay

R = max(8, int(w * 0.02))
# sous-titre : petit contour propre sur le bandeau
sous_c = sur(contour(sous, max(3, R // 3), ombre=False), reflet(sous, 6, 0.35))
bloc_bas = sur(reflet(bandeau, 10, 0.25), sous_c)
bloc_bas = sur(contour(bandeau, R, ombre=True), bloc_bas)
haut = sur(contour(titre, R, ombre=True), reflet(titre, 16, 0.55))
res = sur(bloc_bas, haut)

# étincelles (étoiles à 4 branches) autour du titre
def etoile(img, cx, cy, taille, alpha=1.0):
    H, W = img.shape[:2]
    y, x = np.ogrid[:H, :W]
    dx, dy = np.abs(x - cx) / taille, np.abs(y - cy) / taille
    v = np.clip(1 - (np.sqrt(dx) + np.sqrt(dy)), 0, 1) ** 1.5 * alpha
    lay = np.zeros_like(img); lay[..., :3] = 1.0; lay[..., 3] = v
    return sur(img, lay)
mt = titre[..., 3] > 0.5
ys, xs = np.nonzero(mt)
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
for fx, fy, t in ((0.02, 0.05, 70), (0.47, -0.02, 50), (0.98, 0.12, 80), (0.6, 0.9, 40), (0.12, 0.95, 45)):
    res = etoile(res, x0 + (x1 - x0) * fx, y0 + (y1 - y0) * fy, t)

img = Image.fromarray((np.clip(res, 0, 1) * 255).astype(np.uint8), "RGBA")
img = img.crop(img.getbbox())
img.thumbnail((1024, 1024), Image.LANCZOS)
img.save(dst)
print("logo final :", dst, img.size)
