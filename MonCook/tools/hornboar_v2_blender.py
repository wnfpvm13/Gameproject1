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
from mathutils import Vector

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
    scene.display.shading.color_type = 'MATERIAL'
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
        print(json.dumps(report))
    else:
        raise ValueError(operation)
