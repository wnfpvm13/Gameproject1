"""Build a Studio-focused low-poly Hornboar; preserve silhouette, rig and actions."""
from pathlib import Path
import sys, json, math, hashlib
import bpy, bmesh
from mathutils import Vector
ART=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ART));sys.path.insert(0,str(ART/'blender'))
from hornboar_design import RIG, ACTIONS
from model_spec import shape, BROWN, WARM, BEIGE, IVORY, GOLD, MAGIC
from build_assets import material, mesh_part, preview_scene, convert
parts=[]

def loft(name, profiles, sides, bone, color, binding='Visual', axis='Z', subdivisions=1):
    # Authored cross sections, interpolated longitudinally: flattened belly, proud shoulder, smaller tapered head.
    rings=[]
    for a,b in zip(profiles,profiles[1:]):
        for step in range(subdivisions):
            t=step/subdivisions;rings.append(tuple(x*(1-t)+y*t for x,y in zip(a,b)))
    rings.append(profiles[-1]);verts=[]
    for p in rings:
        coordinate,c1,c2,r1,r2=p
        for i in range(sides):
            angle=2*math.pi*i/sides
            u,v=math.cos(angle)*r1,math.sin(angle)*r2
            if axis=='Z': pos=(c1+u,c2+max(v,-r2*0.86),coordinate)
            else: pos=(c1+u,coordinate,c2+v)
            verts.append(convert(pos))
    faces=[]
    for ring in range(len(rings)-1):
        for i in range(sides):
            a=ring*sides+i;b=ring*sides+(i+1)%sides;c=(ring+1)*sides+(i+1)%sides;d=(ring+1)*sides+i
            # Z-axis mapping reverses cross-section winding; Y-axis does not.
            faces.extend([(a,c,b),(a,d,c)] if axis=='Z' else [(a,b,c),(a,c,d)])
    for start, reverse in [(0,axis=='Y'),((len(rings)-1)*sides,axis=='Z')]:
        for i in range(1,sides-1): faces.append((start,start+i+1,start+i) if reverse else (start,start+i,start+i+1))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material(color));obj['RobloxBinding']=binding;obj['RobloxBone']=bone
    # Broad colour planes follow shape, instead of noisy textures.
    if name in ('Torso','Head','Muzzle'):
        obj.data.materials.append(material(tuple(min(1,c*1.20) for c in color)))
        for polygon in obj.data.polygons:
            polygon.material_index=1 if polygon.normal.z>0.35 else 0
    if binding=='HornBroken':obj.hide_render=True
    parts.append(obj);return obj

def detail(spec):
    # Tiny bevels cost many triangles without changing the readable silhouette.
    if spec['name'] != 'Nose' and not spec['name'].endswith('_Hoof'):spec['bevel']=0
    bpy.ops.object.select_all(action='DESELECT');obj=mesh_part(spec,bevel_segments=1);parts.append(obj);return obj

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
loft('Torso',[(3.9,0,2.45,.6,.65),(3.2,0,2.7,1.75,1.15),(1.7,0,2.8,2.05,1.3),(.0,0,3.0,2.3,1.4),(-1.4,0,3.05,2.5,1.5),(-2.3,0,2.95,2.1,1.35),(-2.9,0,2.8,1.35,.95)],12,'Spine',BROWN)
loft('NeckMass',[(-2.1,0,2.9,1.8,1.1),(-2.8,0,3.0,1.65,1.13),(-3.2,0,3.0,1.25,.95)],10,'Neck',WARM)
loft('Head',[(-2.75,0,3.05,1.12,.85),(-3.3,0,3.0,1.55,1.06),(-4.1,0,2.75,1.38,.92),(-4.8,0,2.55,1.0,.65)],10,'Head',WARM)
loft('Muzzle',[(-4.35,0,2.4,1.0,.58),(-4.95,0,2.3,1.15,.6),(-5.5,0,2.25,1.1,.56),(-5.65,0,2.25,.96,.50)],10,'Head',BEIGE)
detail(shape('Nose','Box',(0,2.25,-5.63),(1.90,.78,.30),(.44,.23,.13),bone='Head',bevel=.12))
for side,sign in [('L',-1),('R',1)]:
    detail(shape('Nostril_'+side,'Box',(sign*.45,2.25,-5.81),(.26,.24,.035),BROWN,bone='Head',bevel=.06))
    detail(shape('Eye_'+side,'Box',(sign*1.35,3.37,-3.9),(.10,.24,.60),GOLD,bone='Head',rotation=(0,0,sign*8),bevel=.06))
    detail(shape('Pupil_'+side,'Box',(sign*1.41,3.36,-4.01),(.04,.18,.20),BROWN,bone='Head',bevel=.02))
    detail(shape('Brow_'+side,'Wedge',(sign*1.34,3.62,-3.92),(.35,.32,.83),BROWN,bone='Head',rotation=(0,0,sign*12)))
    detail(shape('Ear_'+side,'Wedge',(sign*1.38,4.05,-2.95),(.76,1.00,.64),BROWN,bone='Head',rotation=(10,0,-sign*24)))
    detail(shape('EarInset_'+side,'Wedge',(sign*1.38,4.09,-3.08),(.48,.65,.18),BEIGE,bone='Head',rotation=(10,0,-sign*24)))
    loft('Tusk_'+side,[(-4.7,sign*1.0,1.98,.26,.30),(-5.1,sign*1.15,2.25,.20,.23),(-5.3,sign*1.16,2.65,.025,.03)],6,'Head',IVORY)
for prefix,z,x in [('Front',-1.75,1.85),('Back',2.55,1.7)]:
    for side,sign in [('L',-1),('R',1)]:
        bone=prefix+'Leg_'+side;shin=prefix+'Shin_'+side
        loft(bone+'_Upper',[(2.9 if prefix=='Front' else 2.5,sign*x,z,.70,.76),(2.15,sign*x,z,.65,.65),(1.45,sign*x,z-.12,.47,.43),(1.1,sign*x,z-.18,.36,.34)],8,bone,WARM,axis='Y')
        loft(shin+'_Lower',[(1.25,sign*x,z-.16,.37,.34),(.8,sign*x,z-.10,.30,.30),(.35,sign*x,z-.3,.31,.32)],8,shin,BROWN,axis='Y')
        detail(shape(shin+'_Hoof','Box',(sign*x,.28,z-.3),(.86,.54,1.13),(.23,.17,.11),bone=shin,bevel=.12))
        detail(shape(shin+'_HoofSplit','Box',(sign*x,.29,z-.855),(.065,.35,.035),BEIGE,bone=shin,bevel=.01))
for i in range(4):
    detail(shape('ShoulderPlate_'+str(i),'Wedge',(0,4.43-i*.17,-1.55+i*1.24),(2.5-i*.27,.5,1.16),(.57,.34,.16),rotation=(7,0,0)))
# One continuous curved horn from thick forehead root to a restrained cyan point.
loft('Horn_Intact',[(-3.75,0,3.97,.70,.63),(-4.2,0,4.15,.65,.58),(-4.85,0,4.4,.51,.49),(-5.65,0,4.72,.36,.36),(-6.4,0,5.1,.21,.22),(-7.05,0,5.58,.025,.03)],10,'Horn',IVORY,'HornIntact')
loft('HornTip',[(-6.7,0,5.30,.10,.10),(-7.06,0,5.6,.015,.015)],6,'Horn',MAGIC,'HornIntact')
loft('Horn_Broken',[(-3.74,0,3.98,.69,.62),(-4.18,0,4.14,.57,.50)],10,'Horn',IVORY,'HornBroken')
detail(shape('BrokenCore','Box',(0,4.14,-4.2),(.50,.34,.04),MAGIC,bone='Horn',binding='HornBroken',bevel=.05))
loft('Tail',[(3.55,.0,2.8,.15,.15),(4.05,.12,2.7,.16,.16),(4.48,.30,2.6,.19,.20),(4.75,.35,2.3,.08,.08)],6,'Tail',BROWN)
# Remove bevel-collapse duplicates/zero-area faces before rigging and export.
for obj in parts:
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.000001)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=0.000001)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
# Merge only pieces sharing a bone and visibility; preserve the horn break contract.
mesh_groups={}
for obj in parts:mesh_groups.setdefault((obj['RobloxBone'],obj['RobloxBinding']),[]).append(obj)
parts=[]
for (bone,binding),objects in mesh_groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:bpy.ops.object.join()
    obj=objects[0];obj.name='Mesh_'+bone+'_'+binding
    obj['RobloxBone']=bone;obj['RobloxBinding']=binding
    parts.append(obj)
# Bone hierarchy and rigid segment skinning, preserving separate intact/broken pieces.
arm=bpy.data.armatures.new('Rig');rig=bpy.data.objects.new('Rig',arm);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for name,d in RIG.items():
    bone=arm.edit_bones.new(name);bone.head=convert(d['position']);bone.tail=Vector(bone.head)+Vector((0,0,-.7 if 'Leg' in name or 'Shin' in name else .55))
    if d['parent']:bone.parent=arm.edit_bones[d['parent']]
bpy.ops.object.mode_set(mode='OBJECT')
for obj in parts:
    group=obj.vertex_groups.new(name=obj['RobloxBone']);group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
    modifier=obj.modifiers.new('RigSkin','ARMATURE');modifier.object=rig;obj.parent=rig
rig.animation_data_create()
for name in ACTIONS:
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
    for frame in (0,6,12,18,24):
        t=frame/24;pulse=math.sin(t*math.pi)
        for bone in rig.pose.bones:
            bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0);bone.location=(0,0,0)
            if ('Leg' in bone.name or 'Shin' in bone.name) and name in ('Walk','Run','Charge'):
                side=-1 if bone.name.endswith('_R') else 1;back=-1 if bone.name.startswith('Back') else 1
                bone.rotation_euler.x=math.sin(t*math.pi*2)*side*back*(.36 if name=='Walk' else .62)*(.55 if 'Shin' in bone.name else 1)
            if bone.name=='Spine':
                if name=='Idle':bone.location.z=pulse*.035
                if name=='ChargeWindup':bone.rotation_euler.x=-pulse*.18;bone.location.z=-pulse*.12
                if name in ('LightHit','HeavyHit','HornHit','HornBreak','Stagger'):
                    bone.rotation_euler.y=pulse*(.12 if name=='LightHit' else .27);bone.location.z=-pulse*(.04 if name=='LightHit' else .16)
                if name=='Death':bone.rotation_euler.y=1.25*min(1,t*2);bone.location.z=-min(1,t*2)*.9
            if bone.name=='Head':
                if name in ('Alert','Headbutt'):bone.rotation_euler.x=pulse*.35
                if name in ('ChargeWindup','Charge'):bone.rotation_euler.x=-pulse*.30
                if name in ('LightHit','HeavyHit','HornHit','HornBreak'):bone.rotation_euler.x=pulse*({'LightHit':.16,'HeavyHit':.30,'HornHit':.43,'HornBreak':.70}[name])
            bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name);bone.keyframe_insert(data_path='location',frame=frame,group=bone.name)
    for curve in action.fcurves:
        for key in curve.keyframe_points:key.interpolation='LINEAR'
rig.animation_data.action=bpy.data.actions['Idle'];bpy.context.scene.frame_set(0)
source=ART/'blender/Hornboar/MON_Hornboar_V1.blend';export=ART/'exports/Monsters/MON_Hornboar_V1'
bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=24
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.fbx(filepath=str(export.with_suffix('.fbx')),use_selection=True,add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=True,bake_anim_use_nla_strips=False,bake_anim_step=6,bake_anim_simplify_factor=1,axis_forward='-Z',axis_up='Y')
# Studio import only needs the mesh/rig; retain all 13 clips in source + animated FBX.
# A skinned body plus intact/broken horn meshes avoids repeating the complete
# FBX skin hierarchy for each of the fourteen runtime rigid mesh groups.
studio_export=export.with_name(export.name+'_Studio').with_suffix('.fbx')
studio_groups={}
for obj in parts:
    clone=obj.copy();clone.data=obj.data.copy();bpy.context.collection.objects.link(clone)
    studio_groups.setdefault(obj['RobloxBinding'],[]).append(clone)
studio_parts=[]
for binding,objects in studio_groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:bpy.ops.object.join()
    obj=objects[0];obj.name='Hornboar_'+binding;studio_parts.append(obj)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in studio_parts:obj.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(studio_export),use_selection=True,add_leaf_bones=False,bake_anim=False,axis_forward='-Z',axis_up='Y')
for obj in studio_parts:bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(export.with_suffix('.glb')),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
# Export actual authored mesh vertices, triangles and face palette, grouped by joint + break visibility.
def srgb(v):return 12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055
groups={};palette=[]
for obj in parts:
    key=(obj['RobloxBone'],obj['RobloxBinding']);g=groups.setdefault(key,{'Bone':key[0],'Binding':key[1],'Vertices':[],'Faces':[]})
    offset=len(g['Vertices'])
    for v in obj.data.vertices:
        world=obj.matrix_world@v.co;g['Vertices'].append([round(world.x,4),round(world.z,4),round(-world.y,4)])
    for face in obj.data.polygons:
        color=[round(srgb(c),6) for c in obj.data.materials[face.material_index].diffuse_color[:3]]
        if color not in palette:palette.append(color)
        assert len(face.vertices)==3
        g['Faces'].append([offset+v+1 for v in face.vertices]+[palette.index(color)+1])
for g in groups.values():
    mins=[min(v[i] for v in g['Vertices']) for i in range(3)];maxs=[max(v[i] for v in g['Vertices']) for i in range(3)]
    g['Center']=[round((a+b)/2,4) for a,b in zip(mins,maxs)];g['Size']=[round(b-a,4) for a,b in zip(mins,maxs)]
    g['Vertices']=[[round(v[i]-g['Center'][i],4) for i in range(3)] for v in g['Vertices']]
triangles=sum(len(g['Faces']) for g in groups.values())
assert 1000<=triangles<=2000,triangles
meshdata={'AssetId':'MON_Hornboar_V1','SourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'TriangleCount':triangles,'Palette':palette,'Groups':list(groups.values())}
(ART/'hornboar_mesh.json').write_text(json.dumps(meshdata,separators=(',',':'))+'\n')
manifest=json.loads((ART/'asset_manifest.json').read_text());entry=manifest['assets']['MON_Hornboar_V1']
entry.update(status='V1_CANDIDATE',blender_triangles=triangles,triangle_budget=[1000,2000],objects=len(parts),bones=list(RIG),source_actions=list(ACTIONS),studio_fbx=str(studio_export.relative_to(ART)),studio_mesh_objects=len(studio_groups),runtime_representation='Studio-imported .rbxm runtime; lightweight exports await separate import/upload')
(ART/'asset_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('REDESIGN',triangles,'triangles',len(parts),'objects',len(RIG),'bones',len(ACTIONS),'actions',flush=True)
import runpy
runpy.run_path(str(ART/'blender/export_hornboar_rigid.py'),run_name='__main__')
preview=ART/'previews'
for label,distance in [('Close',19),('Medium',29),('Far',48)]:preview_scene((0,1.2,2.3),distance,preview/f'Hornboar_{label}.png')
