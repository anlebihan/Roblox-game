# =====================================================================
#  POULE RENARD VIPÈRE — Rendus 3D pour l'interface (Blender 4.2+ / 5.x, Cycles)
# ---------------------------------------------------------------------
#  Génère des images PNG (fond transparent) :
#    caisse_<Equipe>.png      caisses ouvertes, lumière qui sort, couteau planté dedans
#    pieces_<1|2|3>.png       tas de pièces (petit / moyen / gros)
#    icone_<nom>.png          icônes du menu (engrenage, trophée, cadeau, sac…)
#    fond_menu.png            fond cinématique du menu / écran de chargement (1920x1080)
#  Usage : blender -b -P rendus_interface.py -- <dossier_glb_couteaux> <dossier_sortie> [nom ...]
# =====================================================================
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Euler, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
GLB = ARGS[0] if ARGS else os.path.expanduser("~/couteaux_glb")
SORTIE = ARGS[1] if len(ARGS) > 1 else os.path.expanduser("~/rendus_interface")
QUOI = ARGS[2:]
ECHANTILLONS = int(os.environ.get("PRV_SAMPLES", "96"))

EQUIPES = {
    # caisse : couleur principale, foncée, lueur, couteau mis en avant
    "Poules":     dict(c1=(0.85, 0.12, 0.10), c2=(0.35, 0.03, 0.02), glow=(1.0, 0.75, 0.2), couteau="PouleRoyal"),
    "Renards":    dict(c1=(1.0, 0.36, 0.02), c2=(0.12, 0.08, 0.06), glow=(1.0, 0.45, 0.05), couteau="RenardLegendaire"),
    "Viperes":    dict(c1=(0.20, 0.75, 0.10), c2=(0.18, 0.05, 0.35), glow=(0.5, 1.0, 0.2), couteau="ViperRoyal"),
    "Legendaire": dict(c1=(1.0, 0.70, 0.08), c2=(0.30, 0.12, 0.02), glow=(1.0, 0.85, 0.4), couteau="PouleGeant"),
}

# ------------------------------------------------------------------ utilitaires
def vider():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(nom, couleur, metal=0.0, rough=0.5, emission=None, force=0.0):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*couleur, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emission:
        b.inputs["Emission Color"].default_value = (*emission, 1)
        b.inputs["Emission Strength"].default_value = force
    return m

def boite(nom, taille, pos, materiau, biseau=0.04, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.name = nom
    o.scale = taille
    bpy.ops.object.transform_apply(scale=True)
    if biseau:
        b = o.modifiers.new("biseau", 'BEVEL'); b.width = biseau; b.segments = 3
    o.data.materials.append(materiau)
    bpy.ops.object.shade_smooth()
    return o

def scene_rendu(res=(768, 768), transparent=True, fond=(0.02, 0.02, 0.03)):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = ECHANTILLONS
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = int(os.environ.get("PRV_POURCENT", "100"))
    sc.render.film_transparent = transparent
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Punchy'
    w = bpy.data.worlds.new("monde"); sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (*fond, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    return sc

def lumiere(nom, type_, pos, energie, couleur=(1, 1, 1), taille=1.0, cible=None):
    l = bpy.data.lights.new(nom, type_)
    l.energy = energie; l.color = couleur
    if type_ == 'AREA': l.size = taille
    o = bpy.data.objects.new(nom, l); bpy.context.scene.collection.objects.link(o)
    o.location = pos
    if cible is not None:
        o.rotation_euler = (Vector(cible) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
    return o

def camera(pos, cible, lens=50, ortho=None):
    c = bpy.data.cameras.new("cam")
    if ortho: c.type = 'ORTHO'; c.ortho_scale = ortho
    c.lens = lens
    o = bpy.data.objects.new("cam", c); bpy.context.scene.collection.objects.link(o)
    o.location = pos
    o.rotation_euler = (Vector(cible) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = o
    return o

def importer_couteau(kid, longueur=None, sans_contour=False):
    """Importe un couteau .glb (sans le contour), renvoie un objet vide parent. Origine = bas du manche."""
    avant = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(GLB, kid + ".glb"))
    objs = [o for o in set(bpy.data.objects) - avant if o.type == 'MESH']
    vide = bpy.data.objects.new(kid, None); bpy.context.scene.collection.objects.link(vide)
    for o in objs:
        if o.name.endswith("outline") and sans_contour:
            o.hide_render = True
        elif o.name.endswith("outline"):
            # contour cartoon (normales inversées) : invisible de l'intérieur dans Cycles
            for sl in o.material_slots:
                m = sl.material
                if not m: continue
                m.use_backface_culling = True
                nt = m.node_tree; out = nt.nodes.get("Material Output"); b = nt.nodes.get("Principled BSDF")
                if out and b:
                    geo = nt.nodes.new("ShaderNodeNewGeometry"); tr = nt.nodes.new("ShaderNodeBsdfTransparent")
                    mx = nt.nodes.new("ShaderNodeMixShader")
                    nt.links.new(geo.outputs["Backfacing"], mx.inputs[0]); nt.links.new(b.outputs[0], mx.inputs[1])
                    nt.links.new(tr.outputs[0], mx.inputs[2]); nt.links.new(mx.outputs[0], out.inputs["Surface"])
            o.visible_shadow = o.visible_diffuse = o.visible_glossy = False
        o.parent = vide
    if longueur:
        zs = [(o.matrix_world @ v.co).z for o in objs for v in o.data.vertices]
        vide.scale = [longueur / (max(zs) - min(zs))] * 3
    return vide

def rendre(nom):
    os.makedirs(SORTIE, exist_ok=True)
    bpy.context.scene.render.filepath = os.path.join(SORTIE, nom + ".png")
    bpy.ops.render.render(write_still=True)
    if bpy.context.scene.render.film_transparent and nom.startswith(("logo", "icone", "caisse", "pieces")):
        img = bpy.data.images.load(bpy.context.scene.render.filepath)
        try:
            import numpy as np
            w, h = img.size
            px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
            ys, xs = np.nonzero(px[:, :, 3] > 0.02)
            if len(xs):
                m = 8
                x0, x1, y0, y1 = max(xs.min() - m, 0), min(xs.max() + m, w - 1), max(ys.min() - m, 0), min(ys.max() + m, h - 1)
                crop = px[y0:y1 + 1, x0:x1 + 1].copy()
                out = bpy.data.images.new(nom + "_crop", x1 - x0 + 1, y1 - y0 + 1, alpha=True)
                out.pixels[:] = crop.ravel()
                out.filepath_raw = bpy.context.scene.render.filepath; out.file_format = 'PNG'; out.save()
        except Exception as e:
            print("[PRV] rognage impossible :", e)
    print("[PRV] rendu :", nom)

# ------------------------------------------------------------------ caisse
def caisse(equipe):
    sc = scene_icone()
    e = EQUIPES[equipe]
    bois = mat("bois", e["c1"], 0.0, 0.45)
    fonce = mat("fonce", e["c2"], 0.0, 0.55)
    orm = mat("or", (1.0, 0.72, 0.18), 1.0, 0.22)
    interieur = mat("interieur", (0.05, 0.04, 0.06), 0.0, 0.8, e["glow"], 3.0)
    lueur = mat("lueur", e["glow"], 0.0, 0.3, e["glow"], 25.0)
    L, P, H = 2.4, 1.6, 1.25
    # corps : fond + 4 parois (creux)
    boite("fond", (L, P, 0.15), (0, 0, 0.075), bois)
    boite("avant", (L, 0.15, H), (0, -P / 2 + 0.075, H / 2), bois)
    boite("arriere", (L, 0.15, H), (0, P / 2 - 0.075, H / 2), bois)
    boite("gauche", (0.15, P, H), (-L / 2 + 0.075, 0, H / 2), bois)
    boite("droite", (0.15, P, H), (L / 2 - 0.075, 0, H / 2), bois)
    boite("dedans", (L - 0.3, P - 0.3, 0.05), (0, 0, H - 0.25), interieur, 0)
    # bandes foncées + coins dorés
    for z in (0.22, H - 0.2):
        boite("bande", (L + 0.06, P + 0.06, 0.16), (0, 0, z), fonce, 0.03)
    for x in (-1, 1):
        for y in (-1, 1):
            boite("coin", (0.3, 0.3, H + 0.08), (x * (L / 2 - 0.08), y * (P / 2 - 0.08), H / 2), orm, 0.05)
    # serrure
    boite("serrure", (0.42, 0.12, 0.5), (0, -P / 2 - 0.04, H - 0.32), orm, 0.06)
    # couvercle ouvert (charnière à l'arrière)
    couv = bpy.data.objects.new("couvercle", None); sc.collection.objects.link(couv)
    couv.location = (0, P / 2, H)
    parts = [boite("c_plateau", (L + 0.08, P + 0.08, 0.22), (0, -P / 2, 0.11), bois),
             boite("c_bande", (L + 0.12, P + 0.12, 0.1), (0, -P / 2, 0.05), fonce, 0.03)]
    for x in (-1, 1):
        parts.append(boite("c_coin", (0.32, P + 0.12, 0.26), (x * (L / 2 - 0.08), -P / 2, 0.13), orm, 0.05))
    for p in parts: p.parent = couv
    couv.rotation_euler = (math.radians(-62), 0, 0)
    # lumière qui sort de la caisse
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, H - 0.18))
    pl = bpy.context.active_object; pl.scale = (L - 0.35, P - 0.35, 1); pl.data.materials.append(lueur)
    lumiere("dedans", 'POINT', (0, 0, H + 0.2), 400, e["glow"])
    # couteau planté
    k = importer_couteau(e["couteau"], 3.0, sans_contour=True)
    k.location = (0.25, 0.05, H - 1.0)
    k.rotation_euler = (math.radians(8), math.radians(-24), 0)
    # étincelles
    random.seed(4)
    etin = mat("etin", e["glow"], 0, 0.3, e["glow"], 30)
    for i in range(26):
        a = random.uniform(0, 2 * math.pi); r = random.uniform(0.3, 1.6)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=random.uniform(0.025, 0.06), subdivisions=1,
                                              location=(r * math.cos(a) * 0.8, r * math.sin(a) * 0.5, H + random.uniform(0.1, 2.0)))
        bpy.context.active_object.data.materials.append(etin)
    # lumières studio
    ambiance_icone((0, 0, 1.1), 1.2)
    lumiere("contre", 'AREA', (4, 4, 4), 700, e["glow"], 3, (0, 0, 1))
    camera((4.3, -6.2, 4.2), (0, 0, 1.15), 50)
    rendre("caisse_" + equipe)

# ------------------------------------------------------------------ pièces
def piece(nom, pos, rot, m_or, m_bord):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=0.5, depth=0.12, location=pos, rotation=rot)
    o = bpy.context.active_object; o.name = nom
    b = o.modifiers.new("b", 'BEVEL'); b.width = 0.03; b.segments = 3
    o.data.materials.append(m_or); bpy.ops.object.shade_smooth()
    # relief : anneau + étoile
    bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.035, location=pos, rotation=rot)
    t = bpy.context.active_object; t.data.materials.append(m_bord)
    t.location = Vector(pos) + (Euler(rot).to_matrix() @ Vector((0, 0, 0.065)))
    return o

def pieces(n):
    vider(); scene_rendu()
    m_or = mat("or", (1.0, 0.70, 0.12), 1.0, 0.2)
    m_bord = mat("bord", (1.0, 0.82, 0.35), 1.0, 0.15)
    random.seed(n)
    nb = {1: 6, 2: 18, 3: 46}[n]
    for i in range(nb):
        if n == 1:
            pos = (random.uniform(-0.5, 0.5), random.uniform(-0.3, 0.3), 0.06 + i * 0.12)
            rot = (random.uniform(-0.1, 0.1), random.uniform(-0.1, 0.1), 0)
        else:
            r = random.uniform(0, 1.0 if n == 2 else 1.6) ** 0.7
            a = random.uniform(0, 2 * math.pi)
            h = (1.0 if n == 2 else 1.6) * (1 - r / (1.0 if n == 2 else 1.6)) + 0.06
            pos = (r * math.cos(a), r * math.sin(a), random.uniform(0.06, max(0.07, h)))
            rot = (random.uniform(-0.6, 0.6), random.uniform(-0.6, 0.6), random.uniform(0, 3))
        piece("p%d" % i, pos, rot, m_or, m_bord)
    # pièces debout devant
    piece("debout", (0.6, -0.9, 0.5), (math.radians(80), 0, math.radians(20)), m_or, m_bord)
    lumiere("cle", 'AREA', (-3, -4, 5), 900, (1, 0.95, 0.85), 3, (0, 0, 0.3))
    lumiere("contre", 'AREA', (3, 3, 3), 500, (1, 0.8, 0.4), 3, (0, 0, 0.5))
    camera((3.2, -4.6, 3.2), (0, 0, 0.45), 50)
    rendre("pieces_%d" % n)

# ------------------------------------------------------------------ icônes
def icone_engrenage():
    vider(); scene_rendu((512, 512))
    m = mat("metal", (0.75, 0.78, 0.85), 1.0, 0.25)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=1.0, depth=0.35)
    g = bpy.context.active_object
    for i in range(10):
        a = 2 * math.pi * i / 10
        boite("dent", (0.38, 0.4, 0.35), (1.08 * math.cos(a), 1.08 * math.sin(a), 0), m, 0.05, (0, 0, a))
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.42, depth=0.6)
    trou = bpy.context.active_object
    bo = g.modifiers.new("trou", 'BOOLEAN'); bo.object = trou; bo.operation = 'DIFFERENCE'
    bpy.context.view_layer.objects.active = g; bpy.ops.object.modifier_apply(modifier="trou")
    trou.hide_render = True
    bv = g.modifiers.new("b", 'BEVEL'); bv.width = 0.05; bv.segments = 3
    g.data.materials.append(m); bpy.ops.object.shade_smooth()
    for o in bpy.context.scene.objects:
        if o.type == 'MESH' and o != trou: o.rotation_euler = (math.radians(60), 0, math.radians(15))
    lumiere("cle", 'AREA', (-3, -4, 5), 800, (1, 1, 1), 3, (0, 0, 0))
    lumiere("contre", 'AREA', (3, 3, 2), 500, (0.6, 0.8, 1.0), 3, (0, 0, 0))
    camera((0, -6, 0.5), (0, 0, 0), 50, ortho=3.2)
    rendre("icone_parametres")

def icone_trophee():
    scene_icone()
    m = mat("or", (1.0, 0.72, 0.15), 1.0, 0.2)
    rouge = mat("rouge", (0.8, 0.1, 0.1), 0.0, 0.4)
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.35, radius2=0.95, depth=1.3, location=(0, 0, 1.45))
    c = bpy.context.active_object; c.data.materials.append(m)
    bv = c.modifiers.new("b", 'BEVEL'); bv.width = 0.05; bv.segments = 3; bpy.ops.object.shade_smooth()
    for x in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.38, minor_radius=0.09, location=(x * 0.95, 0, 1.55), rotation=(math.radians(90), 0, 0))
        bpy.context.active_object.data.materials.append(m); bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.14, depth=0.5, location=(0, 0, 0.6))
    bpy.context.active_object.data.materials.append(m)
    boite("socle", (1.2, 0.8, 0.4), (0, 0, 0.2), rouge, 0.06)
    boite("plaque", (0.9, 0.05, 0.22), (0, -0.42, 0.2), m, 0.02)
    ambiance_icone((0, 0, 0.9), 1.0)
    camera((2.2, -5.5, 2.4), (0, 0, 1.1), 50, ortho=3.6)
    rendre("icone_classement")

def icone_cadeau():
    scene_icone()
    rouge = mat("rouge", (0.85, 0.1, 0.25), 0.0, 0.35)
    ruban = mat("ruban", (1.0, 0.8, 0.15), 0.6, 0.25)
    boite("boite", (1.6, 1.6, 1.2), (0, 0, 0.6), rouge, 0.06)
    boite("couv", (1.75, 1.75, 0.35), (0, 0, 1.3), rouge, 0.06)
    boite("r1", (0.3, 1.8, 1.55), (0, 0, 0.78), ruban, 0.03)
    boite("r2", (1.8, 0.3, 1.55), (0, 0, 0.78), ruban, 0.03)
    for a in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.32, minor_radius=0.1, location=(a * 0.3, 0, 1.75), rotation=(math.radians(90), math.radians(a * 25), 0))
        bpy.context.active_object.data.materials.append(ruban); bpy.ops.object.shade_smooth()
    ambiance_icone((0, 0, 0.9), 1.0)
    camera((3, -4.5, 3.2), (0, 0, 0.85), 50, ortho=3.6)
    rendre("icone_cadeau")

# ------------------------------------------------------------------ écran de chargement (3 couches)
POLICE = os.environ.get("PRV_POLICE", os.path.join(os.path.dirname(os.path.abspath(__file__)), "LuckiestGuy.ttf"))

def bruit_sol(o, force=0.6, echelle=3.0):
    tex = bpy.data.textures.get("bruit") or bpy.data.textures.new("bruit", 'CLOUDS')
    tex.noise_scale = echelle
    d = o.modifiers.new("d", 'DISPLACE'); d.texture = tex; d.strength = force

def fond_ciel():
    """Couche 1 : ciel de nuit, montagnes, portail tricolore, brume (1920x1080, opaque)."""
    vider(); sc = scene_rendu((1920, 1080), transparent=False, fond=(0.012, 0.01, 0.035))
    sc.cycles.samples = max(64, ECHANTILLONS)
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'Medium High Contrast'
    # montagnes lointaines
    random.seed(3)
    m_mont = mat("mont", (0.05, 0.045, 0.1), 0, 0.9)
    for i in range(9):
        x = -26 + i * 6.5 + random.uniform(-2, 2)
        bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=random.uniform(5, 8), depth=random.uniform(6, 11),
                                        location=(x, 30 + random.uniform(0, 6), 1.5), rotation=(0, 0, random.uniform(0, 1)))
        bpy.context.active_object.data.materials.append(m_mont); bpy.ops.object.shade_flat()
    # portail : 3 anneaux néon + disque tourbillon
    for i, col in enumerate(((1.0, 0.12, 0.05), (1.0, 0.45, 0.02), (0.3, 1.0, 0.1))):
        bpy.ops.mesh.primitive_torus_add(major_radius=4.3 + i * 0.42, minor_radius=0.12, location=(0, 22 + i * 0.3, 5.3),
                                         rotation=(math.radians(90), 0, 0), major_segments=128)
        bpy.context.active_object.data.materials.append(mat("anneau%d" % i, col, 0, 0.3, col, 2.2))
    bpy.ops.mesh.primitive_circle_add(vertices=96, radius=4.2, fill_type='NGON', location=(0, 22.1, 5.3), rotation=(math.radians(90), 0, 0))
    disque = bpy.context.active_object
    vm = bpy.data.materials.new("vortex"); vm.use_nodes = True
    nt = vm.node_tree; b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord"); mp = nt.nodes.new("ShaderNodeMapping")
    gr = nt.nodes.new("ShaderNodeTexGradient"); gr.gradient_type = 'SPHERICAL'
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 6
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.02, 0.0, 0.05, 1); ramp.color_ramp.elements[1].color = (0.6, 0.2, 1.0, 1)
    mix = nt.nodes.new("ShaderNodeMath"); mix.operation = 'MULTIPLY'
    nt.links.new(tc.outputs["Object"], mp.inputs[0]); nt.links.new(mp.outputs[0], gr.inputs[0]); nt.links.new(tc.outputs["Object"], nz.inputs[0])
    nt.links.new(gr.outputs[1], mix.inputs[0]); nt.links.new(nz.outputs[0], mix.inputs[1]); nt.links.new(mix.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], b.inputs["Emission Color"]); b.inputs["Emission Strength"].default_value = 1.4
    ramp.color_ramp.elements[1].position = 0.9
    nz.inputs["Detail"].default_value = 8; nz.inputs["Distortion"].default_value = 2.5
    b.inputs["Base Color"].default_value = (0, 0, 0, 1)
    mp.inputs["Scale"].default_value = (0.2, 0.2, 0.2)
    disque.data.materials.append(vm)
    lumiere("portail", 'POINT', (0, 19, 5.3), 2500, (0.7, 0.4, 1.0))
    # étoiles
    etoile = mat("etoile", (1, 1, 1), 0, 0.5, (1, 1, 1), 14)
    for i in range(260):
        bpy.ops.mesh.primitive_ico_sphere_add(radius=random.uniform(0.03, 0.09), subdivisions=1,
                                              location=(random.uniform(-45, 45), random.uniform(38, 45), random.uniform(2, 30)))
        bpy.context.active_object.data.materials.append(etoile)
    # sol lointain
    bpy.ops.mesh.primitive_plane_add(size=140, location=(0, 30, 0))
    sol = bpy.context.active_object
    sub = sol.modifiers.new("s", 'SUBSURF'); sub.levels = sub.render_levels = 5; sub.subdivision_type = 'SIMPLE'
    bruit_sol(sol, 0.8, 4.0)
    sol.data.materials.append(mat("sol", (0.04, 0.05, 0.08), 0, 0.9))
    lumiere("lune", 'SUN', (0, 0, 10), 0.8, (0.55, 0.65, 1.0))
    bpy.data.objects["lune"].rotation_euler = (math.radians(60), 0, math.radians(200))
    w = sc.world
    vol = w.node_tree.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Density"].default_value = 0.008
    vol.inputs["Color"].default_value = (0.55, 0.45, 0.9, 1)
    w.node_tree.links.new(vol.outputs[0], w.node_tree.nodes["World Output"].inputs["Volume"])
    camera((0, -6, 2.2), (0, 20, 5.2), 32)
    rendre("chargement_ciel")

def avant_plan():
    """Couche 2 : rocher sombre + 3 couteaux géants plantés, contre-jour aux couleurs des équipes (transparent)."""
    vider(); sc = scene_rendu((1920, 1080), transparent=True)
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'Medium High Contrast'
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=2.4, location=(0, 4, -0.9))
    roc = bpy.context.active_object; roc.scale = (2.3, 1.3, 0.8)
    bruit_sol(roc, 0.45, 0.9)
    m_roc = mat("roche", (0.035, 0.03, 0.045), 0, 0.75)
    roc.data.materials.append(m_roc); bpy.ops.object.shade_flat()
    # petits rochers
    random.seed(7)
    for i in range(7):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=random.uniform(0.25, 0.6),
                                              location=(random.uniform(-4.5, 4.5), random.uniform(2.5, 5), random.uniform(-0.2, 0.4)))
        r = bpy.context.active_object; r.data.materials.append(m_roc); bpy.ops.object.shade_flat()
    couteaux = {}
    for kid, x, ang, haut in (("PouleRoyal", -2.0, 14, 3.3), ("RenardLegendaire", 0, 0, 4.0), ("ViperRoyal", 2.0, -14, 3.3)):
        k = importer_couteau(kid, haut, sans_contour=True)
        couteaux[kid] = k
        pointe_z = 0.55 if kid == "RenardLegendaire" else 0.25
        k.location = (x, 4.0, pointe_z + haut * math.cos(math.radians(ang)))
        k.rotation_euler = (0, math.radians(180 + ang), 0)          # pointe vers le bas, plantée
        k.location.x += haut * math.sin(math.radians(ang)) * -1
    # contre-jours colorés (derrière) + douce lumière de face
    lumiere("poule", 'AREA', (-4.5, 7.5, 3.5), 900, (1.0, 0.25, 0.1), 3, (-2.2, 4, 2))
    lumiere("renard", 'AREA', (0, 8.5, 6.5), 900, (1.0, 0.5, 0.1), 3, (0, 4, 3))
    lumiere("vipere", 'AREA', (4.5, 7.5, 3.5), 900, (0.3, 1.0, 0.15), 3, (2.2, 4, 2))
    lumiere("face", 'AREA', (0, -3, 4), 180, (0.75, 0.8, 1.0), 6, (0, 4, 2.5))
    lumiere("portail", 'POINT', (0, 12, 6), 1500, (0.7, 0.4, 1.0))
    camera((0, -6, 2.2), (0, 20, 5.2), 32)
    # couches séparées (même cadrage) :
    #   rocher seul SANS ombre de couteau, chaque couteau seul (le rocher masque la partie plantée),
    #   et l'ombre de chaque couteau sur le rocher (rendue à part : elle apparaît à l'impact)
    rochers = [o for o in sc.objects if o.type == 'MESH' and o.parent is None]
    def enfants(v): return [o for o in v.children_recursive if o.type == 'MESH']
    tous_couteaux = [o for v in couteaux.values() for o in enfants(v)]
    def regler(cam_visibles, masques, ombres):
        for o in rochers + tous_couteaux:
            o.visible_camera = (o in cam_visibles) or (o in masques)
            o.is_holdout = o in masques
            o.visible_shadow = (o in rochers) or (o in ombres)
    regler(rochers, [], [])
    rendre("chargement_rocher")
    for kid, v in couteaux.items():
        regler(enfants(v), rochers, enfants(v))
        rendre("chargement_" + kid)
        regler(rochers, [], enfants(v))
        rendre("chargement_rocher_ombre_" + kid)
    for o in rochers + tous_couteaux:
        o.visible_camera = True; o.is_holdout = False; o.visible_shadow = True
    rendre("chargement_avant")

NOM_DU_JEU = "TRIPLE HUNT"
SOUS_TITRE = ("CHICKEN", "FOX", "VIPER")

def materiau_degrade(nom, bas, haut, brillant=True):
    m = bpy.data.materials.new(nom); m.use_nodes = True
    nt = m.node_tree; bs = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.2; ramp.color_ramp.elements[0].color = (*bas, 1)
    ramp.color_ramp.elements[1].position = 0.8; ramp.color_ramp.elements[1].color = (*haut, 1)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0]); nt.links.new(sep.outputs["Y"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = 0.22 if brillant else 0.6
    bs.inputs["Coat Weight"].default_value = 0.5 if brillant else 0.0
    bs.inputs["Coat Roughness"].default_value = 0.05
    return m

def texte_bloc(police, mot, taille, z, bas, haut, fonce, profondeur=0.38):
    """Lettres 3D : face en dégradé brillant + bloc de profondeur plus foncé (effet relief cartoon).
    Le contour noir est ajouté ensuite en 2D (finition_logo), bien rond et propre."""
    objs = []
    for couche in ("face", "bloc"):
        bpy.ops.object.text_add(location=(0, 0, 0))
        t = bpy.context.active_object
        t.data.body = mot; t.data.font = police; t.data.size = taille; t.data.align_x = 'CENTER'
        t.data.resolution_u = 24
        if couche == "face":
            t.data.extrude = 0.05 * taille; t.data.bevel_depth = 0.028 * taille; t.data.bevel_resolution = 6
            t.data.materials.append(materiau_degrade("face_" + mot, bas, haut))
            y = 0.0
        else:
            t.data.extrude = profondeur * taille / 2; t.data.bevel_depth = 0.02 * taille; t.data.bevel_resolution = 3
            m = mat("bloc_" + mot, fonce, 0.0, 0.5)
            m.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.2
            t.data.materials.append(m)
            y = profondeur * taille / 2 + 0.03 * taille
        t.rotation_euler = (math.radians(90), 0, 0)
        t.location = (0, y, z)
        objs.append(t)
    bpy.context.view_layer.update()
    return objs, objs[0].dimensions.x

def mot_lettres(police, mot, taille, z, bas, haut, fonce, profondeur=0.38, jeu=True, graine=0):
    """Mot en lettres séparées : légère inclinaison et décalage de chaque lettre (style cartoon)."""
    random.seed(graine)
    lettres = []
    for ch in mot:
        objs, larg = texte_bloc(police, ch, taille, z, bas, haut, fonce, profondeur)
        lettres.append((objs, larg))
    esp = -0.02 * taille
    total = sum(l for _, l in lettres) + esp * (len(lettres) - 1)
    x = -total / 2
    tous = []
    for i, (objs, larg) in enumerate(lettres):
        rot = (random.uniform(-4, 4) if jeu else 0)
        dz = (0.035 * taille * (1 if i % 2 else -1) if jeu else 0)
        for o in objs:
            o.location.x = x + larg / 2
            o.location.z += dz
            o.rotation_euler = (math.radians(90), math.radians(rot), 0)
            tous.append(o)
        x += larg + esp
    return tous, total

def logo():
    """Logo 3D en 3 couches (titre / bandeau / sous-titre) rendues séparément avec la même caméra,
    assemblées par finition_logo.py (contours propres)."""
    vider(); sc = scene_rendu((3072, 1536), transparent=True)
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    sc.cycles.samples = max(ECHANTILLONS, 64)
    police = bpy.data.fonts.load(POLICE)
    mots = NOM_DU_JEU.split(" ")
    o1, l1 = mot_lettres(police, mots[0], 1.3, 0.62, (0.95, 0.12, 0.04), (1.0, 0.86, 0.12), (0.45, 0.04, 0.02), graine=1)
    o2, l2 = mot_lettres(police, mots[1], 1.3, 0.62, (0.05, 0.6, 0.05), (0.72, 1.0, 0.18), (0.03, 0.22, 0.04), graine=2)
    ecart = 0.32
    total = l1 + l2 + ecart
    for o in o1: o.location.x += -total / 2 + l1 / 2
    for o in o2: o.location.x += total / 2 - l2 / 2
    titre = o1 + o2
    largeur = total * 0.8
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.12, -0.22))
    pl = bpy.context.active_object; pl.scale = (largeur, 0.22, 0.62)
    bpy.ops.object.transform_apply(scale=True)
    bv = pl.modifiers.new("b", 'BEVEL'); bv.width = 0.2; bv.segments = 8
    pl.data.materials.append(materiau_degrade("bandeau", (0.25, 0.08, 0.55), (0.55, 0.32, 0.95)))
    bpy.ops.object.shade_smooth()
    bandeau = [pl]
    sous = []
    pas = largeur / 3
    for i, (mot, cb, ch, cf) in enumerate(((SOUS_TITRE[0], (1.0, 0.6, 0.0), (1.0, 0.95, 0.4), (0.5, 0.25, 0.0)),
                                            (SOUS_TITRE[1], (1.0, 0.35, 0.0), (1.0, 0.72, 0.3), (0.45, 0.12, 0.0)),
                                            (SOUS_TITRE[2], (0.2, 0.7, 0.05), (0.7, 1.0, 0.3), (0.04, 0.25, 0.04)))):
        o, _ = mot_lettres(police, mot, 0.42, -0.38, cb, ch, cf, profondeur=0.25, jeu=False)
        for t in o:
            t.location.x += -largeur / 2 + pas * (i + 0.5)
            t.location.y -= 0.12
        sous += o
    for i in (1, 2):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.06, location=(-largeur / 2 + pas * i, -0.05, -0.2))
        o = bpy.context.active_object; o.data.materials.append(mat("point", (1, 1, 1), 0, 0.3, (1, 1, 1), 1.5))
        sous.append(o)
    lumiere("cle", 'AREA', (-2.5, -7, 6), 1300, (1, 0.97, 0.92), 8, (0, 0, 0.3))
    lumiere("bas", 'AREA', (3, -6, -4), 450, (0.75, 0.55, 1.0), 6, (0, 0, 0))
    lumiere("reflet", 'AREA', (0, -5, 9), 700, (1, 1, 1), 2, (0, 0, 0.6))
    camera((-1.0, -15, -2.4), (0, 0, 0.05), 62)
    # 3 passes : chaque couche seule (les autres restent visibles pour les ombres mais pas à la caméra)
    for nom, groupe in (("logo_titre", titre), ("logo_bandeau", bandeau), ("logo_sous", sous)):
        for o in titre + bandeau + sous:
            o.visible_camera = o in groupe
        bpy.context.scene.render.filepath = os.path.join(SORTIE, nom + ".png")
        os.makedirs(SORTIE, exist_ok=True)
        bpy.ops.render.render(write_still=True)
        print("[PRV] rendu :", nom)

def logo_scene():
    """Logo intégré à la scène de chargement : même caméra, mêmes lumières (contre-jour du portail),
    lettres en métal sombre. Le liseré néon et la lueur sont ajoutés par finition_logo_scene.py."""
    vider(); sc = scene_rendu((1920, 1080), transparent=True)
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'Medium High Contrast'
    police = bpy.data.fonts.load(POLICE)
    metal = bpy.data.materials.new("metal_sombre"); metal.use_nodes = True
    nt = metal.node_tree; bs = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.04, 0.03, 0.08, 1); ramp.color_ramp.elements[1].color = (0.24, 0.2, 0.34, 1)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0]); nt.links.new(sep.outputs["Y"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bs.inputs["Base Color"])
    bs.inputs["Metallic"].default_value = 0.85; bs.inputs["Roughness"].default_value = 0.3
    groupe = bpy.data.objects.new("Logo", None); sc.collection.objects.link(groupe)
    def mot(texte, taille, x, z, prof):
        bpy.ops.object.text_add(location=(0, 0, 0))
        t = bpy.context.active_object
        t.data.body = texte; t.data.font = police; t.data.size = taille; t.data.align_x = 'CENTER'
        t.data.extrude = prof; t.data.bevel_depth = 0.05 * taille; t.data.bevel_resolution = 5; t.data.resolution_u = 24
        t.data.materials.append(metal)
        t.rotation_euler = (math.radians(90), 0, 0); t.location = (x, 0, z); t.parent = groupe
        bpy.context.view_layer.update()
        return t
    mots = NOM_DU_JEU.split(" ")
    a = mot(mots[0], 1.6, 0, 0.55, 0.32); b2 = mot(mots[1], 1.6, 0, 0.55, 0.32)
    ecart = 0.4; total = a.dimensions.x + b2.dimensions.x + ecart
    a.location.x = -total / 2 + a.dimensions.x / 2; b2.location.x = total / 2 - b2.dimensions.x / 2
    sous = mot("  •  ".join(SOUS_TITRE), 0.62, 0, -0.45, 0.12)
    # placé au-dessus du portail, légèrement penché vers la caméra
    groupe.location = (0, 14, 8.75)
    groupe.rotation_euler = (math.radians(14), 0, 0)
    groupe.scale = (1.15, 1.15, 1.15)
    # mêmes ambiances que la scène : contre-jour violet du portail + couleurs d'équipes + lune
    lumiere("portail", 'AREA', (0, 22, 6), 4000, (0.7, 0.4, 1.0), 8, (0, 14, 8.75))
    lumiere("poule", 'POINT', (-7, 11, 9), 1800, (1.0, 0.3, 0.12))
    lumiere("vipere", 'POINT', (7, 11, 9), 1800, (0.35, 1.0, 0.2))
    lumiere("lune", 'AREA', (-4, 2, 16), 900, (0.6, 0.7, 1.0), 6, (0, 14, 8.75))
    lumiere("face", 'AREA', (0, 4, 7), 1100, (0.85, 0.8, 1.0), 6, (0, 14, 8.75))
    camera((0, -6, 2.2), (0, 20, 5.2), 32)
    rendre("chargement_logo")

def eclats():
    """6 éclats de roche (même roche et mêmes éclairages que le rocher), en grille : decoupés ensuite en sprites."""
    vider(); sc = scene_rendu((1536, 1024), transparent=True)
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'Medium High Contrast'
    m_roc = mat("roche", (0.06, 0.05, 0.075), 0, 0.7)
    random.seed(11)
    for i in range(6):
        x, z = (i % 3) * 2.0 - 2.0, (i // 3) * -2.0 + 1.0
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.62, location=(x, 0, z))
        o = bpy.context.active_object
        for v in o.data.vertices:
            v.co *= random.uniform(0.82, 1.12)
            v.co += Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) * 0.07
        # cassure : une face plane (comme un morceau arraché)
        bm = bmesh.new(); bm.from_mesh(o.data)
        n = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-0.3, 1))).normalized()
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=n * 0.25, plane_no=n, clear_outer=True)
        bmesh.ops.contextual_create(bm, geom=[e for e in bm.edges if e.is_boundary])
        bm.to_mesh(o.data); bm.free()
        o.scale = (random.uniform(0.8, 1.3), random.uniform(0.6, 1.0), random.uniform(0.55, 1.0))
        o.rotation_euler = (random.uniform(0, 3), random.uniform(0, 3), random.uniform(0, 3))
        o.data.materials.append(m_roc)
        bpy.ops.object.shade_flat()
    lumiere("poule", 'AREA', (-6, 3, 3), 900, (1.0, 0.3, 0.12), 4, (0, 0, 0))
    lumiere("vipere", 'AREA', (6, 3, 3), 900, (0.35, 1.0, 0.2), 4, (0, 0, 0))
    lumiere("haut", 'AREA', (0, -2, 6), 700, (0.75, 0.6, 1.0), 6, (0, 0, 0))
    lumiere("face", 'AREA', (0, -6, 1), 250, (0.85, 0.85, 1.0), 6, (0, 0, 0))
    camera((0, -10, 0), (0, 0, 0), 50, ortho=6.2)
    rendre("eclats_grille")

# ------------------------------------------------------------------ icônes de l'interface (même ambiance que la scène)
def ambiance_icone(cible=(0, 0, 0.8), dist=1.0):
    """Éclairage commun : clé froide, contre-jour violet (portail), touches rouge (Poules) et verte (Vipères)."""
    c = Vector(cible)
    lumiere("cle", 'AREA', tuple(c + Vector((-3, -5, 4)) * dist), 1100 * dist ** 2, (0.9, 0.9, 1.0), 4, tuple(c))
    lumiere("portail", 'AREA', tuple(c + Vector((0, 5, 3)) * dist), 1600 * dist ** 2, (0.7, 0.4, 1.0), 4, tuple(c))
    lumiere("poule", 'AREA', tuple(c + Vector((-5, 1, 1)) * dist), 650 * dist ** 2, (1.0, 0.3, 0.12), 3, tuple(c))
    lumiere("vipere", 'AREA', tuple(c + Vector((5, 1, 1)) * dist), 650 * dist ** 2, (0.35, 1.0, 0.2), 3, tuple(c))

def scene_icone():
    vider(); sc = scene_rendu((640, 640), transparent=True)
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'Medium High Contrast'
    sc.cycles.samples = max(ECHANTILLONS, 64)
    return sc

def icone_caisse():
    sc = scene_icone()
    bois = mat("bois", (0.32, 0.12, 0.6), 0.0, 0.4)
    fonce = mat("fonce", (0.08, 0.04, 0.16), 0.0, 0.5)
    orm = mat("or", (1.0, 0.72, 0.18), 1.0, 0.22)
    lueur = mat("lueur", (1.0, 0.8, 0.3), 0.0, 0.3, (1.0, 0.75, 0.25), 20.0)
    L, P, H = 2.4, 1.6, 1.25
    boite("fond", (L, P, 0.15), (0, 0, 0.075), bois)
    for nom, t, pos in (("avant", (L, 0.15, H), (0, -P / 2 + 0.075, H / 2)), ("arriere", (L, 0.15, H), (0, P / 2 - 0.075, H / 2)),
                        ("g", (0.15, P, H), (-L / 2 + 0.075, 0, H / 2)), ("d", (0.15, P, H), (L / 2 - 0.075, 0, H / 2))):
        boite(nom, t, pos, bois)
    for z in (0.22, H - 0.2):
        boite("bande", (L + 0.06, P + 0.06, 0.16), (0, 0, z), fonce, 0.03)
    for x in (-1, 1):
        for y in (-1, 1):
            boite("coin", (0.3, 0.3, H + 0.08), (x * (L / 2 - 0.08), y * (P / 2 - 0.08), H / 2), orm, 0.05)
    boite("serrure", (0.42, 0.12, 0.5), (0, -P / 2 - 0.04, H - 0.32), orm, 0.06)
    couv = bpy.data.objects.new("couvercle", None); sc.collection.objects.link(couv); couv.location = (0, P / 2, H)
    for o in (boite("c1", (L + 0.08, P + 0.08, 0.22), (0, -P / 2, 0.11), bois), boite("c2", (L + 0.12, P + 0.12, 0.1), (0, -P / 2, 0.05), fonce, 0.03),
              boite("c3", (0.32, P + 0.12, 0.26), (-(L / 2 - 0.08), -P / 2, 0.13), orm, 0.05), boite("c4", (0.32, P + 0.12, 0.26), ((L / 2 - 0.08), -P / 2, 0.13), orm, 0.05)):
        o.parent = couv
    couv.rotation_euler = (math.radians(-55), 0, 0)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, H - 0.15)); pl = bpy.context.active_object
    pl.scale = (L - 0.35, P - 0.35, 1); pl.data.materials.append(lueur)
    lumiere("dedans", 'POINT', (0, 0, H + 0.3), 250, (1.0, 0.8, 0.3))
    k = importer_couteau("RenardLegendaire", 2.6, sans_contour=True)
    k.location = (0.2, 0.05, H - 0.8); k.rotation_euler = (math.radians(8), math.radians(-22), 0)
    ambiance_icone((0, 0, 1.1), 1.2)
    camera((4.2, -6.4, 4.0), (0, 0, 1.25), 50)
    rendre("icone_caisses")

def icone_couteaux():
    scene_icone()
    for kid, ang, x in (("PouleRoyal", 38, -0.15), ("ViperRoyal", -38, 0.15)):
        k = importer_couteau(kid, 3.0, sans_contour=True)
        k.rotation_euler = (math.radians(90), math.radians(ang), 0)
        k.location = (x - math.sin(math.radians(ang)) * 1.5, 0, -math.cos(math.radians(ang)) * 1.5 + 0.2)
        k.rotation_euler = (0, math.radians(ang), 0)
    ambiance_icone((0, 0, 0.2), 1.0)
    camera((0, -9, 0.6), (0, 0, 0.2), 50, ortho=3.6)
    rendre("icone_couteaux")

def icone_parametres():
    scene_icone()
    m = mat("metal", (0.55, 0.52, 0.66), 1.0, 0.28)
    neon = mat("neon", (1.0, 0.75, 0.2), 0, 0.3, (1.0, 0.7, 0.2), 6)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=1.0, depth=0.4)
    g = bpy.context.active_object
    for i in range(9):
        a = 2 * math.pi * i / 9
        dent = boite("dent", (0.42, 0.45, 0.4), (1.1 * math.cos(a), 1.1 * math.sin(a), 0), m, 0.06, (0, 0, a))
        dent.select_set(True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.context.scene.objects:
        if o.type == 'MESH': o.select_set(True)
    bpy.context.view_layer.objects.active = g; bpy.ops.object.join()
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.42, depth=0.8)
    trou = bpy.context.active_object
    bo = g.modifiers.new("trou", 'BOOLEAN'); bo.object = trou; bo.operation = 'DIFFERENCE'
    bpy.context.view_layer.objects.active = g; bpy.ops.object.modifier_apply(modifier="trou")
    bpy.data.objects.remove(trou)
    bv = g.modifiers.new("b", 'BEVEL'); bv.width = 0.05; bv.segments = 3
    g.data.materials.clear(); g.data.materials.append(m); bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_torus_add(major_radius=0.62, minor_radius=0.05, location=(0, 0, 0.21))
    bpy.context.active_object.data.materials.append(neon)
    for o in bpy.context.scene.objects:
        if o.type == 'MESH': o.rotation_euler = (math.radians(62), 0, math.radians(12))
    ambiance_icone((0, 0, 0), 1.0)
    camera((0, -7, 0.4), (0, 0, 0), 50, ortho=3.1)
    rendre("icone_parametres")

def icone_boutique():
    scene_icone()
    m_or = mat("or", (1.0, 0.70, 0.12), 1.0, 0.2); m_bord = mat("bord", (1.0, 0.82, 0.35), 1.0, 0.15)
    sac = mat("sac", (0.42, 0.16, 0.7), 0.0, 0.5); corde = mat("corde", (1.0, 0.75, 0.2), 0.5, 0.35)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1.0, location=(0, 0, 0.95))
    s_ = bpy.context.active_object; s_.scale = (1.0, 0.9, 1.0); s_.data.materials.append(sac); bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.35, radius2=0.65, depth=0.6, location=(0, 0, 2.05))
    c = bpy.context.active_object; c.data.materials.append(sac); bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_torus_add(major_radius=0.38, minor_radius=0.08, location=(0, 0, 1.78))
    bpy.context.active_object.data.materials.append(corde)
    random.seed(2)
    for i in range(9):
        a = random.uniform(-2.6, -0.5); r = random.uniform(1.0, 1.6)
        piece("p%d" % i, (r * math.cos(a) * 0.9, r * math.sin(a) * 0.7, random.uniform(0.06, 0.6)),
              (random.uniform(-0.8, 0.8), random.uniform(-0.8, 0.8), 0), m_or, m_bord)
    ambiance_icone((0, 0, 0.9), 1.1)
    camera((2.6, -6.0, 2.6), (0, 0, 0.95), 50)
    rendre("icone_boutique")

def icone_quetes():
    scene_icone()
    papier = mat("papier", (0.95, 0.86, 0.62), 0.0, 0.6); bois = mat("bois", (0.35, 0.18, 0.08), 0.0, 0.5)
    sceau = mat("sceau", (0.85, 0.08, 0.1), 0.2, 0.35); encre = mat("encre", (0.25, 0.15, 0.1), 0, 0.8)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
    f = bpy.context.active_object; f.scale = (1.6, 2.0, 1)
    bpy.ops.object.transform_apply(scale=True)
    sub = f.modifiers.new("s", 'SUBSURF'); sub.levels = 3
    sol = f.modifiers.new("e", 'SOLIDIFY'); sol.thickness = 0.03
    f.data.materials.append(papier)
    for y in (-1.0, 1.0):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.2, depth=1.9, location=(0, y, 0.12), rotation=(0, math.radians(90), 0))
        bpy.context.active_object.data.materials.append(papier); bpy.ops.object.shade_smooth()
        for x in (-1, 1):
            bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.12, depth=0.25, location=(x * 1.05, y, 0.12), rotation=(0, math.radians(90), 0))
            bpy.context.active_object.data.materials.append(bois)
    for i in range(4):
        boite("ligne", (1.0 - 0.15 * (i % 2), 0.06, 0.01), (-0.05, -0.45 + i * 0.28, 0.02), encre, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.28, depth=0.08, location=(0.5, 0.55, 0.06))
    bpy.context.active_object.data.materials.append(sceau)
    for o in bpy.context.scene.objects:
        if o.type == 'MESH':
            o.matrix_world = Matrix.Rotation(math.radians(58), 4, 'X') @ Matrix.Rotation(math.radians(-14), 4, 'Z') @ o.matrix_world
    ambiance_icone((0, 0, 0), 1.0)
    camera((0, -7, 0.3), (0, 0, 0), 50, ortho=3.4)
    rendre("icone_quetes")

def icone_piece():
    scene_icone()
    m_or = mat("or", (1.0, 0.70, 0.12), 1.0, 0.2); m_bord = mat("bord", (1.0, 0.85, 0.4), 1.0, 0.15)
    piece("p", (0, 0, 0), (math.radians(80), 0, math.radians(14)), m_or, m_bord)
    etoile = [(0.0, 0.3), (0.07, 0.1), (0.29, 0.09), (0.11, -0.04), (0.18, -0.25), (0.0, -0.12), (-0.18, -0.25),
              (-0.11, -0.04), (-0.29, 0.09), (-0.07, 0.1)]
    e = prisme("etoile", etoile, 0.05, m_bord, 0.015)
    e.matrix_world = Matrix.Rotation(math.radians(14), 4, 'Z') @ Matrix.Rotation(math.radians(-10), 4, 'X') @ Matrix.Translation((0, -0.07, 0))
    lumiere("cle", 'AREA', (-2, -4, 3), 900, (1, 0.95, 0.85), 3, (0, 0, 0))
    lumiere("face", 'AREA', (1, -4, -1), 350, (1, 0.9, 0.7), 3, (0, 0, 0))
    lumiere("portail", 'AREA', (0, 4, 2), 600, (0.7, 0.4, 1.0), 3, (0, 0, 0))
    camera((0, -5, 0.3), (0, 0, 0), 50, ortho=1.25)
    rendre("icone_piece")

def icone_sprint():
    scene_icone()
    jaune = mat("jaune", (1.0, 0.8, 0.1), 0.2, 0.3, (1.0, 0.6, 0.05), 0.6)
    pts = [(0.15, 1.3), (-0.75, -0.05), (-0.1, -0.05), (-0.35, -1.3), (0.8, 0.25), (0.1, 0.25), (0.45, 1.3)]
    me = bpy.data.meshes.new("eclair")
    v = [(x, -0.18, z) for x, z in pts] + [(x, 0.18, z) for x, z in pts]
    n = len(pts)
    faces = [list(range(n))[::-1], list(range(n, 2 * n))] + [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    me.from_pydata(v, [], faces); me.update()
    o = bpy.data.objects.new("eclair", me); bpy.context.scene.collection.objects.link(o)
    bv = o.modifiers.new("b", 'BEVEL'); bv.width = 0.06; bv.segments = 3
    o.data.materials.append(jaune)
    o.rotation_euler = (0, math.radians(-12), math.radians(-18))
    ambiance_icone((0, 0, 0), 1.0)
    camera((0, -6, 0.2), (0, 0, 0), 50, ortho=3.0)
    rendre("icone_sprint")

def prisme(nom, pts, ep, materiau, biseau=0.05):
    """Forme 2D (x, z) extrudée sur Y."""
    me = bpy.data.meshes.new(nom)
    n = len(pts)
    v = [(x, -ep / 2, z) for x, z in pts] + [(x, ep / 2, z) for x, z in pts]
    faces = [list(range(n))[::-1], list(range(n, 2 * n))] + [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    me.from_pydata(v, [], faces); me.update()
    o = bpy.data.objects.new(nom, me); bpy.context.scene.collection.objects.link(o)
    if biseau:
        bv = o.modifiers.new("b", 'BEVEL'); bv.width = biseau; bv.segments = 3
    o.data.materials.append(materiau)
    return o

def icone_esquive():
    """Double chevron qui file vers la droite + traits de vitesse."""
    scene_icone()
    cyan = mat("cyan", (0.35, 0.85, 1.0), 0.1, 0.3, (0.2, 0.6, 1.0), 0.7)
    blanc = mat("blanc", (0.85, 0.95, 1.0), 0.1, 0.3, (0.6, 0.85, 1.0), 0.5)
    chevron = [(-0.35, 0.9), (0.15, 0.9), (0.75, 0.0), (0.15, -0.9), (-0.35, -0.9), (0.25, 0.0)]
    prisme("c1", [(x - 0.55, z) for x, z in chevron], 0.4, cyan)
    prisme("c2", [(x + 0.35, z) for x, z in chevron], 0.4, cyan)
    for z, l in ((0.45, 0.9), (0.0, 1.3), (-0.45, 0.9)):
        prisme("trait", [(-1.25 - l, z + 0.07), (-1.15, z + 0.07), (-1.15, z - 0.07), (-1.25 - l, z - 0.07)], 0.12, blanc, 0.03)
    for o in bpy.context.scene.objects:
        if o.type == 'MESH': o.rotation_euler = (0, math.radians(-8), math.radians(-14))
    ambiance_icone((0, 0, 0), 1.0)
    camera((0, -6, 0.3), (-0.4, 0, 0), 50, ortho=3.6)
    rendre("icone_esquive")

def icone_frapper():
    scene_icone()
    k = importer_couteau("RenardBase", 3.0, sans_contour=True)
    k.rotation_euler = (0, math.radians(40), 0)              # lame vers le haut-droit
    k.location = (-1.5 * math.sin(math.radians(40)), 0, -1.5 * math.cos(math.radians(40)))
    ambiance_icone((0, 0, 0), 1.0)
    camera((0, -9, 0.3), (0, 0, 0.0), 50, ortho=3.2)
    rendre("icone_frapper")

ICONES = (icone_caisse, icone_couteaux, icone_parametres, icone_boutique, icone_quetes, icone_piece,
          icone_sprint, icone_esquive, icone_frapper, icone_cadeau, icone_trophee)

# ------------------------------------------------------------------ coffres détaillés (boutique / ouverture)
COFFRES = {
    #              métal (accents)        runes / lumière          couteau
    "Poules":     dict(metal=(0.75, 0.08, 0.06), rune=(1.0, 0.25, 0.1), couteau="PouleRoyal"),
    "Renards":    dict(metal=(0.95, 0.38, 0.08), rune=(1.0, 0.55, 0.1), couteau="RenardLegendaire"),
    "Viperes":    dict(metal=(0.12, 0.55, 0.12), rune=(0.4, 1.0, 0.2), couteau="ViperRoyal"),
    "Legendaire": dict(metal=(1.0, 0.72, 0.15), rune=(1.0, 0.85, 0.35), couteau="PouleGeant"),
}

def materiau_bois(nom):
    """Bois sombre en planches (bandes + fentes + grain)."""
    m = bpy.data.materials.new(nom); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    onde = nt.nodes.new("ShaderNodeTexWave"); onde.wave_type = 'BANDS'; onde.bands_direction = 'Z'
    onde.inputs["Scale"].default_value = 2.2; onde.inputs["Distortion"].default_value = 0.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.03; ramp.color_ramp.elements[0].color = (0.015, 0.008, 0.006, 1)
    ramp.color_ramp.elements[1].position = 0.09; ramp.color_ramp.elements[1].color = (0.13, 0.06, 0.03, 1)
    grain = nt.nodes.new("ShaderNodeTexNoise"); grain.inputs["Scale"].default_value = 40; grain.inputs["Detail"].default_value = 6
    mixr = nt.nodes.new("ShaderNodeMix"); mixr.data_type = 'RGBA'; mixr.blend_type = 'MULTIPLY'; mixr.inputs[0].default_value = 0.35
    nt.links.new(tc.outputs["Object"], onde.inputs["Vector"]); nt.links.new(onde.outputs["Fac"], ramp.inputs[0])
    nt.links.new(tc.outputs["Object"], grain.inputs["Vector"])
    nt.links.new(ramp.outputs[0], mixr.inputs[6]); nt.links.new(grain.outputs["Color"], mixr.inputs[7])
    nt.links.new(mixr.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.55
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.35
    nt.links.new(onde.outputs["Fac"], bump.inputs["Height"]); nt.links.new(bump.outputs[0], b.inputs["Normal"])
    return m

def coffre(equipe, ouverture=0.0, sc=None):
    """Coffre au trésor détaillé. ouverture : 0 fermé -> 1 grand ouvert (lumière + couteau qui monte)."""
    e = COFFRES[equipe]
    bois = materiau_bois("bois_" + equipe)
    fer = mat("fer", (0.06, 0.06, 0.07), 0.9, 0.35)
    accent = mat("accent", e["metal"], 1.0, 0.25)
    orm = mat("or", (1.0, 0.72, 0.18), 1.0, 0.2)
    rune = mat("rune", e["rune"], 0, 0.3, e["rune"], 6 + 14 * ouverture)
    interieur = mat("interieur", (0.02, 0.01, 0.03), 0, 0.8, e["rune"], 2 + 25 * ouverture)
    L, P, H, R = 2.6, 1.7, 1.25, 0.85
    objs = []
    def ajoute(o): objs.append(o); return o
    # caisse (creuse) avec bords biseautés
    for nom, t, pos in (("fond", (L, P, 0.16), (0, 0, 0.08)), ("av", (L, 0.16, H), (0, -P / 2 + 0.08, H / 2)),
                        ("ar", (L, 0.16, H), (0, P / 2 - 0.08, H / 2)), ("g", (0.16, P, H), (-L / 2 + 0.08, 0, H / 2)),
                        ("d", (0.16, P, H), (L / 2 - 0.08, 0, H / 2))):
        ajoute(boite(nom, t, pos, bois, 0.03))
    ajoute(boite("dedans", (L - 0.32, P - 0.32, 0.04), (0, 0, H - 0.18), interieur, 0))
    # sangles de fer + rivets
    for x in (-0.82, 0.82):
        ajoute(boite("sangle", (0.2, P + 0.06, H + 0.04), (x, 0, H / 2), fer, 0.02))
        for z in (0.25, 0.65, 1.05):
            for y in (-P / 2 - 0.04, P / 2 + 0.04):
                bpy.ops.mesh.primitive_uv_sphere_add(radius=0.045, location=(x, y, z)); r = bpy.context.active_object
                r.data.materials.append(orm); bpy.ops.object.shade_smooth(); ajoute(r)
    ajoute(boite("ceinture", (L + 0.06, P + 0.06, 0.14), (0, 0, 0.16), accent, 0.03))
    ajoute(boite("ceinture2", (L + 0.06, P + 0.06, 0.12), (0, 0, H - 0.06), accent, 0.03))
    # coins dorés
    for x in (-1, 1):
        for y in (-1, 1):
            for z in (0.12, H - 0.12):
                ajoute(boite("coin", (0.26, 0.26, 0.26), (x * (L / 2 - 0.05), y * (P / 2 - 0.05), z), orm, 0.06))
    # emblème lumineux en losange (contour + point central) de chaque côté de la serrure
    r_l = 0.15
    for cx in (-0.45, 0.45):
        for sx in (-1, 1):
            for sz in (-1, 1):
                rot_y = math.radians(45 if sx * sz > 0 else -45)
                ajoute(boite("rune", (r_l * 1.414, 0.02, 0.03), (cx + sx * r_l / 2, -P / 2 - 0.005, 0.62 + sz * r_l / 2), rune, 0, (0, rot_y, 0)))
        ajoute(boite("rune_c", (0.06, 0.02, 0.06), (cx, -P / 2 - 0.005, 0.62), rune, 0, (0, math.radians(45), 0)))
    # serrure (plaque + anneau) aux couleurs
    ajoute(boite("plaque", (0.5, 0.08, 0.55), (0, -P / 2 - 0.04, H - 0.3), orm, 0.05))
    ajoute(boite("trou", (0.12, 0.02, 0.2), (0, -P / 2 - 0.085, H - 0.35), rune, 0))
    # couvercle bombé (demi-cylindre) articulé à l'arrière
    pivot = bpy.data.objects.new("pivot", None); bpy.context.scene.collection.objects.link(pivot)
    pivot.location = (0, P / 2, H)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=R, depth=L, location=(0, 0, 0), rotation=(0, math.radians(90), 0))
    c = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    bm = bmesh.new(); bm.from_mesh(c.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0), plane_no=(0, 0, -1), clear_outer=True)
    bmesh.ops.contextual_create(bm, geom=[ed for ed in bm.edges if ed.is_boundary])
    bm.to_mesh(c.data); bm.free()
    c.scale = (1, P / (2 * R), 0.62); bpy.ops.object.transform_apply(scale=True)
    bv = c.modifiers.new("b", 'BEVEL'); bv.width = 0.03; bv.segments = 2
    c.data.materials.append(bois); bpy.ops.object.shade_smooth()
    c.location = (0, -P / 2, 0); c.parent = pivot; ajoute(c)
    for x in (-0.82, 0.82):
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=R + 0.04, depth=0.2, location=(0, 0, 0), rotation=(0, math.radians(90), 0))
        sg = bpy.context.active_object
        bpy.ops.object.transform_apply(rotation=True)
        bm = bmesh.new(); bm.from_mesh(sg.data)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0), plane_no=(0, 0, -1), clear_outer=True)
        bm.to_mesh(sg.data); bm.free()
        sg.scale = (1, (P + 0.08) / (2 * R + 0.08), 0.64); bpy.ops.object.transform_apply(scale=True)
        bmesh_ok = True
        sg.data.materials.append(fer); bpy.ops.object.shade_smooth()
        sg.location = (x, -P / 2, 0); sg.parent = pivot; ajoute(sg)
    lid_r = ajoute(boite("bord_couv", (L + 0.06, P + 0.06, 0.1), (0, -P / 2, 0.05), accent, 0.03)); lid_r.parent = pivot
    for x in (-1, 1):
        g = ajoute(boite("coin_couv", (0.26, P + 0.08, 0.24), (x * (L / 2 - 0.05), -P / 2, 0.14), orm, 0.06)); g.parent = pivot
    r2 = ajoute(boite("rune_couv", (1.0, 0.03, 0.04), (0, -P - 0.005, 0.3), rune, 0)); r2.parent = pivot
    pivot.rotation_euler = (math.radians(-108 * ouverture), 0, 0)
    # lumière qui sort + faisceau + couteau qui monte
    if ouverture > 0:
        lumiere("coeur", 'POINT', (0, 0, H + 0.2), 100 + 900 * ouverture, e["rune"])
        bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.95, radius2=1.8, depth=3.2, location=(0, 0, H + 1.6))
        f = bpy.context.active_object
        fm = bpy.data.materials.new("faisceau"); fm.use_nodes = True
        nt = fm.node_tree; out = nt.nodes["Material Output"]
        em = nt.nodes.new("ShaderNodeEmission"); em.inputs["Color"].default_value = (*e["rune"], 1); em.inputs["Strength"].default_value = 2.5 * ouverture
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (0.75, 0.75, 0.75, 1); ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
        mx = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(tc.outputs["Generated"], sep.inputs[0]); nt.links.new(sep.outputs["Z"], ramp.inputs[0])
        nt.links.new(ramp.outputs[0], mx.inputs[0]); nt.links.new(em.outputs[0], mx.inputs[1]); nt.links.new(tr.outputs[0], mx.inputs[2])
        nt.links.new(mx.outputs[0], out.inputs["Surface"])
        fm.blend_method = 'BLEND' if hasattr(fm, "blend_method") else None
        f.data.materials.append(fm); f.visible_shadow = False
        if ouverture > 0.45:
            k = importer_couteau(e["couteau"], 2.4, sans_contour=True)
            monte = (ouverture - 0.45) / 0.55
            k.location = (0, 0, H - 1.2 + 2.0 * monte)
            k.rotation_euler = (0, math.radians(14), math.radians(25 * monte))
        random.seed(3)
        etin = mat("etin", e["rune"], 0, 0.3, e["rune"], 25)
        for i in range(int(22 * ouverture)):
            a = random.uniform(0, 2 * math.pi); rr = random.uniform(0.3, 1.4)
            bpy.ops.mesh.primitive_ico_sphere_add(radius=random.uniform(0.02, 0.05), subdivisions=1,
                                                  location=(rr * math.cos(a), rr * math.sin(a) * 0.6, H + random.uniform(0.2, 2.6) * ouverture))
            bpy.context.active_object.data.materials.append(etin)
    return objs

def coffre_scene(equipe, ouverture, res=768, angle=0.0, nom=None):
    sc = scene_icone()
    sc.render.resolution_x = sc.render.resolution_y = res
    coffre(equipe, ouverture)
    ambiance_icone((0, 0, 1.0), 1.25)
    e = COFFRES[equipe]
    lumiere("contre_equipe", 'AREA', (3.5, 4.5, 3.5), 900, e["rune"], 3, (0, 0, 1))
    d = 7.6
    a = math.radians(-32 + angle)
    camera((d * math.sin(a), -d * math.cos(a), 4.6), (0, 0, 1.35 + 0.4 * ouverture), 50)
    rendre(nom or ("coffre_%s" % equipe))

def planche_sprites(prefixe, n, sortie, taille=256):
    """Assemble n images <prefixe>_00.png… en planche 4x4 (1024 px) pour Roblox (ImageRectOffset)."""
    from PIL import Image as PImage
    cote = int(math.ceil(math.sqrt(n)))
    planche = PImage.new("RGBA", (cote * taille, cote * taille), (0, 0, 0, 0))
    for i in range(n):
        im = PImage.open(os.path.join(SORTIE, "%s_%02d.png" % (prefixe, i))).convert("RGBA").resize((taille, taille), PImage.LANCZOS)
        planche.paste(im, ((i % cote) * taille, (i // cote) * taille))
    planche.save(os.path.join(SORTIE, sortie))

def coffres_complets(equipes=None):
    for eq in (equipes or COFFRES):
        coffre_scene(eq, 0.0, 768, 0, "coffre_%s" % eq)                 # vitrine fermée
        coffre_scene(eq, 1.0, 768, 0, "coffre_%s_ouvert" % eq)          # vitrine ouverte
        for i in range(16):                                              # rotation sur lui-même
            coffre_scene(eq, 0.0, 256, i * 360 / 16, "rot_%s_%02d" % (eq, i))
        for i in range(16):                                              # ouverture (0 -> 1, avec accélération)
            x = i / 15
            coffre_scene(eq, x * x * (3 - 2 * x), 256, 0, "ouv_%s_%02d" % (eq, i))
        planche_sprites("rot_%s" % eq, 16, "coffre_%s_rotation.png" % eq)
        planche_sprites("ouv_%s" % eq, 16, "coffre_%s_ouverture.png" % eq)

TOUT = {"caisses": lambda: [caisse(e) for e in EQUIPES], "pieces": lambda: [pieces(n) for n in (1, 2, 3)],
        "icones": lambda: (icone_engrenage(), icone_trophee(), icone_cadeau()),
        "chargement": lambda: (fond_ciel(), avant_plan(), logo()), "ciel": fond_ciel, "avant": avant_plan, "logo": logo, "logo_scene": logo_scene, "eclats": eclats,
        "icones_ui": lambda: [f() for f in ICONES], "coffres": coffres_complets,
        "coffre_test": lambda: (coffre_scene("Renards", 0.0, 512, 0, "test_ferme"), coffre_scene("Renards", 1.0, 512, 0, "test_ouvert"))}
for k in (QUOI or TOUT.keys()):
    if k in TOUT: TOUT[k]()
    elif k in EQUIPES: caisse(k)
