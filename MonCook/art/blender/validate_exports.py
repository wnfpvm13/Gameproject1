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
(ART / "export_validation.json").write_text(json.dumps(results, ensure_ascii=False, indent=2)+"\n")
print("All real FBX exports re-imported successfully.", flush=True)
