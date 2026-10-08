"""Catch stale packed 2K/JPEG data escaping into the Roblox FBX texture package."""
from pathlib import Path
import struct
import json
import unittest

EXPORT=Path(__file__).resolve().parent.parent/'art/generated/Monsters/Hornboar/V2/export'

class HornboarTextureExport(unittest.TestCase):
    def test_glb_embeds_final_authored_atlas(self):
        data=(EXPORT/'MON_Hornboar_V2.glb').read_bytes()
        size,kind=struct.unpack_from('<II',data,12)
        self.assertEqual(kind,0x4e4f534a)
        doc=json.loads(data[20:20+size])
        binary_start=20+size+8
        view=doc['bufferViews'][doc['images'][0]['bufferView']]
        offset=binary_start+view.get('byteOffset',0)
        embedded=data[offset:offset+view['byteLength']]
        self.assertEqual(embedded,(EXPORT/'Hornboar_BaseColor_512.png').read_bytes(),'GLB embeds a stale palette instead of the final authored atlas')

    def test_roblox_fbx_texture_package_contains_actual_512_png(self):
        for stem in ('MON_Hornboar_V2','MON_Hornboar_V2_Studio'):
            with self.subTest(stem=stem):
                data=(EXPORT/(stem+'.fbm')/'Hornboar_BaseColor_512.png').read_bytes()
                self.assertEqual(data[:8],b'\x89PNG\r\n\x1a\n','FBX exported stale packed JPEG instead of authored atlas')
                self.assertEqual(struct.unpack_from('>II',data,16),(512,512),'Roblox import texture exceeds mobile atlas budget')
                self.assertIn(data,(EXPORT/(stem+'.fbx')).read_bytes(),'FBX embeds different texture bytes than its sidecar')

if __name__=='__main__':unittest.main()
