# Rendu d'aperçu du Gardien : python gardien_apercu.py -- <fichier.blend> <sortie.png> [vue] [action] [image]
import bpy, sys, math
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=a[0])
vue = a[2] if len(a) > 2 else "face"
sc = bpy.context.scene
if len(a) > 3 and a[3] != "-":
    arm = bpy.data.objects.get("Squelette")
    arm.animation_data.action = bpy.data.actions[a[3]]
    sc.frame_set(int(a[4]) if len(a) > 4 else 0)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
pos = {"face": (3.5, -17, 3.0), "trois_quart": (11, -13, 4.5), "dos": (-8, 14, 6), "cote": (17, -1, 4), "bas": (2.5, -13, 0.6)}[vue]
cam.location = pos; cam.data.lens = 50
cible = Vector((0, 0, 4.6))
cam.rotation_euler = (cible - cam.location).to_track_quat("-Z", "Y").to_euler()
for nm, rot, en, col in (("k", (50, 10, 35), 4.0, (1, 0.96, 0.9)), ("r", (60, 0, 200), 2.5, (0.7, 0.8, 1)), ("f", (80, 0, -60), 1.2, (1, 1, 1))):
    l = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "SUN")); sc.collection.objects.link(l)
    l.rotation_euler = [math.radians(x) for x in rot]; l.data.energy = en; l.data.color = col; l.data.angle = math.radians(8)
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.57, 0.62, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
bpy.ops.mesh.primitive_plane_add(size=60); sol = bpy.context.active_object
m = bpy.data.materials.new("sol"); m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.33, 0.35, 1); sol.data.materials.append(m)
sc.render.engine = "CYCLES"; sc.cycles.samples = 24; sc.cycles.use_denoising = True
sc.view_settings.view_transform = "AgX"
sc.render.resolution_x, sc.render.resolution_y = 640, 800
sc.render.filepath = a[1]
bpy.ops.render.render(write_still=True)
