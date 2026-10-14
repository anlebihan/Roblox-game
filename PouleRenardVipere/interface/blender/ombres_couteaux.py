# Calcule la couche « ombre » de chaque couteau sur le rocher :
#   ombre = assombrissement entre chargement_rocher.png (sans ombre) et chargement_rocher_ombre_<Id>.png
# -> PNG noir dont l'alpha = force de l'ombre (à superposer au rocher quand le couteau se plante).
# Usage : python ombres_couteaux.py <dossier_rendus>
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
d = sys.argv[1]
base = np.asarray(Image.open(os.path.join(d, "chargement_rocher.png")).convert("RGBA")).astype(np.float32) / 255
lum0 = base[..., :3].mean(-1)
for kid in ("PouleRoyal", "RenardLegendaire", "ViperRoyal"):
    o = np.asarray(Image.open(os.path.join(d, "chargement_rocher_ombre_%s.png" % kid)).convert("RGBA")).astype(np.float32) / 255
    lum1 = o[..., :3].mean(-1)
    a = np.clip(1 - (lum1 + 0.004) / (lum0 + 0.004), 0, 0.9) * base[..., 3]
    a = ndi.gaussian_filter(a, 1.2)
    a[a < 0.03] = 0
    out = np.zeros_like(o); out[..., :3] = np.array([0.03, 0.01, 0.06]); out[..., 3] = a
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(os.path.join(d, "chargement_ombre_%s.png" % kid))
    print("ombre :", kid, float(a.max()))
