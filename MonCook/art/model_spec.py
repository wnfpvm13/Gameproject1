"""Shared, authored V1 shapes for Blender exports and native Roblox equivalents.

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

RIG = {
    "Root": {"parent": None, "position": (0, 0, 0)},
    "Spine": {"parent": "Root", "position": (0, 2.6, 0)},
    "Neck": {"parent": "Spine", "position": (0, 2.8, -2.5)},
    "Head": {"parent": "Neck", "position": (0, 2.8, -3.3)},
    "FrontLeg_L": {"parent": "Spine", "position": (-1.65, 2.3, -1.8)},
    "FrontLeg_R": {"parent": "Spine", "position": (1.65, 2.3, -1.8)},
    "BackLeg_L": {"parent": "Spine", "position": (-1.6, 2.25, 2.2)},
    "BackLeg_R": {"parent": "Spine", "position": (1.6, 2.25, 2.2)},
    "Horn": {"parent": "Head", "position": (0, 3.0, -4.4)},
    "Tail": {"parent": "Spine", "position": (0, 2.6, 3.0)},
}


def hornboar():
    p = [
        shape("Body", "Ellipsoid", (0, 2.7, 0.2), (4.9, 3.65, 6.5), BROWN, segments=16, rings=10),
        shape("Shoulders", "Ellipsoid", (0, 2.95, -1.45), (5.25, 3.8, 3.6), WARM, segments=16, rings=10),
        shape("Chest", "Ellipsoid", (0, 1.95, -1.65), (3.9, 2.4, 3.9), BEIGE),
        shape("Head", "Ellipsoid", (0, 2.8, -3.25), (3.9, 2.9, 3.4), WARM, bone="Head", segments=16, rings=10),
        shape("Muzzle", "Ellipsoid", (0, 2.05, -4.7), (2.5, 1.5, 2.25), BEIGE, bone="Head"),
        shape("Nose", "Ellipsoid", (0, 2.17, -5.62), (1.9, 1.12, 0.52), (0.48, 0.24, 0.15), bone="Head", segments=12, rings=8),
        shape("Chin", "Ellipsoid", (0, 1.47, -4.65), (2.15, 0.75, 1.7), BROWN, bone="Head", segments=12, rings=8),
    ]
    for side, x in (("L", -1), ("R", 1)):
        p += [
            shape(f"Nostril_{side}", "Ellipsoid", (x*0.43, 2.20, -5.89), (0.27, 0.28, 0.1), BROWN, bone="Head", segments=8, rings=6),
            shape(f"EyeGold_{side}", "Ellipsoid", (x*1.64, 3.27, -3.67), (0.37, 0.43, 0.62), GOLD, bone="Head", segments=10, rings=8),
            shape(f"Pupil_{side}", "Ellipsoid", (x*1.80, 3.29, -3.79), (0.17, 0.27, 0.26), BROWN, bone="Head", segments=8, rings=6),
            shape(f"EyeGlint_{side}", "Ellipsoid", (x*1.88, 3.40, -3.88), (0.08, 0.09, 0.1), IVORY, bone="Head", segments=8, rings=6),
            shape(f"Brow_{side}", "Box", (x*1.62, 3.61, -3.62), (0.58, 0.27, 1.03), BROWN, bone="Head", rotation=(0, 0, x*12), bevel=0.07),
            shape(f"Ear_{side}", "Wedge", (x*1.68, 4.02, -2.84), (1.02, 1.75, 1.02), BROWN, bone="Head", rotation=(12, 0, -x*26)),
            shape(f"EarInset_{side}", "Wedge", (x*1.68, 4.05, -3.0), (0.64, 1.17, 0.35), BEIGE, bone="Head", rotation=(12, 0, -x*26)),
            shape(f"Tusk_{side}", "Wedge", (x*1.16, 1.91, -5.0), (0.48, 1.27, 0.95), IVORY, bone="Head", rotation=(25, 0, x*18)),
        ]
    for prefix, z in (("FrontLeg", -1.8), ("BackLeg", 2.2)):
        for side, x in (("L", -1.65), ("R", 1.65)):
            bone = f"{prefix}_{side}"
            p += [
                shape(f"{bone}_Haunch", "Ellipsoid", (x, 1.95, z), (1.48, 2.05, 1.63), WARM, bone=bone, segments=12, rings=8),
                shape(f"{bone}_Shin", "Ellipsoid", (x, 0.89, z-0.12), (0.91, 1.56, 1.08), BROWN, bone=bone, segments=12, rings=8),
                shape(f"{bone}_Hoof", "Box", (x, 0.3, z-0.25), (1.02, 0.59, 1.42), (0.29, 0.21, 0.15), bone=bone, bevel=0.12),
                shape(f"{bone}_HoofTip", "Box", (x, 0.32, z-0.87), (0.92, 0.32, 0.12), GOLD, bone=bone, bevel=0.03),
            ]
    for index in range(4):
        p.append(shape(f"BackPlate_{index}", "Wedge", (0, 4.18-index*0.11, -1.12+index*1.08),
                       (2.38-index*0.15, 0.81, 1.24), (0.62+index*0.025, 0.39, 0.19), rotation=(8, 0, 0)))
        p.append(shape(f"PlateAccent_{index}", "Box", (0, 4.56-index*0.11, -1.24+index*1.08),
                       (0.4, 0.08, 0.44), GOLD, bevel=0.02))
    # One large signature horn, kept separate from the face and broken stump.
    for index in range(5):
        t = index/4
        p.append(shape(f"PART_Hornboar_Horn_{index}", "Cone", (0, 3.00+0.94*t+0.47*t*t, -4.46-3.1*t),
                       (1.75*(1-t)+0.15, 1.1, 1.75*(1-t)+0.15), IVORY if index < 4 else MAGIC,
                       bone="Horn", binding="HornIntact", rotation=(-65+index*5, 0, 0), segments=8))
    p.append(shape("HornRune", "Box", (0, 3.33, -4.91), (0.20, 0.12, 0.75), MAGIC, bone="Horn", binding="HornIntact", rotation=(-20, 0, 0), bevel=0.03))
    p.append(shape("Horn_Broken", "Cone", (0, 3.04, -4.45), (1.2, 0.52, 1.2), IVORY,
                   bone="Horn", binding="HornBroken", rotation=(-65, 0, 0), segments=8))
    p.append(shape("BrokenCoreGlow", "Ellipsoid", (0, 3.2, -4.65), (0.48, 0.24, 0.24), MAGIC,
                   bone="Horn", binding="HornBroken", segments=8, rings=6))
    for index in range(3):
        p.append(shape(f"Tail_{index}", "Ellipsoid", (0.18*index, 2.7+index*0.2, 3.0+index*0.45),
                       (0.36, 0.36, 0.95), BROWN, bone="Tail", rotation=(18, index*20, 0), segments=10, rings=6))
    return p


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
    assets = {
        "MON_Hornboar_V1": {"family": "Monsters", "parts": hornboar(), "rig": RIG},
        "WPN_StarterCleaver_V1": {"family": "Weapons", "parts": cleaver(), "rig": {}},
    }
    for name in ("ING_HornboarMeat_V1", "ING_ArcaneFat_V1", "ING_MarbledLoin_V1", "MAT_HornCore_V1"):
        assets[name] = {"family": "Ingredients", "parts": ingredient(name), "rig": {}}
    for name, parts in environments().items():
        assets[name] = {"family": "Environment", "parts": parts, "rig": {}}
    return assets
