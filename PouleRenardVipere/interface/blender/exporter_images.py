# Prépare les images de l'écran de chargement pour Roblox (1024 px max par image) :
#  - couches plein écran opaques/larges (ciel, rocher) : découpées en 4 morceaux (avec 4 px de recouvrement)
#  - couches avec peu de contenu (couteaux, ombres, logo) : rognées à leur contenu (une seule image)
#  - écrit le tableau DECOUPE (position de chaque morceau) directement dans EcranChargement.lua
# Usage : python exporter_images.py <dossier_rendus> <dossier_fx> <dossier_images_sortie> <EcranChargement.lua>
import sys, os, shutil
from PIL import Image

rendus, fx, sortie, lua = sys.argv[1:5]
os.makedirs(sortie, exist_ok=True)
W, H = 1920, 1080
R = 4
couches = {
    "Ciel": ("chargement_ciel", "tuiles"), "Rocher": ("chargement_rocher", "tuiles"),
    "CouteauRenard": ("chargement_RenardLegendaire", "rogner"), "CouteauPoule": ("chargement_PouleRoyal", "rogner"),
    "CouteauVipere": ("chargement_ViperRoyal", "rogner"),
    "OmbreRenard": ("chargement_ombre_RenardLegendaire", "rogner"), "OmbrePoule": ("chargement_ombre_PouleRoyal", "rogner"),
    "OmbreVipere": ("chargement_ombre_ViperRoyal", "rogner"),
    "Logo": ("chargement_logo_final", "rogner"), "LogoMasque": ("chargement_logo_masque", "rogner_comme:Logo"),
}
sources = {k: os.path.join(fx if v[0] == "chargement_logo_masque" else rendus, v[0] + ".png") for k, v in couches.items()}
rects_logo = None
lignes = []
for cle, (nom, mode) in couches.items():
    im = Image.open(sources[cle]).convert("RGBA").resize((W, H), Image.LANCZOS)
    morceaux = []
    if mode == "tuiles":
        for iy in range(2):
            for ix in range(2):
                x0 = 0 if ix == 0 else W // 2 - R; x1 = W // 2 + R if ix == 0 else W
                y0 = 0 if iy == 0 else H // 2 - R; y1 = H // 2 + R if iy == 0 else H
                f = "%s_%d" % (nom, iy * 2 + ix + 1)
                im.crop((x0, y0, x1, y1)).save(os.path.join(sortie, f + ".png"))
                morceaux.append((f, x0, y0, x1, y1))
    else:
        if mode.startswith("rogner_comme"):
            x0, y0, x1, y1 = rects_logo
        else:
            x0, y0, x1, y1 = im.getbbox()
            x0, y0, x1, y1 = max(0, x0 - 2), max(0, y0 - 2), min(W, x1 + 2), min(H, y1 + 2)
            if cle == "Logo":
                rects_logo = (x0, y0, x1, y1)
        c = im.crop((x0, y0, x1, y1))
        if max(c.size) > 1024:
            print("attention : %s fait %s, Roblox le réduira à 1024" % (nom, c.size))
        c.save(os.path.join(sortie, nom + ".png"))
        morceaux.append((nom, x0, y0, x1, y1))
    lignes.append("\t%s = { %s }," % (cle, ", ".join(
        '{ "%s", %.5f, %.5f, %.5f, %.5f }' % (f, x0 / W, y0 / H, (x1 - x0) / W, (y1 - y0) / H) for f, x0, y0, x1, y1 in morceaux)))
for f in os.listdir(fx):
    if f.startswith("fx_") and f.endswith(".png"):
        shutil.copy(os.path.join(fx, f), os.path.join(sortie, f))
bloc = "local DECOUPE = { -- généré par exporter_images.py : { fichier, x, y, largeur, hauteur } en fraction de l'image\n" + "\n".join(lignes) + "\n}"
s = open(lua, encoding="utf-8").read()
a, b = s.index("local DECOUPE = {"), s.index("-- FIN DECOUPE")
s = s[:a] + bloc + "\n" + s[b:]
open(lua, "w", encoding="utf-8").write(s)
print("images ->", sortie, "| DECOUPE écrit dans", lua)
