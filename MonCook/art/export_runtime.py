"""Build native Roblox .rbxmx V1 equivalents from the authored shape specification.

This path needs no uploaded mesh/animation IDs. It preserves rig joints, authored
palette, named intact/broken horn bindings and separate visual geometry. Gameplay
hitboxes are added by the runtime binder from Config, not from mesh collision.
"""
from __future__ import annotations
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

from model_spec import catalog

ART = Path(__file__).resolve().parent


def multiply(a, b):
    return [[sum(a[r][k]*b[k][c] for k in range(3)) for c in range(3)] for r in range(3)]


def rotation(degrees):
    x,y,z = (math.radians(v) for v in degrees)
    rx = [[1,0,0],[0,math.cos(x),-math.sin(x)],[0,math.sin(x),math.cos(x)]]
    ry = [[math.cos(y),0,math.sin(y)],[0,1,0],[-math.sin(y),0,math.cos(y)]]
    rz = [[math.cos(z),-math.sin(z),0],[math.sin(z),math.cos(z),0],[0,0,1]]
    return multiply(multiply(rx,ry),rz)


class Writer:
    def __init__(self):
        self.next_id = 0
        self.root = ET.Element("roblox", version="4")
        ET.SubElement(self.root, "External").text = "null"
        ET.SubElement(self.root, "External").text = "nil"

    def item(self, parent, kind, name):
        self.next_id += 1
        obj = ET.SubElement(parent, "Item", {"class": kind, "referent": f"RBX{self.next_id}"})
        props = ET.SubElement(obj, "Properties")
        ET.SubElement(props, "string", name="Name").text = name
        return obj

    def property(self, obj, kind, name, value):
        props = obj.find("Properties")
        node = ET.SubElement(props, kind, name=name)
        if kind == "Vector3":
            for axis, v in zip("XYZ", value): ET.SubElement(node, axis).text = f"{v:.8g}"
        elif kind == "CoordinateFrame":
            pos, matrix = value
            for axis, v in zip("XYZ", pos): ET.SubElement(node, axis).text = f"{v:.8g}"
            for r in range(3):
                for c in range(3): ET.SubElement(node, f"R{r}{c}").text = f"{matrix[r][c]:.8g}"
        else:
            node.text = str(value).lower() if isinstance(value, bool) else str(value)
        return node

    def binding(self, obj, value):
        tag = self.item(obj, "StringValue", "Binding")
        self.property(tag, "string", "Value", value)

    def part(self, parent, name, position, size, color, *, kind="Part", matrix=None, shape=1, anchored=False, hidden=False, binding="Visual"):
        obj = self.item(parent, kind, name)
        self.property(obj, "Vector3", "size", size)
        self.property(obj, "CoordinateFrame", "CFrame", (position, matrix or rotation((0,0,0))))
        self.property(obj, "Color3uint8", "Color3uint8", sum(round(c*255)<<shift for c,shift in zip(color,(16,8,0))))
        self.property(obj, "token", "Material", 272)
        self.property(obj, "bool", "Anchored", anchored)
        self.property(obj, "bool", "CanCollide", False)
        self.property(obj, "bool", "CanTouch", False)
        self.property(obj, "bool", "CanQuery", False)
        self.property(obj, "bool", "Massless", True)
        self.property(obj, "float", "Transparency", 1 if hidden else 0)
        self.property(obj, "token", "TopSurface", 0)
        self.property(obj, "token", "BottomSurface", 0)
        if kind == "Part": self.property(obj, "token", "shape", shape)
        self.binding(obj, binding)
        return obj

    def weld(self, parent, a, b):
        obj = self.item(parent, "WeldConstraint", "VisualWeld")
        self.property(obj, "Ref", "Part0", a.attrib["referent"])
        self.property(obj, "Ref", "Part1", b.attrib["referent"])


def native_parts(writer, parent, spec, anchored):
    kind, matrix, size = spec["kind"], rotation(spec["rotation"]), spec["size"]
    shared = dict(anchored=anchored, hidden=spec["binding"] == "HornBroken", binding=spec["binding"])
    if kind == "Cone":
        # Four wedge sectors produce an ivory faceted horn without external MeshIds.
        result = []
        for index in range(4):
            sector = rotation((0,index*90,0))
            local = (0,0,size[2]*0.16)
            offset = [sum(sector[r][c]*local[c] for c in range(3)) for r in range(3)]
            world = [spec["position"][r]+sum(matrix[r][c]*offset[c] for c in range(3)) for r in range(3)]
            result.append(writer.part(parent, f'{spec["name"]}_{index}', world,
                (size[0]*0.70,size[1],size[2]*0.62), spec["color"], kind="WedgePart", matrix=multiply(matrix,sector), **shared))
        return result
    if kind == "Cylinder":
        size = (size[1],size[0],size[2])
        matrix = multiply(matrix, rotation((0,0,90)))
    return [writer.part(parent, spec["name"], spec["position"], size, spec["color"],
        kind="WedgePart" if kind == "Wedge" else "Part", matrix=matrix,
        shape=0 if kind == "Ellipsoid" else 2 if kind == "Cylinder" else 1, **shared)]


def build(asset_id, asset):
    writer = Writer()
    model = writer.item(writer.root, "Model", asset_id)
    visual = writer.item(model, "Folder", "Visual")
    gameplay = writer.item(model, "Folder", "Gameplay")
    rig = writer.item(model, "Folder", "Rig")
    root = writer.part(model, "Root", (0,0,0), (0.2,0.2,0.2), (1,1,1), anchored=True, hidden=True, binding="Root")
    writer.property(model, "Ref", "PrimaryPart", root.attrib["referent"])
    bones = {"Root": root}
    if asset["rig"]:
        for name, definition in asset["rig"].items():
            if name == "Root": continue
            node = writer.part(rig, "Bone_"+name, definition["position"], (0.12,0.12,0.12), (1,1,1), hidden=True, binding="RigNode")
            bones[name] = node
            parent_name = definition["parent"]
            joint = writer.item(rig, "Motor6D", name)
            writer.binding(joint, "Joint:"+name)
            writer.property(joint, "Ref", "Part0", bones[parent_name].attrib["referent"])
            writer.property(joint, "Ref", "Part1", node.attrib["referent"])
            parent_position = asset["rig"][parent_name]["position"]
            delta = tuple(definition["position"][i]-parent_position[i] for i in range(3))
            writer.property(joint, "CoordinateFrame", "C0", (delta, rotation((0,0,0))))
            writer.property(joint, "CoordinateFrame", "C1", ((0,0,0), rotation((0,0,0))))
        controller = writer.item(rig, "AnimationController", "AnimationController")
        writer.item(controller, "Animator", "Animator")
    count = 1+len(bones)-1
    for spec in asset["parts"]:
        parts = native_parts(writer, visual, spec, asset["family"] == "Environment")
        count += len(parts)
        for part in parts:
            writer.weld(part, bones.get(spec["bone"], root), part)
    # Binding-based Gameplay hitboxes are configured by the runtime, intentionally absent in art.
    writer.binding(gameplay, "GameplayContainer")
    path = ART / "runtime" / asset["family"] / f"{asset_id}.rbxmx"
    path.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(writer.root, space="  ")
    ET.ElementTree(writer.root).write(path, encoding="utf-8", xml_declaration=True)
    return count


def main():
    counts = {}
    for asset_id, asset in catalog().items():
        counts[asset_id] = build(asset_id, asset)
    path = ART / "runtime_manifest.json"
    path.write_text(json.dumps({"representation": "native Roblox primitive V1 equivalents", "baseparts": counts}, indent=2)+"\n")
    print(f"Native Roblox model generation: {len(counts)} assets, {sum(counts.values())} template BaseParts.")


if __name__ == "__main__":
    main()
