"""Run with Blender 4.3+: blender --background --python art/blender/build_assets.py.

Produces real triangulated .blend/.fbx/.glb assets and calls the redesigned
Hornboar mesh builder (14 bones / 13 actions) with measured manifests/previews. Native Roblox model equivalents
are generated separately from the same authored specification.
"""
from __future__ import annotations
import json
import math
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector

ART = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ART))
from model_spec import catalog


def convert(p):
    return (p[0], -p[2], p[1])


def material(color):
    key = "Palette_" + "_".join(str(round(c*255)) for c in color)
    m = bpy.data.materials.get(key) or bpy.data.materials.new(key)
    linear = tuple(c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4 for c in color)
    m.diffuse_color = (*linear, 1)
    m.use_nodes = True
    shader = m.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*linear, 1)
    shader.inputs["Roughness"].default_value = 0.72
    return m


def mesh_part(spec, bevel_segments=2):
    kind = spec["kind"]
    if kind == "Ellipsoid":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=spec["segments"], ring_count=spec["rings"], radius=1)
    elif kind == "Cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=spec["segments"], radius=1, depth=2)
    elif kind == "Cone":
        bpy.ops.mesh.primitive_cone_add(vertices=spec["segments"], radius1=1, radius2=0.12, depth=2)
    elif kind == "Wedge":
        mesh = bpy.data.meshes.new(spec["name"])
        mesh.from_pydata([(-1,-1,-1),(1,-1,-1),(-1,1,-1),(1,1,-1),(-1,1,1),(1,1,1)], [],
                         [(0,2,3,1),(2,4,5,3),(0,1,5,4),(0,4,2),(1,3,5)])
        obj = bpy.data.objects.new(spec["name"], mesh)
        bpy.context.collection.objects.link(obj)
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
    else:
        bpy.ops.mesh.primitive_cube_add(size=2)
    obj = bpy.context.object
    obj.name = spec["name"]
    # Cylinder/cone longitudinal direction is Blender Z == Roblox Y.
    obj.scale = tuple(c/2 for c in convert((spec["size"][0], spec["size"][1], -spec["size"][2])))
    obj.location = convert(spec["position"])
    rotation = spec["rotation"]
    obj.rotation_euler = tuple(math.radians(v) for v in (rotation[0], -rotation[2], rotation[1]))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if kind == "Box" and spec["bevel"] > 0:
        modifier = obj.modifiers.new("CraftedEdges", "BEVEL")
        modifier.width = spec["bevel"]
        modifier.segments = bevel_segments
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    triangulate = obj.modifiers.new("GameTriangles", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    obj.data.materials.append(material(spec["color"]))
    obj["RobloxBinding"] = spec["binding"]
    obj["RobloxBone"] = spec["bone"]
    if spec["binding"] == "HornBroken":
        obj.hide_render = True
    return obj


def rig_asset(asset, parts):
    arm = bpy.data.armatures.new("Rig")
    rig = bpy.data.objects.new("Rig", arm)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, definition in asset["rig"].items():
        bone = arm.edit_bones.new(name)
        bone.head = convert(definition["position"])
        tail = Vector(bone.head) + Vector((0, 0, 0.8 if name == "Root" else 0.55))
        if "Leg" in name:
            tail = Vector(bone.head) + Vector((0, 0, -1.8))
        bone.tail = tail
        if definition["parent"]:
            bone.parent = arm.edit_bones[definition["parent"]]
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj, spec in parts:
        group = obj.vertex_groups.new(name=spec["bone"])
        group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        modifier = obj.modifiers.new("HornboarRig", "ARMATURE")
        modifier.object = rig
        obj.parent = rig
    rig.animation_data_create()
    actions = ("Idle", "Walk", "Run", "Alert", "ChargeWindup", "Charge", "Headbutt", "HitReact", "Stagger", "Death")
    for name in actions:
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        duration = 32 if name == "Death" else 24
        for frame in (0, duration//2, duration):
            t = frame/duration
            for bone in rig.pose.bones:
                bone.rotation_mode = "XYZ"
                bone.rotation_euler = (0, 0, 0)
                bone.location = (0, 0, 0)
                if "Leg" in bone.name and name in ("Walk", "Run", "Charge"):
                    opposite = -1 if bone.name in ("FrontLeg_R", "BackLeg_L") else 1
                    bone.rotation_euler.x = math.sin(t*math.pi*2+math.pi/2)*opposite*(0.38 if name == "Walk" else 0.65)
                if bone.name == "Spine":
                    bone.location.z = math.sin(t*math.pi)*(0.06 if name == "Idle" else 0.12)
                    if name == "ChargeWindup": bone.rotation_euler.x = -0.13*math.sin(t*math.pi)
                    if name == "Death": bone.rotation_euler.y = 1.2*t
                    if name == "HitReact": bone.rotation_euler.y = 0.12*math.sin(t*math.pi)
                    if name == "Stagger": bone.rotation_euler.y = 0.20*math.sin(t*math.pi*2)
                if bone.name == "Head":
                    bone.rotation_euler.x = (0.2*math.sin(t*math.pi) if name in ("Alert", "Headbutt") else -0.10*math.sin(t*math.pi))
                bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone.name)
                bone.keyframe_insert(data_path="location", frame=frame, group=bone.name)
        for curve in action.fcurves:
            for key in curve.keyframe_points: key.interpolation = "LINEAR"
    rig.animation_data.action = bpy.data.actions["Idle"]
    bpy.context.scene.frame_set(0)
    return rig, list(actions)


def preview_scene(target, distance, output, ground_height=-0.03):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 600
    scene.render.resolution_y = 600
    scene.render.resolution_percentage = 100
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.72, 0.85, 0.92, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.65
    bpy.ops.object.light_add(type="AREA", location=(7, 4, 13))
    light = bpy.context.object; light.data.energy = 1700; light.data.shape = "DISK"; light.data.size = 8
    light.rotation_euler = (Vector(target)-light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, ground_height))
    ground = bpy.context.object; ground.data.materials.append(material((0.63, 0.77, 0.37)))
    bpy.ops.object.camera_add(location=Vector(target)+Vector((distance*0.68, distance*0.70, distance*0.27)))
    camera = bpy.context.object; camera.data.lens = 42
    camera.rotation_euler = (Vector(target)-camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)
    for obj in (camera, light, ground): bpy.data.objects.remove(obj, do_unlink=True)


def main():
    manifest = {"coordinate_system": "Roblox X/right Y/up -Z/forward", "assets": {}}
    for asset_id, asset in catalog().items():
        if asset_id == "MON_Hornboar_V1": continue
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.object.delete(use_global=False)
        # Clear previous objects/actions so exported actions belong to this rig only.
        for action in list(bpy.data.actions): bpy.data.actions.remove(action)
        parts = []
        for spec in asset["parts"]:
            bpy.ops.object.select_all(action="DESELECT")
            obj = mesh_part(spec)
            parts.append((obj, spec))
        bones, actions = [], []
        if asset["rig"]:
            rig, actions = rig_asset(asset, parts)
            bones = list(asset["rig"])
        triangles = sum(len(obj.data.polygons) for obj, _ in parts)
        family = asset["family"]
        source = ART / "blender" / ("Hornboar" if family == "Monsters" else "StarterCleaver" if family == "Weapons" else family) / asset_id
        source.parent.mkdir(parents=True, exist_ok=True)
        export = ART / "exports" / family / asset_id
        export.parent.mkdir(parents=True, exist_ok=True)
        bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, 32
        bpy.ops.wm.save_as_mainfile(filepath=str(source.with_suffix(".blend")), compress=True)
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.fbx(filepath=str(export.with_suffix(".fbx")), use_selection=True,
            add_leaf_bones=False, bake_anim=bool(actions), bake_anim_use_all_actions=True,
            axis_forward="-Z", axis_up="Y", use_mesh_modifiers=True)
        bpy.ops.export_scene.gltf(filepath=str(export.with_suffix(".glb")), export_format="GLB", use_selection=True,
            export_animations=False, export_yup=True)
        manifest["assets"][asset_id] = {"family": family, "status": "V1", "blender_triangles": triangles,
            "objects": len(parts), "bones": bones, "source_actions": actions,
            "runtime_representation": "native Roblox primitive equivalent; not an imported mesh",
            "source": str(source.with_suffix(".blend").relative_to(ART)),
            "fbx": str(export.with_suffix(".fbx").relative_to(ART)), "glb": str(export.with_suffix(".glb").relative_to(ART))}
        print(f"ASSET {asset_id}: {triangles} triangles, {len(bones)} bones, {len(actions)} actions", flush=True)
        if asset_id == "MON_Hornboar_V1":
            preview = ART / "previews"; preview.mkdir(exist_ok=True)
            for label, distance in (("Close", 18), ("Medium", 28), ("Far", 48)):
                preview_scene((0, 1.7, 2.2), distance, preview / f"Hornboar_{label}.png")
    manifest["assets"]["MON_Hornboar_V1"] = {"family":"Monsters", "source":"blender/Hornboar/MON_Hornboar_V1.blend", "fbx":"exports/Monsters/MON_Hornboar_V1.fbx", "glb":"exports/Monsters/MON_Hornboar_V1.glb"}
    (ART / "asset_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n")
    import runpy
    runpy.run_path(str(ART / "blender/redesign_hornboar.py"), run_name="__main__")
    print("Asset source/export/manifest generation finished.", flush=True)


if __name__ == "__main__":
    main()
