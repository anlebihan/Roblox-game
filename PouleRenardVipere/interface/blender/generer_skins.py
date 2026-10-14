# Textures « 9-slice » du style de l'interface : verre sombre, coins biseautés, liseré néon fin,
# reflet en haut, halo doux. Dessinées en x4 puis réduites (bords parfaitement lisses).
# Usage : python generer_skins.py <dossier_sortie>      (pip install pillow numpy scipy)
# Dans Roblox : ImageLabel.ScaleType = Slice, SliceCenter = valeur affichée pour chaque skin.
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
SS = 4

def poly_biseau(w, h, c, marge):
    m, c = marge, c
    return [(m + c, m), (w - m - c, m), (w - m, m + c), (w - m, h - m - c), (w - m - c, h - m), (m + c, h - m), (m, h - m - c), (m, m + c)]

def masque(w, h, pts):
    im = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(im).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    return im

def degrade(w, h, haut, bas, angle=90):
    y = np.linspace(0, 1, h * SS)[:, None]
    x = np.linspace(0, 1, w * SS)[None, :]
    t = y if angle == 90 else np.clip(0.75 * y + 0.25 * x, 0, 1)
    haut, bas = np.array(haut, np.float32), np.array(bas, np.float32)
    return haut[None, None, :] * (1 - t[..., None]) + bas[None, None, :] * t[..., None]

def skin(nom, w, h, coin, haut, bas, bord, alpha_fond=0.94, bord_alpha=0.75, halo=None, reflet=0.22, marge=10, epaisseur=2.0):
    pts = poly_biseau(w, h, coin, marge)
    M = np.asarray(masque(w, h, pts)).astype(np.float32) / 255
    rgb = degrade(w, h, haut, bas)
    img = np.zeros((h * SS, w * SS, 4), np.float32)
    # halo extérieur
    if halo:
        g = np.asarray(Image.fromarray((M * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(7 * SS))).astype(np.float32) / 255
        img[..., :3] = np.array(halo[:3]); img[..., 3] = np.clip(g * halo[3] * 1.6, 0, halo[3]) * (1 - M)
    # fond
    fond = np.zeros_like(img); fond[..., :3] = rgb; fond[..., 3] = M * alpha_fond
    img = sur(img, fond)
    # reflet (bande claire en haut)
    if reflet:
        yy = np.linspace(0, 1, h * SS)[:, None] * np.ones((1, w * SS))
        band = np.clip(1 - (yy - (marge + 2) / h) / 0.18, 0, 1) * (yy > (marge + 1) / h)
        r = np.zeros_like(img); r[..., :3] = 1; r[..., 3] = band * reflet * M
        img = sur(img, r)
    # liseré (contour du polygone)
    contour = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(contour).polygon([(x * SS, y * SS) for x, y in pts], outline=255, width=int(epaisseur * SS))
    C = np.asarray(contour).astype(np.float32) / 255
    l = np.zeros_like(img); l[..., :3] = np.array(bord); l[..., 3] = C * bord_alpha
    img = sur(img, l)
    res = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)
    res.save(os.path.join(out, nom + ".png"))
    print("%-24s %4dx%-4d SliceCenter = Rect.new(%d, %d, %d, %d)" % (nom, w, h, marge + coin + 4, marge + coin + 4, w - marge - coin - 4, h - marge - coin - 4))

def sur(dessous, dessus):
    ad = dessus[..., 3:4]; ab = dessous[..., 3:4]
    ao = ad + ab * (1 - ad)
    rgb = (dessus[..., :3] * ad + dessous[..., :3] * ab * (1 - ad)) / np.maximum(ao, 1e-6)
    return np.concatenate([rgb, ao], -1)

V = lambda r, g, b: (r / 255, g / 255, b / 255)
# panneaux / tuiles (verre violet sombre)
skin("skin_panneau", 256, 256, 22, V(40, 20, 82), V(12, 6, 28), V(190, 150, 255), halo=(*V(150, 90, 255), 0.35))
skin("skin_tuile", 192, 192, 16, V(52, 28, 104), V(18, 9, 40), V(200, 160, 255), halo=(*V(150, 90, 255), 0.4))
skin("skin_tuile_or", 192, 192, 16, V(70, 44, 30), V(24, 12, 30), V(255, 210, 63), halo=(*V(255, 190, 40), 0.55), bord_alpha=0.95)
skin("skin_ligne", 256, 96, 10, V(255, 255, 255), V(255, 255, 255), V(190, 150, 255), alpha_fond=0.05, bord_alpha=0.35, reflet=0, marge=4, epaisseur=1.5)
# boutons pleins
skin("skin_bouton_vert", 192, 96, 14, V(110, 245, 120), V(20, 150, 60), V(200, 255, 200), alpha_fond=1, bord_alpha=0.8, reflet=0.3, marge=6)
skin("skin_bouton_or", 192, 96, 14, V(255, 228, 110), V(230, 150, 0), V(255, 245, 200), alpha_fond=1, bord_alpha=0.8, reflet=0.3, marge=6)
skin("skin_bouton_rouge", 192, 96, 14, V(255, 120, 120), V(190, 25, 30), V(255, 210, 210), alpha_fond=1, bord_alpha=0.8, reflet=0.3, marge=6)
skin("skin_bouton_violet", 192, 96, 14, V(70, 40, 140), V(30, 15, 64), V(190, 150, 255), alpha_fond=1, bord_alpha=0.8, reflet=0.2, marge=6)
skin("skin_bouton_sombre", 192, 96, 14, V(40, 22, 80), V(16, 8, 34), V(150, 120, 220), alpha_fond=0.95, bord_alpha=0.6, reflet=0.12, marge=6)

# onglet en biais (parallélogramme)
def onglet(nom, haut, bas, bord, alpha=1.0):
    w, h, d = 192, 64, 18
    pts = [(d + 4, 4), (w - 4, 4), (w - d - 4, h - 4), (4, h - 4)]
    M = np.asarray(masque(w, h, pts)).astype(np.float32) / 255
    img = np.zeros((h * SS, w * SS, 4), np.float32); img[..., :3] = degrade(w, h, haut, bas); img[..., 3] = M * alpha
    c = Image.new("L", (w * SS, h * SS), 0); ImageDraw.Draw(c).polygon([(x * SS, y * SS) for x, y in pts], outline=255, width=2 * SS)
    l = np.zeros_like(img); l[..., :3] = np.array(bord); l[..., 3] = np.asarray(c).astype(np.float32) / 255 * 0.8
    img = sur(img, l)
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS).save(os.path.join(out, nom + ".png"))
    print("%-24s SliceCenter = Rect.new(30, 10, 162, 54)" % nom)
onglet("skin_onglet_actif", V(255, 228, 110), V(230, 150, 0), V(255, 245, 200))
onglet("skin_onglet", V(52, 28, 104), V(22, 11, 48), V(190, 150, 255), 0.95)

# cercle des boutons d'action (verre sombre + anneau) et anneau segmenté (recharge)
N = 512
y, x = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
r = np.sqrt(x * x + y * y)
def lisse(v): v = np.clip(v, 0, 1); return v * v * (3 - 2 * v)
corps = lisse((0.86 - r) / 0.01)
fond = np.zeros((N, N, 4)); fond[..., :3] = (np.array(V(44, 22, 90)) * (1 - (y + 1) / 2)[..., None] + np.array(V(12, 6, 28)) * ((y + 1) / 2)[..., None]); fond[..., 3] = corps * 0.92
bord = np.clip(lisse((0.86 - r) / 0.01) - lisse((0.83 - r) / 0.01), 0, 1)
l = np.zeros_like(fond); l[..., :3] = 1; l[..., 3] = bord
reflet = np.clip(1 - np.hypot(x * 1.2, (y + 0.45) * 2.2), 0, 1) * corps * 0.22
rf = np.zeros_like(fond); rf[..., :3] = 1; rf[..., 3] = reflet
img = sur(sur(fond, rf), l)
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(os.path.join(out, "skin_cercle.png"))
ang = (np.degrees(np.arctan2(x, -y)) + 360) % 360
segments = ((ang % 30) > 3) * lisse((0.99 - r) / 0.01) * lisse((r - 0.9) / 0.01)
img = np.zeros((N, N, 4)); img[..., :3] = 1; img[..., 3] = segments
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(os.path.join(out, "skin_anneau_segments.png"))
# reflet diagonal qui balaie les panneaux / boutons
W, H = 256, 256
yy, xx = np.mgrid[0:H, 0:W] / 255.0
d = (xx - yy * 0.5)
band = np.exp(-((d - 0.4) / 0.06) ** 2) * 0.9 + np.exp(-((d - 0.55) / 0.02) ** 2) * 0.6
img = np.zeros((H, W, 4)); img[..., :3] = 1; img[..., 3] = np.clip(band, 0, 1)
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(os.path.join(out, "fx_brillance.png"))
# coins de visée (crochets) pour les cartes de caisse
C = 128
im = Image.new("L", (C * SS, C * SS), 0); dr = ImageDraw.Draw(im)
e = 6 * SS
dr.line([(4 * SS, 4 * SS), (40 * SS, 4 * SS)], fill=255, width=e); dr.line([(4 * SS, 4 * SS), (4 * SS, 40 * SS)], fill=255, width=e)
a = np.asarray(im.resize((C, C), Image.LANCZOS)).astype(np.float32) / 255
img = np.zeros((C, C, 4)); img[..., :3] = 1; img[..., 3] = a
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(os.path.join(out, "fx_coin_visee.png"))
print("skins ->", out)
