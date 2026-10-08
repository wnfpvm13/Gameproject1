"""Validate generated art, native model references and source in a Rojo Studio place.

This is a serialization/asset check. It does not execute Roblox Studio or claim
PC/Touch/multiplayer/animation playback acceptance.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

PROJECT = Path(__file__).resolve().parent.parent


def name(item):
    return next((p.text for p in item.find("Properties") if p.attrib.get("name") == "Name"), "")


def props(item):
    return {p.attrib["name"]: p for p in item.find("Properties")}


def index(root):
    result = {}
    def visit(parent, prefix=()):
        for item in parent.findall("Item"):
            path = (*prefix, name(item))
            result["/".join(path)] = item
            visit(item, path)
    visit(root)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--place", type=Path)
    parser.add_argument("--art-only", action="store_true", help="Validate source/export geometry without claiming runtime asset availability")
    args = parser.parse_args()
    if not args.art_only and args.place is None:parser.error("--place is required unless --art-only is used")
    art = PROJECT / "art"
    source = json.loads((art / "asset_manifest.json").read_text())
    native = json.loads((art / "runtime_manifest.json").read_text())["baseparts"]
    exports = json.loads((art / "export_validation.json").read_text())
    topology = json.loads((art / "hornboar_mesh.json").read_text())
    hornboar = source["assets"]["MON_Hornboar_V1"]
    assert topology["SourceSHA256"] == hashlib.sha256((art / hornboar["source"]).read_bytes()).hexdigest()
    assert topology["TriangleCount"] == hornboar["blender_triangles"] == sum(len(g["Faces"]) for g in topology["Groups"])
    imported = json.loads((art / "imported_hornboar.json").read_text())
    imported_path = art / "runtime" / "Monsters" / "MON_Hornboar_V1.rbxm"
    if not args.art_only:
        assert imported_path.is_file(), "Studio-imported .rbxm is absent; supply the original asset before validating a play file"
        assert imported_path.stat().st_size == imported["size_bytes"]
        assert hashlib.sha256(imported_path.read_bytes()).hexdigest() == imported["sha256"]
    bounds = []
    for group in topology["Groups"]:
        assert group["Bone"] in hornboar["bones"]
        for vertex in group["Vertices"]:
            assert len(vertex) == 3 and all(abs(v) < 100 for v in vertex)
        for face in group["Faces"]:
            assert len(face) == 4 and all(1 <= index <= len(group["Vertices"]) for index in face[:3])
            assert 1 <= face[3] <= len(topology["Palette"])
            a,b,c = (group["Vertices"][i-1] for i in face[:3])
            u,v = [b[i]-a[i] for i in range(3)], [c[i]-a[i] for i in range(3)]
            assert sum((u[(i+1)%3]*v[(i+2)%3]-u[(i+2)%3]*v[(i+1)%3])**2 for i in range(3)) > 1e-14
        if group["Binding"] == "Visual" and group["Bone"] != "Tail":
            bounds.extend([[v[i]+group["Center"][i] for i in range(3)] for v in group["Vertices"]])
        if group["Binding"] == "HornIntact":
            horn_vertices = [[v[i]+group["Center"][i] for i in range(3)] for v in group["Vertices"]]
            assert all(abs(v[0]) <= 1.375 and 3.0 <= v[1] <= 5.9 and -7.5 <= v[2] <= -3.0 for v in horn_vertices)
    # Body box intentionally includes the torso/neck, head and leg-gap silhouette.
    assert all(abs(v[0]) <= 2.8 and -.01 <= v[1] <= 5.0 and -5.85 <= v[2] <= 4.75 for v in bounds)
    assert hornboar["triangle_budget"] == [1000, 2000]
    assert 1000 <= hornboar["blender_triangles"] <= 2000
    assert len(topology["Groups"]) == 14 and len(hornboar["bones"]) == 14
    assert sum(len(g["Vertices"]) for g in topology["Groups"]) <= 1000
    assert (art / "hornboar_mesh.json").stat().st_size < 50_000
    assert (art / hornboar["studio_fbx"]).stat().st_size < 250_000
    assert exports["MON_Hornboar_V1"]["studio_fbx_reimport"] == "PASS"
    assert (art / hornboar["studio_rigid_fbx"]).stat().st_size < 250_000
    assert exports["MON_Hornboar_V1"]["studio_rigid_fbx_reimport"] == "PASS"
    assert 1000 <= source["assets"]["WPN_StarterCleaver_V1"]["blender_triangles"] <= 2500
    for asset_id, asset in source["assets"].items():
        for kind in ("source", "fbx", "glb"):
            path = art / asset[kind]; assert path.is_file() and path.stat().st_size > 100
        assert exports[asset_id]["fbx_reimport"] == "PASS"
        assert exports[asset_id]["triangles"] == asset["blender_triangles"], (asset_id, "stale FBX validation record")
        if asset_id == "MON_Hornboar_V1":
            # The user-approved Studio import is a binary .rbxm. Its byte hash is
            # checked above; structure is checked from the Rojo-built XML place below.
            continue
        root = ET.parse(art / "runtime" / asset["family"] / (asset_id+".rbxmx")).getroot()
        objects = list(root.iter("Item")); refs = {i.attrib["referent"] for i in objects}
        count = sum(i.attrib["class"] in ("Part", "WedgePart", "CornerWedgePart", "MeshPart") for i in objects)
        assert count == native[asset_id]
        for item in objects:
            for prop in item.find("Properties"):
                if prop.tag == "Ref": assert prop.text in refs or prop.text in ("null", "nil"), (asset_id, "dangling reference")
            if item.attrib["class"] in ("Part", "WedgePart"):
                p = props(item)
                assert p["CanCollide"].text == "false" and p["CanQuery"].text == "false", (asset_id, "visual used as hitbox")
    source_text = "\n".join(p.read_text() for p in PROJECT.joinpath("src").rglob("*.luau"))
    assert "CreateEditableMesh" not in source_text and "CreateMeshPartAsync" not in source_text, "runtime EditableMesh path returned"
    if args.art_only:
        print(f"PASS ART ONLY: {len(source['assets'])} source/FBX/GLB assets, {topology['TriangleCount']} topology triangles; Studio FBX 3 meshes/14 bones. Runtime .rbxm/place not validated.")
        return
    place = ET.parse(args.place).getroot()
    entries = index(place)
    imported_prefix = "ReplicatedStorage/Assets/Monsters/MON_Hornboar_V1"
    imported_entries = {p:i for p,i in entries.items() if p == imported_prefix or p.startswith(imported_prefix + "/")}
    assert imported_prefix in imported_entries, "imported Hornboar missing from built place"
    imported_names = {name(i) for i in imported_entries.values()}
    for required in imported["required_parts"]:
        assert required in imported_names, ("imported Hornboar missing part", required)
    assert any(i.attrib["class"] == "Motor6D" for i in imported_entries.values()), "imported Hornboar missing Motor6D rig"
    assert any(i.attrib["class"] == "AnimationController" for i in imported_entries.values()), "imported Hornboar missing AnimationController"
    source_text = "\n".join(p.read_text() for p in PROJECT.joinpath("src").rglob("*.luau"))
    assert "CreateEditableMesh" not in source_text and "CreateMeshPartAsync" not in source_text, "runtime EditableMesh path returned"
    scripts = {p:i for p,i in entries.items() if i.attrib["class"] in ("Script", "LocalScript", "ModuleScript")}
    expected = {}
    for file in PROJECT.joinpath("src").rglob("*.luau"):
        relative = file.relative_to(PROJECT / "src")
        parts = list(relative.with_suffix("").parts)
        filename = parts[-1].removesuffix(".server").removesuffix(".client")
        if parts[0] == "shared": path = "/".join(("ReplicatedStorage", "Shared", *parts[1:-1], filename))
        elif parts[0] == "client": path = "/".join(("StarterPlayer", "StarterPlayerScripts", *parts[1:-1], filename))
        else: path = "/".join(("ServerScriptService", *parts[1:-1], filename))
        expected[path] = file
    assert scripts.keys() == expected.keys(), (scripts.keys()-expected.keys(), expected.keys()-scripts.keys())
    for path, file in expected.items():
        expected_class = "Script" if file.name.endswith(".server.luau") else "LocalScript" if file.name.endswith(".client.luau") else "ModuleScript"
        assert scripts[path].attrib["class"] == expected_class, (path, "script class mismatch")
        assert props(scripts[path])["Source"].text == file.read_text(), (path, "source mismatch")
    for asset_id, asset in source["assets"].items():
        path = "ReplicatedStorage/Assets/"+asset["family"]+"/"+asset_id
        assert path in entries and entries[path].attrib["class"] == "Model", (path, "missing runtime asset")
    baseline = "a8b3ad0fbd9beda30a1e73dfa84affc58c805648"
    old = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", baseline, "MonCook/tests"], cwd=PROJECT.parent).decode().splitlines()
    for path in old:
        expected_bytes = subprocess.check_output(["git", "show", baseline+":"+path], cwd=PROJECT.parent)
        assert (PROJECT.parent/path).read_bytes() == expected_bytes, (path, "existing test changed")
    print(f"PASS: {len(source['assets'])} real FBX/source/GLB assets, {topology['TriangleCount']} exact Blender topology triangles, skeleton/bindings, {len(scripts)} runtime script sources, all original test files unchanged.")
    print("Studio place SHA256:", hashlib.sha256(args.place.read_bytes()).hexdigest())


if __name__ == "__main__": main()
