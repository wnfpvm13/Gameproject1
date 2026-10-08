"""Render existing real sources without regenerating model/animation exports."""
from pathlib import Path
import sys
import bpy

BLENDER = Path(__file__).resolve().parent
sys.path.insert(0, str(BLENDER))
from build_assets import preview_scene

ART = BLENDER.parent
PREVIEWS = ART / "previews"
PREVIEWS.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BLENDER / "Hornboar" / "MON_Hornboar_V1.blend"))
bpy.context.scene.frame_set(0)
for label, distance in (("Close", 18), ("Medium", 28), ("Far", 48)):
    preview_scene((0, 1.7, 2.2), distance, PREVIEWS / f"Hornboar_{label}.png")
bpy.ops.wm.open_mainfile(filepath=str(BLENDER / "StarterCleaver" / "WPN_StarterCleaver_V1.blend"))
preview_scene((0, 0, 0.5), 7, PREVIEWS / "StarterCleaver.png", ground_height=-1.85)
print("Rendered Hornboar close/medium/far and Starter Cleaver source previews.", flush=True)
