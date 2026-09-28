import trimesh, numpy as np, pymeshlab, sys, json
from PIL import Image
MAXT=18000
def decimate(v,f,uv,target):
    ms=pymeshlab.MeshSet()
    if uv is not None:
        ms.add_mesh(pymeshlab.Mesh(vertex_matrix=v,face_matrix=f,v_tex_coords_matrix=uv))
        ms.compute_texcoord_transfer_vertex_to_wedge()
        for pb in (True,False):
            ms.meshing_decimation_quadric_edge_collapse_with_texture(targetfacenum=target,preserveboundary=pb,qualitythr=0.3,optimalplacement=True)
            if ms.current_mesh().face_number()<=target*1.03: break
        for _ in range(4):
            if ms.current_mesh().face_number()<=target*1.03: break
            ms.meshing_decimation_quadric_edge_collapse_with_texture(targetfacenum=target,preserveboundary=False,qualitythr=0.1,extratcoordw=0.3,optimalplacement=True)
        mm=ms.current_mesh(); V=mm.vertex_matrix(); F=mm.face_matrix(); W=np.asarray(mm.wedge_tex_coord_matrix()).reshape(len(F),3,2)
        key=np.round(np.c_[V[F].reshape(-1,3),W.reshape(-1,2)],7)
        u,inv=np.unique(key,axis=0,return_inverse=True)
        return u[:,:3],inv.reshape(-1,3),u[:,3:]
    ms.add_mesh(pymeshlab.Mesh(vertex_matrix=v,face_matrix=f))
    ms.meshing_decimation_quadric_edge_collapse(targetfacenum=target,preserveboundary=True,optimalplacement=True)
    mm=ms.current_mesh(); return mm.vertex_matrix(),mm.face_matrix(),None
def convert(name,src,out,tex=None,rot=None,height=6.0):
    sc=trimesh.load(src,force='scene')
    parts=[]
    for node in sc.graph.nodes_geometry:
        T,gname=sc.graph[node]; g=sc.geometry[gname]
        v=trimesh.transform_points(g.vertices,T); f=np.asarray(g.faces)
        vis=g.visual; uv=getattr(vis,'uv',None); mat=getattr(vis,'material',None)
        img=None; color=None
        if mat is not None:
            img=getattr(mat,'baseColorTexture',None) or getattr(mat,'image',None)
            color=getattr(mat,'baseColorFactor',None)
            if color is None and hasattr(mat,'main_color'): color=mat.main_color
        if tex: img=Image.open(tex)
        if img is not None and img.size[0]<=4: img=None
        if img is None: uv=None
        parts.append([v,f,None if uv is None else np.asarray(uv,float),img,color])
    if rot is not None:
        R=trimesh.transformations.euler_matrix(*[np.radians(a) for a in rot])
        for p in parts: p[0]=trimesh.transform_points(p[0],R)
    tot=sum(len(p[1]) for p in parts)
    res=trimesh.Scene()
    allv=np.vstack([p[0] for p in parts]); mn,mx=allv.min(0),allv.max(0)
    s=height/(mx[1]-mn[1]); c=np.array([(mn[0]+mx[0])/2,mn[1],(mn[2]+mx[2])/2])
    nt=0
    for i,(v,f,uv,img,color) in enumerate(parts):
        if tot>MAXT:
            tgt=max(50,int(len(f)*MAXT/tot*0.97))
            v,f,uv=decimate(v,f,uv,tgt)
        nt+=len(f)
        if img is not None:
            img=img.convert('RGB')
            if max(img.size)>1024: img=img.resize((1024,1024))
            m=trimesh.visual.material.PBRMaterial(baseColorTexture=img,metallicFactor=0.0,roughnessFactor=0.8)
            vis=trimesh.visual.TextureVisuals(uv=uv,material=m)
        else:
            col=np.asarray(color if color is not None else [200,200,200,255])
            if col.max()<=1.0: col=col*255
            m=trimesh.visual.material.PBRMaterial(baseColorFactor=col.astype(np.uint8),metallicFactor=0.0,roughnessFactor=0.8)
            vis=trimesh.visual.TextureVisuals(material=m)
        res.add_geometry(trimesh.Trimesh((v-c)*s,f,process=False,visual=vis),node_name=f'{name}_{i+1}',geom_name=f'{name}_{i+1}')
    res.export(out); print(name,'tris',tot,'->',nt,'parts',len(parts))
