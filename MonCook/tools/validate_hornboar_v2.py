"""Validate V2 exports, skin weights, authored clips and unchanged V1/test assets.

This is offline validation; uploaded MeshIds, Studio playback and mobile FPS are
not implied. Blender reimport measurement is checked against actual export hashes.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import subprocess
import xml.etree.ElementTree as ET

PROJECT=Path(__file__).resolve().parent.parent
ROOT=PROJECT/'art/generated/Monsters/Hornboar/V2'
BASE='5fcb8a93d7e9d294a69425b9c54c9016ae74a008'


def glb(path):
    data=path.read_bytes()
    magic,version,length=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and length==len(data)
    size,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a
    document=json.loads(data[20:20+size]);offset=20+size
    binary_size,binary_kind=struct.unpack_from('<II',data,offset);assert binary_kind==0x004e4942
    return document,data[offset+8:offset+8+binary_size]


def accessor(document,binary,index):
    entry=document['accessors'][index];view=document['bufferViews'][entry['bufferView']]
    components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[entry['type']]
    fmt={5121:'B',5123:'H',5125:'I',5126:'f'}[entry['componentType']]
    size=struct.calcsize('<'+fmt)*components
    stride=view.get('byteStride',size);start=view.get('byteOffset',0)+entry.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*components,binary,start+i*stride) for i in range(entry['count'])]


def main():
    report=json.loads((ROOT/'metadata/v2_analysis.json').read_text())
    assert 2500<=report['triangles']<=3500 and report['mesh_count']==5 and report['material_count']==2
    assert report['textures'][0]['resolution']==[512,512] and len(report['rigs'][0]['bones'])==14
    for mesh in report['meshes']:
        assert mesh['duplicate_faces']==mesh['duplicate_vertices']==mesh['zero_area_faces']==0
        assert mesh['unweighted_vertices']==0 and mesh['max_weight_sum_error']<1e-5
    export=ROOT/'export/MON_Hornboar_V2.glb';document,binary=glb(export)
    assert len(document['meshes'])==5 and len(document['materials'])==2 and len(document['images'])==1
    image=document['images'][0];image_view=document['bufferViews'][image['bufferView']]
    image_start=image_view.get('byteOffset',0);embedded=binary[image_start:image_start+image_view['byteLength']]
    assert image['mimeType']=='image/png' and struct.unpack_from('>II',embedded,16)==(512,512)
    triangles=0;maximum_influences=0
    for mesh in document['meshes']:
        for primitive in mesh['primitives']:
            assert primitive.get('mode',4)==4
            indices=accessor(document,binary,primitive['indices'])
            positions=accessor(document,binary,primitive['attributes']['POSITION'])
            assert len(indices)%3==0 and all(0<=i[0]<len(positions) for i in indices)
            assert all(all(math.isfinite(v) for v in p) for p in positions)
            triangles+=len(indices)//3
            weights=accessor(document,binary,primitive['attributes']['WEIGHTS_0'])
            for weights_row in weights:
                assert abs(sum(weights_row)-1)<1e-4 and min(weights_row)>=0
                maximum_influences=max(maximum_influences,sum(v>1e-5 for v in weights_row))
    assert triangles==report['triangles'] and maximum_influences<=4
    for skin in document['skins']:
        names={document['nodes'][index]['name'] for index in skin['joints']}
        assert len(names)==14 and {'Root','Spine','Neck','Head','Horn','Tail'}<=names
    atlas=(ROOT/'export/Hornboar_BaseColor_512.png').read_bytes()
    assert atlas[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack_from('>II',atlas,16)==(512,512)
    reimport=json.loads((ROOT/'metadata/FBXReimport_analysis.json').read_text())
    assert reimport['triangles']==triangles and reimport['mesh_count']==5 and len(reimport['rigs'][0]['bones'])==14
    provenance=json.loads((ROOT/'metadata/export_receipt.json').read_text())
    assert provenance['fbx_sha256']==hashlib.sha256((ROOT/'export/MON_Hornboar_V2.fbx').read_bytes()).hexdigest()
    assert provenance['glb_sha256']==hashlib.sha256(export.read_bytes()).hexdigest()
    clips=ET.parse(PROJECT/'art/runtime/Animations/PlayerCombat.rbxmx').getroot()
    sequences=[item for item in clips.iter('Item') if item.get('class')=='KeyframeSequence']
    assert len(sequences)==5
    for sequence in sequences:
        frames=[item for item in sequence if item.tag=='Item' and item.get('class')=='Keyframe']
        assert len(frames)>10
        for frame in frames:
            poses=[item for item in frame.iter('Item') if item.get('class')=='Pose']
            names={item.find("./Properties/string[@name='Name']").text for item in poses}
            assert len(names)==16 and {'RightFoot','LeftFoot','LowerTorso','UpperTorso','RightHand'}<=names
    names=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'MonCook/tests','MonCook/art/blender','MonCook/art/exports','MonCook/art/runtime/Monsters/MON_Hornboar_V1.rbxmx'],cwd=PROJECT.parent).decode().splitlines()
    for name in names:
        # Compare Git's clean-filter representation: Windows autoCRLF changes only
        # checkout line endings, not tracked source. Binary assets still hash exactly.
        original=subprocess.check_output(['git','rev-parse',BASE+':'+name],cwd=PROJECT.parent).strip()
        current=subprocess.check_output(['git','hash-object','--path',name,name],cwd=PROJECT.parent).strip()
        assert current==original,('Baseline changed',name)
    biggest=max((p.stat().st_size for p in ROOT.rglob('*') if p.is_file()),default=0)
    assert biggest<100_000_000,'GitHub single-file limit risk'
    result={'offline_validation':'PASS','triangles':triangles,'meshes':5,'materials':2,'textures':1,
            'bones':14,'max_skin_influences':maximum_influences,'player_clips':5,'unchanged_baseline_files':len(names),
            'largest_asset_bytes':biggest,'studio_execution':'미검증','mobile_performance':'미검증'}
    (ROOT/'metadata/validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False))


if __name__=='__main__':main()
