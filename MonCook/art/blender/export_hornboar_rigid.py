"""Export lightweight separate meshes compatible with the existing Studio Motor6D rig."""
from pathlib import Path
import json
import bpy

ART = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ART/'blender/Hornboar/MON_Hornboar_V1.blend'))
bpy.context.scene.frame_set(0)
originals = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
clones = []
for original in originals:
    obj = original.copy(); obj.data = original.data.copy()
    bpy.context.collection.objects.link(obj)
    matrix = original.matrix_world.copy(); obj.parent = None; obj.matrix_world = matrix
    for modifier in list(obj.modifiers):
        if modifier.type == 'ARMATURE': obj.modifiers.remove(modifier)
    obj.vertex_groups.clear()
    bone, binding = original['RobloxBone'], original['RobloxBinding']
    if binding == 'HornIntact': obj.name = 'Horn_Intact'
    elif binding == 'HornBroken': obj.name = 'Horn_Broken'
    elif bone == 'Spine': obj.name = 'Torso'
    elif bone == 'Neck': obj.name = 'NeckMass'
    elif 'Shin' in bone: obj.name = bone+'_Lower'
    elif 'Leg' in bone: obj.name = bone+'_Upper'
    else: obj.name = bone
    clones.append(obj)
bpy.ops.object.select_all(action='DESELECT')
for obj in clones: obj.select_set(True)
output = ART/'exports/Monsters/MON_Hornboar_V1_Studio_Rigid.fbx'
bpy.ops.export_scene.fbx(filepath=str(output),use_selection=True,object_types={'MESH'},bake_anim=False,
                         axis_forward='-Z',axis_up='Y',use_custom_props=False)
for obj in clones: bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.object.select_all(action='SELECT')
manifest_path = ART/'asset_manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest['assets']['MON_Hornboar_V1']['studio_rigid_fbx'] = str(output.relative_to(ART))
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
print('STUDIO RIGID FBX:',output.stat().st_size,'bytes, 14 named meshes; existing Motor6D rig remains external',flush=True)
