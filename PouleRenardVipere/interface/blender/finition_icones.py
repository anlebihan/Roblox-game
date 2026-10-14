# Finition des icônes 3D : contour sombre bien lisse (champ de distance, double résolution)
# + halo violet doux (comme le portail), recadrage, taille 512 px max.
# Usage : python finition_icones.py <dossier_rendus> <dossier_sortie> [motif, ex. "icone_*.png"]
import sys, os, glob
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

src, out = sys.argv[1], sys.argv[2]
MOTIF = sys.argv[3] if len(sys.argv) > 3 else "*.png"
os.makedirs(out, exist_ok=True)

def lisse(x):
    x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)

def sur(dessous, dessus):
    ad = dessus[..., 3:4]; ab = dessous[..., 3:4]
    ao = ad + ab * (1 - ad)
    rgb = (dessus[..., :3] * ad + dessous[..., :3] * ab * (1 - ad)) / np.maximum(ao, 1e-6)
    return np.concatenate([rgb, ao], -1)

for f in sorted(glob.glob(os.path.join(src, MOTIF))):
    im = Image.open(f).convert("RGBA")
    bb = im.getbbox()
    if not bb: continue
    marge = 60
    im = im.crop((max(bb[0] - marge, 0), max(bb[1] - marge, 0), min(bb[2] + marge, im.width), min(bb[3] + marge, im.height)))
    pad = Image.new("RGBA", (im.width + 2 * marge, im.height + 2 * marge), (0, 0, 0, 0)); pad.paste(im, (marge, marge))
    SS = 2
    big = pad.resize((pad.width * SS, pad.height * SS), Image.BICUBIC)
    A = np.asarray(big).astype(np.float32) / 255
    alpha = ndi.gaussian_filter(A[..., 3], 0.7)
    m = alpha > 0.5
    k = max(pad.width, pad.height) * SS / 640
    d = ndi.distance_transform_edt(~m)
    contour = lisse((7 * k - d) / (1.5 * k) + 0.5)
    halo = np.exp(-(d / (16 * k)) ** 2) * 0.55 * (d > 0)
    H, W = alpha.shape
    res = np.zeros((H, W, 4), np.float32); res[..., :3] = np.array([0.55, 0.3, 1.0]); res[..., 3] = halo
    c = np.zeros_like(res); c[..., :3] = np.array([0.05, 0.02, 0.1]); c[..., 3] = contour
    res = sur(res, c)
    lettres = A.copy(); lettres[..., 3] = lisse((alpha - 0.3) / 0.35)
    res = sur(res, lettres)
    img = Image.fromarray((np.clip(res, 0, 1) * 255).astype(np.uint8), "RGBA").resize((pad.width, pad.height), Image.LANCZOS)
    img = img.crop(img.getbbox())
    img.thumbnail((512, 512), Image.LANCZOS)
    img.save(os.path.join(out, os.path.basename(f)))
    print("icône :", os.path.basename(f), img.size)
