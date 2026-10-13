import bpy, sys, glob, os, math
d, outp = sys.argv[sys.argv.index('--')+1:][:2]
ids = sys.argv[sys.argv.index('--')+3:]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene
files=[os.path.join(d,k+'.glb') for k in ids] if ids else sorted(glob.glob(d+'/*.glb'))
for i,f in enumerate(files):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    for o in set(bpy.data.objects)-before:
        if o.parent is None:
            o.location=((i%5)*1.9-3.8, 0, -(i//5)*3.5)
        if o.name.endswith('outline'):
            o.visible_shadow=o.visible_diffuse=o.visible_glossy=False
            m=o.active_material
            if m:
                nt=m.node_tree; out=nt.nodes.get('Material Output'); b=nt.nodes.get('Principled BSDF')
                geo=nt.nodes.new('ShaderNodeNewGeometry'); tr=nt.nodes.new('ShaderNodeBsdfTransparent'); mx=nt.nodes.new('ShaderNodeMixShader')
                nt.links.new(geo.outputs['Backfacing'],mx.inputs[0]); nt.links.new(b.outputs[0],mx.inputs[1]); nt.links.new(tr.outputs[0],mx.inputs[2]); nt.links.new(mx.outputs[0],out.inputs['Surface'])
n=len(files); rows=(n+4)//5
cam=bpy.data.objects.new('cam',bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
cam.data.type='ORTHO'; cam.data.ortho_scale=max(9.8, rows*3.6)
yaw=float(os.environ.get('YAW','0'))
cx=0; cz=1.4-(rows-1)*1.75
r=20
cam.location=(cx+r*math.sin(math.radians(yaw)), r*math.cos(math.radians(yaw)), cz)
cam.rotation_euler=(math.radians(90),0,math.radians(180+ -yaw))
sc.camera=cam
for nm,rot,en in (('k',(50,0,150),3.5),('f',(70,0,-30),1.2)):
    l=bpy.data.objects.new(nm,bpy.data.lights.new(nm,'SUN')); sc.collection.objects.link(l); l.rotation_euler=[math.radians(a) for a in rot]; l.data.energy=en
w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[0].default_value=(0.03,0.03,0.035,1)
w.node_tree.nodes['Background'].inputs[1].default_value=1.5
sc.render.engine='CYCLES'; sc.cycles.samples=24; sc.view_settings.view_transform='Standard'
sc.render.resolution_x=1000; sc.render.resolution_y=int(1000*cam.data.ortho_scale/9.8*rows*3.6/max(9.8,rows*3.6)) if rows>1 else 380*1+0
sc.render.resolution_y=int(1000*(rows*3.6)/9.8)
sc.render.filepath=outp; bpy.ops.render.render(write_still=True)
