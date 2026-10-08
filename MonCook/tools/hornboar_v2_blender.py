"""DCC-MCP Blender pipeline. Only operates on task-owned MonCook scenes.

Invoke main(operation, parameters) through blender_scripting__execute_python.
The artist's original Scene and its objects are never deleted or overwritten.
"""
from pathlib import Path
from typing import Dict
import json
import math
import bpy
import bmesh
from mathutils import Vector, Matrix

PROJECT = Path(__file__).resolve().parent.parent
OUTPUT = PROJECT / 'art/generated/Monsters/Hornboar/V2'


def audit(scene):
    meshes = [o for o in scene.objects if o.type == 'MESH']
    materials = {m.name for o in meshes for m in o.data.materials if m}
    images = {n.image for name in materials for n in bpy.data.materials[name].node_tree.nodes
              if n.type == 'TEX_IMAGE' and n.image} if materials else set()
    result = {'scene': scene.name, 'blender': bpy.app.version_string,
              'mesh_count': len(meshes), 'object_count': len(scene.objects),
              'materials': sorted(materials), 'material_count': len(materials),
              'textures': [{'name': i.name, 'resolution': list(i.size)} for i in images],
              'texture_count': len(images), 'triangles': 0, 'meshes': [], 'rigs': []}
    for obj in meshes:
        mesh = obj.data
        mesh.calc_loop_triangles()
        coords = [tuple(round(v, 6) for v in vert.co) for vert in mesh.vertices]
        faces = [tuple(sorted(p.vertices)) for p in mesh.polygons]
        bm = bmesh.new(); bm.from_mesh(mesh)
        row = {'name': obj.name, 'triangles': len(mesh.loop_triangles),
               'vertices': len(mesh.vertices), 'materials': len(mesh.materials),
               'uv_layers': len(mesh.uv_layers), 'duplicate_vertices': len(coords)-len(set(coords)),
               'duplicate_faces': len(faces)-len(set(faces)),
               'zero_area_faces': sum(p.area < 1e-10 for p in mesh.polygons),
               'boundary_edges': sum(e.is_boundary for e in bm.edges),
               'nonmanifold_edges': sum(not e.is_manifold for e in bm.edges),
               'scale': list(obj.scale), 'location': list(obj.location),
               'dimensions': list(obj.dimensions), 'modifiers': [m.type for m in obj.modifiers]}
        if obj.vertex_groups:
            totals=[sum(g.weight for g in v.groups) for v in mesh.vertices]
            row['unweighted_vertices']=sum(t<.999 for t in totals)
            row['max_weight_sum_error']=max(abs(t-1) for t in totals)
        bm.free(); result['triangles'] += row['triangles']; result['meshes'].append(row)
    for obj in scene.objects:
        if obj.type == 'ARMATURE':
            result['rigs'].append({'name': obj.name, 'bone_count': len(obj.data.bones),
                'bones': [{'name': b.name, 'parent': b.parent.name if b.parent else None,
                           'head': list(b.head_local), 'tail': list(b.tail_local)} for b in obj.data.bones]})
    result['inspection_limits'] = 'Internal/intersecting surfaces require visual inspection; edge metrics do not prove their absence.'
    return result


def setup_views(scene, prefix, front_y=1):
    # Neutral workbench render is deliberately independent of lights and PBR maps.
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.render.resolution_x = scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.background_type = 'WORLD'
    scene.world = bpy.data.worlds.new(prefix + '_NeutralWorld')
    scene.world.color = (0.18, 0.20, 0.22)
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'Medium High Contrast' if 'Medium High Contrast' in [i.identifier for i in scene.bl_rna.properties] else 'None'
    meshes = [o for o in scene.objects if o.type == 'MESH' and not o.hide_render]
    points = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = (low+high)/2; size = max(high-low)*1.28
    views = {'front': (0, front_y, .10), 'left': (-1, 0, .12),
             'back': (0, -front_y, .10), 'three_quarter': (-.82, front_y, .48)}
    for label, direction in views.items():
        camera = bpy.data.objects.new(prefix+'_'+label, bpy.data.cameras.new(prefix+'_'+label))
        scene.collection.objects.link(camera)
        camera.location = center + Vector(direction).normalized()*size*2
        camera.rotation_euler = (center-camera.location).to_track_quat('-Z', 'Y').to_euler()
        camera.data.type, camera.data.ortho_scale = 'ORTHO', size
    scene.camera = scene.objects[prefix+'_three_quarter']
    if bpy.context.window:
        for area in bpy.context.window.screen.areas:
            if area.type == 'VIEW_3D':
                area.spaces.active.region_3d.view_rotation = scene.camera.rotation_euler.to_quaternion()
                area.spaces.active.region_3d.view_distance = size*1.5
                area.spaces.active.region_3d.view_location = center
    return {'bounds_min': list(low), 'bounds_max': list(high), 'camera_names': [prefix+'_'+v for v in views]}


def main(operation: str, parameters: Dict):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for folder in ('source', 'blender', 'export', 'preview', 'metadata'):
        (OUTPUT/folder).mkdir(exist_ok=True)
    scene = bpy.context.scene
    assert scene.name.startswith('MonCook_'), 'Refuse to edit artist scene'
    if operation == 'audit_v1':
        for obj in scene.objects:
            if obj.type == 'ARMATURE':
                obj.animation_data_clear()
                for bone in obj.pose.bones: bone.matrix_basis.identity()
        scene.frame_set(1); bpy.context.view_layer.update()
        for obj in scene.objects:
            if 'HornBroken' in obj.name: obj.hide_render = True
        report = audit(scene)
        report.update(setup_views(scene, 'V1', front_y=1))
        report['source_commit'] = parameters['commit']
        report['source_file'] = 'art/exports/Monsters/MON_Hornboar_V1.fbx'
        (OUTPUT/'metadata/v1_analysis.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        bpy.data.libraries.write(str(OUTPUT/'blender/V1_reference.blend'), {scene}, fake_user=True)
        print(json.dumps({k: report[k] for k in ('triangles','mesh_count','material_count','texture_count','camera_names')}))
    elif operation == 'audit_candidate':
        report = audit(scene)
        report.update(setup_views(scene, parameters['prefix'], front_y=parameters.get('front_y', 1)))
        (OUTPUT/('metadata/'+parameters['prefix']+'_analysis.json')).write_text(json.dumps(report, indent=2), encoding='utf-8')
        print(json.dumps({k: report[k] for k in ('triangles','mesh_count','material_count','texture_count','camera_names','meshes')}))
    elif operation == 'optimize':
        optimize(parameters)
    elif operation == 'animate':
        animate(parameters)
    elif operation == 'polish':
        assert scene.name=='MonCook_V2_Final'
        atlas=next(n.image for obj in scene.objects if obj.type=='MESH' for mat in obj.data.materials if mat and mat.use_nodes
                   for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
        assert not atlas.get('ArtPass'), 'Palette pass already applied'
        pixels=list(atlas.pixels[:])
        for index in range(0,len(pixels),4):
            pixels[index]=min(1,pixels[index]*1.30+.025)
            pixels[index+1]=min(1,pixels[index+1]*1.27+.02)
            pixels[index+2]=min(1,pixels[index+2]*1.20+.012)
        atlas.pixels[:]=pixels;atlas['ArtPass']='bright fantasy diffuse';atlas.save();atlas.pack()
        for obj in scene.objects:
            if obj.type=='MESH':
                for mat in obj.data.materials:
                    if mat and mat.use_nodes:
                        shader=mat.node_tree.nodes.get('Principled BSDF')
                        if shader:shader.inputs['Metallic'].default_value=0;shader.inputs['Roughness'].default_value=.85
        scene.display.shading.show_specular_highlight=False
        scene.display.shading.show_cavity=False
        bpy.data.libraries.write(str(OUTPUT/'blender/MON_Hornboar_V2.blend'),{scene},fake_user=True)
        print('Atlas diffuse palette brightened; metallic removed; raw Tripo textures untouched')
    elif operation == 'audit_final':
        assert scene.name=='MonCook_V2_Final'
        bpy.context.view_layer.update()
        report=audit(scene)
        previous=json.loads((OUTPUT/'metadata/v2_analysis.json').read_text(encoding='utf-8'))
        for key in ('original_triangles','scale_studs','forward','removed_helper','rig_repair','bounds_min','bounds_max','camera_names'):report[key]=previous[key]
        (OUTPUT/'metadata/v2_analysis.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
        print(json.dumps(report['meshes']))
    elif operation == 'repack_atlas':
        assert scene.name=='MonCook_V2_Final'
        atlas=next(n.image for obj in scene.objects if obj.type=='MESH' for mat in obj.data.materials if mat and mat.use_nodes
                   for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
        path=OUTPUT/'export/Hornboar_BaseColor_512.png'
        data=path.read_bytes()
        assert data[:8]==b'\x89PNG\r\n\x1a\n'
        if atlas.packed_file:atlas.unpack(method='REMOVE')
        atlas.filepath_raw=str(path)
        # Refresh decoded pixels and file format too: GLTF may re-encode pixels,
        # whereas FBX copies packed bytes. Both must see the authored PNG palette.
        atlas.reload()
        atlas.pack(data=data,data_len=len(data))
        assert bytes(atlas.packed_file.data)==data
        # FBX COPY mode keeps an already existing .fbm image; synchronize that
        # sidecar explicitly so Studio cannot prefer the old JPEG over embedded PNG.
        for stem in ('MON_Hornboar_V2','MON_Hornboar_V2_Studio'):
            directory=OUTPUT/'export'/(stem+'.fbm');directory.mkdir(exist_ok=True)
            (directory/'Hornboar_BaseColor_512.png').write_bytes(data)
        bpy.data.libraries.write(str(OUTPUT/'blender/MON_Hornboar_V2.blend'),{scene},fake_user=True)
        print('Packed image now equals authored 512 PNG, not stale Tripo JPEG')
    elif operation == 'prepare_export':
        assert scene.name == 'MonCook_V2_Final'
        if parameters.get('camera'):scene.camera=scene.objects[parameters['camera']]
        rig=next(o for o in scene.objects if o.type=='ARMATURE')
        for track in rig.animation_data.nla_tracks:track.mute=True
        rig.animation_data.action=bpy.data.actions.get('HBV2_'+parameters.get('clip',''))
        for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
        scene.frame_start=1;scene.frame_end=parameters.get('end_frame',1)
        scene.frame_set(parameters.get('frame',1))
        for obj in scene.objects:obj.select_set(obj.type in ('MESH','ARMATURE'))
        for obj in scene.objects:
            if obj.name=='Horn_Intact':obj.hide_render=parameters.get('broken',False)
            if obj.name=='Horn_Broken':obj.hide_render=not parameters.get('broken',False)
        bpy.context.view_layer.objects.active=rig
        print(json.dumps({'selected':[o.name for o in scene.objects if o.select_get()],'clip':parameters.get('clip')}))
    elif operation == 'prepare_studio_export':
        assert scene.name=='MonCook_V2_Final'
        rig=next(o for o in scene.objects if o.type=='ARMATURE')
        rig.rotation_euler.z=math.pi
        scene.objects['Head'].name='HeadVisual'
        bpy.context.view_layer.update()
        print('Studio export: compensate importer forward, HeadVisual avoids Head Bone/mesh name collapse')
    elif operation == 'restore_studio_export':
        assert scene.name=='MonCook_V2_Final'
        rig=next(o for o in scene.objects if o.type=='ARMATURE')
        rig.rotation_euler.z=0
        scene.objects['HeadVisual'].name='Head'
        bpy.context.view_layer.update()
        print('Canonical Blender scene restored')
    else:
        raise ValueError(operation)


def optimize(parameters):
    source_scene = bpy.context.scene
    source = next(o for o in source_scene.objects if o.type == 'MESH' and o.modifiers)
    source_rig = next(o for o in source_scene.objects if o.type == 'ARMATURE')
    assert source.data.polygons and len(source_rig.data.bones) == 25
    assert 'MonCook_V2_Final' not in bpy.data.scenes, 'Do not blindly replay optimization'
    scene = bpy.data.scenes.new('MonCook_V2_Final'); bpy.context.window.scene = scene
    obj = source.copy()
    depsgraph=bpy.context.evaluated_depsgraph_get()
    obj.data=bpy.data.meshes.new_from_object(source.evaluated_get(depsgraph),preserve_all_data_layers=True,depsgraph=depsgraph)
    obj.name = 'ProcessingBody'
    obj.parent = None; scene.collection.objects.link(obj)
    obj.modifiers.clear()
    # Tripo's +X forward becomes Blender +Y, i.e. Roblox -Z. Match existing hitbox bounds.
    scale = 11.70
    original_world = source.matrix_world.copy()
    ground=min((original_world@v.co).z for v in obj.data.vertices)
    mat = Matrix.Translation((0,1.10,-ground*scale)) @ Matrix.Rotation(math.pi/2,4,'Z') @ Matrix.Scale(scale,4)
    for vertex in obj.data.vertices: vertex.co = mat @ original_world @ vertex.co
    obj.matrix_world=Matrix.Identity(4)
    bpy.context.view_layer.objects.active = obj; obj.select_set(True)
    original_triangles = len(obj.data.polygons)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.00001)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=0.00001)
    # Remove exact duplicate triangle topology after UV/normal-seam vertex welding.
    seen=set(); duplicates=[]
    for face in bm.faces:
        key=tuple(sorted(tuple(round(v,6) for v in vert.co) for vert in face.verts))
        if key in seen: duplicates.append(face)
        seen.add(key)
    if duplicates: bmesh.ops.delete(bm,geom=duplicates,context='FACES')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    # Correct the auto-rig's asymmetric 25-bone layout to the established 14-bone semantics.
    # Retain its useful skin weights, collapse redundant bridge/end bones, then patch horn/tail.
    mapping = {'tripo::Root':'Spine','tripo::Spine_0':'Spine','tripo::Spine_1':'Spine',
        'tripo::Head_0':'Neck','tripo::Head_1':'Head','tripo::Head_2':'Head','bone_6':'Spine',
        'tripo::0_Left_Limb_0':'FrontLeg_L','tripo::0_Left_Limb_1':'FrontShin_L','tripo::0_Left_Limb_2':'FrontShin_L',
        'tripo::0_Right_Limb_0':'Spine','tripo::0_Right_Limb_1':'FrontLeg_R','tripo::0_Right_Limb_2':'FrontShin_R','tripo::0_Right_Limb_3':'FrontShin_R',
        'tripo::1_Left_Limb_0':'Spine','bone_15':'BackLeg_L','bone_16':'BackShin_L','bone_17':'BackShin_L',
        'tripo::1_Left_Limb_1':'Spine','bone_19':'BackLeg_R','bone_20':'BackShin_R','bone_21':'BackShin_R',
        'tripo::1_Left_Limb_2':'Tail','tripo::1_Left_Limb_3':'Spine','tripo::1_Left_Limb_4':'Spine'}
    old_groups={g.index:g.name for g in obj.vertex_groups}
    weights=[]
    for vert in obj.data.vertices:
        row={}
        for group in vert.groups:
            name=mapping.get(old_groups[group.group],'Spine')
            row[name]=row.get(name,0)+group.weight
        if vert.co.y>3.4 and vert.co.z>3.95 and abs(vert.co.x)<.79: row={'Horn':1}
        elif vert.co.y < -3.65 and vert.co.z > 2: row={'Tail':1}
        total=sum(row.values());weights.append({k:v/total for k,v in row.items()} if total else {'Spine':1})
    obj.vertex_groups.clear()
    import sys
    sys.path.insert(0,str(PROJECT/'art'))
    from hornboar_design import RIG
    rig=bpy.data.objects.new('HornboarRig',bpy.data.armatures.new('HornboarRig'))
    scene.collection.objects.link(rig)
    obj.select_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name,definition in RIG.items():
        bone=rig.data.edit_bones.new(name);p=definition['position']
        bone.head=(p[0],-p[2],p[1])
        bone.tail=bone.head+Vector((0,0,.5))
        if definition['parent']: bone.parent=rig.data.edit_bones[definition['parent']]
    bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)
    for name in RIG: obj.vertex_groups.new(name=name)
    for index,row in enumerate(weights):
        for name,value in row.items(): obj.vertex_groups[name].add([index],value,'REPLACE')
    obj.select_set(True);bpy.context.view_layer.objects.active=obj
    # Extract horn first. Partition the remaining surface by skin semantics: head,
    # body/tail, and a single four-leg skinned mesh. No dozens of tiny MeshParts.
    partitions={'Body':[], 'Head':[], 'Legs':[], 'Horn_Intact':[]}
    for face in obj.data.polygons:
        center=face.center
        row={}
        for index in face.vertices:
            for group in obj.data.vertices[index].groups:
                name=obj.vertex_groups[group.group].name;row[name]=row.get(name,0)+group.weight
        if center.y>3.45 and center.z>3.97 and abs(center.x)<.80: name='Horn_Intact'
        elif sum(v for k,v in row.items() if 'Leg_' in k or 'Shin_' in k)>1.55: name='Legs'
        elif row.get('Head',0)+row.get('Neck',0)>1.55: name='Head'
        else:name='Body'
        partitions[name].append(face.index)
    parts=[]
    for name,indices in partitions.items():
        assert indices, name+' partition empty'
        part=obj.copy();part.data=obj.data.copy();part.name=name;scene.collection.objects.link(part)
        bm=bmesh.new();bm.from_mesh(part.data);bm.faces.ensure_lookup_table()
        discard=[f for f in bm.faces if f.index not in set(indices)]
        bmesh.ops.delete(bm,geom=discard,context='FACES')
        loose=[v for v in bm.verts if not v.link_faces]
        if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
        bm.to_mesh(part.data);bm.free();part.data.update()
        part['RobloxBinding']='HornIntact' if name=='Horn_Intact' else 'Visual'
        mod=part.modifiers.new('HornboarSkin','ARMATURE');mod.object=rig
        part.parent=rig;parts.append(part)
    scene.collection.objects.unlink(obj);bpy.data.objects.remove(obj,do_unlink=True)
    intact=next(p for p in parts if p.name=='Horn_Intact')
    broken=intact.copy();broken.data=intact.data.copy();broken.name='Horn_Broken';scene.collection.objects.link(broken)
    bm=bmesh.new();bm.from_mesh(broken.data)
    cut=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,
                              plane_co=(0,4.40,0),plane_no=(0,1,0),clear_outer=True,clear_inner=False)
    boundary=[e for e in cut['geom_cut'] if isinstance(e,bmesh.types.BMEdge) and e.is_boundary]
    if boundary:
        fill=bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
        for face in fill['faces']:
            face.material_index=1
            for loop in face.loops:
                if bm.loops.layers.uv.active:loop[bm.loops.layers.uv.active].uv=(.5,.5)
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(broken.data);bm.free();broken.data.update()
    broken['RobloxBinding']='HornBroken';broken.hide_render=True;parts.append(broken)
    core=bpy.data.materials.new('HornCore_Fracture');core.diffuse_color=(.15,.80,.70,1);core.use_nodes=True
    core.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.15,.80,.70,1)
    broken.data.materials.append(core)
    # One 512 atlas. Duplicate imported image before resizing to preserve all raw candidates.
    material=parts[0].data.materials[0].copy();material.name='Hornboar_Atlas'
    image_node=next(n for n in material.node_tree.nodes if n.type=='TEX_IMAGE')
    atlas=image_node.image.copy();atlas.name='Hornboar_BaseColor_512';atlas.scale(512,512)
    atlas.filepath_raw=str(OUTPUT/'export/Hornboar_BaseColor_512.png');atlas.file_format='PNG';atlas.save();atlas.pack()
    image_node.image=atlas
    for part in parts:
        part.data.materials[0]=material
        for poly in part.data.polygons:poly.use_smooth=False
    scene.render.fps=60
    scene.frame_start,scene.frame_end=1,133
    rig['RigSource']='Tripo quadruped weights, corrected semantic skeleton in Blender'
    report=audit(scene);report['original_triangles']=original_triangles
    report['scale_studs']=scale;report['forward']='Blender +Y / Roblox -Z'
    report['removed_helper']='Tripo Icosphere armature display helper excluded from production scene'
    report['rig_repair']='25 asymmetric bones collapsed to 14 canonical bones; skin weights remapped and normalized'
    report.update(setup_views(scene,'V2',1))
    assert 2500<=report['triangles']<=3500 and report['mesh_count']==5 and report['material_count']<=2
    (OUTPUT/'metadata/v2_analysis.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    bpy.data.libraries.write(str(OUTPUT/'blender/MON_Hornboar_V2.blend'),{scene},fake_user=True)
    print(json.dumps({k:report[k] for k in ('triangles','original_triangles','mesh_count','material_count','texture_count','bounds_min','bounds_max')}))


def animate(parameters):
    scene=bpy.context.scene;assert scene.name=='MonCook_V2_Final'
    rig=next(o for o in scene.objects if o.type=='ARMATURE');rig.animation_data_create()
    if parameters.get('replace'):
        rig.animation_data.action=None
        for track in list(rig.animation_data.nla_tracks):
            if all(strip.action and strip.action.name.startswith('HBV2_') for strip in track.strips):rig.animation_data.nla_tracks.remove(track)
        for action in list(bpy.data.actions):
            if action.name.startswith('HBV2_'):bpy.data.actions.remove(action)
    source=json.loads((OUTPUT/'metadata/hornboar_clip_samples.json').read_text(encoding='utf-8-sig'))
    conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    result={}
    for name,clip in source.items():
        action=bpy.data.actions.new('HBV2_'+name);action.use_fake_user=True;rig.animation_data.action=action
        for frame,poses in clip['Frames'].items():
            for bone in rig.pose.bones:
                pose=poses.get(bone.name,{})
                delta=Matrix.Translation((pose.get('X',0),pose.get('Y',0)+pose.get('Lift',0),pose.get('Z',0)))
                delta=delta@Matrix.Rotation(pose.get('Pitch',0),4,'X')@Matrix.Rotation(pose.get('Yaw',0),4,'Y')@Matrix.Rotation(pose.get('Roll',0),4,'Z')
                delta=conversion@delta@conversion.inverted()
                axes=bone.bone.matrix_local.to_3x3().to_4x4()
                bone.matrix_basis=axes.inverted()@delta@axes
                bone.rotation_mode='QUATERNION'
                bone.keyframe_insert('rotation_quaternion',frame=int(frame)+1,group=bone.name)
                bone.keyframe_insert('location',frame=int(frame)+1,group=bone.name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for point in curve.keyframe_points:point.interpolation='LINEAR'
        track=rig.animation_data.nla_tracks.new();track.name=name
        track.strips.new(name,1,action);track.mute=True
        result[name]={'duration':clip['Duration'],'frames':len(clip['Frames']),'bones':len(rig.data.bones),
                      'last_frame':max(int(f) for f in clip['Frames'])+1}
    rig.animation_data.action=None
    for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    scene.frame_set(1)
    bpy.data.libraries.write(str(OUTPUT/'blender/MON_Hornboar_V2.blend'),{scene},fake_user=True)
    (OUTPUT/'metadata/animations.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result))
