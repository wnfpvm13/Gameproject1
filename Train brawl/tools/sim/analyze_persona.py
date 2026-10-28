"""QA only: sums up what the persona testers' rounds logged (.qa/sim/persona_<name>.json, from tools/sim/run_persona.py)
into the numbers docs/PERSONA_PLAYTEST_2026-10-28.md quotes.

  python -I tools/sim/analyze_persona.py
"""
import glob, io, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    files = sorted(glob.glob(os.path.join(ROOT, ".qa", "sim", "persona_*.json")))
    every = []
    for path in files:
        rounds = json.load(io.open(path, encoding="utf-8"))
        if not rounds:
            continue
        name = rounds[0]["persona"]
        n = len(rounds)
        total = lambda key: sum(r.get(key, 0) for r in rounds)
        fight = total("fightSeconds")
        alive = total("aliveSeconds")
        dealt = {k: sum(r["dealt"].get(k, 0) for r in rounds) for k in ("light", "launch", "smash")}
        taken = {k: sum(r["taken"].get(k, 0) for r in rounds) for k in ("light", "launch", "smash")}
        weapons, pickups = {}, {}
        for r in rounds:
            for w, c in (r.get("dealtBy") or {}).items():
                weapons[w] = weapons.get(w, 0) + c
            for w, c in (r.get("pickups") or {}).items():
                pickups[w] = pickups.get(w, 0) + c
        outs = [f"{r.get('out') or ('승리' if r.get('won') else '끝까지')}({r.get('outBy') or '-'}) {r['aliveSeconds']:.0f}초" for r in rounds]
        print(f"== {name}: {n}판, 승리 {sum(1 for r in rounds if r.get('won'))}")
        print(f"  판 길이 합 {fight:.0f}초, 살아 있던 시간 {alive:.0f}초 ({alive / max(fight, 1) * 100:.0f}%), 관전 {total('watchSeconds'):.0f}초")
        print(f"  살아 있는 동안: 상대 찾아 걷기 {total('roamSeconds'):.0f}초, 갈 데 없음 {total('lonelySeconds'):.0f}초, 맞아서 못 움직임 {total('stunnedSeconds'):.0f}초")
        print(f"  누른 공격 {total('presses')}번 ({total('presses') / max(alive, 1) * 60:.0f}/분), 맞힘 약 {dealt['light']} 날림 {dealt['launch']} 홈런 {dealt['smash']}, KO {total('kos')}")
        print(f"  맞음 약 {taken['light']} 날림 {taken['launch']} 홈런 {taken['smash']}, 가장 낮은 체력 {min(r.get('lowestHealth', 100) for r in rounds)}")
        print(f"  상자 가러 감 {total('crateTrips')}번, 주운 무기 {pickups or '-'}, 무기별 맞힘 {weapons}")
        states = {}
        for r in rounds:
            for k, v in (r.get("states") or {}).items():
                states[k] = states.get(k, 0) + v
        if states:
            names = {"approach": "다가감", "react": "닿고 반응 전", "inReach": "닿아서 침", "waitFar": "멀리서 기다림", "distracted": "딴짓", "offTop": "지붕 밖(석탄·판자 등)"}
            print("  상태별 초: " + ", ".join(f"{names.get(k, k)} {v:.0f}" for k, v in sorted(states.items(), key=lambda kv: -kv[1])))
        print(f"  판마다: {' / '.join(outs)}")
        errors = [r["error"] for r in rounds if r.get("error")]
        if errors:
            print(f"  오류: {errors[:2]}")
        every.extend(rounds)
    if every:
        print("== 전체")
        lengths = [r["fightSeconds"] for r in every]
        print(f"  {len(every)}판, 판 길이 평균 {sum(lengths) / len(lengths):.0f}초 ({min(lengths):.0f}~{max(lengths):.0f}), 무승부(시간 끝) {sum(1 for r in every if not r.get('winner'))}판")
        print(f"  탈락까지 평균 {sum(r['aliveSeconds'] for r in every if r.get('out')) / max(1, sum(1 for r in every if r.get('out'))):.0f}초, 탈락 방식 {dict((k, sum(1 for r in every if r.get('out') == k)) for k in ('fall', 'homerun'))}")


if __name__ == "__main__":
    main()
