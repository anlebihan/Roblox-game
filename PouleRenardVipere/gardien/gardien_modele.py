# LE GARDIEN — robot géant original de TRIPLE HUNT (modélisation Blender, procédurale).
# Robot « sentinelle » : métal usé, pistons et ressorts apparents, longues lames sur les avant-bras,
# casque à visière lumineuse, 3 lumières d'équipe sur le torse, jambes digitigrades et pieds griffus.
#
# Chaque pièce porte le nom  <Segment>__<matiere>  (ex : « AvantBrasD__acier ») : le script Roblox
# sait ainsi à quelle partie du corps elle appartient (animation) et quelle couleur / matière lui donner.
# Blender : Z vers le haut, le robot regarde vers -Y.  Hauteur ~ 10 unités (mis à l'échelle dans Roblox).
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler

# ------------------------------------------------------------------ matières (aperçu Blender + palette Roblox)
MATIERES = {
    #  nom      couleur (RVB 0-1)        métal rugosité émission
    "carrosserie": ((0.03, 0.10, 0.62), 0.55, 0.14, 0),  # peinture bleu métallisé de supercar
    "carbone": ((0.025, 0.025, 0.03), 0.3, 0.32, 0),  # toit, prises d'air, lèvres en carbone
    "jante":   ((0.30, 0.31, 0.33), 1.0, 0.30, 0),   # jantes gris anthracite
    "visage":  ((0.70, 0.72, 0.75), 1.0, 0.25, 0),   # visage en métal argenté
    "sombre":  ((0.12, 0.13, 0.15), 1.0, 0.45, 0),   # gris canon
    "noir":    ((0.05, 0.05, 0.06), 0.6, 0.55, 0),   # articulations, câbles
    "chrome":  ((0.85, 0.86, 0.88), 1.0, 0.12, 0),   # tiges de piston, lames
    "jaune":   ((0.95, 0.68, 0.10), 0.3, 0.45, 0),   # vérins, rayures de danger
    "cuivre":  ((0.80, 0.42, 0.20), 1.0, 0.30, 0),   # ressorts, bobines
    "lueur":   ((0.25, 0.85, 1.00), 0.0, 0.40, 6),   # visière, noyau, fil des lames
    "phare":   ((1.00, 0.95, 0.80), 0.0, 0.20, 5),   # phares
    "verre":   ((0.05, 0.09, 0.14), 0.2, 0.05, 0),   # pare-brise, vitres
    "poule":   ((1.00, 0.24, 0.16), 0.0, 0.40, 5),   # lumières d'équipe
    "renard":  ((1.00, 0.50, 0.08), 0.0, 0.40, 5),
    "vipere":  ((0.40, 1.00, 0.16), 0.0, 0.40, 5),
}

def nettoyer():
    bpy.ops.wm.read_factory_settings(use_empty=True)

_mats = {}
def materiau(nom):
    if nom in _mats: return _mats[nom]
    c, met, rug, em = MATIERES[nom]
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Metallic"].default_value = met
    b.inputs["Roughness"].default_value = rug
    if em:
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = em
    _mats[nom] = m
    return m

PIECES = []          # (objet, segment, matière)

def _fin(ob, seg, mat, biseau=0.0, segs=2, lisse=False):
    if mat == "carrosserie" and biseau > 0:          # carrosserie : arêtes très arrondies, comme une supercar
        biseau, segs = max(biseau * 2.0, 0.07), 4
    if biseau > 0:
        mod = ob.modifiers.new("b", "BEVEL")
        mod.width = biseau; mod.segments = segs; mod.limit_method = "ANGLE"; mod.angle_limit = math.radians(35)
        mod.harden_normals = True
    ob.data.materials.append(materiau(mat))
    for p in ob.data.polygons: p.use_smooth = lisse or biseau > 0
    PIECES.append((ob, seg, mat))
    return ob

def _obj(nom, me):
    ob = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob

def placer(ob, loc=(0, 0, 0), rot=(0, 0, 0), base=None):
    m = Matrix.Translation(Vector(loc)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
    ob.matrix_world = (base @ m) if base is not None else m
    return ob

def boite(seg, mat, taille, loc=(0, 0, 0), rot=(0, 0, 0), biseau=0.04, base=None, effile=None):
    """Boîte biseautée. effile = (sx, sy) : réduit le haut (+Z local) pour faire des plaques trapézoïdales."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co.x *= taille[0]; v.co.y *= taille[1]; v.co.z *= taille[2]
        if effile and v.co.z > 0:
            v.co.x *= effile[0]; v.co.y *= effile[1]
    me = bpy.data.meshes.new("m"); bm.to_mesh(me); bm.free()
    ob = _obj(seg, me); placer(ob, loc, rot, base)
    return _fin(ob, seg, mat, biseau)

def cylindre(seg, mat, r, h, loc=(0, 0, 0), rot=(0, 0, 0), n=20, biseau=0.02, base=None, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=n, radius1=r, radius2=r if r2 is None else r2, depth=h)
    me = bpy.data.meshes.new("m"); bm.to_mesh(me); bm.free()
    ob = _obj(seg, me); placer(ob, loc, rot, base)
    return _fin(ob, seg, mat, biseau, lisse=True)

def sphere(seg, mat, r, loc=(0, 0, 0), echelle=(1, 1, 1), base=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=r)
    for v in bm.verts: v.co = Vector((v.co.x * echelle[0], v.co.y * echelle[1], v.co.z * echelle[2]))
    me = bpy.data.meshes.new("m"); bm.to_mesh(me); bm.free()
    ob = _obj(seg, me); placer(ob, loc, (0, 0, 0), base)
    return _fin(ob, seg, mat, 0, lisse=True)

def prisme(seg, mat, pts, epaisseur, loc=(0, 0, 0), rot=(0, 0, 0), biseau=0.03, base=None, plan="XZ"):
    """Plaque extrudée à partir d'un contour 2D (u, v), épaisseur le long du 3e axe."""
    bm = bmesh.new()
    vs = []
    for u, v in pts:
        co = {"XZ": (u, 0, v), "XY": (u, v, 0), "YZ": (0, u, v)}[plan]
        vs.append(bm.verts.new(co))
    f = bm.faces.new(vs)
    n = {"XZ": Vector((0, 1, 0)), "XY": Vector((0, 0, 1)), "YZ": Vector((1, 0, 0))}[plan]
    bmesh.ops.translate(bm, verts=vs, vec=-n * epaisseur / 2)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)], vec=n * epaisseur)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("m"); bm.to_mesh(me); bm.free()
    ob = _obj(seg, me); placer(ob, loc, rot, base)
    return _fin(ob, seg, mat, biseau)

def tube(seg, mat, points, r, n=8, base=None, lisse=True):
    """Tube le long d'une polyligne (câbles, ressorts)."""
    bm = bmesh.new()
    anneaux = []
    pts = [Vector(p) for p in points]
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = t.orthogonal().normalized(); b = t.cross(a)
        anneaux.append([bm.verts.new(p + (a * math.cos(k / n * 2 * math.pi) + b * math.sin(k / n * 2 * math.pi)) * r) for k in range(n)])
    for i in range(len(anneaux) - 1):
        for k in range(n):
            bm.faces.new((anneaux[i][k], anneaux[i][(k + 1) % n], anneaux[i + 1][(k + 1) % n], anneaux[i + 1][k]))
    bm.faces.new(anneaux[0][::-1]); bm.faces.new(anneaux[-1])
    me = bpy.data.meshes.new("m"); bm.to_mesh(me); bm.free()
    ob = _obj(seg, me)
    if base is not None: ob.matrix_world = base
    return _fin(ob, seg, mat, 0, lisse=lisse)

def entre(a, b):
    """Matrice qui place l'axe Z local de a vers b (pour pistons / tiges)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4(), d.length

def piston(seg, a, b, r=0.09, ressort=True, mat_corps="sombre"):
    """Vérin : corps + tige chromée + (option) ressort hélicoïdal cuivré."""
    m, L = entre(a, b)
    cylindre(seg, mat_corps, r, L * 0.55, (0, 0, -L * 0.2), n=14, base=m)
    cylindre(seg, "chrome", r * 0.45, L * 0.6, (0, 0, L * 0.2), n=10, base=m)
    cylindre(seg, "noir", r * 1.15, 0.06, (0, 0, -L * 0.5 + 0.03), n=14, base=m)
    cylindre(seg, "noir", r * 0.8, 0.08, (0, 0, L * 0.5 - 0.04), n=12, base=m)
    if ressort:
        tours, rr = 7, r * 1.5
        pts = [(math.cos(t) * rr, math.sin(t) * rr, -L * 0.42 + L * 0.84 * t / (tours * 2 * math.pi))
               for t in [i / 10 * 2 * math.pi for i in range(tours * 10 + 1)]]
        tube(seg, "cuivre" if ressort is True else ressort, pts, r * 0.22, n=6, base=m)

def engrenage(seg, r, ep, loc, rot, dents=12, mat="sombre", base=None):
    pts = []
    for i in range(dents * 2):
        a = i / (dents * 2) * 2 * math.pi
        rr = r if i % 2 == 0 else r * 0.82
        a2 = a + math.pi / (dents * 2)
        pts += [(math.cos(a) * rr, math.sin(a) * rr), (math.cos(a2) * rr, math.sin(a2) * rr)]
    prisme(seg, mat, pts, ep, loc, rot, biseau=0.01, base=base, plan="XY")
    cylindre(seg, "chrome", r * 0.3, ep * 1.4, loc, rot, n=12, base=base)

def vis(seg, loc, rot=(0, 0, 0), r=0.035, base=None):
    cylindre(seg, "chrome", r, 0.03, loc, rot, n=8, biseau=0.008, base=base)

# ------------------------------------------------------------------ squelette (pivots des articulations)
J = {
    "Bassin":     (0, 0.05, 4.5),
    "Torse":      (0, 0.1, 5.2),
    "Tete":       (0, 0.05, 8.3),
    "BrasHautD":  (2.35, 0.1, 7.55), "BrasHautG": (-2.35, 0.1, 7.55),
    "AvantBrasD": (2.95, 0.15, 5.75), "AvantBrasG": (-2.95, 0.15, 5.75),
    "MainD":      (3.3, 0.0, 4.05),   "MainG": (-3.3, 0.0, 4.05),
    "LameD":      (3.2, 0.05, 5.3),   "LameG": (-3.2, 0.05, 5.3),
    "CuisseD":    (0.9, 0.0, 4.35),   "CuisseG": (-0.9, 0.0, 4.35),
    "TibiaD":     (1.3, -0.4, 2.6),   "TibiaG": (-1.3, -0.4, 2.6),
    "PiedD":      (1.5, 0.15, 0.85),  "PiedG": (-1.5, 0.15, 0.85),
}
PARENT = {
    "Bassin": None, "Torse": "Bassin", "Tete": "Torse",
    "BrasHautD": "Torse", "AvantBrasD": "BrasHautD", "MainD": "AvantBrasD", "LameD": "AvantBrasD",
    "BrasHautG": "Torse", "AvantBrasG": "BrasHautG", "MainG": "AvantBrasG", "LameG": "AvantBrasG",
    "CuisseD": "Bassin", "TibiaD": "CuisseD", "PiedD": "TibiaD",
    "CuisseG": "Bassin", "TibiaG": "CuisseG", "PiedG": "TibiaG",
}

def V(*a): return Vector(a)

def roue(seg, centre, axe_rot, r=0.62, larg=0.42, base=None):
    """Roue de voiture : pneu sculpté + jante chromée à 5 branches + moyeu."""
    m = Matrix.Translation(Vector(centre)) @ Euler([math.radians(x) for x in axe_rot], "XYZ").to_matrix().to_4x4()
    if base is not None: m = base @ m
    cylindre(seg, "noir", r, larg, n=32, biseau=0.08, base=m)                       # pneu
    for k in range(22):                                                             # crampons
        ang = k / 22 * 360
        mk = m @ Euler((0, 0, math.radians(ang)), "XYZ").to_matrix().to_4x4()
        boite(seg, "noir", (0.1, 0.08, larg * 0.9), (r, 0, 0), biseau=0.01, base=mk)
    cylindre(seg, "jante", r * 0.66, larg * 1.04, n=32, biseau=0.03, base=m)         # jante
    cylindre(seg, "noir", r * 0.56, larg * 1.08, n=32, biseau=0.0, base=m)
    cylindre(seg, "jaune", r * 0.3, larg * 0.5, (r * 0.32, 0, 0), n=10, biseau=0.02, base=m)   # étrier de frein
    for k in range(5):                                                              # 5 branches en étoile
        mk = m @ Euler((0, 0, math.radians(k * 72)), "XYZ").to_matrix().to_4x4()
        prisme(seg, "jante", [(-0.07, 0), (0.07, 0), (0.05, r * 0.58), (0.02, r * 0.6), (-0.06, r * 0.56)], 0.07,
               (0, 0, larg * 0.56), plan="XY", biseau=0.015, base=mk)
    cylindre(seg, "jante", r * 0.17, larg * 1.2, n=16, biseau=0.02, base=m)

def phare(seg, centre, rot=(0, 0, 0), larg=0.42, haut=0.16, mat="phare", base=None):
    """Phare fin en amande, étiré vers l'extérieur (style supercar)."""
    h = haut * 0.7
    prisme(seg, "carbone", [(-larg / 2 - 0.05, h * 0.2), (0, h / 2 + 0.05), (larg / 2 + 0.08, h / 2 + 0.08), (larg / 2 + 0.02, -h / 2 - 0.02), (-larg / 2, -h / 2 - 0.04)],
           0.08, centre, rot, biseau=0.01, base=base)
    m = Matrix.Translation(Vector(centre)) @ Euler([math.radians(x) for x in rot], "XYZ").to_matrix().to_4x4()
    if base is not None: m = base @ m
    prisme(seg, mat, [(-larg / 2, 0), (0, h / 2), (larg / 2 + 0.05, h / 2 + 0.04), (larg / 2 - 0.02, -h / 3), (-larg / 3, -h / 2)], 0.06,
           (0, -0.03, 0), biseau=0.005, base=m)

# ------------------------------------------------------------------ TÊTE (style robot-voiture : casque, visage en métal, masque)
def tete():
    s = "Tete"; o = V(*J[s]); K = 1.3
    def L(x, y, z): return tuple(o + V(x, y, z) * K)
    def T(t): return tuple(v * K for v in t)
    def P2(pts): return [(u * K, v * K) for u, v in pts]
    # --- visage en métal gris (bouclier) ---
    prisme(s, "visage", P2([(-0.25, 0.3), (0.25, 0.3), (0.27, 0.02), (0.19, -0.2), (0.08, -0.3), (-0.08, -0.3), (-0.19, -0.2), (-0.27, 0.02)]),
           0.3 * K, L(0, -0.28, 0.42), biseau=0.02)
    # arcade sourcilière en V (bleue) + gemme frontale
    prisme(s, "carrosserie", P2([(-0.33, 0.1), (0, 0.0), (0.33, 0.1), (0.34, 0.02), (0, -0.07), (-0.34, 0.02)]), 0.14 * K, L(0, -0.44, 0.6), biseau=0.01)
    prisme(s, "lueur", P2([(0, 0.06), (0.04, 0.0), (0, -0.05), (-0.04, 0.0)]), 0.06 * K, L(0, -0.52, 0.66), biseau=0.0)
    # yeux en amande lumineux (sous l'arcade) dans des orbites noires
    for c in (1, -1):
        prisme(s, "noir", P2([(0.03 * c, 0.03), (0.22 * c, 0.07), (0.25 * c, 0.02), (0.18 * c, -0.04), (0.04 * c, -0.03)]), 0.08 * K, L(0, -0.43, 0.52), biseau=0.003)
        prisme(s, "lueur", P2([(0.05 * c, 0.02), (0.2 * c, 0.05), (0.22 * c, 0.02), (0.16 * c, -0.02), (0.06 * c, -0.015)]), 0.05 * K, L(0, -0.47, 0.52), biseau=0.0)
        # pommettes : plaques en biais avec fentes
        prisme(s, "sombre", P2([(0.1 * c, 0.0), (0.26 * c, 0.03), (0.24 * c, -0.14), (0.12 * c, -0.1)]), 0.06 * K, L(0, -0.44, 0.4), biseau=0.005)
        for k in range(3):
            boite(s, "noir", T((0.09, 0.02, 0.012)), L(0.18 * c, -0.475, 0.42 - k * 0.035), (0, -20 * c, 0), biseau=0)
    # arête du nez
    prisme(s, "visage", P2([(-0.03, 0.06), (0.03, 0.06), (0.045, -0.1), (0, -0.13), (-0.045, -0.1)]), 0.07 * K, L(0, -0.44, 0.43), biseau=0.006)
    # masque de combat (bouche) à rainures + menton
    prisme(s, "visage", P2([(-0.17, 0.0), (0.17, 0.0), (0.15, -0.12), (0.06, -0.18), (-0.06, -0.18), (-0.15, -0.12)]), 0.1 * K, L(0, -0.44, 0.3), biseau=0.008)
    for k in range(4):
        boite(s, "noir", T((0.26 - k * 0.04, 0.012, 0.012)), L(0, -0.495, 0.285 - k * 0.035), biseau=0)
    boite(s, "noir", T((0.012, 0.012, 0.14)), L(0, -0.497, 0.24), biseau=0)
    boite(s, "visage", T((0.12, 0.08, 0.05)), L(0, -0.45, 0.115), biseau=0.01)
    # --- casque bleu ---
    boite(s, "carrosserie", T((0.7, 0.62, 0.32)), L(0, 0.0, 0.76), biseau=0.06, effile=(0.8, 0.85))      # dôme
    boite(s, "carrosserie", T((0.66, 0.42, 0.52)), L(0, 0.2, 0.45), biseau=0.06)                           # arrière du crâne
    prisme(s, "carrosserie", P2([(-0.08, 0.0), (0.08, 0.0), (0.04, 0.42), (0.0, 0.5), (-0.04, 0.42)]), 0.12 * K, L(0, -0.38, 0.72), (12, 0, 0), biseau=0.01)  # crête frontale
    prisme(s, "carrosserie", [(0, 0), (0.45 * K, 0.05 * K), (0.7 * K, 0.28 * K), (0.3 * K, 0.2 * K), (0.0, 0.12 * K)], 0.09 * K, L(0, -0.05, 0.9), (0, 0, 90), plan="XZ")     # crête dorsale
    for c in (1, -1):
        # joues blindées qui encadrent le visage jusqu'à la mâchoire
        prisme(s, "carrosserie", [(0.0, 0.18 * K), (0.12 * K, 0.22 * K), (0.16 * K, -0.08 * K), (0.08 * K, -0.3 * K), (0.0, -0.2 * K)], 0.36 * K,
               L(0.27 * c, -0.18, 0.42), (0, 0, 0) if c > 0 else (0, 0, 180), plan="XZ", biseau=0.02)
        # oreilles mécaniques : disque + anneau chromé + lumière + antenne
        cylindre(s, "sombre", 0.17 * K, 0.12 * K, L(0.39 * c, 0.05, 0.52), (0, 90, 0), n=24)
        cylindre(s, "chrome", 0.12 * K, 0.14 * K, L(0.4 * c, 0.05, 0.52), (0, 90, 0), n=20)
        cylindre(s, "renard", 0.05 * K, 0.16 * K, L(0.41 * c, 0.05, 0.52), (0, 90, 0), n=12, biseau=0)
        prisme(s, "chrome", [(0, 0), (0.05 * K, 0), (0.07 * K, 0.5 * K), (0.03 * K, 0.62 * K), (0.0, 0.5 * K)], 0.04 * K,
               L(0.42 * c, 0.1, 0.6), (0, -14 * c, 0), plan="YZ" if False else "XZ", biseau=0.005)
        # plaques arrière en flèche
        prisme(s, "carrosserie", [(0, 0), (0.3 * K, 0.04 * K), (0.5 * K, 0.3 * K), (0.2 * K, 0.18 * K)], 0.05 * K,
               L(0.3 * c, 0.25, 0.7), (0, 0, 90 + 20 * c), plan="XZ", biseau=0.01)
        for k in range(3):
            boite(s, "noir", T((0.02, 0.18, 0.012)), L(0.33 * c, 0.2, 0.6 - k * 0.05), biseau=0)            # aérations
    # --- cou : vertèbres, câbles, pistons ---
    for i in range(3):
        cylindre(s, "noir", (0.2 - i * 0.015) * K, 0.08 * K, L(0, 0.05, -0.02 - i * 0.1), n=16)
    for c in (1, -1):
        piston(s, L(0.18 * c, 0.15, -0.32), L(0.15 * c, 0.1, 0.1), r=0.045 * K, ressort=False)
        tube(s, "noir", [L(0.1 * c, -0.1, -0.32), L(0.13 * c, -0.15, -0.1), L(0.12 * c, -0.1, 0.12)], 0.025 * K)

# ------------------------------------------------------------------ TORSE (capot, pare-brise, phares, portières en ailes)
def torse():
    s = "Torse"; o = V(*J[s])
    def L(x, y, z): return tuple(o + V(x, y, z))
    # masse du torse
    boite(s, "sombre", (2.6, 1.55, 1.9), L(0, 0.15, 1.95), biseau=0.12, effile=(1.12, 1.05))
    boite(s, "noir", (1.5, 1.0, 1.3), L(0, 0.15, 0.6), biseau=0.08, effile=(1.4, 1.1))                # abdomen
    # abdomen : mécanique (engrenages, vérins, câbles)
    engrenage(s, 0.3, 0.08, L(0.32, -0.42, 0.6), (90, 0, 0), dents=13)
    engrenage(s, 0.22, 0.08, L(-0.3, -0.42, 0.75), (90, 0, 0), dents=11, mat="carrosserie")
    for k in range(4):
        boite(s, "carrosserie", (1.05 - k * 0.12, 0.2, 0.1), L(0, -0.48, 0.15 + k * 0.16), biseau=0.03)        # abdos blindés
    for c in (1, -1):
        piston(s, L(0.6 * c, -0.1, -0.05), L(0.95 * c, -0.25, 1.15), r=0.1, ressort="jaune")
        tube(s, "noir", [L(0.45 * c, -0.35, 0.0), L(0.7 * c, -0.5, 0.6), L(0.8 * c, -0.55, 1.1)], 0.05)
    # capot de voiture sur la poitrine (plaques bombées en V)
    for c in (1, -1):
        rot = (0, 0, 0) if c > 0 else (0, 0, 180)
        prisme(s, "carrosserie", [(0, 0), (1.3, 0.1), (1.45, 0.7), (1.2, 1.15), (0.1, 1.05)], 0.3, L(0.05 * c, -0.68, 1.45), rot, plan="XZ", biseau=0.06)
        # pare-brise (vitre sombre) en haut de la poitrine
        prisme(s, "verre", [(0.12, 0), (1.05, 0.05), (0.95, 0.48), (0.15, 0.42)], 0.08, L(0.02 * c, -0.84, 2.0), rot, plan="XZ", biseau=0.01)
        # phares
        phare(s, L(0.95 * c, -0.86, 1.62), (0, 0, 8 * c), larg=0.5, haut=0.18)
        # ailes du capot (côtés) + clignotant
        boite(s, "carrosserie", (0.55, 1.3, 1.25), L(1.35 * c, 0.05, 1.95), (0, -10 * c, 0), biseau=0.09, effile=(0.8, 1))
        phare(s, L(1.42 * c, -0.62, 1.35), (0, 0, 20 * c), larg=0.22, haut=0.1, mat="renard")
        # rayures de danger
    # calandre au centre + noyau + 3 lumières d'équipe
    boite(s, "carbone", (0.55, 0.12, 0.62), L(0, -0.86, 1.5), biseau=0.03)
    for k in range(5):
        boite(s, "noir", (0.48, 0.04, 0.03), L(0, -0.93, 1.27 + k * 0.11), biseau=0)
    boite(s, "carbone", (2.3, 0.35, 0.08), L(0, -0.82, 1.08), biseau=0.03, effile=(1.05, 1.3))      # lame avant en carbone
    cylindre(s, "sombre", 0.3, 0.14, L(0, -0.88, 2.25), (90, 0, 0), n=28)
    cylindre(s, "lueur", 0.2, 0.12, L(0, -0.94, 2.25), (90, 0, 0), n=28, biseau=0.0)
    for eq, x in (("poule", -0.62), ("renard", 0.0), ("vipere", 0.62)):
        prisme(s, eq, [(-0.16, 0.05), (0.16, 0.05), (0.12, -0.05), (-0.12, -0.05)], 0.05, L(x, -0.95, 2.62), biseau=0.005)
    # col
    boite(s, "sombre", (0.8, 0.75, 0.3), L(0, 0.1, 2.98), biseau=0.06)
    # dos : portières relevées comme des ailes
    for c in (1, -1):
        mporte = Matrix.Translation(Vector(L(0.85 * c, 0.95, 2.4))) @ Euler((math.radians(-20), math.radians(-28 * c), math.radians(18 * c)), "XYZ").to_matrix().to_4x4()
        prisme(s, "carrosserie", [(0, -0.6), (1.0 * c, -0.5), (1.15 * c, 0.6), (0.6 * c, 1.25), (0.05 * c, 0.9)], 0.12, plan="XZ", base=mporte, biseau=0.03)
        prisme(s, "verre", [(0.15 * c, 0.05), (0.95 * c, 0.1), (0.62 * c, 0.95), (0.15 * c, 0.7)], 0.14, plan="XZ", base=mporte, biseau=0.01)
        boite(s, "chrome", (0.25, 0.06, 0.06), (0.75 * c, -0.08, -0.25), biseau=0.01, base=mporte)        # poignée
        piston(s, L(0.5 * c, 0.85, 1.6), L(0.95 * c, 1.05, 2.25), r=0.06, ressort=False)
    # épaules : gros blocs avec roue sur le dessus
    for c in (1, -1):
        boite(s, "carrosserie", (1.1, 1.3, 0.95), L(2.15 * c, 0.1, 2.45), (0, -8 * c, 0), biseau=0.1, effile=(0.85, 0.85))
        boite(s, "sombre", (0.9, 1.1, 0.25), L(2.15 * c, 0.1, 1.9), biseau=0.05)
        phare(s, L(2.15 * c, -0.58, 2.45), (0, 0, 0), larg=0.5, haut=0.14)
        boite(s, "carbone", (0.9, 1.0, 0.12), L(2.15 * c, 0.15, 2.9), biseau=0.04)                # « toit » noir
        boite(s, "renard", (0.18, 0.05, 0.06), L(2.15 * c, -0.66, 2.15), biseau=0.01)            # feu orange
        roue(s, L(2.25 * c, 0.15, 2.98), (0, 90, 0), r=0.55, larg=0.38)

# ------------------------------------------------------------------ BASSIN (bloc solide + hanches)
def bassin():
    s = "Bassin"; o = V(*J[s])
    def L(x, y, z): return tuple(o + V(x, y, z))
    boite(s, "sombre", (1.7, 1.05, 0.7), L(0, 0.05, 0.1), biseau=0.08, effile=(1.15, 1))
    cylindre(s, "noir", 0.55, 0.9, L(0, 0.1, 0.65), n=24)                           # colonne / taille
    for k in range(3):
        cylindre(s, "sombre", 0.62, 0.08, L(0, 0.1, 0.4 + k * 0.2), n=24)
    prisme(s, "carrosserie", [(-0.5, 0.35), (0.5, 0.35), (0.3, -0.3), (0, -0.42), (-0.3, -0.3)], 0.18, L(0, -0.55, 0.05), biseau=0.04)
    for c in (1, -1):
        boite(s, "carrosserie", (0.7, 1.0, 0.75), L(0.9 * c, 0.05, 0.05), biseau=0.08, effile=(0.85, 0.9))
        cylindre(s, "noir", 0.38, 0.5, L(0.95 * c, 0.0, -0.12), (0, 90, 0), n=22)
        piston(s, L(0.55 * c, 0.4, 0.3), L(0.4 * c, 0.4, 1.15), r=0.08)

# ------------------------------------------------------------------ BRAS (épais, avant-bras énormes, lames)
def bras(c):
    sd = "D" if c > 0 else "G"
    s = "BrasHaut" + sd; a, b = V(*J[s]), V(*J["AvantBras" + sd])
    m, L_ = entre(a, b)
    cylindre(s, "noir", 0.36, L_ * 0.95, (0, 0, 0), n=20, base=m)
    boite(s, "carrosserie", (0.72, 0.8, L_ * 0.6), (0.12 * c, -0.05, 0.15), biseau=0.08, base=m, effile=(0.85, 0.9))
    piston(s, tuple(a + V(0.1 * c, -0.42, -0.25)), tuple(b + V(0, -0.35, 0.35)), r=0.09)
    piston(s, tuple(a + V(0.1 * c, 0.42, -0.3)), tuple(b + V(0, 0.35, 0.4)), r=0.08, ressort=False, mat_corps="jaune")
    cylindre(s, "sombre", 0.45, 0.65, tuple(b), (90, 0, 0), n=22)
    cylindre(s, "chrome", 0.18, 0.72, tuple(b), (90, 0, 0), n=14)
    s = "AvantBras" + sd; a, b = V(*J[s]), V(*J["Main" + sd])
    m, L_ = entre(a, b)
    boite(s, "carrosserie", (1.0, 1.0, L_ * 0.9), (0.06 * c, 0, -0.05), biseau=0.1, base=m, effile=(1.15, 1.15))
    boite(s, "sombre", (0.82, 1.06, L_ * 0.35), (0.08 * c, 0, -L_ * 0.3), biseau=0.05, base=m)
    for k in range(5):
        boite(s, "noir", (0.9, 0.05, 0.05), (0.06 * c, -0.53, -0.3 + k * 0.13), biseau=0, base=m)
    phare(s, (0.06 * c, -0.54, L_ * 0.3), (0, 0, 0), larg=0.5, haut=0.12, base=m)
    engrenage(s, 0.22, 0.06, (0.55 * c, 0, 0.3), (0, 90, 0), dents=11, base=m)
    tube(s, "noir", [tuple(a + V(-0.35 * c, -0.3, 0)), tuple(a.lerp(b, 0.5) + V(-0.5 * c, -0.35, 0)), tuple(b + V(-0.25 * c, -0.2, 0.15))], 0.05)
    s = "Main" + sd; o = V(*J[s])
    boite(s, "sombre", (0.62, 0.55, 0.5), tuple(o + V(0, 0, -0.12)), biseau=0.06)
    for k in range(4):
        boite(s, "carrosserie", (0.13, 0.17, 0.42), tuple(o + V(-0.21 + k * 0.14, -0.1, -0.5)), (15, 0, 0), biseau=0.03)
        boite(s, "noir", (0.12, 0.16, 0.1), tuple(o + V(-0.21 + k * 0.14, -0.12, -0.3)), biseau=0.02)
    boite(s, "carrosserie", (0.16, 0.18, 0.36), tuple(o + V(0.3 * -c, -0.15, -0.3)), (25, 0, 30 * c), biseau=0.03)
    s = "Lame" + sd; o = V(*J[s])
    base_l = Matrix.Translation(o) @ Euler((math.radians(-4), math.radians(-14 * c), 0), "XYZ").to_matrix().to_4x4()
    prisme(s, "sombre", [(-0.16, 0.3), (0.16, 0.3), (0.18, -0.25), (-0.18, -0.25)], 0.3, (0.48 * c, 0, 0), plan="XZ", base=base_l)
    lame = [(0.0, 0.3), (0.3, 0.15), (0.34, -1.2), (0.18, -3.0), (0.02, -4.2), (-0.15, -2.6), (-0.25, -1.0), (-0.2, 0.12)]
    fil = [(0.3, 0.12), (0.35, -1.2), (0.19, -3.0), (0.02, -4.15), (0.12, -3.0), (0.27, -1.2), (0.25, 0.1)]
    dos = [(-0.2, 0.1), (-0.08, 0.1), (-0.04, -2.5), (-0.13, -2.55)]
    if c < 0:
        lame = [(-u, v) for u, v in lame]; fil = [(-u, v) for u, v in fil]; dos = [(-u, v) for u, v in dos]
    prisme(s, "chrome", lame, 0.08, (0.52 * c, 0, -0.1), plan="YZ", base=base_l, biseau=0.02)
    prisme(s, "lueur", fil, 0.04, (0.52 * c, -0.02, -0.1), plan="YZ", base=base_l, biseau=0.0)
    prisme(s, "sombre", dos, 0.13, (0.52 * c, 0, -0.1), plan="YZ", base=base_l, biseau=0.01)

# ------------------------------------------------------------------ JAMBES (massives, roues sur les mollets)
def jambe(c):
    sd = "D" if c > 0 else "G"
    s = "Cuisse" + sd; a, b = V(*J[s]), V(*J["Tibia" + sd])
    m, L_ = entre(a, b)
    cylindre(s, "noir", 0.4, L_ * 0.95, (0, 0, 0), n=20, base=m)
    boite(s, "carrosserie", (1.05, 1.1, L_ * 0.68), (0.05 * c, -0.15, 0.12), biseau=0.1, base=m, effile=(0.85, 0.85))
    boite(s, "sombre", (0.75, 0.4, L_ * 0.45), (0.05 * c, 0.42, 0.1), biseau=0.05, base=m)
    prisme(s, "carbone", [(0, 0.35), (0.12, -0.35), (-0.3, -0.25), (-0.35, 0.2)], 0.12, (0.55 * c, -0.1, 0.1), (0, 0, 90), plan="XZ", base=m, biseau=0.02)
    piston(s, tuple(a + V(0.45 * c, 0.3, -0.35)), tuple(b + V(0.25 * c, 0.42, 0.4)), r=0.11)
    piston(s, tuple(a + V(-0.25 * c, -0.45, -0.45)), tuple(b + V(-0.15 * c, -0.35, 0.45)), r=0.09, ressort=False, mat_corps="jaune")
    cylindre(s, "sombre", 0.52, 0.9, tuple(b), (0, 90, 0), n=24)
    boite(s, "carrosserie", (0.7, 0.4, 0.75), tuple(b + V(0, -0.45, 0.05)), (15, 0, 0), biseau=0.08, effile=(0.8, 1))
    s = "Tibia" + sd; a, b = V(*J[s]), V(*J["Pied" + sd])
    m, L_ = entre(a, b)
    boite(s, "carrosserie", (1.0, 1.05, L_ * 0.8), (0, -0.1, 0.05), biseau=0.1, base=m, effile=(0.8, 0.85))
    boite(s, "noir", (0.5, 0.5, L_ * 0.95), (0, 0.2, 0), biseau=0.04, base=m)
    # pare-chocs / calandre sur le tibia
    boite(s, "sombre", (0.75, 0.12, L_ * 0.35), (0, -0.66, 0.15), biseau=0.03, base=m)
    for k in range(4):
        boite(s, "chrome", (0.65, 0.04, 0.04), (0, -0.74, 0.0 + k * 0.12), biseau=0, base=m)
    phare(s, (0, -0.74, L_ * 0.3), (0, 0, 0), larg=0.55, haut=0.14, base=m)
    piston(s, tuple(a + V(0, 0.55, -0.1)), tuple(b + V(0, 0.45, 0.3)), r=0.14, ressort="jaune")
    roue(s, tuple(a.lerp(b, 0.55) + V(0.7 * c, 0.15, 0)), (0, 90, 0), r=0.68, larg=0.45)     # roue sur le mollet
    cylindre(s, "sombre", 0.42, 0.75, tuple(b), (0, 90, 0), n=22)
    s = "Pied" + sd; o = V(*J[s])
    boite(s, "sombre", (1.05, 1.35, 0.55), tuple(o + V(0, -0.25, -0.55)), biseau=0.1, effile=(0.85, 0.8))
    boite(s, "carrosserie", (0.95, 0.9, 0.3), tuple(o + V(0, -0.45, -0.22)), biseau=0.07, effile=(0.8, 0.8))
    boite(s, "carrosserie", (0.9, 0.55, 0.32), tuple(o + V(0, -1.0, -0.62)), (6, 0, 0), biseau=0.08, effile=(0.85, 0.7))   # bout du pied
    boite(s, "noir", (1.0, 1.5, 0.12), tuple(o + V(0, -0.35, -0.8)), biseau=0.03)                                   # semelle
    boite(s, "carrosserie", (0.5, 0.5, 0.3), tuple(o + V(0, 0.45, -0.62)), biseau=0.06)                                   # talon
    piston(s, tuple(o + V(0.45 * c, -0.1, 0.1)), tuple(o + V(0.4 * c, -0.75, -0.4)), r=0.06, ressort=False)

def construire():
    nettoyer()
    tete(); torse(); bassin()
    for c in (1, -1):
        bras(c); jambe(c)
    # fusion par segment + matière (moins de pièces dans Roblox)
    groupes = {}
    for ob, seg, mat in PIECES:
        groupes.setdefault((seg, mat), []).append(ob)
    resultat = []
    dg = bpy.context.evaluated_depsgraph_get()
    for (seg, mat), obs in groupes.items():
        bm = bmesh.new()
        for ob in obs:
            ev = ob.evaluated_get(dg)
            me = ev.to_mesh()
            me.transform(ob.matrix_world)
            bm.from_mesh(me)
            ev.to_mesh_clear()
        nom = "%s__%s" % (seg, mat)
        me = bpy.data.meshes.new(nom)
        bm.to_mesh(me); bm.free()
        me.materials.append(materiau(mat))
        for ob in obs: bpy.data.objects.remove(ob)
        ob = _obj(nom, me)
        ob["segment"], ob["matiere"] = seg, mat
        resultat.append(ob)
    return resultat

if __name__ == "__main__":
    import sys, os
    obs = construire()
    tri = 0
    for ob in obs:
        n = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        tri += n
        if n > 18000: print("TROP DE TRIANGLES", ob.name, n)
    print("pièces :", len(obs), "triangles :", tri)
    sortie = os.environ.get("GARDIEN_BLEND")
    if sortie: bpy.ops.wm.save_as_mainfile(filepath=sortie)
