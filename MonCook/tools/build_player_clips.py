"""Build reusable R15 KeyframeSequence sources; uploaded IDs remain explicit.

Reads Luau sampled canonical full-body motion, emits XML mapped by Rojo. Studio
preview retargets these transforms to the avatar's actual Motor6D C0 axes.
"""
from pathlib import Path
import json
import math
import xml.etree.ElementTree as ET

PROJECT = Path(__file__).resolve().parent.parent
JOINTS = {
    'HumanoidRootPart': (None, None), 'LowerTorso': ('HumanoidRootPart', 'RootJoint'),
    'UpperTorso': ('LowerTorso', 'Waist'), 'Head': ('UpperTorso', 'Neck'),
    'RightUpperArm': ('UpperTorso', 'RightShoulder'), 'RightLowerArm': ('RightUpperArm', 'RightElbow'),
    'RightHand': ('RightLowerArm', 'RightWrist'), 'LeftUpperArm': ('UpperTorso', 'LeftShoulder'),
    'LeftLowerArm': ('LeftUpperArm', 'LeftElbow'), 'LeftHand': ('LeftLowerArm', 'LeftWrist'),
    'RightUpperLeg': ('LowerTorso', 'RightHip'), 'RightLowerLeg': ('RightUpperLeg', 'RightKnee'),
    'RightFoot': ('RightLowerLeg', 'RightAnkle'), 'LeftUpperLeg': ('LowerTorso', 'LeftHip'),
    'LeftLowerLeg': ('LeftUpperLeg', 'LeftKnee'), 'LeftFoot': ('LeftLowerLeg', 'LeftAnkle'),
}


def matrix(pose):
    x, y, z = (pose.get(k, 0) for k in ('Pitch', 'Yaw', 'Roll'))
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    return [cy*cz, -cy*sz, sy, cx*sz+sx*sy*cz, cx*cz-sx*sy*sz, -sx*cy,
            sx*sz-cx*sy*cz, sx*cz+cx*sy*sz, cx*cy]


def main():
    source = PROJECT/'art/generated/PlayerCombat/player_clip_samples.json'
    data = json.loads(source.read_text(encoding='utf-8-sig'))
    root = ET.Element('roblox', version='4')
    ET.SubElement(root, 'External').text = 'null'; ET.SubElement(root, 'External').text = 'nil'
    refs = 0
    def item(parent, cls, name):
        nonlocal refs
        refs += 1
        node = ET.SubElement(parent, 'Item', {'class': cls, 'referent': 'RBX'+str(refs)})
        props = ET.SubElement(node, 'Properties')
        ET.SubElement(props, 'string', name='Name').text = name
        return node, props
    folder, _ = item(root, 'Folder', 'PlayerCombat')
    for name, definition in data.items():
        clip, props = item(folder, 'KeyframeSequence', name)
        ET.SubElement(props, 'bool', name='Loop').text = 'false'
        ET.SubElement(props, 'token', name='Priority').text = '2'  # Action
        for at, poses in sorted(definition['Frames'].items(), key=lambda p: float(p[0])):
            frame, properties = item(clip, 'Keyframe', 'Frame_'+at)
            ET.SubElement(properties, 'float', name='Time').text = at
            nodes = {}
            for part, (parent, joint) in JOINTS.items():
                node, properties = item(nodes[parent] if parent else frame, 'Pose', part)
                nodes[part] = node; pose = poses.get(joint, {})
                cf = ET.SubElement(properties, 'CoordinateFrame', name='CFrame')
                for axis in ('X', 'Y', 'Z'): ET.SubElement(cf, axis).text = str(pose.get(axis, 0))
                for index, value in enumerate(matrix(pose)): ET.SubElement(cf, 'R'+str(index//3)+str(index%3)).text = format(value,'.9g')
                ET.SubElement(properties, 'float', name='Weight').text = '0' if joint is None else '1'
                ET.SubElement(properties, 'token', name='EasingStyle').text = '0'  # Linear sampled at 60Hz
                ET.SubElement(properties, 'token', name='EasingDirection').text = '0'
            # Cosmetic markers are evidence/feedback only; damage remains server-timed.
            for label, time in (('HitStart', definition['Windup']), ('HitEnd', definition['Windup']+definition['Window'])):
                if name != 'Dodge' and abs(float(at)-time) < 1e-7:
                    _, marker = item(frame, 'KeyframeMarker', label)
                    ET.SubElement(marker, 'string', name='Value').text = label
    output = PROJECT/'art/runtime/Animations/PlayerCombat.rbxmx'
    output.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(root)
    ET.ElementTree(root).write(output, encoding='utf-8', xml_declaration=True)
    print(f'Authored 5 R15 clips / {sum(len(d["Frames"]) for d in data.values())} sampled frames: {output}')


if __name__ == '__main__': main()
