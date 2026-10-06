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
    parser.add_argument("--place", type=Path, required=True)
    args = parser.parse_args()
    art = PROJECT / "art"
    source = json.loads((art / "asset_manifest.json").read_text())
    native = json.loads((art / "runtime_manifest.json").read_text())["baseparts"]
    exports = json.loads((art / "export_validation.json").read_text())
    assert 3000 <= source["assets"]["MON_Hornboar_V1"]["blender_triangles"] <= 6000
    assert 1000 <= source["assets"]["WPN_StarterCleaver_V1"]["blender_triangles"] <= 2500
    for asset_id, asset in source["assets"].items():
        for kind in ("source", "fbx", "glb"):
            path = art / asset[kind]; assert path.is_file() and path.stat().st_size > 100
        assert exports[asset_id]["fbx_reimport"] == "PASS"
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
        if asset["bones"]:
            joints = {name(i) for i in objects if i.attrib["class"] == "Motor6D"}
            assert joints == set(asset["bones"])-{"Root"}
            bindings = [props(i)["Value"].text for i in objects if i.attrib["class"] == "StringValue" and name(i) == "Binding"]
            assert "HornIntact" in bindings and "HornBroken" in bindings and "Root" in bindings
    place = ET.parse(args.place).getroot()
    entries = index(place)
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
    print(f"PASS: {len(source['assets'])} real FBX/source/GLB assets, native references/rig bindings, {len(scripts)} runtime script sources, all original test files unchanged.")
    print("Studio place SHA256:", hashlib.sha256(args.place.read_bytes()).hexdigest())


if __name__ == "__main__": main()
