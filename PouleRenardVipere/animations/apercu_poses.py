# render key poses of an animation at larger size from several views
import bpy, sys, os, math, json
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:]
blend,outdir,name=args[0],args[1],args[2]; frames=[int(x) for x in args[3].split(',')]; views=args[4].split(',')
bpy.ops.wm.open_mainfile(filepath=blend)
sc=bpy.context.scene; arm=bpy.data.objects['R15']
for nm in ('Cube','Light','Camera'):
    o=bpy.data.objects.get(nm)
    if o: o.hide_render=True
arm.animation_data.action=bpy.data.actions[name]
for o in bpy.data.objects:
    if o.name.endswith('outline'): o.hide_render=True
bpy.ops.mesh.primitive_plane_add(size=60); sol=bpy.context.active_object
m=bpy.data.materials.new('sol'); m.use_nodes=True; m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(0.35,0.38,0.42,1); sol.data.materials.append(m)
cam=bpy.data.objects.new('cam',bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera=cam
P={'tq':(7,9,4.5),'cote':(12,-0.5,3.2),'face':(0,12.5,3.4),'dessus':(0.01,2,14),'tqd':(-7,9,4.5)}
for nm,rot,en in (('k',(45,10,150),3.0),('f',(65,0,-40),1.2)):
    l=bpy.data.objects.new(nm,bpy.data.lights.new(nm,'SUN')); sc.collection.objects.link(l); l.rotation_euler=[math.radians(a) for a in rot]; l.data.energy=en
w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[0].default_value=(0.12,0.12,0.14,1)
sc.render.engine='CYCLES'; sc.cycles.samples=8; sc.view_settings.view_transform='Standard'
sc.render.resolution_x=420; sc.render.resolution_y=460
os.makedirs(outdir,exist_ok=True)
for v in views:
    cam.location=P[v]; cam.data.lens=36
    d=Vector((0,-1.4,2.4))-cam.location; cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
    for f in frames:
        sc.frame_set(f); sc.render.filepath=f'{outdir}/{name}_{v}_{f:03d}.png'; bpy.ops.render.render(write_still=True)
