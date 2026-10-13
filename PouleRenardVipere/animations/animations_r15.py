# =====================================================================
#  POULE RENARD VIPÈRE — Animations R15 (Blender 4.4+ / 5.x)
# ---------------------------------------------------------------------
#  Ce script :
#    1. construit un squelette R15 identique à Roblox : un os par pièce
#       (LowerTorso, UpperTorso, Head, RightUpperArm…), pivots aux articulations,
#       axes des os = axes Roblox -> les rotations Blender = les Motor6D Roblox ;
#    2. crée les animations (Actions) image par image : anticipation, impact,
#       follow-through, retour ; jambes calculées en IK (pieds posés au sol) ;
#    3. exporte un script Lua qui recrée les animations dans Studio
#       (KeyframeSequence prêtes à publier) -> aucun souci d'import FBX ;
#    4. (option) rend des aperçus.
#
#  Dans Blender : onglet Scripting > ouvrir > ▶ Run. Pour modifier une animation,
#  change ses poses dans ANIMS ci-dessous (ou retouche l'Action dans le Dope Sheet),
#  puis relance seulement l'export : exporter_lua(chemin).
#
#  Repère (comme Roblox) : X = droite du perso, Y = haut, Z = arrière (le perso regarde -Z).
#  Rotations en degrés, ordre Euler XYZ :
#    X+ = vers l'avant (bras qui se lève devant, buste/tête/bassin qui se penchent, cuisse qui monte)
#    Y+ = tourner vers la gauche          Z+ = vers la droite du perso (bras droit qui s'écarte)
#  (pour LowerTorso / UpperTorso / Head, qui pointent vers le haut, le script inverse X et Z
#   tout seul afin que « + = avant / droite » reste vrai partout)
# =====================================================================
import bpy, math, os, json
from mathutils import Vector, Matrix, Euler, Quaternion

FPS = 60
EXPORT_FPS = 30               # images par seconde dans les KeyframeSequence Roblox

# ------------------------------------------------------------------ squelette R15
# nom de l'os = nom de la pièce Roblox ; parent ; pivot (articulation) ; taille et centre de la pièce
# (coordonnées Roblox, pieds au sol y = 0)
R15 = {
    #  nom              parent           pivot                 centre pièce          taille
    "LowerTorso":    (None,            (0, 2.9, 0),          (0, 2.9, 0),          (2, 0.4, 1)),
    "UpperTorso":    ("LowerTorso",    (0, 3.1, 0),          (0, 3.9, 0),          (2, 1.6, 1)),
    "Head":          ("UpperTorso",    (0, 4.7, 0),          (0, 5.3, 0),          (1.2, 1.2, 1.2)),
    "RightUpperArm": ("UpperTorso",    (1.5, 4.45, 0),       (1.5, 4.1, 0),        (1, 1.2, 1)),
    "RightLowerArm": ("RightUpperArm", (1.5, 3.5, 0),        (1.5, 2.98, 0),       (1, 1.05, 1)),
    "RightHand":     ("RightLowerArm", (1.5, 2.45, 0),       (1.5, 2.3, 0),        (1, 0.3, 1)),
    "LeftUpperArm":  ("UpperTorso",    (-1.5, 4.45, 0),      (-1.5, 4.1, 0),       (1, 1.2, 1)),
    "LeftLowerArm":  ("LeftUpperArm",  (-1.5, 3.5, 0),       (-1.5, 2.98, 0),      (1, 1.05, 1)),
    "LeftHand":      ("LeftLowerArm",  (-1.5, 2.45, 0),      (-1.5, 2.3, 0),       (1, 0.3, 1)),
    "RightUpperLeg": ("LowerTorso",    (0.5, 2.7, 0),        (0.5, 2.1, 0),        (1, 1.2, 1)),
    "RightLowerLeg": ("RightUpperLeg", (0.5, 1.5, 0),        (0.5, 0.9, 0),        (1, 1.2, 1)),
    "RightFoot":     ("RightLowerLeg", (0.5, 0.3, 0),        (0.5, 0.15, -0.1),    (1, 0.3, 1.2)),
    "LeftUpperLeg":  ("LowerTorso",    (-0.5, 2.7, 0),       (-0.5, 2.1, 0),       (1, 1.2, 1)),
    "LeftLowerLeg":  ("LeftUpperLeg",  (-0.5, 1.5, 0),       (-0.5, 0.9, 0),       (1, 1.2, 1)),
    "LeftFoot":      ("LeftLowerLeg",  (-0.5, 0.3, 0),       (-0.5, 0.15, -0.1),   (1, 0.3, 1.2)),
}
HAUT = ["UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperArm", "LeftLowerArm", "LeftHand"]
TOUT = list(R15.keys())
VERS_LE_HAUT = ("LowerTorso", "UpperTorso", "Head")    # os orientés vers le haut
CUISSE, GENOU = 1.2, 1.2      # longueurs hanche->genou, genou->cheville

def rb(v):
    """Roblox (x, y, z) -> Blender (x, -z, y)"""
    return Vector((v[0], -v[2], v[1]))

# ------------------------------------------------------------------ IK des jambes
def ik_jambe(cote, root_pos, root_pitch, pied, pied_pitch=0.0):
    """Angles (hanche, genou, cheville) en X pour poser la cheville au point `pied` (y, z),
    racine déplacée de root_pos et penchée de root_pitch (degrés). Plan sagittal."""
    rp = math.radians(-root_pitch)                      # angle brut Roblox (Rx) de la racine
    # hanche = pivot racine (y 2.9) + (0, -0.2, 0) tourné par l'inclinaison de la racine
    hy = 2.9 + root_pos[1] - 0.2 * math.cos(rp)
    hz = root_pos[2] - 0.2 * math.sin(rp)
    # cible relative à la hanche
    dy, dz = pied[0] - hy, pied[1] - hz
    d = min(math.hypot(dy, dz), CUISSE + GENOU - 1e-3)
    # angle de la direction hanche->cheville par rapport à « vers le bas », positif vers l'avant (-Z)
    a_dir = math.atan2(-dz, -dy)
    a_gen = math.acos(max(-1, min(1, (CUISSE**2 + GENOU**2 - d*d) / (2 * CUISSE * GENOU))))
    a_cui = math.acos(max(-1, min(1, (CUISSE**2 + d*d - GENOU**2) / (2 * CUISSE * d))))
    hanche = math.degrees(a_dir + a_cui) + root_pitch
    genou = -(180 - math.degrees(a_gen))
    cheville = -(hanche + genou - root_pitch) + pied_pitch
    return hanche, genou, cheville

def jambes(root_pos, root_pitch, droite, gauche, pd=0.0, pg=0.0, ecart=4):
    """droite/gauche = position de la cheville (y, z) en coordonnées Roblox."""
    h, g, c = ik_jambe(1, root_pos, root_pitch, droite, pd)
    h2, g2, c2 = ik_jambe(-1, root_pos, root_pitch, gauche, pg)
    return {"RightUpperLeg": (h, 0, ecart), "RightLowerLeg": (g, 0, 0), "RightFoot": (c, 0, -ecart),
            "LeftUpperLeg": (h2, 0, -ecart), "LeftLowerLeg": (g2, 0, 0), "LeftFoot": (c2, 0, ecart)}

def jambes3(root_pos, root_rot, droite, gauche):
    """IK complète des jambes en 3D. root_rot = (penché avant, tourné gauche, penché droite) en degrés ;
    droite/gauche = position (x, y, z) de la cheville en coordonnées Roblox (sol : y = 0.3)."""
    pitch, yaw, roll = root_rot
    R = Euler((math.radians(-pitch), math.radians(yaw), math.radians(-roll)), 'XYZ').to_matrix()
    pivot = Vector((0, 2.9, 0)) + Vector(root_pos)
    out = {}
    for cote, pied, x in (("Right", droite, 0.5), ("Left", gauche, -0.5)):
        hanche = pivot + R @ Vector((x, -0.2, 0))
        dl = R.inverted() @ (Vector(pied) - hanche)
        L = min(dl.length, CUISSE + GENOU - 1e-3)
        tz = math.atan2(dl.x, -dl.y)
        a_dir = math.atan2(-dl.z, math.hypot(dl.x, dl.y))
        a_gen = math.acos(max(-1, min(1, (CUISSE**2 + GENOU**2 - L*L) / (2 * CUISSE * GENOU))))
        a_cui = math.acos(max(-1, min(1, (CUISSE**2 + L*L - GENOU**2) / (2 * CUISSE * L))))
        hx = math.degrees(a_dir + a_cui)
        gx = -(180 - math.degrees(a_gen))
        out[cote + "UpperLeg"] = (hx, 0, math.degrees(tz))
        out[cote + "LowerLeg"] = (gx, 0, 0)
        out[cote + "Foot"] = (-(hx + gx) + pitch, 0, -math.degrees(tz) + roll)
    return out

# ------------------------------------------------------------------ poses de base
GARDE = {   # couteau prêt, lame vers le haut devant le torse
    "UpperTorso": (8, 14, 0), "Head": (-6, -12, 0),
    "RightUpperArm": (36, 8, 22), "RightLowerArm": (78, 0, 0), "RightHand": (-12, 0, 0),
    "LeftUpperArm": (38, -6, -22), "LeftLowerArm": (78, 0, 0), "LeftHand": (0, 0, 0),
}

def P(base, **kw):
    """Copie d'une pose avec modifications : P(GARDE, RightUpperArm=(90,0,0))."""
    p = dict(base)
    for k, v in kw.items():
        p[k] = v
    return p

def full(pose, root=(0, 0, 0), rootrot=(0, 0, 0)):
    p = dict(pose)
    p["LowerTorso"] = (rootrot, root)
    return p

# --------------------------------------------------------- les animations
# Chaque clé : (temps en s, pose, interpolation vers la clé suivante)
# interpolations : "SINE_OUT", "SINE_INOUT", "EXPO_IN", "EXPO_OUT", "QUART_OUT", "BACK_OUT", "CUBIC_INOUT", "LINEAR"
def anim_coup1():
    """Taille horizontale de droite à gauche."""
    arme = P(GARDE,
             UpperTorso=(6, -38, -4), Head=(-4, 30, 0),
             RightUpperArm=(74, -62, 0), RightLowerArm=(48, 0, 0), RightHand=(-35, 25, 0),
             LeftUpperArm=(55, 25, -10), LeftLowerArm=(60, 0, 0))
    impact = P(GARDE,
               UpperTorso=(10, 12, 0), Head=(-6, -10, 0),
               RightUpperArm=(90, 8, 4), RightLowerArm=(8, 0, 0), RightHand=(-80, 0, 0),
               LeftUpperArm=(25, -10, -30), LeftLowerArm=(40, 0, 0))
    suite = P(GARDE,
              UpperTorso=(12, 48, 4), Head=(-6, -38, 0),
              RightUpperArm=(78, 82, 0), RightLowerArm=(30, 0, 0), RightHand=(-80, -30, 0),
              LeftUpperArm=(-15, -10, -35), LeftLowerArm=(25, 0, 0))
    return dict(nom="Coup1", os=HAUT, boucle=False, priorite="Action2", cles=[
        (0.00, GARDE, "SINE_OUT"),
        (0.09, arme, "EXPO_IN"),
        (0.16, impact, "LINEAR"),
        (0.21, suite, "QUART_OUT"),
        (0.30, P(suite, UpperTorso=(12, 52, 4)), "SINE_INOUT"),
        (0.52, GARDE, "LINEAR"),
    ])

def anim_coup2():
    """Revers en diagonale : armé au-dessus de l'épaule gauche, frappe vers le bas-droite."""
    arme = P(GARDE,
             UpperTorso=(0, 42, 6), Head=(-4, -34, 0),
             RightUpperArm=(118, 78, 0), RightLowerArm=(100, 0, 0), RightHand=(-10, 0, -30),
             LeftUpperArm=(15, -10, -35), LeftLowerArm=(40, 0, 0))
    impact = P(GARDE,
               UpperTorso=(14, 4, 0), Head=(-10, -4, 0),
               RightUpperArm=(88, 12, 0), RightLowerArm=(12, 0, 0), RightHand=(-85, 0, 0),
               LeftUpperArm=(45, -15, -25), LeftLowerArm=(70, 0, 0))
    suite = P(GARDE,
              UpperTorso=(22, -42, -6), Head=(-14, 34, 0),
              RightUpperArm=(52, -72, 10), RightLowerArm=(8, 0, 0), RightHand=(-75, 0, 25),
              LeftUpperArm=(70, 25, -15), LeftLowerArm=(70, 0, 0))
    return dict(nom="Coup2", os=HAUT, boucle=False, priorite="Action2", cles=[
        (0.00, GARDE, "SINE_OUT"),
        (0.10, arme, "EXPO_IN"),
        (0.17, impact, "LINEAR"),
        (0.22, suite, "QUART_OUT"),
        (0.32, P(suite, UpperTorso=(24, -46, -6)), "SINE_INOUT"),
        (0.55, GARDE, "LINEAR"),
    ])

def anim_coup3():
    """Estoc : on se ramasse, puis fente en avant bras tendu (corps entier)."""
    sol = 0.3                                                   # hauteur de la cheville au repos
    def pose(haut, root, pitch, pd, pg, pdp=0, pgp=0):
        p = full(haut, root, (pitch, 0, 0))
        p.update(jambes(root, pitch, pd, pg, pdp, pgp))
        return p
    debut = pose(GARDE, (0, -0.15, 0), 0, (sol, 0.0), (sol, 0.0))
    arme = pose(P(GARDE,
                  UpperTorso=(0, -32, 0), Head=(0, 28, 0),
                  RightUpperArm=(25, -15, 25), RightLowerArm=(115, 0, 0), RightHand=(-5, 0, 0),
                  LeftUpperArm=(80, 10, -10), LeftLowerArm=(30, 0, 0)),
                (0, -0.55, 0.35), -6, (sol, 0.25), (sol, 0.45))
    fente = pose(P(GARDE,
                   UpperTorso=(18, 26, 0), Head=(-20, -22, 0),
                   RightUpperArm=(118, 18, 6), RightLowerArm=(0, 0, 0), RightHand=(-92, 0, 0),
                   LeftUpperArm=(-50, 15, -30), LeftLowerArm=(20, 0, 0)),
                 (0, -0.85, -1.0), 12, (sol, -2.0), (sol, 0.6), 0, 25)
    tenue = pose(P(GARDE,
                   UpperTorso=(20, 28, 0), Head=(-22, -24, 0),
                   RightUpperArm=(122, 20, 6), RightLowerArm=(0, 0, 0), RightHand=(-94, 0, 0),
                   LeftUpperArm=(-55, 15, -32), LeftLowerArm=(22, 0, 0)),
                 (0, -0.9, -1.05), 14, (sol, -2.0), (sol, 0.6), 0, 25)
    fin = pose(GARDE, (0, -0.15, 0), 0, (sol, 0.0), (sol, 0.0))
    return dict(nom="Coup3", os=TOUT, boucle=False, priorite="Action2", cles=[
        (0.00, debut, "SINE_OUT"),
        (0.13, arme, "EXPO_IN"),
        (0.22, fente, "QUART_OUT"),
        (0.36, tenue, "CUBIC_INOUT"),
        (0.62, fin, "LINEAR"),
    ])

def _pose_esq(haut, root, rot, droite, gauche):
    p = full(haut, root, rot)
    p.update(jambes3(root, rot, droite, gauche))
    return p

def anim_esquive_cote(s):
    """Saut d'esquive sur le côté (s = +1 droite, -1 gauche), corps entier, 0,5 s.
    Charge sur les jambes, bond latéral penché dans la direction, réception basse et large."""
    nom = "EsquiveDroite" if s > 0 else "EsquiveGauche"
    sol = 0.3
    def pieds(dx_lead, y_lead, dx_trail, y_trail, z_trail=0.0):
        lead, trail = (dx_lead * s, y_lead, 0.0), (dx_trail * s, y_trail, z_trail)
        return (lead, trail) if s > 0 else (trail, lead)          # (droite, gauche)
    def bras(cote_dehors, x, z, coude):
        """bras côté esquive écarté pour l'équilibre ; le couteau reste en garde s'il est de l'autre côté."""
        if s > 0:   # bras droit (couteau) dehors, bras gauche replié
            return {"RightUpperArm": (x, 0, z), "RightLowerArm": (coude, 0, 0), "RightHand": (-20, 0, 0),
                    "LeftUpperArm": (35, -10, -25), "LeftLowerArm": (60, 0, 0), "LeftHand": (0, 0, 0)}
        return {"LeftUpperArm": (x, 0, -z), "LeftLowerArm": (coude, 0, 0), "LeftHand": (0, 0, 0),
                "RightUpperArm": (42, 8, 15), "RightLowerArm": (82, 0, 0), "RightHand": (-12, 0, 0)}
    def haut(torse, tete, *b):
        h = {"UpperTorso": torse, "Head": tete}
        h.update(bras(*b))
        return h
    k0 = _pose_esq(GARDE, (0, -0.25, 0), (5, 0, 0), *pieds(0.6, sol, -0.6, sol))
    k1 = _pose_esq(P(GARDE, UpperTorso=(15, 0, -5 * s), Head=(-8, 0, 5 * s)),
                   (-0.15 * s, -0.6, 0), (12, 0, -8 * s), *pieds(0.6, sol, -0.7, sol))
    k2 = _pose_esq(haut((14, 0, 8 * s), (-6, 0, -26 * s), True, 20, 95, 20),
                   (0.25 * s, -0.15, 0), (10, 0, 24 * s), *pieds(1.15, 0.85, -0.25, 0.75, 0.1))
    k3 = _pose_esq(haut((18, 0, 6 * s), (-10, 0, -18 * s), True, 25, 65, 30),
                   (0.2 * s, -0.9, 0), (16, 0, 12 * s), *pieds(1.25, sol, -0.55, sol, 0.15))
    k4 = _pose_esq(haut((16, 0, 4 * s), (-10, 0, -12 * s), True, 32, 40, 40),
                   (0.15 * s, -0.82, 0), (14, 0, 8 * s), *pieds(1.25, sol, -0.55, sol, 0.15))
    k5 = _pose_esq(GARDE, (0.05 * s, -0.3, 0), (5, 0, 2 * s), *pieds(0.85, sol, -0.45, sol, 0.05))
    return dict(nom=nom, os=TOUT, boucle=False, priorite="Action3", cles=[
        (0.00, k0, "SINE_OUT"), (0.05, k1, "QUART_OUT"), (0.12, k2, "SINE_INOUT"),
        (0.20, k3, "QUART_OUT"), (0.30, k4, "SINE_INOUT"), (0.50, k5, "LINEAR"),
    ])

def anim_esquive_droite(): return anim_esquive_cote(1)
def anim_esquive_gauche(): return anim_esquive_cote(-1)

def anim_esquive_arriere():
    """Saut en arrière : charge, bond vers l'arrière bras devant, réception en fente basse."""
    sol = 0.3
    devant = P(GARDE, LeftUpperArm=(60, -10, -20), LeftLowerArm=(40, 0, 0))
    k0 = _pose_esq(GARDE, (0, -0.25, 0), (5, 0, 0), (0.6, sol, 0), (-0.6, sol, 0))
    k1 = _pose_esq(P(GARDE, UpperTorso=(14, 10, 0)), (0, -0.6, -0.1), (15, 0, 0), (0.6, sol, 0), (-0.6, sol, 0))
    k2 = _pose_esq(P(devant, UpperTorso=(6, 8, 0), Head=(6, -8, 0)),
                   (0, -0.15, 0.35), (-12, 0, 0), (0.6, 0.9, -0.45), (-0.6, 0.75, -0.2))
    k3 = _pose_esq(P(devant, UpperTorso=(16, 12, 0), Head=(-14, -10, 0)),
                   (0, -0.9, 0.3), (18, 0, 0), (0.65, sol, -0.75), (-0.6, sol, 0.6))
    k4 = _pose_esq(P(devant, UpperTorso=(14, 12, 0), Head=(-12, -10, 0)),
                   (0, -0.8, 0.25), (14, 0, 0), (0.65, sol, -0.75), (-0.6, sol, 0.6))
    k5 = _pose_esq(GARDE, (0, -0.3, 0.05), (5, 0, 0), (0.6, sol, -0.35), (-0.6, sol, 0.25))
    return dict(nom="EsquiveArriere", os=TOUT, boucle=False, priorite="Action3", cles=[
        (0.00, k0, "SINE_OUT"), (0.05, k1, "QUART_OUT"), (0.13, k2, "SINE_INOUT"),
        (0.21, k3, "QUART_OUT"), (0.32, k4, "SINE_INOUT"), (0.48, k5, "LINEAR"),
    ])

def anim_course():
    """Sprint (boucle de 0,6 s)."""
    sol = 0.3
    def pas(phase, haut_y, d, g, pd_pitch, pg_pitch, bras):
        root = (0, haut_y, 0)
        p = full({
            "UpperTorso": (16, -6 * bras, 0), "Head": (-12, 6 * bras, 0),
            "RightUpperArm": (-45 * bras + 10, 0, 8), "RightLowerArm": (70 + 25 * max(bras, 0), 0, 0), "RightHand": (0, 0, 0),
            "LeftUpperArm": (45 * bras + 10, 0, -8), "LeftLowerArm": (70 + 25 * max(-bras, 0), 0, 0), "LeftHand": (0, 0, 0),
        }, root, (10, 7 * bras, 0))
        p.update(jambes(root, 10, d, g, pd_pitch, pg_pitch, ecart=2))
        return p
    # contact droit devant / jambe gauche derrière, puis passage, puis inverse
    k0 = pas(0, -0.35, (sol + 0.05, -1.05), (sol + 0.75, 1.05), 15, -40, 1)
    k1 = pas(1, -0.05, (sol + 0.0, 0.15), (sol + 1.05, -0.2), 0, -20, 0)
    k2 = pas(2, -0.35, (sol + 0.75, 1.05), (sol + 0.05, -1.05), -40, 15, -1)
    k3 = pas(3, -0.05, (sol + 1.05, -0.2), (sol + 0.0, 0.15), -20, 0, 0)
    return dict(nom="Course", os=TOUT, boucle=True, priorite="Movement", cles=[
        (0.00, k0, "SINE_INOUT"), (0.15, k1, "SINE_INOUT"), (0.30, k2, "SINE_INOUT"),
        (0.45, k3, "SINE_INOUT"), (0.60, k0, "LINEAR"),
    ])

def anim_garde():
    """Garde couteau en main (boucle, haut du corps) : respiration."""
    a = GARDE
    b = P(GARDE, UpperTorso=(11, 15, 0), RightUpperArm=(50, 8, 18), RightLowerArm=(65, 0, 0),
          LeftUpperArm=(40, -6, -22), LeftLowerArm=(80, 0, 0), Head=(-8, -12, 0))
    return dict(nom="Garde", os=HAUT, boucle=True, priorite="Action", cles=[
        (0.0, a, "SINE_INOUT"), (0.8, b, "SINE_INOUT"), (1.6, a, "LINEAR"),
    ])

ANIMS = [anim_coup1, anim_coup2, anim_coup3, anim_esquive_droite, anim_esquive_gauche, anim_esquive_arriere,
         anim_course, anim_garde]

# =====================================================================
#  Blender : squelette, poupée de test, actions
# =====================================================================
def construire_rig():
    if "R15" in bpy.data.objects:
        return bpy.data.objects["R15"]
    arm_data = bpy.data.armatures.new("R15")
    arm = bpy.data.objects.new("R15", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for nom, (parent, pivot, centre, taille) in R15.items():
        eb = arm_data.edit_bones.new(nom)
        eb.head = rb(pivot)
        eb.tail = rb(pivot) + Vector((0, 0, 0.35))       # os vers le haut = axe Y Roblox
        eb.align_roll(Vector((0, -1, 0)))                # axe Z local = Z Roblox (arrière)
        eb.use_deform = False
        if parent:
            eb.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    # vérification des axes
    b = arm_data.bones["RightUpperArm"].matrix_local.to_3x3()
    assert (b.col[0] - Vector((1, 0, 0))).length < 1e-4 and (b.col[2] - Vector((0, -1, 0))).length < 1e-4, b
    for pb in arm.pose.bones:
        pb.rotation_mode = 'XYZ'
    # poupée R15 (cubes colorés) pour visualiser
    def materiau(nom, rgb):
        m = bpy.data.materials.get(nom) or bpy.data.materials.new(nom)
        m.diffuse_color = (*rgb, 1)
        if m.node_tree is None: m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1)
        return m
    couleurs = {"Torso": (0.15, 0.35, 0.8), "Head": (0.95, 0.8, 0.3), "Arm": (0.95, 0.8, 0.3),
                "Hand": (0.95, 0.8, 0.3), "Leg": (0.2, 0.22, 0.25), "Foot": (0.1, 0.1, 0.1)}
    bpy.context.view_layer.update()
    def cube(nom, centre, taille, mat, os_):
        bpy.ops.mesh.primitive_cube_add(size=1)
        c = bpy.context.active_object
        c.name = nom
        c.scale = (taille[0] * 0.98, taille[2] * 0.98, taille[1] * 0.98)
        c.location = rb(centre)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bev = c.modifiers.new("b", 'BEVEL'); bev.width = 0.06; bev.segments = 2
        c.data.materials.append(mat)
        w = c.matrix_world.copy()
        c.parent = arm; c.parent_type = 'BONE'; c.parent_bone = os_
        bpy.context.view_layer.update()
        c.matrix_world = w
    for nom, (parent, pivot, centre, taille) in R15.items():
        cle = next(k for k in couleurs if k in nom)
        rgb = couleurs[cle]
        if nom.startswith("Right") and cle in ("Arm", "Hand"): rgb = (0.9, 0.35, 0.25)   # bras droit = rouge
        cube("Poupee_" + nom, centre, taille, materiau("R15_" + cle + nom[:4], rgb), nom)
    # visage (yeux) vers l'avant (-Z Roblox)
    noir = materiau("R15_yeux", (0.02, 0.02, 0.02))
    for x in (-0.25, 0.25):
        cube("Poupee_Oeil%+.0f" % (x * 4), (x, 5.4, -0.62), (0.16, 0.3, 0.06), noir, "Head")
    return arm

def attacher_couteau(arm, glb):
    """Importe un couteau .glb et le met dans la main droite (lame dans l'axe -Z de la main)."""
    avant = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=glb)
    objs = [o for o in set(bpy.data.objects) - avant if o.type == 'MESH']
    zs = [(o.matrix_world @ v.co).z for o in objs for v in o.data.vertices]
    bas = min(zs)
    garde = 1.12
    vide = bpy.data.objects.new("Couteau", None); bpy.context.scene.collection.objects.link(vide)
    for o in objs:
        w = o.matrix_world.copy()
        o.parent = vide
        o.matrix_world = Matrix.Translation((0, 0, -(bas + garde / 2))) @ w
    # main droite : point de prise (1.5, 2.25, 0) ; lame = -Z Roblox = +Y Blender
    vide.matrix_world = Matrix.Translation(rb((1.5, 2.25, 0))) @ Matrix.Rotation(math.radians(-90), 4, 'X')
    w = vide.matrix_world.copy()
    vide.parent = arm; vide.parent_type = 'BONE'; vide.parent_bone = "RightHand"
    bpy.context.view_layer.update()
    vide.matrix_world = w
    return vide

INTERP = {
    "LINEAR": ('LINEAR', 'AUTO'), "SINE_OUT": ('SINE', 'EASE_OUT'), "SINE_IN": ('SINE', 'EASE_IN'),
    "SINE_INOUT": ('SINE', 'EASE_IN_OUT'), "EXPO_IN": ('EXPO', 'EASE_IN'), "EXPO_OUT": ('EXPO', 'EASE_OUT'),
    "QUART_OUT": ('QUART', 'EASE_OUT'), "BACK_OUT": ('BACK', 'EASE_OUT'), "CUBIC_INOUT": ('CUBIC', 'EASE_IN_OUT'),
}

def creer_actions(arm):
    from bpy_extras.anim_utils import animdata_get_channelbag_for_assigned_slot
    arm.animation_data_create()
    infos = {}
    for f in ANIMS:
        a = f()
        act = bpy.data.actions.get(a["nom"])
        if act: bpy.data.actions.remove(act)
        act = bpy.data.actions.new(a["nom"]); act.use_fake_user = True
        arm.animation_data.action = act
        prec = {}
        cles_frames = []
        for (t, pose, interp) in a["cles"]:
            fr = round(t * FPS)
            cles_frames.append((fr, interp))
            pose = {**prec, **pose}
            prec = pose
            for nom in TOUT:
                pb = arm.pose.bones[nom]
                v = pose.get(nom, (0, 0, 0))
                rot, loc = (v if (len(v) == 2 and isinstance(v[0], (tuple, list))) else (v, (0, 0, 0)))
                if nom in VERS_LE_HAUT:
                    rot = (-rot[0], rot[1], -rot[2])
                pb.rotation_euler = Euler([math.radians(x) for x in rot], 'XYZ')
                pb.location = Vector(loc)
                pb.keyframe_insert("rotation_euler", frame=fr, group=nom)
                if nom == "LowerTorso":
                    pb.keyframe_insert("location", frame=fr, group=nom)
        cb = animdata_get_channelbag_for_assigned_slot(arm.animation_data)
        for fc in cb.fcurves:
            for kp in fc.keyframe_points:
                interp = next((i for fr, i in cles_frames if fr == round(kp.co.x)), "LINEAR")
                kp.interpolation, kp.easing = INTERP[interp]
        if a["boucle"]:
            act.use_cyclic = True
        infos[a["nom"]] = dict(os=a["os"], boucle=a["boucle"], priorite=a["priorite"],
                               fin=cles_frames[-1][0])
        act["prv"] = json.dumps(infos[a["nom"]])
    return infos

# =====================================================================
#  Export vers Roblox (script Lua -> KeyframeSequence)
# =====================================================================
PARENTS = {n: R15[n][0] or "HumanoidRootPart" for n in R15}

def exporter_lua(arm, chemin):
    sc = bpy.context.scene
    lignes = []
    for act in [a for a in bpy.data.actions if "prv" in a]:
        info = json.loads(act["prv"])
        arm.animation_data.action = act
        fin = info["fin"]
        pas = FPS // EXPORT_FPS
        frames = list(range(0, fin + 1, pas))
        if frames[-1] != fin: frames.append(fin)
        os_anim = info["os"]
        donnees = {n: [] for n in os_anim}
        for fr in frames:
            sc.frame_set(fr)
            for n in os_anim:
                m = arm.pose.bones[n].matrix_basis
                q = m.to_quaternion(); p = m.to_translation()
                donnees[n].append("%g,%g,%g,%g,%g,%g,%g" % tuple(round(x, 4) for x in (p.x, p.y, p.z, q.x, q.y, q.z, q.w)))
        temps = ",".join("%g" % round(fr / FPS, 4) for fr in frames)
        corps = ";\n".join('\t\t%s = {%s}' % (n, ",".join("{%s}" % s for s in donnees[n])) for n in os_anim)
        lignes.append('\t%s = { Boucle = %s, Priorite = "%s", Temps = {%s},\n\t\tPoses = {\n%s } },' % (
            act.name, "true" if info["boucle"] else "false", info["priorite"], temps, corps.replace("\t\t", "\t\t\t")))
    lua = MODELE_LUA.replace("--DONNEES--", "\n".join(lignes)).replace("--PARENTS--", ", ".join(
        '%s = "%s"' % (k, v) for k, v in PARENTS.items()))
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(lua)
    print("[PRV] animations exportées :", chemin)

MODELE_LUA = r'''--[[ À COLLER DANS LA BARRE DE COMMANDES de Studio, puis Entrée.  (fichier généré par animations_r15.py)
     Crée les animations des couteaux (KeyframeSequence) :
       - ReplicatedStorage.Couteaux.Animations : utilisées directement pour tester en Play dans Studio ;
       - <Rig>.AnimSaves : pour les PUBLIER avec l'Éditeur d'animation (si un rig R15 nommé "Rig" ou "Dummy"
         est dans le Workspace : Avatar > Constructeur de rig > R15 > Bloc).
     Publier : Éditeur d'animation > sélectionner le Rig > « ... » > Charger > choisir l'animation >
               « ... » > Publier sur Roblox > copier l'ID dans Config.Animations.
     Ne supprime rien : une animation qui existe déjà est remplacée seulement dans ces deux dossiers.
]]
local ANIMS = {
--DONNEES--
}
local PARENTS = { --PARENTS-- }

local RS = game:GetService("ReplicatedStorage")
local dossierCouteaux = RS:FindFirstChild("Couteaux") or Instance.new("Folder")
dossierCouteaux.Name = "Couteaux"
dossierCouteaux.Parent = RS
local dossierAnims = dossierCouteaux:FindFirstChild("Animations") or Instance.new("Folder")
dossierAnims.Name = "Animations"
dossierAnims.Parent = dossierCouteaux

local function construire(nom, a)
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = nom
	kfs.Loop = a.Boucle
	kfs.Priority = Enum.AnimationPriority[a.Priorite]
	for i, t in ipairs(a.Temps) do
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local poses = {}
		local function pose(n)
			if poses[n] then return poses[n] end
			local p = Instance.new("Pose")
			p.Name = n
			p.EasingStyle = Enum.PoseEasingStyle.Linear
			local d = a.Poses[n]
			if d then
				local v = d[i]
				p.CFrame = CFrame.new(v[1], v[2], v[3], v[4], v[5], v[6], v[7])
				p.Weight = 1
			else
				p.CFrame = CFrame.new()
				p.Weight = 0 -- simple conteneur : n'anime pas cette articulation
			end
			local parent = PARENTS[n]
			p.Parent = parent and pose(parent) or kf
			poses[n] = p
			return p
		end
		local racine = Instance.new("Pose")
		racine.Name = "HumanoidRootPart"
		racine.Weight = 0
		racine.Parent = kf
		poses.HumanoidRootPart = racine
		for n in pairs(a.Poses) do pose(n) end
		kf.Parent = kfs
	end
	return kfs
end

local rig = workspace:FindFirstChild("Rig") or workspace:FindFirstChild("Dummy")
local saves
if rig and rig:FindFirstChildOfClass("Humanoid") then
	saves = rig:FindFirstChild("AnimSaves") or Instance.new("Model")
	saves.Name = "AnimSaves"
	saves.Parent = rig
end
for nom, a in pairs(ANIMS) do
	local ancien = dossierAnims:FindFirstChild(nom)
	if ancien then ancien:Destroy() end
	construire(nom, a).Parent = dossierAnims
	if saves then
		local s = saves:FindFirstChild(nom)
		if s then s:Destroy() end
		construire(nom, a).Parent = saves
	end
end
print("[Couteaux] animations créées dans ReplicatedStorage.Couteaux.Animations" ..
	(saves and (" et " .. saves:GetFullName()) or " (ajoute un rig R15 nommé « Rig » pour les publier)"))
'''

# =====================================================================
if __name__ == "__main__":
    import sys
    sortie = os.environ.get("PRV_SORTIE") or os.path.dirname(bpy.data.filepath or os.path.expanduser("~/x"))
    couteau = os.environ.get("PRV_COUTEAU")
    arm = construire_rig()
    if couteau: attacher_couteau(arm, couteau)
    creer_actions(arm)
    exporter_lua(arm, os.path.join(sortie, "InstallerAnimations.lua"))
    if os.environ.get("PRV_BLEND"):
        bpy.ops.wm.save_as_mainfile(filepath=os.environ["PRV_BLEND"])
