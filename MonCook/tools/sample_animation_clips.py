"""Sample pure Luau motion offline, rewriting require paths in a temporary copy only."""
from pathlib import Path
import argparse
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parent.parent


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau',default='luau')
    parser.add_argument('target',choices=['player','hornboar'])
    args=parser.parse_args()
    player=args.target=='player'
    utility='CombatAnimation' if player else 'HuntingAnimation'
    sampler='sample_player_clips.luau' if player else 'sample_hornboar_clips.luau'
    output=PROJECT/('art/generated/PlayerCombat/player_clip_samples.json' if player else 'art/generated/Monsters/Hornboar/V2/metadata/hornboar_clip_samples.json')
    with tempfile.TemporaryDirectory(prefix='moncook-clip-samples-') as directory:
        temp=Path(directory)
        motion=(PROJECT/'src/shared/Utilities'/f'{utility}.luau').read_text(encoding='utf-8')
        motion=motion.replace('require(script.Parent.Parent.Config.HuntingConfig)','require("./HuntingConfig")')
        (temp/'Motion.luau').write_text(motion,encoding='utf-8')
        (temp/'HuntingConfig.luau').write_bytes((PROJECT/'src/shared/Config/HuntingConfig.luau').read_bytes())
        source=(PROJECT/'tools'/sampler).read_text(encoding='utf-8')
        source=source.replace(f'../src/shared/Utilities/{utility}','./Motion').replace('../src/shared/Config/HuntingConfig','./HuntingConfig')
        (temp/'sample.luau').write_text(source,encoding='utf-8')
        content=subprocess.check_output([args.luau,str(temp/'sample.luau')])
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_bytes(content)
    print(f'{args.target}: {len(content)} bytes of authored clip samples')


if __name__=='__main__':main()
