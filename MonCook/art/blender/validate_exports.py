"""Re-import every generated FBX in Blender and verify mesh/rig/action output."""
from __future__ import annotations
import json
from pathlib import Path
import bpy

ART = Path(__file__).resolve().parents[1]
manifest = json.loads((ART / "asset_manifest.json").read_text())
results = {}
for asset_id, entry in manifest["assets"].items():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions): bpy.data.actions.remove(action)
    bpy.ops.import_scene.fbx(filepath=str(ART / entry["fbx"]), use_anim=True)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    triangles = sum(sum(len(face.vertices)-2 for face in obj.data.polygons) for obj in meshes)
    assert triangles == entry["blender_triangles"], (asset_id, triangles, entry["blender_triangles"])
    bones = [bone.name for rig in rigs for bone in rig.data.bones]
    for bone in entry["bones"]: assert bone in bones, (asset_id, "missing bone", bone)
    actions = [action.name for action in bpy.data.actions]
    for action in entry["source_actions"]:
        assert any(name.endswith("|"+action) or name == action for name in actions), (asset_id, "missing action", action, actions)
    assert len(meshes) == entry["objects"], (asset_id, "mesh object count mismatch")
    for obj in meshes:
        assert all(v.co.length < 1000 for v in obj.data.vertices), (asset_id, "invalid vertex")
        if rigs: assert obj.vertex_groups and any(mod.type == "ARMATURE" for mod in obj.modifiers), (asset_id, "unbound mesh", obj.name)
    results[asset_id] = {"triangles": triangles, "mesh_objects": len(meshes), "bones": bones,
                         "imported_actions": actions, "fbx_reimport": "PASS"}
    print(f"FBX REIMPORT PASS {asset_id}: {triangles} triangles, {len(bones)} bones, {len(actions)} actions", flush=True)
    if entry.get('studio_fbx'):
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
        for action in list(bpy.data.actions):bpy.data.actions.remove(action)
        bpy.ops.import_scene.fbx(filepath=str(ART/entry['studio_fbx']),use_anim=True)
        studio_meshes=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
        studio_rigs=[obj for obj in bpy.context.scene.objects if obj.type=='ARMATURE']
        assert sum(sum(len(f.vertices)-2 for f in obj.data.polygons) for obj in studio_meshes)==entry['blender_triangles']
        assert len(studio_meshes)==entry['studio_mesh_objects']==3 and not bpy.data.actions
        assert {b.name for r in studio_rigs for b in r.data.bones}==set(entry['bones'])
        assert all(obj.vertex_groups and any(m.type=='ARMATURE' for m in obj.modifiers) for obj in studio_meshes)
        assert {obj.name for obj in studio_meshes}=={'Hornboar_Visual','Hornboar_HornIntact','Hornboar_HornBroken'}
        # Joining the Studio body must preserve deform weights for every leg/head.
        weighted={g.name for obj in studio_meshes for g in obj.vertex_groups if any(any(w.group==g.index and w.weight>0 for w in v.groups) for v in obj.data.vertices)}
        assert weighted==set(entry['bones'])-{'Root'}
        results[asset_id]['studio_fbx_reimport']='PASS'
        print(f"STUDIO FBX REIMPORT PASS {asset_id}: {len(studio_meshes)} meshes, 14 bones, no baked clips",flush=True)
    if entry.get('studio_rigid_fbx'):
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
        for action in list(bpy.data.actions):bpy.data.actions.remove(action)
        bpy.ops.import_scene.fbx(filepath=str(ART/entry['studio_rigid_fbx']),use_anim=True)
        rigid_meshes=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
        assert len(rigid_meshes)==14
        assert sum(sum(len(f.vertices)-2 for f in obj.data.polygons) for obj in rigid_meshes)==entry['blender_triangles']
        assert not bpy.data.actions and not any(obj.type=='ARMATURE' for obj in bpy.context.scene.objects)
        expected={'Torso','NeckMass','Head','Tail','Horn_Intact','Horn_Broken'}
        expected|={p+s+t for p in ('Front','Back') for s in ('Leg_L','Leg_R','Shin_L','Shin_R') for t in ('_Lower' if 'Shin' in s else '_Upper',)}
        assert {obj.name for obj in rigid_meshes}==expected
        results[asset_id]['studio_rigid_fbx_reimport']='PASS'
        print('STUDIO RIGID FBX REIMPORT PASS: 14 compatible named meshes, 1500 triangles',flush=True)
(ART / "export_validation.json").write_text(json.dumps(results, ensure_ascii=False, indent=2)+"\n")
print("All real FBX exports re-imported successfully.", flush=True)
