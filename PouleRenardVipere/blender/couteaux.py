# =====================================================================
#  POULE RENARD VIPÈRE — Générateur des 15 couteaux (Blender 4.1+ / 5.x)
# ---------------------------------------------------------------------
#  Utilisation dans Blender : onglet "Scripting" > Ouvrir ce fichier > ▶ Run.
#  Résultat :
#    - une collection par couteau (Poules / Renards / Vipères) dans la scène,
#    - un fichier .glb par couteau dans le dossier DOSSIER_EXPORT,
#    - (option) une planche d'aperçu PNG.
#
#  Unités : 1 unité Blender = 1 stud Roblox.
#  Axes   : la lame pointe vers +Z (devient +Y dans Roblox), le tranchant vers -X,
#           l'épaisseur est sur Y. L'origine (0,0,0) = point de prise en main.
#
#  Chaque couteau est découpé en un objet PAR COULEUR, nommé
#     <IdCouteau>_<Partie>_<cleCouleur>     ex : PouleBase_Blade_white
#  -> le script Roblox InstallerCouteaux.lua relit la clé couleur pour appliquer
#     la bonne couleur / le Neon. L'objet *_Outline_outline est le contour noir
#     cartoon (technique « inverted hull », fonctionne dans Roblox).
# =====================================================================
import bpy, bmesh, math, os, json, sys
from mathutils import Vector

# ----------------------------------------------------------------- réglages
DOSSIER_EXPORT = os.environ.get("PRV_EXPORT") or os.path.join(
    os.path.dirname(bpy.data.filepath) if bpy.data.filepath else os.path.expanduser("~"),
    "couteaux_glb")
EXPORTER_GLB   = True
EPAISSEUR_CONTOUR = 0.022          # contour noir (studs)
SEULEMENT = None                   # ex : ["PouleGeant"] pour ne refaire qu'un couteau

# --------------------------------------------------------------- palette
# (même clés que ReplicatedStorage.Couteaux.Config.Palette côté Roblox)
PALETTE = {
    # clé          couleur      metal rough  neon
    "white":      ("F4F1EA", 0.0, 0.45, False),
    "cream":      ("EADBB8", 0.0, 0.7,  False),
    "steel":      ("D8DEE6", 0.9, 0.25, False),
    "steel_dark": ("8E98A6", 0.9, 0.3,  False),
    "red":        ("D62828", 0.0, 0.5,  False),
    "red_dark":   ("8E1414", 0.0, 0.6,  False),
    "yellow":     ("F6B21A", 0.0, 0.5,  False),
    "gold":       ("F2C230", 1.0, 0.25, False),
    "black":      ("1B1B1F", 0.0, 0.6,  False),
    "gray_dark":  ("3A3D44", 0.6, 0.35, False),
    "orange":     ("FF6A00", 0.0, 0.5,  False),
    "fox_dark":   ("2A2420", 0.0, 0.7,  False),
    "green":      ("47D11F", 0.0, 0.5,  False),
    "green_dark": ("1E4D1E", 0.0, 0.6,  False),
    "purple":     ("7A2FD0", 0.0, 0.5,  False),
    "purple_dark":("3B1670", 0.0, 0.6,  False),
    "orange_glow":("FF7A1A", 0.0, 0.3,  True),
    "yellow_glow":("FFD23A", 0.0, 0.3,  True),
    "green_glow": ("7CFF2E", 0.0, 0.3,  True),
    "outline":    ("000000", 0.0, 1.0,  False),
}

# =====================================================================
#  Outils géométriques
# =====================================================================
def hexrgb(h):
    c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]

def cr(points):
    """Courbe lisse (Catmull-Rom) passant par des points (t, x)."""
    pts = sorted(points)
    def f(t):
        if t <= pts[0][0]: return pts[0][1]
        if t >= pts[-1][0]: return pts[-1][1]
        for i in range(len(pts) - 1):
            if pts[i][0] <= t <= pts[i+1][0]: break
        p0 = pts[max(i-1, 0)]; p1 = pts[i]; p2 = pts[i+1]; p3 = pts[min(i+2, len(pts)-1)]
        s = (t - p1[0]) / (p2[0] - p1[0])
        m1 = (p2[1] - p0[1]) / max(p2[0] - p0[0], 1e-6) * (p2[0] - p1[0])
        m2 = (p3[1] - p1[1]) / max(p3[0] - p1[0], 1e-6) * (p2[0] - p1[0])
        s2, s3 = s*s, s*s*s
        return (2*s3-3*s2+1)*p1[1] + (s3-2*s2+s)*m1 + (-2*s3+3*s2)*p2[1] + (s3-s2)*m2
    return f

def teeth(t0, t1, count, depth, shape="saw"):
    """Dents (scie / éclairs) entre t0 et t1 : renvoie un décalage >= 0."""
    def f(t):
        if t <= t0 or t >= t1: return 0.0
        p = ((t - t0) / (t1 - t0) * count) % 1.0
        if shape == "saw": return depth * (1 - p)
        if shape == "tri": return depth * (1 - abs(2*p - 1))
        if shape == "flame": return depth * (1 - p) ** 1.8
        return 0.0
    return f

def add(fn, *offs, sign=1):
    return lambda t: fn(t) + sign * sum(o(t) for o in offs)

def circle_pts(n, rx=0.5, rz=None, start=0):
    rz = rx if rz is None else rz
    return [(rx*math.cos(start + 2*math.pi*i/n), rz*math.sin(start + 2*math.pi*i/n)) for i in range(n)]

SHAPES = {
    "crown":  [(-0.5,0),(0.5,0),(0.55,0.62),(0.27,0.32),(0,0.75),(-0.27,0.32),(-0.55,0.62)],
    "fox":    [(-0.52,0.6),(-0.36,0.08),(0,-0.5),(0.36,0.08),(0.52,0.6),(0.2,0.3),(0,0.36),(-0.2,0.3)],
    "bolt":   [(0.15,0.62),(-0.32,-0.02),(-0.03,-0.02),(-0.18,-0.62),(0.32,0.06),(0.03,0.06)],
    "snake":  [(0,0.6),(-0.3,0.25),(-0.38,-0.15),(-0.18,-0.5),(0,-0.58),(0.18,-0.5),(0.38,-0.15),(0.3,0.25)],
    "comb":   [(-0.45,0),(0.45,0),(0.42,0.3),(0.25,0.18),(0.15,0.48),(0,0.25),(-0.12,0.55),(-0.25,0.22),(-0.42,0.42)],
    "diamond":[(0,0.5),(0.3,0),(0,-0.5),(-0.3,0)],
    "eye":    [(0.5,0),(0.25,0.22),(-0.25,0.22),(-0.5,0),(-0.25,-0.22),(0.25,-0.22)],
    "slit":   [(0.05,0.2),(0.05,-0.2),(-0.05,-0.2),(-0.05,0.2)],
    "chicken":[(-0.4,-0.4),(0.4,-0.4),(0.45,0.15),(0.25,0.42),(0.1,0.35),(0,0.58),(-0.15,0.38),(-0.32,0.5),(-0.42,0.2)],
}

class Knife:
    """Accumule la géométrie d'un couteau, rangée par (partie, couleur)."""
    def __init__(self, kid):
        self.id = kid
        self.buckets = {}       # (part, color) -> [list of face coord lists]

    def face(self, part, color, coords):
        self.buckets.setdefault((part, color), []).append([Vector(c) for c in coords])

    # ---------------------------------------------------- loft générique
    def loft(self, part, rings, color_fn, cap0=True, cap1=None, tip=None, cap1_color=None):
        n, m = len(rings), len(rings[0][0])
        for i in range(n - 1):
            (ra, ma), (rb, mb) = rings[i], rings[i+1]
            for j in range(m):
                k = (j + 1) % m
                info = [ma[j], ma[k], mb[k], mb[j]]
                self.face(part, color_fn(i, j, info), [ra[j], ra[k], rb[k], rb[j]])
        def fan(ring, meta, center, rev):
            for j in range(m):
                k = (j + 1) % m
                tri = [ring[k], ring[j], center] if rev else [ring[j], ring[k], center]
                self.face(part, cap1_color or color_fn(len(rings)-1, j, [meta[j], meta[k]]), tri)
        if cap0:
            r0, m0 = rings[0]
            c = sum(r0, Vector()) / m
            for j in range(m):
                k = (j + 1) % m
                self.face(part, color_fn(0, j, [m0[j], m0[k]]), [r0[k], r0[j], c])
        rl, ml = rings[-1]
        if tip is not None:
            fan(rl, ml, Vector(tip), False)
        elif cap1:
            fan(rl, ml, sum(rl, Vector()) / m, False)

    # ---------------------------------------------------- lame
    def blade(self, L, spine, edge, h0=0.05, bevel=0.42, double=False, n=90, nu=4,
              color="steel", z0=0.0, end="point", thick=None, part="Blade"):
        """spine(t)/edge(t) = position X du dos / du tranchant, t de 0 (garde) à 1 (pointe)."""
        b0 = 1 - bevel
        if double:
            us = [i / (2*nu) for i in range(2*nu + 1)]
            yprof = lambda u: 1 - abs(2*u - 1) ** 1.0 * 0.92
            yprof_ = lambda u: 0.0 if u in (0.0, 1.0) else yprof(u)
        else:
            us = [b0 * i / nu for i in range(nu + 1)] + [b0 + (1 - b0) * k / 2 for k in (1, 2)]
            yprof_ = lambda u: 1.0 if u <= b0 else 1 - (u - b0) / (1 - b0)
        thick = thick or (lambda t: h0 * (1 - 0.72 * t ** 1.6))
        tmax = 1.0 if end == "flat" else 1.0 - 1.0 / n
        rings = []
        for i in range(n + (1 if end == "flat" else 0)):
            t = min(i / n, 1.0) if end == "flat" else i / n
            if t > tmax: t = tmax
            sx, ex, hh, z = spine(t), edge(t), thick(t), z0 + t * L
            top, meta_top = [], []
            for u in us:
                x = sx + (ex - sx) * u
                top.append(Vector((x, yprof_(u) * hh, z))); meta_top.append((t, u, +1))
            bot, meta_bot = [], []
            for u in reversed(us):
                if u == 1.0: continue
                if double and u == 0.0: continue
                x = sx + (ex - sx) * u
                bot.append(Vector((x, -yprof_(u) * hh, z))); meta_bot.append((t, u, -1))
            rings.append((top + bot, meta_top + meta_bot))
        def cf(i, j, info):
            if callable(color) is False: return color
            tc = sum(a[0] for a in info) / len(info)
            uc = sum(a[1] for a in info) / len(info)
            side = 1 if sum(a[2] for a in info) >= 0 else -1
            region = "spine" if (not double and all(a[1] == 0 for a in info)) else (
                     "bevel" if (not double and uc > b0 + 1e-6) else "flat")
            return color(tc, uc, region, side)
        if end == "flat":
            self.loft(part, rings, cf, cap0=True, cap1=True)
        else:
            tip = (spine(1.0) * 0.5 + edge(1.0) * 0.5, 0, z0 + L)
            self.loft(part, rings, cf, cap0=True, tip=tip)

    # ---------------------------------------------------- manche / anneaux
    def handle(self, z0, z1, r, color="black", ratio=0.78, seg=16, n=18, part="Handle", flat=False):
        r = r if callable(r) else (lambda t, rr=r: rr)
        rings = []
        for i in range(n + 1):
            t = i / n; z = z0 + (z1 - z0) * t; rr = r(t)
            pts, meta = [], []
            for j in range(seg):
                a = 2 * math.pi * j / seg + (math.pi / seg if flat else 0)
                pts.append(Vector((rr * math.cos(a), rr * ratio * math.sin(a), z))); meta.append((t, a, 0))
            rings.append((pts, meta))
        def cf(i, j, info):
            if not callable(color): return color
            tc = sum(a[0] for a in info) / len(info)
            ac = math.atan2(sum(math.sin(a[1]) for a in info), sum(math.cos(a[1]) for a in info))
            return color(tc, ac % (2 * math.pi), i, j)
        self.loft(part, rings, cf, cap0=True, cap1=True)

    def band(self, z0, z1, r, color, ratio=0.78, part="Handle"):
        self.handle(z0, z1, r, color, ratio=ratio, n=1, part=part)

    # ---------------------------------------------------- primitives
    def _from_bm(self, part, color, bm, mat=None):
        if mat: bmesh.ops.transform(bm, matrix=mat, verts=bm.verts)
        for f in bm.faces:
            self.face(part, color, [v.co.copy() for v in f.verts])
        bm.free()

    def box(self, c, s, color, part="Guard", bevel=0.02):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * s[0] + c[0], v.co.y * s[1] + c[1], v.co.z * s[2] + c[2]))
        if bevel:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect='EDGES')
        self._from_bm(part, color, bm)

    def sphere(self, c, r, color, scale=(1, 1, 1), part="Pommel", seg=14):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2 + 1, radius=r)
        for v in bm.verts:
            v.co = Vector((v.co.x * scale[0] + c[0], v.co.y * scale[1] + c[1], v.co.z * scale[2] + c[2]))
        self._from_bm(part, color, bm)

    def prism(self, pts, color, y0=0.0, depth=0.05, part="Deco"):
        """Forme 2D (x, z) extrudée en épaisseur sur Y."""
        front = [Vector((x, y0 + depth / 2, z)) for x, z in pts]
        back = [Vector((x, y0 - depth / 2, z)) for x, z in pts]
        self.face(part, color, front)
        self.face(part, color, list(reversed(back)))
        n = len(pts)
        for i in range(n):
            k = (i + 1) % n
            self.face(part, color, [front[i], back[i], back[k], front[k]])

    def emblem(self, shape, cx, cz, s, color, y_surface, depth=0.025, both=True, rot=0.0, sx=None, part="Deco"):
        pts = SHAPES[shape] if isinstance(shape, str) else shape
        cs, sn = math.cos(rot), math.sin(rot)
        sx = s if sx is None else sx
        tp = [(cx + (x*sx)*cs - (z*s)*sn, cz + (x*sx)*sn + (z*s)*cs) for x, z in pts]
        self.prism(tp, color, y0=y_surface + depth / 2 - 0.004, depth=depth, part=part)
        if both:
            self.prism([(x, z) for x, z in tp], color, y0=-(y_surface + depth / 2 - 0.004), depth=depth, part=part)

    def tube(self, path, r, color, sides=8, part="Deco", r_fn=None):
        path = [Vector(p) for p in path]
        n = len(path)
        tans = []
        for i in range(n):
            a = path[max(i-1, 0)]; b = path[min(i+1, n-1)]
            tans.append((b - a).normalized())
        ref = Vector((0, 0, 1)) if abs(tans[0].z) < 0.9 else Vector((1, 0, 0))
        nrm = tans[0].cross(ref).normalized()
        rings = []
        for i in range(n):
            if i:
                nrm = (nrm - tans[i] * nrm.dot(tans[i])).normalized()
            bin_ = tans[i].cross(nrm)
            rr = r_fn(i / (n - 1)) if r_fn else r
            pts = [path[i] + (nrm * math.cos(2*math.pi*j/sides) + bin_ * math.sin(2*math.pi*j/sides)) * rr
                   for j in range(sides)]
            rings.append((pts, [(i/(n-1), jj, 0) for jj in range(sides)]))
        self.loft(part, rings, lambda i, j, info: color, cap0=True, cap1=True)

    def helix(self, z0, z1, radius, turns, r, color, part="Deco", steps=90, ratio=0.78, phase=0.0):
        path = []
        for i in range(steps + 1):
            t = i / steps; a = phase + 2 * math.pi * turns * t
            path.append((radius * math.cos(a), radius * ratio * math.sin(a), z0 + (z1 - z0) * t))
        self.tube(path, r, color, part=part)

# =====================================================================
#  Les 15 couteaux
# =====================================================================
L = 1.65          # longueur de lame standard (studs)
HZ0, HZ1 = -0.95, -0.1   # manche : de HZ0 (bas) à HZ1 (sous la garde)
HR = 0.105        # rayon du manche
HY = HR * 0.78    # surface du manche sur Y (pour les emblèmes)

def std_guard(k, color, w=0.5, d=0.17, hgt=0.1):
    k.box((0, 0, -0.05), (w, d, hgt), color)

def stripes_handle(c1, c2, freq=7, slant=1.0):
    return lambda t, a, i, j: c1 if math.sin((t * freq + a / (2*math.pi) * slant) * 2 * math.pi) > 0.25 else c2

def rings_handle(base, ring, at=(0.1, 0.5, 0.9), w=0.06):
    return lambda t, a, i, j: ring if any(abs(t - x) < w for x in at) else base

# ---------------------------------------------------------------- POULES
def PouleBase():
    k = Knife("PouleBase")
    sp = cr([(0, 0.17), (0.45, 0.2), (0.72, 0.17), (1, -0.06)])
    ed = cr([(0, -0.17), (0.35, -0.23), (0.7, -0.19), (1, -0.06)])
    k.blade(L, sp, ed, color=lambda t, u, r, s: "steel" if r in ("bevel", "spine") else "white")
    for i, t in enumerate((0.42, 0.55, 0.68)):          # plumes rouges sur le dos
        x, z = sp(t) - 0.02, t * L
        k.prism([(x, z - 0.05), (x + 0.03, z + 0.15), (x + 0.2 - 0.03*i, z + 0.32)], "red", depth=0.07, part="Feathers")
    k.box((0, 0, -0.04), (0.44, 0.19, 0.08), "steel_dark")
    k.band(-0.2, -0.08, 0.125, "red")
    k.handle(HZ0, -0.2, lambda t: HR * (1 + 0.12 * math.sin(math.pi * t)), "yellow")
    k.emblem("chicken", 0, -0.55, 0.14, "white", HY * 1.1)
    k.emblem("comb", 0, -0.48, 0.09, "red", HY * 1.1 + 0.02)
    k.sphere((0, 0, HZ0 - 0.04), 0.13, "gold", scale=(1, 0.8, 0.6))
    return k

def PouleRoyal():
    k = Knife("PouleRoyal")
    wave = lambda t: 0.012 * math.sin(t * math.pi * 7) if t < 0.75 else 0
    sp = add(cr([(0, 0.16), (0.5, 0.2), (0.8, 0.15), (1, -0.02)]), wave)
    ed = cr([(0, -0.16), (0.3, -0.2), (0.65, -0.17), (1, -0.02)])
    def col(t, u, r, s):
        if r == "spine" or u < 0.16: return "gold"
        if t < 0.1: return "gold"
        return "steel"
    k.blade(L * 1.05, sp, ed, color=col)
    k.emblem("crown", -0.02, 0.62, 0.17, "gold", 0.05 * (1 - 0.72 * 0.38 ** 1.6))
    k.box((0, 0, -0.05), (0.56, 0.2, 0.11), "gold")
    k.sphere((0.3, 0, -0.05), 0.07, "gold"); k.sphere((-0.3, 0, -0.05), 0.07, "gold")
    k.handle(HZ0, HZ1, HR, rings_handle("black", "gold", at=(0.08, 0.92), w=0.05))
    k.emblem("crown", 0, -0.62, 0.11, "gold", HY)
    k.sphere((0, 0, HZ0 - 0.05), 0.12, "gold", scale=(1, 0.85, 0.7))
    k.emblem("crown", 0, HZ0 - 0.17, 0.12, "gold", 0, depth=0.06, both=False, part="Pommel")
    return k

def PoulePlume():
    k = Knife("PoulePlume")
    width = cr([(0, 0.12), (0.3, 0.2), (0.6, 0.2), (0.85, 0.12), (1, 0.0)])
    curve = cr([(0, 0), (0.5, 0.03), (1, 0.16)])
    sp = add(lambda t: curve(t) + width(t), teeth(0.25, 0.95, 10, 0.03))
    ed = add(lambda t: curve(t) - width(t), teeth(0.15, 0.95, 11, 0.03), sign=-1)
    def col(t, u, r, s):
        if t < 0.2: return "red"
        if (0.38 < t < 0.48 and u > 0.6) or (0.55 < t < 0.62 and u < 0.35): return "red"
        if 0.47 < u < 0.53: return "cream"
        return "white"
    k.blade(L * 1.1, sp, ed, h0=0.04, double=True, n=150, nu=5, color=col)
    k.box((0, 0, -0.04), (0.3, 0.16, 0.08), "red", bevel=0.03)
    k.handle(HZ0, HZ1, HR * 0.95, stripes_handle("cream", "white", freq=6, slant=1.0))
    k.band(-0.3, -0.24, HR * 1.12, "red"); k.band(-0.75, -0.69, HR * 1.12, "red")
    k.tube([(0.09 * math.cos(a), 0, HZ0 - 0.12 + 0.09 * math.sin(a)) for a in [i * 2 * math.pi / 16 for i in range(17)]],
           0.03, "red", part="Pommel")
    k.sphere((0, 0, HZ0 - 0.1), 0.06, "white")
    return k

def PouleElectrique():
    k = Knife("PouleElectrique")
    sp = add(cr([(0, 0.15), (0.5, 0.2), (0.8, 0.14), (1, 0.0)]), teeth(0.12, 0.88, 5, 0.04, "saw"))
    ed = add(cr([(0, -0.15), (0.4, -0.2), (0.8, -0.14), (1, 0.0)]), teeth(0.1, 0.85, 4, 0.04, "saw"), sign=-1)
    def col(t, u, r, s):
        if r == "spine" or u < 0.1 or u > 0.8: return "yellow_glow"
        return "gray_dark"
    k.blade(L * 1.05, sp, ed, n=160, color=col)
    k.emblem("bolt", 0.0, 0.62, 0.2, "yellow_glow", 0.05 * (1 - 0.72 * 0.37 ** 1.6))
    k.box((0, 0, -0.05), (0.5, 0.19, 0.1), "gold")
    k.handle(HZ0, HZ1, HR, rings_handle("black", "gold", at=(0.1, 0.5, 0.9), w=0.05))
    k.emblem("bolt", 0, -0.32, 0.1, "yellow_glow", HY)
    k.sphere((0, 0, HZ0 - 0.04), 0.12, "gold", scale=(1, 0.85, 0.65))
    return k

def PouleGeant():
    k = Knife("PouleGeant")
    LB = 1.75
    sp = lambda t: 0.2
    ed = lambda t: -0.95
    def col(t, u, r, s):
        if r == "bevel" or r == "spine": return "steel"
        if u < 0.05 or t > 0.95 or t < 0.04: return "steel_dark"
        return "white"
    k.blade(LB, sp, ed, h0=0.06, thick=lambda t: 0.06, n=12, nu=6, bevel=0.15, end="flat", color=col)
    y = 0.06
    cx, cz = -0.37, 0.95
    k.emblem(circle_pts(20, 0.33, 0.38), cx, cz, 1, "cream", y)                    # tête
    k.emblem("comb", cx + 0.02, cz + 0.33, 0.42, "red", y + 0.006)                 # crête
    k.emblem([(0, 0.08), (-0.2, -0.02), (0, -0.1)], cx - 0.2, cz - 0.08, 1, "yellow", y + 0.012)  # bec
    k.emblem(circle_pts(10, 0.07, 0.11), cx - 0.2, cz - 0.24, 1, "red", y + 0.012)  # barbillon
    for ex in (-0.06, 0.12):
        k.emblem(circle_pts(10, 0.06, 0.07), cx + ex, cz + 0.07, 1, "black", y + 0.012)
    k.emblem([(-0.16, 0.2), (0.04, 0.13), (0.04, 0.17), (-0.16, 0.24)], cx, cz, 1, "black", y + 0.012)
    k.emblem([(0.06, 0.13), (0.24, 0.2), (0.24, 0.24), (0.06, 0.17)], cx, cz, 1, "black", y + 0.012)
    k.box((0, 0, -0.05), (0.42, 0.2, 0.12), "steel_dark")
    k.handle(HZ0 - 0.15, HZ1, HR * 1.15, stripes_handle("red", "red_dark", freq=8, slant=1.0))
    for z in (-0.3, -0.6, -0.9):
        k.sphere((0, HY * 1.15, z), 0.035, "gold", part="Studs"); k.sphere((0, -HY * 1.15, z), 0.035, "gold", part="Studs")
    k.box((0, 0, HZ0 - 0.2), (0.28, 0.22, 0.12), "white", part="Pommel", bevel=0.04)
    return k

# ---------------------------------------------------------------- RENARDS
def RenardBase():
    k = Knife("RenardBase")
    sp = add(cr([(0, 0.16), (0.45, 0.18), (0.75, 0.13), (1, -0.08)]), teeth(0.08, 0.38, 5, 0.035))
    ed = cr([(0, -0.16), (0.35, -0.22), (0.72, -0.18), (1, -0.08)])
    def col(t, u, r, s):
        if r == "bevel": return "orange_glow" if u > 0.8 else "steel_dark"
        if t > 0.86: return "orange"
        return "gray_dark"
    k.blade(L, sp, ed, n=150, color=col)
    k.box((0, 0, -0.05), (0.46, 0.19, 0.1), "orange")
    k.handle(HZ0, HZ1, lambda t: HR * (1 + 0.1 * math.sin(math.pi * t * 2)), "fox_dark")
    k.emblem("fox", 0, -0.5, 0.17, "orange", HY * 1.08)
    k.band(HZ0 + 0.02, HZ0 + 0.1, HR * 1.12, "orange")
    k.sphere((0, 0, HZ0 - 0.03), 0.1, "fox_dark", scale=(1, 0.85, 0.7))
    return k

def RenardFurtif():
    k = Knife("RenardFurtif")
    sp = add(cr([(0, 0.15), (0.5, 0.17), (0.8, 0.1), (1, -0.05)]), teeth(0.15, 0.6, 4, 0.06, "tri"))
    ed = cr([(0, -0.15), (0.4, -0.2), (0.75, -0.16), (1, -0.05)])
    def col(t, u, r, s):
        if r == "bevel": return "gray_dark"
        return "orange" if math.sin((t * 5.5 + u * 1.2) * 2 * math.pi) > 0.35 else "black"
    k.blade(L, sp, ed, n=150, nu=8, color=col)
    k.box((0, 0, -0.05), (0.42, 0.18, 0.1), "black")
    k.handle(HZ0, HZ1, HR, stripes_handle("orange", "black", freq=5, slant=2.0))
    k.emblem("fox", 0, -0.55, 0.15, "orange", HY * 1.05)
    k.tube([(0.08 * math.cos(a), 0, HZ0 - 0.1 + 0.08 * math.sin(a)) for a in [i * 2 * math.pi / 16 for i in range(17)]],
           0.03, "black", part="Pommel")
    return k

def RenardSpectre():
    k = Knife("RenardSpectre")
    w = cr([(0, 0.1), (0.25, 0.22), (0.55, 0.2), (0.85, 0.1), (1, 0)])
    sp = w; ed = lambda t: -w(t)
    def col(t, u, r, s):
        if u < 0.13 or u > 0.87: return "orange_glow"
        return "fox_dark"
    k.blade(L, sp, ed, h0=0.045, double=True, n=60, nu=5, color=col)
    k.emblem("fox", 0, 0.62, 0.22, "orange_glow", 0.045 * (1 - 0.72 * 0.37 ** 1.6) * 0.2 + 0.012)
    k.prism([(-0.3, -0.12), (-0.35, 0.02), (-0.14, -0.02), (0, 0.05), (0.14, -0.02), (0.35, 0.02), (0.3, -0.12)],
            "orange", depth=0.18, part="Guard")
    k.handle(HZ0, -0.12, HR * 0.95, rings_handle("fox_dark", "orange", at=(0.3, 0.6), w=0.04))
    k.sphere((0, 0, HZ0 - 0.03), 0.1, "orange", scale=(1, 0.8, 0.6))
    return k

def RenardLegendaire():
    k = Knife("RenardLegendaire")
    sp = add(cr([(0, 0.16), (0.45, 0.2), (0.75, 0.15), (1, -0.04)]), teeth(0.1, 0.55, 6, 0.045, "tri"))
    ed = cr([(0, -0.16), (0.4, -0.22), (0.75, -0.17), (1, -0.04)])
    def col(t, u, r, s):
        if r == "bevel": return "steel"
        flame = 0.22 + 0.28 * (0.5 + 0.5 * math.sin(u * 17 + 1.3))
        if t < flame: return "orange"
        if t < flame + 0.05: return "black"
        return "steel"
    k.blade(L * 1.08, sp, ed, n=160, nu=10, color=col)
    k.prism([(-0.32, -0.1), (-0.38, 0.1), (-0.18, 0.02), (0, 0.06), (0.18, 0.02), (0.38, 0.1), (0.32, -0.1)],
            "orange", depth=0.2, part="Guard")
    k.handle(HZ0, -0.1, HR, "fox_dark")
    k.emblem("fox", 0, -0.45, 0.18, "orange", HY * 1.02)
    k.band(-0.8, -0.72, HR * 1.12, "orange")
    k.sphere((0, 0, HZ0 - 0.04), 0.11, "orange", scale=(1, 0.8, 0.7))
    return k

def RenardOrigami():
    k = Knife("RenardOrigami")
    sp = cr([(0, 0.1), (0.35, 0.3), (0.7, 0.18), (1, 0.0)])
    ed = cr([(0, -0.1), (0.45, -0.22), (1, 0.0)])
    k.blade(L * 1.05, sp, ed, h0=0.09, double=True, n=4, nu=1,
            color=lambda t, u, r, s: ("orange" if ((int(t * 4) + (u > 0.5) + (s > 0)) % 2) else "black"))
    k.box((0, 0, -0.05), (0.3, 0.2, 0.1), "black", bevel=0)
    k.handle(HZ0, HZ1, HR * 1.05, lambda t, a, i, j: "orange" if (i + j) % 2 else "black", seg=6, n=5, flat=True)
    k.tube([(-0.1, 0, -0.15), (-0.32, 0, -0.3), (-0.32, 0, -0.75), (-0.1, 0, HZ0 + 0.02)], 0.045, "orange",
           sides=4, part="Loop")
    return k

# ---------------------------------------------------------------- VIPÈRES
def ViperBase():
    k = Knife("ViperBase")
    sp = cr([(0, 0.15), (0.35, 0.14), (0.7, 0.02), (1, -0.3)])
    ed = cr([(0, -0.15), (0.35, -0.24), (0.7, -0.3), (1, -0.3)])
    def col(t, u, r, s):
        if r in ("bevel", "spine"): return "green"
        if 0.18 < u < 0.62 and 0.08 < t < 0.85:
            return "purple" if (int(t * 16) + int(u * 6)) % 2 else "purple_dark"
        return "green"
    k.blade(L, sp, ed, n=90, nu=8, color=col)
    k.box((0, 0, -0.05), (0.44, 0.18, 0.1), "black")
    k.handle(HZ0, HZ1, HR, stripes_handle("green_dark", "black", freq=7, slant=1.5))
    k.emblem("snake", 0, -0.5, 0.14, "green", HY * 1.05)
    k.tube([(0.08 * math.cos(a), 0, HZ0 - 0.1 + 0.08 * math.sin(a)) for a in [i * 2 * math.pi / 16 for i in range(17)]],
           0.03, "green", part="Pommel")
    return k

def ViperToxique():
    k = Knife("ViperToxique")
    sp = add(cr([(0, 0.13), (0.5, 0.2), (0.85, 0.1), (1, 0.06)]), teeth(0.15, 0.85, 4, 0.05, "flame"))
    ed = add(cr([(0, -0.13), (0.4, -0.18), (0.8, -0.1), (1, 0.06)]), teeth(0.1, 0.8, 4, 0.05, "flame"), sign=-1)
    def col(t, u, r, s):
        if r == "spine" or u < 0.1 or u > 0.8: return "green_glow"
        return "black"
    k.blade(L * 1.05, sp, ed, n=170, color=col)
    k.emblem("snake", 0.02, 0.5, 0.16, "green_glow", 0.05 * (1 - 0.72 * 0.3 ** 1.6))
    k.box((0, 0, -0.05), (0.44, 0.18, 0.1), "green_dark")
    k.handle(HZ0, HZ1, HR, rings_handle("black", "green_glow", at=(0.15, 0.5, 0.85), w=0.04))
    k.sphere((0, 0, HZ0 - 0.04), 0.11, "green_dark", scale=(1, 0.8, 0.7))
    return k

def ViperSerpent():
    k = Knife("ViperSerpent")
    c = lambda t: 0.13 * math.sin(t * 2 * math.pi * 1.4) * (1 - 0.25 * t)
    w = cr([(0, 0.13), (0.5, 0.12), (0.85, 0.08), (1, 0.0)])
    sp = lambda t: c(t) + w(t); ed = lambda t: c(t) - w(t)
    def col(t, u, r, s):
        if u < 0.12 or u > 0.88: return "green"
        return "purple" if (int(t * 22) + int(u * 6)) % 2 else "purple_dark"
    k.blade(L * 1.12, sp, ed, h0=0.05, double=True, n=110, nu=6, color=col)
    k.box((0, 0, -0.05), (0.38, 0.18, 0.1), "green")
    k.handle(HZ0, HZ1, HR * 0.95, "purple_dark")
    k.helix(HZ0 + 0.05, HZ1 - 0.02, HR * 1.05, 2.5, 0.035, "green", part="Snake")
    k.sphere((HR * 1.05 * math.cos(2 * math.pi * 2.5), 0, HZ1 + 0.02), 0.06, "green", scale=(1, 0.8, 1.4), part="Snake")
    k.sphere((0, 0, HZ0 - 0.04), 0.1, "green", scale=(1, 0.8, 0.7))
    return k

def ViperVenin():
    k = Knife("ViperVenin")
    sp = cr([(0, 0.15), (0.4, 0.19), (0.75, 0.12), (1, 0.08)])
    ed = cr([(0, -0.15), (0.4, -0.16), (0.75, -0.06), (1, 0.08)])
    def col(t, u, r, s):
        if r == "spine" or u < 0.08 or u > 0.82: return "green_glow"
        return "purple" if t > 0.25 else "purple_dark"
    k.blade(L * 1.05, sp, ed, n=90, color=col)
    yy = 0.05 * (1 - 0.72 * 0.3 ** 1.6)
    k.emblem("eye", 0.0, 0.48, 0.24, "green_glow", yy)
    k.emblem("slit", 0.0, 0.48, 0.24, "black", yy + 0.012)
    k.box((0, 0, -0.05), (0.42, 0.18, 0.1), "purple_dark")
    k.handle(HZ0, HZ1, HR, rings_handle("black", "green", at=(0.2, 0.5, 0.8), w=0.05))
    k.sphere((0, 0, HZ0 - 0.04), 0.11, "black", scale=(1, 0.8, 0.7))
    return k

def ViperRoyal():
    k = Knife("ViperRoyal")
    sp = add(cr([(0, 0.15), (0.45, 0.19), (0.8, 0.12), (1, 0.02)]), teeth(0.15, 0.7, 4, 0.06, "tri"))
    ed = cr([(0, -0.15), (0.35, -0.2), (0.75, -0.14), (1, 0.02)])
    def col(t, u, r, s):
        if r == "spine" or u < 0.08 or u > 0.82: return "green_glow"
        return "green_dark" if t > 0.15 else "black"
    k.blade(L * 1.08, sp, ed, n=150, color=col)
    k.box((0, 0, -0.05), (0.46, 0.2, 0.1), "black")
    k.emblem("crown", 0, 0.06, 0.32, "green", 0, depth=0.14, both=False, part="Crown")
    k.handle(HZ0, HZ1, HR * 0.95, "black")
    k.helix(HZ0 + 0.05, HZ1 - 0.02, HR * 1.05, 2.0, 0.04, "green", part="Snake")
    k.sphere((HR * 1.05, 0, HZ1 + 0.03), 0.065, "green", scale=(1, 0.8, 1.4), part="Snake")
    k.sphere((0, 0, HZ0 - 0.04), 0.11, "green_glow", scale=(1, 0.8, 0.7))
    return k

COUTEAUX = [
    # id, fonction, nom affiché, équipe
    ("PouleBase", PouleBase, "Couteau de base", "Poules"),
    ("PouleRoyal", PouleRoyal, "Couteau royal", "Poules"),
    ("PoulePlume", PoulePlume, "Couteau plume", "Poules"),
    ("PouleElectrique", PouleElectrique, "Couteau électrique", "Poules"),
    ("PouleGeant", PouleGeant, "Couteau géant", "Poules"),
    ("RenardBase", RenardBase, "Couteau de base", "Renards"),
    ("RenardFurtif", RenardFurtif, "Couteau furtif", "Renards"),
    ("RenardSpectre", RenardSpectre, "Couteau spectre", "Renards"),
    ("RenardLegendaire", RenardLegendaire, "Couteau légendaire", "Renards"),
    ("RenardOrigami", RenardOrigami, "Couteau origami", "Renards"),
    ("ViperBase", ViperBase, "Couteau de base", "Vipères"),
    ("ViperToxique", ViperToxique, "Couteau toxique", "Vipères"),
    ("ViperSerpent", ViperSerpent, "Couteau serpent", "Vipères"),
    ("ViperVenin", ViperVenin, "Couteau venin", "Vipères"),
    ("ViperRoyal", ViperRoyal, "Couteau royal", "Vipères"),
]

# =====================================================================
#  Construction des objets Blender
# =====================================================================
def material(key):
    name = "PRV_" + key
    m = bpy.data.materials.get(name)
    if m: return m
    hexc, metal, rough, neon = PALETTE[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    rgb = hexrgb(hexc) + [1.0]
    bsdf.inputs["Base Color"].default_value = rgb
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if neon:
        bsdf.inputs["Emission Color"].default_value = rgb
        bsdf.inputs["Emission Strength"].default_value = 1.6
    if key == "outline":
        m.use_backface_culling = True
        out = nt.nodes.get("Material Output")
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
        nt.links.new(bsdf.outputs[0], mix.inputs[1])
        nt.links.new(tr.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
    m.diffuse_color = rgb
    return m

def build_mesh(name, faces, matkey, coll, offset):
    bm = bmesh.new()
    for f in faces:
        vs = [bm.verts.new(c + offset) for c in f]
        try: bm.faces.new(vs)
        except ValueError: pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(40))
    me.materials.append(material(matkey))
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob

def build_outline(name, objs, coll, w):
    bm = bmesh.new()
    for ob in objs:
        tmp = bmesh.new(); tmp.from_mesh(ob.data)
        tmp.normal_update()
        vmap = {}
        for v in tmp.verts:
            vmap[v.index] = bm.verts.new(v.co + v.normal * w)
        for f in tmp.faces:
            try: bm.faces.new([vmap[v.index] for v in reversed(f.verts)])
            except ValueError: pass
        tmp.free()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    me.materials.append(material("outline"))
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob

def build_all(only=None):
    root = bpy.data.collections.get("Couteaux") or bpy.data.collections.new("Couteaux")
    if root.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(root)
    result = {}
    for kid, fn, nom, team in COUTEAUX:
        if only and kid not in only: continue
        old = bpy.data.collections.get(kid)
        if old:
            for ob in list(old.objects): bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.collections.remove(old)
        coll = bpy.data.collections.new(kid); root.children.link(coll)
        k = fn()
        # origine = milieu du manche (point de prise en main)
        hz = [v.z for (p, c), fs in k.buckets.items() if p == "Handle" for f in fs for v in f]
        grip = (min(hz) + max(hz)) / 2 if hz else -0.5
        off = Vector((0, 0, -grip))
        objs = []
        for (part, color), faces in sorted(k.buckets.items()):
            objs.append(build_mesh(f"{kid}_{part}_{color}", faces, color, coll, off))
        objs.append(build_outline(f"{kid}_Outline_outline", objs, coll, EPAISSEUR_CONTOUR * (1.4 if kid == "PouleGeant" else 1)))
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
        result[kid] = {"objs": objs, "team": team, "nom": nom, "tris": tris}
        print(f"[PRV] {kid:18s} {len(objs):2d} pièces  {tris:6d} triangles")
    return result

def export_glb(result, folder):
    os.makedirs(folder, exist_ok=True)
    for kid, info in result.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in info["objs"]: o.select_set(True)
        bpy.context.view_layer.objects.active = info["objs"][0]
        path = os.path.join(folder, kid + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                                  export_yup=True, export_apply=True, export_materials='EXPORT')
        print("[PRV] exporté :", path)

if __name__ == "__main__":
    res = build_all(SEULEMENT)
    if EXPORTER_GLB:
        export_glb(res, DOSSIER_EXPORT)
