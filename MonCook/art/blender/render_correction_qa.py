from pathlib import Path
import sys,bpy
ART=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ART));sys.path.insert(0,str(ART/'blender'))
from build_assets import mesh_part,preview_scene
from model_spec import shape
bpy.ops.wm.open_mainfile(filepath=str(ART/'blender/Hornboar/MON_Hornboar_V1.blend'))
# A 5.5-stud Roblox-scale mannequin, for source proportions only.
for name,pos,size,color in [('Head',(7,4.9,0),(1.4,1.2,1.2),(.94,.77,.49)),('Torso',(7,3.25,0),(2,2,1),(.3,.59,.7)),('ArmL',(5.55,3.25,0),(.8,2,1),(.94,.77,.49)),('ArmR',(8.45,3.25,0),(.8,2,1),(.94,.77,.49)),('LegL',(6.45,1.05,0),(.95,2.1,1),(.24,.28,.39)),('LegR',(7.55,1.05,0),(.95,2.1,1),(.24,.28,.39))]:
 mesh_part(shape('AvatarScale_'+name,'Box',pos,size,color,bone='Root',bevel=.05))
preview_scene((3.0,1.0,2.5),28,ART/'previews/Hornboar_AvatarScale.png')
