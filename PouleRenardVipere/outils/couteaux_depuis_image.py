# =====================================================================
#  POULE RENARD VIPÈRE — couteaux 3D fidèles à l'image de référence
# ---------------------------------------------------------------------
#  Pour chaque couteau de la planche :
#    1. découpe + détourage (masque IA rembg/BiRefNet, nettoyé),
#    2. redresse le couteau (lame vers le haut),
#    3. construit un modèle 3D « gonflé » à partir de la silhouette exacte :
#         lame fine avec tranchant biseauté, garde et manche arrondis,
#    4. applique l'image elle-même comme texture (recto/verso),
#    5. ajoute un contour noir cartoon (inverted hull) et exporte un .glb
#       (1 unité = 1 stud, lame vers +Y dans Roblox).
#
#  Dépendances : pip install bpy scipy scikit-image pillow "rembg[cpu]"
#  Usage       : python couteaux_depuis_image.py <planche.webp> <dossier_masques> <dossier_sortie>
#                (les masques <Id>_mask.png sont faits par rembg, modèle birefnet-general,
#                 sur les découpes agrandies x4 : voir decouper())
# =====================================================================
import sys, os, json, math
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi
from scipy.spatial import Delaunay
from skimage import measure

ECHELLE = 4                     # les découpes sont agrandies x4 avant détourage
TEX_MAX = 1024                  # taille max de texture Roblox

# Rectangle de chaque couteau dans la planche (x0, y0, x1, y1)
BOITES = {
    "PouleBase": [256, 24, 392, 345], "PouleRoyal": [422, 13, 556, 345], "PoulePlume": [592, 13, 745, 345],
    "PouleElectrique": [757, 16, 909, 347], "PouleGeant": [936, 12, 1077, 345],
    "RenardBase": [262, 432, 398, 740], "RenardFurtif": [426, 434, 562, 740], "RenardSpectre": [594, 436, 739, 742],
    "RenardLegendaire": [775, 422, 907, 743], "RenardOrigami": [963, 434, 1063, 743],
    "ViperBase": [259, 814, 375, 1125], "ViperToxique": [424, 808, 539, 1127], "ViperSerpent": [580, 809, 703, 1127],
    "ViperVenin": [780, 813, 865, 1127], "ViperRoyal": [944, 812, 1024, 1127],
}

# Réglages par couteau :
#   garde  = position de la garde (0 = pointe, 1 = bout du manche), séparant lame fine / manche rond
#   long   = longueur totale en studs
#   lame   = demi-épaisseur max de la lame (studs) ; biseau = largeur du biseau (studs)
REGLAGES = {
    "PouleBase":        dict(garde=0.60, long=2.8),
    "PouleRoyal":       dict(garde=0.63, long=2.85),
    "PoulePlume":       dict(garde=0.70, long=2.9),
    "PouleElectrique":  dict(garde=0.66, long=2.85),
    "PouleGeant":       dict(garde=0.64, long=3.1, lame=0.07, biseau=0.12, angle=0),
    "RenardBase":       dict(garde=0.57, long=2.8),
    "RenardFurtif":     dict(garde=0.57, long=2.8),
    "RenardSpectre":    dict(garde=0.60, long=2.8),
    "RenardLegendaire": dict(garde=0.60, long=2.85),
    "RenardOrigami":    dict(garde=0.57, long=2.8, lame=0.09, biseau=0.14),
    "ViperBase":        dict(garde=0.55, long=2.8),
    "ViperToxique":     dict(garde=0.58, long=2.8),
    "ViperSerpent":     dict(garde=0.62, long=2.9),
    "ViperVenin":       dict(garde=0.58, long=2.8),
    "ViperRoyal":       dict(garde=0.50, long=2.85),
}

# ------------------------------------------------------------------ 1. découpe
def decouper(planche, kid):
    im = Image.open(planche).convert("RGB")
    c = im.crop(BOITES[kid])
    return c.resize((c.width * ECHELLE, c.height * ECHELLE), Image.LANCZOS)

def nettoyer_masque(alpha, rgb):
    """alpha : masque IA (0-255). On le combine avec la luminosité pour récupérer
    les parties sombres oubliées, sans les halos lumineux."""
    a = alpha.astype(np.float32) / 255
    v = rgb.max(2).astype(np.float32)
    m = (a > 0.5) | ((a > 0.12) & (v > 24))         # lames translucides (spectre…)
    # lames sombres entourées de bords lumineux : on referme la forme
    r = 7 * ECHELLE
    ferme = ndi.binary_fill_holes(ndi.binary_closing(np.pad(m, r), structure=np.ones((3, 3)), iterations=r)[r:-r, r:-r])
    m = m | (ferme & (v > 24))
    # parties sombres (manches noirs) collées au couteau mais ratées par l'IA
    sombre = (v > 30) & (a > 0.08)
    m = m | (sombre & ndi.binary_dilation(m, iterations=6))
    m = ndi.binary_opening(m, iterations=2)
    lab, n = ndi.label(m)
    if n == 0:
        return m
    tailles = ndi.sum(m, lab, range(1, n + 1))
    m = lab == (np.argmax(tailles) + 1)
    # bouche les petits trous, garde les vrais trous (anneau du pommeau…)
    trous = ndi.binary_fill_holes(m) & ~m
    lab, n = ndi.label(trous)
    for i in range(1, n + 1):
        if (lab == i).sum() < 900:
            m |= lab == i
    return ndi.binary_closing(m, iterations=2) | m

# ------------------------------------------------------------------ 2. redresser
def redresser(rgb, m, force=None):
    ys, xs = np.nonzero(m)
    pts = np.stack([xs - xs.mean(), ys - ys.mean()], 1)
    w, vecs = np.linalg.eigh(np.cov(pts.T))
    ax = vecs[:, np.argmax(w)]
    ang = math.degrees(math.atan2(ax[0], ax[1]))     # angle par rapport à la verticale
    if ang > 90: ang -= 180
    if ang < -90: ang += 180
    if force is not None: ang = force
    img = Image.fromarray(rgb)
    msk = Image.fromarray((m * 255).astype(np.uint8))
    img = img.rotate(-ang, resample=Image.BICUBIC, expand=True)
    msk = msk.rotate(-ang, resample=Image.BILINEAR, expand=True)
    m2 = np.asarray(msk) > 127
    ys, xs = np.nonzero(m2)
    pad = 6 * ECHELLE
    x0, x1 = max(xs.min() - pad, 0), xs.max() + pad
    y0, y1 = max(ys.min() - pad, 0), ys.max() + pad
    rgb2 = np.asarray(img)[y0:y1, x0:x1]
    m2 = m2[y0:y1, x0:x1]
    # la pointe doit être en haut : la moitié « manche » est la plus étroite en bas
    h = m2.shape[0]
    if m2[: h // 5].sum() > m2[-h // 5:].sum() * 1.6:   # gros bloc en haut = cas normal (lame large)
        pass
    return rgb2, m2, ang

# ------------------------------------------------------------------ 3. texture
def texture(rgb, m):
    """Étend les couleurs du couteau sur le fond (évite les bords noirs à la texture)."""
    _, (iy, ix) = ndi.distance_transform_edt(~m, return_indices=True)
    t = rgb[iy, ix].copy()
    h, w = m.shape
    s = min(1.0, TEX_MAX / max(h, w))
    im = Image.fromarray(t).resize((max(4, int(w * s)), max(4, int(h * s))), Image.LANCZOS)
    im = im.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    return im

# ------------------------------------------------------------------ 4. maillage gonflé
def maillage(m, reg, pas=10):
    """Renvoie sommets (studs), triangles, UV. pas = espacement des points (en pixels x4)."""
    H, W = m.shape
    ys, xs = np.nonzero(m)
    top, bot = ys.min(), ys.max()
    long_px = bot - top
    s = reg["long"] / long_px                         # studs par pixel
    lame = reg.get("lame", 0.045) / s                 # en pixels
    biseau = reg.get("biseau", 0.09) / s
    garde_y = top + reg["garde"] * long_px
    trans = 0.04 * long_px                            # transition lame -> manche

    d = ndi.distance_transform_edt(np.pad(m, 1))[1:-1, 1:-1]
    # demi-largeur locale (pour arrondir le manche) : max de d sur un voisinage
    R = ndi.maximum_filter(d, size=int(pas * 3))
    R = ndi.gaussian_filter(R, pas)

    def hauteur(x, y):
        xi = np.clip(np.round(x).astype(int), 0, W - 1)
        yi = np.clip(np.round(y).astype(int), 0, H - 1)
        dd = ndi.map_coordinates(d, [y, x], order=1)
        rr = np.maximum(ndi.map_coordinates(R, [y, x], order=1), 1.0)
        k = np.clip(dd / biseau, 0, 1)
        h_lame = lame * (1 - (1 - k) ** 2)                       # biseau puis plat
        q = np.clip(dd / rr, 0, 1)
        h_manche = 0.8 * rr * np.sqrt(np.clip(1 - (1 - q) ** 2, 0, 1))   # section ovale
        w = np.clip((y - (garde_y - trans)) / (2 * trans), 0, 1)
        w = w * w * (3 - 2 * w)
        return (1 - w) * h_lame + w * np.maximum(h_manche, h_lame)

    # contour(s) précis
    cont = measure.find_contours(np.pad(m.astype(float), 1), 0.5)
    bpts = []
    for c in cont:
        c = c - 1
        if len(c) < 20: continue
        c = measure.approximate_polygon(c, tolerance=1.2)
        # rééchantillonne pour garder des segments courts
        seg = []
        for i in range(len(c) - 1):
            a, b = c[i], c[i + 1]
            n = max(1, int(np.linalg.norm(b - a) / (pas * 0.6)))
            for t in range(n):
                seg.append(a + (b - a) * t / n)
        bpts += seg
    bpts = np.array(bpts)[:, ::-1]                    # (x, y)
    # points intérieurs : grille plus serrée près du bord et dans le manche
    gy, gx = np.mgrid[0:H:pas, 0:W:pas].astype(float)
    gx += (np.arange(gx.shape[0])[:, None] % 2) * pas / 2
    gx, gy = gx.ravel(), gy.ravel()
    din = ndi.map_coordinates(d, [gy, gx], order=1)
    ipts = np.stack([gx, gy], 1)[din > pas * 0.55]
    pts = np.concatenate([bpts, ipts])
    nb = len(bpts)
    tri = Delaunay(pts).simplices
    # garde les triangles à l'intérieur (centre et milieux des côtés)
    def dedans(p):
        return ndi.map_coordinates(m.astype(float), [p[:, 1], p[:, 0]], order=1) > 0.5
    P = pts[tri]
    ok = dedans(P.mean(1))
    for a, b in ((0, 1), (1, 2), (2, 0)):
        ok &= dedans((P[:, a] + P[:, b]) / 2)
    tri = tri[ok]

    h = hauteur(pts[:, 0], pts[:, 1])
    h[:nb] = 0.0
    n = len(pts)
    # sommets : recto (0..n-1), verso (n..2n-1) ; les sommets du bord sont partagés
    X = (W / 2 - pts[:, 0]) * s                       # recto vu depuis +Y = image à l'endroit
    Y = (bot - pts[:, 1]) * s                         # bas du manche = 0
    V = np.concatenate([np.stack([X, h * s, Y], 1), np.stack([X, -h * s, Y], 1)])
    UV = np.stack([pts[:, 0] / W, 1 - pts[:, 1] / H], 1)
    UV = np.concatenate([UV, UV])
    idx_back = np.arange(n) + n
    idx_back[:nb] = np.arange(nb)                     # bord commun
    F = [t[::-1] for t in tri] + [idx_back[t] for t in tri]   # recto (normale vers +Y), verso
    info = dict(echelle=s, garde=float((bot - garde_y) * s), pointe=float((bot - top) * s), bas=0.0)
    return V, np.array(F), UV, info

# ------------------------------------------------------------------ 5. Blender
def construire_blender(kid, V, F, UV, tex_path, sortie, contour=0.018):
    import bpy, bmesh
    bpy.ops.wm.read_factory_settings(use_empty=True)
    me = bpy.data.meshes.new(f"{kid}_Body_tex")
    me.from_pydata([tuple(v) for v in V], [], [tuple(int(i) for i in f) for f in F])
    me.validate()
    uvl = me.uv_layers.new(name="UV")
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uvl.data[li].uv = UV[vi]
    for p in me.polygons: p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(60))
    mat = bpy.data.materials.new(f"{kid}_mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    img = bpy.data.images.load(tex_path)
    tn = mat.node_tree.nodes.new("ShaderNodeTexImage"); tn.image = img
    mat.node_tree.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.45
    me.materials.append(mat)
    ob = bpy.data.objects.new(f"{kid}_Body_tex", me)
    bpy.context.scene.collection.objects.link(ob)
    # recalcule les normales vers l'extérieur
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    # contour noir
    bm = bmesh.new(); bm.from_mesh(me); bm.normal_update()
    for v in bm.verts: v.co += v.normal * contour
    for f in bm.faces: f.normal_flip()
    ome = bpy.data.meshes.new(f"{kid}_Outline_outline"); bm.to_mesh(ome); bm.free()
    for p in ome.polygons: p.use_smooth = True
    omat = bpy.data.materials.new("outline"); omat.use_backface_culling = True
    omat.use_nodes = True
    omat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0, 0, 0, 1)
    ome.materials.append(omat)
    oob = bpy.data.objects.new(f"{kid}_Outline_outline", ome)
    bpy.context.scene.collection.objects.link(oob)
    os.makedirs(sortie, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(sortie, kid + ".glb"), export_format='GLB',
                              export_yup=True, export_apply=True, export_image_format='AUTO')
    return len(F)

def traiter(planche, dossier_masques, sortie, ids=None):
    meta = {}
    os.makedirs(os.path.join(sortie, "textures"), exist_ok=True)
    for kid in (ids or BOITES):
        rgb = np.asarray(decouper(planche, kid))
        alpha = np.asarray(Image.open(os.path.join(dossier_masques, f"{kid}_mask.png")).convert("L"))
        m = nettoyer_masque(alpha, rgb)
        rgb2, m2, ang = redresser(rgb, m, REGLAGES[kid].get("angle"))
        tex = texture(rgb2, m2)
        tp = os.path.join(sortie, "textures", kid + ".png")
        tex.save(tp)
        Image.fromarray((m2 * 255).astype(np.uint8)).save(os.path.join(sortie, "textures", kid + "_masque.png"))
        V, F, UV, info = maillage(m2, REGLAGES[kid])
        ntri = construire_blender(kid, V, F, UV, tp, sortie)
        info["triangles"] = int(ntri)
        meta[kid] = info
        print(f"[PRV] {kid:18s} angle {ang:6.1f}°  {ntri:6d} triangles  longueur {info['pointe']:.2f} studs")
    json.dump(meta, open(os.path.join(sortie, "infos.json"), "w"), indent=1)
    return meta

if __name__ == "__main__":
    traiter(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:] or None)
