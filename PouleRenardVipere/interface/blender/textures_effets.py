# Textures des effets de l'interface (halo, rayons, braise, masque du logo, éclat de lame).
# Usage : python textures_effets.py <logo_final.png> <dossier_sortie>      (pip install pillow numpy scipy)
import sys, os, math
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

logo, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)

def sauver(arr, nom):
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA").save(os.path.join(out, nom + ".png"))

N = 512
y, x = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
r = np.sqrt(x * x + y * y)
a = np.arctan2(y, x)

# halo d'anneau (blanc, on le teinte dans Roblox avec ImageColor3)
anneau = np.exp(-((r - 0.78) / 0.07) ** 2) + 0.35 * np.exp(-((r - 0.78) / 0.22) ** 2)
img = np.zeros((N, N, 4)); img[..., :3] = 1; img[..., 3] = np.clip(anneau, 0, 1)
sauver(img, "fx_anneau")

# rayons de lumière (16 rayons doux, fondu vers l'extérieur)
rayons = (0.5 + 0.5 * np.cos(a * 16)) ** 6 * np.clip(1 - r, 0, 1) ** 1.5
img = np.zeros((N, N, 4)); img[..., :3] = 1; img[..., 3] = np.clip(rayons, 0, 1)
sauver(img, "fx_rayons")

# braise / particule douce
M = 128
yy, xx = np.mgrid[-1:1:M * 1j, -1:1:M * 1j]
rr = np.sqrt(xx * xx + yy * yy)
img = np.zeros((M, M, 4)); img[..., :3] = 1; img[..., 3] = np.clip(np.exp(-(rr / 0.35) ** 2) * 1.2, 0, 1)
sauver(img, "fx_braise")

# étincelle à 4 branches
dx, dy = np.abs(xx), np.abs(yy)
et = np.clip(1 - (np.sqrt(dx) + np.sqrt(dy)), 0, 1) ** 1.4
img = np.zeros((M, M, 4)); img[..., :3] = 1; img[..., 3] = et
sauver(img, "fx_etincelle")

# éclat de lame (bande diagonale lumineuse pour la transition « coup de couteau »)
W, H = 1024, 128
yy2, xx2 = np.mgrid[-1:1:H * 1j, -1:1:W * 1j]
bande = np.exp(-(yy2 / 0.18) ** 2) * np.clip(1 - np.abs(xx2) ** 6, 0, 1)
coeur = np.exp(-(yy2 / 0.05) ** 2)
img = np.zeros((H, W, 4)); img[..., :3] = 1; img[..., 3] = np.clip(bande * 0.8 + coeur, 0, 1)
sauver(img, "fx_lame")

# masque blanc du logo (pour le reflet qui passe dessus)
L = np.asarray(Image.open(logo).convert("RGBA")).astype(np.float32) / 255
m = np.zeros_like(L); m[..., :3] = 1; m[..., 3] = L[..., 3]
sauver(m, "logo_masque")
print("textures ->", out)

# fissure lumineuse (vue de biais : aplatie), teintée dans Roblox à la couleur de l'équipe
import random
from PIL import ImageDraw, ImageFilter
random.seed(5)
F = 512
fis = Image.new("L", (F, F), 0); dr = ImageDraw.Draw(fis)
def branche(x, y, ang, long, ep, prof):
    for _ in range(int(long / 10)):
        ang += random.uniform(-0.45, 0.45)
        nx, ny = x + math.cos(ang) * 10, y + math.sin(ang) * 10
        dr.line([(x, y), (nx, ny)], fill=255, width=max(1, int(ep)))
        x, y = nx, ny; ep *= 0.96
        if prof < 2 and random.random() < 0.08:
            branche(x, y, ang + random.choice((-1, 1)) * random.uniform(0.5, 1.0), long * 0.45, ep * 0.8, prof + 1)
for i in range(7):
    branche(F / 2, F / 2, i * 2 * math.pi / 7 + random.uniform(-0.3, 0.3), random.uniform(150, 230), 7, 0)
coeur = np.asarray(fis).astype(np.float32) / 255
lueur = np.asarray(fis.filter(ImageFilter.GaussianBlur(9))).astype(np.float32) / 255
a_f = np.clip(coeur + lueur * 2.2, 0, 1)
img = np.zeros((F, F, 4)); img[..., :3] = 1; img[..., 3] = a_f
Image.fromarray((img * 255).astype(np.uint8), "RGBA").resize((F, int(F * 0.42)), Image.LANCZOS).save(os.path.join(out, "fx_fissure.png"))

# nuage de poussière (bruit doux)
P = 256
bruit = ndi.gaussian_filter(np.random.RandomState(3).rand(P, P), 9)
bruit = (bruit - bruit.min()) / (bruit.max() - bruit.min())
yy3, xx3 = np.mgrid[-1:1:P * 1j, -1:1:P * 1j]
rond = np.clip(1 - np.sqrt(xx3 ** 2 + yy3 ** 2), 0, 1) ** 1.2
img = np.zeros((P, P, 4)); img[..., :3] = 1; img[..., 3] = np.clip(rond * (0.45 + 0.75 * bruit), 0, 1)
sauver(img, "fx_fumee")
print("fissure + fumée ->", out)
