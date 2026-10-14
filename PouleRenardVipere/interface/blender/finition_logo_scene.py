# Finition du logo intégré à la scène (chargement_logo.png, rendu avec la caméra de la scène) :
# liseré néon aux couleurs des équipes + lueur douce, comme les anneaux du portail.
# Contours calculés par champ de distance en double résolution : bords parfaitement lisses,
# la lueur prend la couleur de la lettre la plus proche (aucune cassure de couleur).
# Le résultat garde le cadrage plein écran pour se superposer pile aux autres couches.
# Usage : python finition_logo_scene.py chargement_logo.png chargement_logo_final.png
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

src, dst = sys.argv[1], sys.argv[2]
img = Image.open(src).convert("RGBA")
W, H = img.size
SS = 2                                                     # super-échantillonnage
big = img.resize((W * SS, H * SS), Image.BICUBIC)
A = np.asarray(big).astype(np.float32) / 255
alpha = ndi.gaussian_filter(A[..., 3], 0.6)
m = alpha > 0.5
k = W * SS / 1920                                          # échelle (pixels pour 1920 de large)

# distance (en pixels) au bord des lettres, à l'extérieur ; + index de la lettre la plus proche
d_ext, (iy, ix) = ndi.distance_transform_edt(~m, return_indices=True)

# couleurs : titre (mot 1 rouge -> orange, mot 2 vert), sous-titre en 3 parties (jaune, orange, vert)
lignes = np.nonzero(m.any(1))[0]; y0, y1 = lignes.min(), lignes.max()
proj = m[y0:y1 + 1].sum(1); trous = np.nonzero(proj == 0)[0]
coupe = y0 + (trous[len(trous) // 2] if len(trous) else int((y1 - y0) * 0.75))
cols_t = np.nonzero(m[y0:coupe].any(0))[0]
vides = np.setdiff1d(np.arange(cols_t.min(), cols_t.max()), cols_t)
milieu = vides[len(vides) // 2] if len(vides) else (cols_t.min() + cols_t.max()) // 2
cols_s = np.nonzero(m[coupe:].any(0))[0]
s0, s1 = (cols_s.min(), cols_s.max()) if len(cols_s) else (0, W * SS)
rouge, orange, jaune, vert = (np.array(c, np.float32) for c in ((1.0, 0.2, 0.08), (1.0, 0.55, 0.06), (1.0, 0.86, 0.18), (0.38, 1.0, 0.18)))
yy, xx = np.mgrid[0:H * SS, 0:W * SS]
t1 = np.clip((xx - cols_t.min()) / max(milieu - cols_t.min(), 1), 0, 1)[..., None]
titre = np.where((xx < milieu)[..., None], rouge * (1 - t1) + orange * t1, vert)
u = np.clip((xx - s0) / max(s1 - s0, 1), 0, 1)[..., None]
# transitions douces entre les 3 mots du sous-titre
w1 = np.clip((u - 0.30) / 0.06, 0, 1); w2 = np.clip((u - 0.64) / 0.06, 0, 1)
sous = jaune * (1 - w1) + orange * w1 * (1 - w2) + vert * w2
col_lettres = np.where((yy < coupe)[..., None], titre, sous).astype(np.float32)
col = col_lettres[iy, ix]                                  # couleur de la lettre la plus proche

def lisse(x):                                              # smoothstep 0..1
    x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)

R_LISERE = 5.0 * k
liser_a = lisse((R_LISERE - d_ext) / (1.2 * k) + 0.5) * (~m)
lueur_a = np.exp(-(d_ext / (16 * k)) ** 2) * 0.85 * (~m)

def sur(dessous, dessus):
    ad = dessus[..., 3:4]; ab = dessous[..., 3:4]
    ao = ad + ab * (1 - ad)
    rgb = (dessus[..., :3] * ad + dessous[..., :3] * ab * (1 - ad)) / np.maximum(ao, 1e-6)
    return np.concatenate([rgb, ao], -1)

def couche(a, c):
    o = np.zeros((H * SS, W * SS, 4), np.float32); o[..., :3] = c; o[..., 3] = np.clip(a, 0, 1); return o

lettres = A.copy()
lettres[..., 3] = lisse((alpha - 0.35) / 0.3)              # bord des lettres net mais anti-crénelé
res = couche(lueur_a, col)
res = sur(res, couche(liser_a, np.clip(col * 0.55 + 0.45, 0, 1)))
res = sur(res, lettres)
out = Image.fromarray((np.clip(res, 0, 1) * 255).astype(np.uint8), "RGBA").resize((W, H), Image.LANCZOS)
out.save(dst)
print("logo scène :", dst)
