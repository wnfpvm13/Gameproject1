"""Export Blender-authored topology to a static Luau packet for client MeshPart generation."""
from pathlib import Path
import json
ART=Path(__file__).resolve().parent
data=json.loads((ART/'hornboar_mesh.json').read_text())
p=ART.parent/'src/shared/Assets/HornboarMeshData.luau';p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('--!strict\n-- Actual Blender topology; run art/export_hornboar_mesh.py.\nreturn { Json = [=['+json.dumps(data,separators=(',',':'))+']=] }\n')
print('Blender topology packet:',data['TriangleCount'],'triangles,',len(data['Groups']),'bound mesh groups,',p.stat().st_size,'bytes')
