"""Validate authoring topology without restoring the removed runtime mesh loader."""
from pathlib import Path
import json,hashlib
ART=Path(__file__).resolve().parent
data=json.loads((ART/'hornboar_mesh.json').read_text())
assert data['SourceSHA256']==hashlib.sha256((ART/'blender/Hornboar/MON_Hornboar_V1.blend').read_bytes()).hexdigest()
assert data['TriangleCount']==sum(len(g['Faces']) for g in data['Groups'])
print('Authoring topology:',data['TriangleCount'],'triangles,',len(data['Groups']),'mesh groups,',(ART/'hornboar_mesh.json').stat().st_size,'bytes; game uses Studio-imported asset')
