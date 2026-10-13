# Rend une planche d'aperçu des 15 couteaux (après couteaux.py).
# Blender : lancer couteaux.py puis ce script. En ligne de commande :
#   blender -b -P couteaux.py -P apercu.py   (variable PRV_APERCU = chemin du PNG)
import bpy, math, os
from mathutils import Vector

sortie = os.environ.get("PRV_APERCU") or os.path.join(os.path.expanduser("~"), "apercu_couteaux.png")
sc = bpy.context.scene
for nm in ("Cube", "Light", "Camera"):
    if bpy.data.objects.get(nm): bpy.data.objects.remove(bpy.data.objects[nm])
CONTOUR = os.environ.get("PRV_CONTOUR", "1") == "1"
ordre = [["PouleBase","PouleRoyal","PoulePlume","PouleElectrique","PouleGeant"],
         ["RenardBase","RenardFurtif","RenardSpectre","RenardLegendaire","RenardOrigami"],
         ["ViperBase","ViperToxique","ViperSerpent","ViperVenin","ViperRoyal"]]
for r, ligne in enumerate(ordre):
    for c, kid in enumerate(ligne):
        coll = bpy.data.collections.get(kid)
        if not coll: continue
        for ob in coll.objects:
            ob.hide_render = (not CONTOUR) and ob.name.endswith("_outline")
            if ob.name.endswith("_outline"):      # le contour ne doit pas faire d'ombre
                ob.visible_shadow = ob.visible_diffuse = ob.visible_glossy = ob.visible_transmission = False
            ob.location = (c * 1.6 - 3.2, 0, -r * 3.6 + 3.6)
            ob.rotation_euler = (0, math.radians(-18), 0)
cam = bpy.data.objects.get("PRV_Cam") or bpy.data.objects.new("PRV_Cam", bpy.data.cameras.new("PRV_Cam"))
if cam.name not in sc.collection.objects: sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'; cam.data.ortho_scale = 11.5
cam.location = (0, -20, 0); cam.rotation_euler = (math.radians(90), 0, 0)
sc.camera = cam
for nm, rot, en in (("PRV_Key", (50, 0, -30), 4.0), ("PRV_Fill", (70, 0, 140), 1.5)):
    li = bpy.data.objects.get(nm) or bpy.data.objects.new(nm, bpy.data.lights.new(nm, 'SUN'))
    if li.name not in sc.collection.objects: sc.collection.objects.link(li)
    li.rotation_euler = [math.radians(a) for a in rot]; li.data.energy = en
w = sc.world or bpy.data.worlds.new("W"); sc.world = w
w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.02, 0.025, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sc.render.engine = 'CYCLES'; sc.cycles.samples = 24; sc.cycles.device = 'CPU'
sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x = 1300; sc.render.resolution_y = 1500
sc.render.filepath = sortie
bpy.ops.render.render(write_still=True)
print("[PRV] aperçu :", sortie)
