"""Shared V1 primitives for weapons, ingredients and environment. Hornboar uses its Blender mesh builder.

Coordinates use Roblox X/right, Y/up, -Z/forward, in studs. The Blender builder
converts these to its axes. Primitive equivalents preserve silhouette, palette,
part boundaries and rig bindings; they are not claimed to be imported meshes.
"""
from __future__ import annotations

import math


def shape(name, kind, position, size, color, *, bone="Spine", binding="Visual",
          rotation=(0, 0, 0), segments=12, rings=8, bevel=0.08):
    return dict(name=name, kind=kind, position=position, size=size, color=color,
                bone=bone, binding=binding, rotation=rotation, segments=segments,
                rings=rings, bevel=bevel)


BROWN = (0.31, 0.16, 0.095)
WARM = (0.53, 0.32, 0.18)
BEIGE = (0.78, 0.59, 0.36)
IVORY = (0.96, 0.86, 0.62)
GOLD = (0.91, 0.62, 0.20)
MAGIC = (0.30, 0.85, 0.78)



def hornboar():
    raise RuntimeError("Hornboar uses art/blender/redesign_hornboar.py actual mesh, not native primitive blockout")


def cleaver():
    p = [
        shape("Blade", "Box", (0, 1.12, 0), (1.35, 2.67, 0.23), (0.78, 0.87, 0.86), bone="Root", bevel=0.11),
        shape("BladeShoulder", "Wedge", (0.08, 2.40, 0), (1.30, 0.48, 0.23), (0.67, 0.79, 0.77), bone="Root", rotation=(0, 90, 0)),
        shape("CuttingEdge", "Box", (-0.59, 1.06, 0), (0.12, 2.48, 0.27), IVORY, bone="Root", bevel=0.025),
        shape("Spine", "Box", (0.66, 1.1, 0), (0.17, 2.48, 0.32), (0.44, 0.62, 0.60), bone="Root", bevel=0.03),
        shape("Guard", "Box", (0, -0.30, 0), (1.01, 0.20, 0.51), GOLD, bone="Root", bevel=0.065),
        shape("Grip", "Cylinder", (0, -0.98, 0), (0.35, 1.25, 0.35), BROWN, bone="Root", segments=16),
        shape("Pommel", "Ellipsoid", (0, -1.64, 0), (0.54, 0.33, 0.54), GOLD, bone="Root", segments=14, rings=10),
    ]
    for i in range(6):
        p.append(shape(f"GripWrap_{i}", "Cylinder", (0, -0.49-i*0.17, 0), (0.395, 0.064, 0.395), WARM, bone="Root", segments=16))
    for side in (-1, 1):
        for i in range(3):
            p.append(shape(f"Rivet_{side}_{i}", "Ellipsoid", (0.45, 0.31+i*0.77, side*0.135), (0.115, 0.115, 0.09), GOLD,
                           bone="Root", segments=10, rings=8))
        p.append(shape(f"Rune_{side}", "Box", (0.20, 1.64, side*0.14), (0.23, 0.44, 0.018), MAGIC,
                       bone="Root", rotation=(0, 0, 35), bevel=0.01))
    return p


def ingredient(asset):
    if asset == "ING_HornboarMeat_V1":
        return [shape("Meat", "Ellipsoid", (0, 0.45, 0), (1.8, 0.8, 1.4), (0.86, 0.37, 0.32), bone="Root"),
                shape("FatCap", "Ellipsoid", (0.48, 0.60, 0.1), (0.6, 0.35, 1.17), IVORY, bone="Root"),
                shape("CutFace", "Ellipsoid", (0, 0.84, 0), (1.54, 0.05, 1.12), (0.96, 0.51, 0.40), bone="Root")]
    if asset == "ING_ArcaneFat_V1":
        return [shape("Fat", "Ellipsoid", (0, 0.44, 0), (1.28, 0.83, 1.14), (1.0, 0.85, 0.43), bone="Root"),
                shape("Cream", "Ellipsoid", (0.2, 0.69, 0), (0.83, 0.45, 0.82), (1.0, 0.97, 0.75), bone="Root"),
                shape("ArcaneSpark", "Ellipsoid", (-0.35, 0.85, -0.22), (0.25, 0.25, 0.25), MAGIC, bone="Root")]
    if asset == "ING_MarbledLoin_V1":
        p = [shape("Loin", "Ellipsoid", (0, 0.55, 0), (2.02, 1.0, 1.65), (0.80, 0.28, 0.23), bone="Root"),
             shape("CleanFace", "Ellipsoid", (0, 1.03, 0), (1.8, 0.06, 1.46), (0.98, 0.51, 0.43), bone="Root")]
        for i in range(5):
            p.append(shape(f"Marbling_{i}", "Box", (-0.60+i*0.29, 1.07, -0.10+i*0.025),
                           (0.062, 0.04, 0.83-abs(i-2)*0.14), IVORY, bone="Root", rotation=(0, 20+i*12, 0), bevel=0.01))
        p.append(shape("RareMedallion", "Ellipsoid", (0.73, 0.78, 0.05), (0.22, 0.38, 0.45), GOLD, bone="Root"))
        return p
    return [shape("IvoryCore", "Cone", (0, 0.68, 0), (1.1, 1.24, 1.1), IVORY, bone="Root", rotation=(0, 0, -16), segments=10),
            shape("MagicCore", "Ellipsoid", (-0.05, 1.11, 0.0), (0.45, 0.63, 0.45), MAGIC, bone="Root"),
            shape("CoreBand", "Cylinder", (0.03, 0.32, 0), (1.05, 0.16, 1.05), GOLD, bone="Root", rotation=(0, 0, -16), segments=10)]


def environments():
    assets = {}
    for index, (height, width, color) in enumerate(((11, 7, (0.30, 0.64, 0.24)), (14, 6, (0.44, 0.73, 0.23)), (9, 8, (0.23, 0.56, 0.33)))):
        name = f"ENV_Greenwood_Tree_{chr(65+index)}_V1"
        assets[name] = [shape("Trunk", "Cylinder", (0, height*0.25, 0), (1.3, height*0.5, 1.3), WARM, bone="Root", segments=8)]
        for level in range(3):
            assets[name].append(shape(f"Canopy_{level}", "Ellipsoid", (0.5*math.sin(level+index), height*0.50+level*1.8, 0),
                                      (width-level*1.1, 4.0, width-level*1.1), color, bone="Root", segments=10, rings=6))
    for index in range(3):
        assets[f"ENV_Greenwood_Rock_{chr(65+index)}_V1"] = [shape("Rock", "Ellipsoid", (0, 1.0+index*0.2, 0),
            (3+index*0.6, 2.1+index*0.4, 2.8+index*0.3), (0.68+index*0.04, 0.67+index*0.02, 0.48), bone="Root", segments=8, rings=6)]
    assets["ENV_Greenwood_Bush_V1"] = [shape(f"Leaves_{i}", "Ellipsoid", (i*0.8-0.8, 0.7+0.3*(i%2), 0),
        (1.8, 1.6, 1.8), (0.43, 0.70, 0.22), bone="Root", segments=10, rings=6) for i in range(3)]
    assets["ENV_Greenwood_Grass_V1"] = [shape(f"Blade_{i}", "Wedge", ((i%3)*0.5-0.5, 0.4, (i//3)*0.4-0.4),
        (0.15, 0.95+(i%3)*0.2, 0.28), (0.58, 0.79, 0.26), bone="Root", rotation=(0, i*43, (i%3-1)*15)) for i in range(9)]
    assets["ENV_Greenwood_Stump_V1"] = [shape("Stump", "Cylinder", (0, 0.6, 0), (1.8, 1.2, 1.8), WARM, bone="Root", segments=10),
        shape("CutWood", "Cylinder", (0, 1.22, 0), (1.7, 0.08, 1.7), BEIGE, bone="Root", segments=10)]
    assets["ENV_Greenwood_Sign_V1"] = [shape("Post", "Box", (0, 1.8, 0), (0.42, 3.6, 0.42), WARM, bone="Root", bevel=0.04),
        shape("Signboard", "Box", (0, 3.0, 0), (4.4, 1.38, 0.34), BEIGE, bone="Root", bevel=0.08),
        shape("Arrow", "Wedge", (2.4, 3.0, 0), (0.82, 1.38, 0.34), GOLD, bone="Root", rotation=(0, 0, -90))]
    return assets


def catalog():
    from hornboar_design import RIG as hornboar_rig
    assets = {
        "MON_Hornboar_V1": {"family": "Monsters", "parts": [], "rig": hornboar_rig},
        "WPN_StarterCleaver_V1": {"family": "Weapons", "parts": cleaver(), "rig": {}},
    }
    for name in ("ING_HornboarMeat_V1", "ING_ArcaneFat_V1", "ING_MarbledLoin_V1", "MAT_HornCore_V1"):
        assets[name] = {"family": "Ingredients", "parts": ingredient(name), "rig": {}}
    for name, parts in environments().items():
        assets[name] = {"family": "Environment", "parts": parts, "rig": {}}
    return assets
