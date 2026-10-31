"""QA only: sums up what the persona testers' rounds logged (.qa/sim/persona_<name>.json, from tools/sim/run_persona.py)
into the numbers docs/PERSONA_PLAYTEST_2026-10-28.md and docs/PERSONA_RERUN_2026-10-31.md quote. Logs from before the
persona fixes (no tickets, blocks or falls list) read too: what they lack counts as none.

  python -I tools/sim/analyze_persona.py [folder with the logs, default .qa/sim]
"""
import glob, io, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

STATES = {"approach": "다가감", "react": "닿고 반응 전", "inReach": "닿아서 침", "waitFar": "멀리서 기다림", "distracted": "딴짓",
          "offTop": "지붕 밖(석탄·판자 등)", "returning": "복귀 중", "block": "막기", "escape": "떨어질 칸에서 피함", "crate": "상자 가러 감",
          "retreat": "체력 낮아 피함", "offPlank": "판자 건너감"}


def falls_of(r):
    """Every fall the round logged; an old log (first fall = out) has at most its one way out."""
    if "falls" in r:
        return r["falls"]
    return [{"t": r["aliveSeconds"], "how": r["out"], "by": r.get("outBy"), "out": True}] if r.get("out") else []


def with_car(f):
    """Whether a fall came with a car coming off: its car was marked so, or it was walking off one just before."""
    return bool(f.get("car")) or any("escape" in t for t in (f.get("trail") or [])[-6:])


def end_of(r):
    if r.get("out"):
        return f"{r['out']}({r.get('outBy') or '-'})"
    if r.get("won"):
        return "승리" + (f"(공동 {r.get('winnerCount')})" if (r.get("winnerCount") or 1) > 1 else "")
    return "끝까지"


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, ".qa", "sim")
    files = sorted(glob.glob(os.path.join(folder, "persona_*.json")))
    every = []
    for path in files:
        rounds = json.load(io.open(path, encoding="utf-8"))
        if not rounds:
            continue
        name = rounds[0]["persona"]
        n = len(rounds)
        total = lambda key: sum(r.get(key, 0) or 0 for r in rounds)
        fight = total("fightSeconds")
        alive = total("aliveSeconds")
        back = total("returnSeconds")
        dealt = {k: sum(r["dealt"].get(k, 0) for r in rounds) for k in ("light", "launch", "smash")}
        taken = {k: sum(r["taken"].get(k, 0) for r in rounds) for k in ("light", "launch", "smash")}
        block = {k: sum((r.get("block") or {}).get(k, 0) for r in rounds) for k in ("starts", "seconds", "blocked", "broken")}
        weapons, pickups = {}, {}
        for r in rounds:
            for w, c in (r.get("dealtBy") or {}).items():
                weapons[w] = weapons.get(w, 0) + c
            for w, c in (r.get("pickups") or {}).items():
                pickups[w] = pickups.get(w, 0) + c
        falls = [f for r in rounds for f in falls_of(r)]
        print(f"== {name}: {n}판, 승리 {sum(1 for r in rounds if r.get('won'))}")
        print(f"  판 길이 합 {fight:.0f}초, 판에 남아 있던 시간 {alive:.0f}초 ({alive / max(fight, 1) * 100:.0f}%), 그중 복귀 중 {back:.0f}초, 관전 {total('watchSeconds'):.0f}초")
        print(f"  떨어짐 {len(falls)}번 (홈런 {sum(1 for f in falls if f['how'] == 'homerun')}, 낙하 {sum(1 for f in falls if f['how'] == 'fall')}, 그중 떨어져 나가는 칸 때문 {sum(1 for f in falls if with_car(f))}), 판마다 처음 떨어진 때 {[round(falls_of(r)[0]['t']) if falls_of(r) else '-' for r in rounds]}")
        print(f"  싸우는 동안: 상대 찾아 걷기 {total('roamSeconds'):.0f}초, 갈 데 없음 {total('lonelySeconds'):.0f}초, 맞아서 못 움직임 {total('stunnedSeconds'):.0f}초, 무기 든 시간 {total('weaponSeconds'):.0f}초")
        fighting = max(alive - back, 1)
        print(f"  누른 공격 {total('presses')}번 ({total('presses') / fighting * 60:.0f}/분), 맞힘 약 {dealt['light']} 날림 {dealt['launch']} 홈런 {dealt['smash']}, KO {total('kos')}, 최고 연속 홈런 {max((r.get('bestStreak') or 0) for r in rounds)}")
        print(f"  맞음 약 {taken['light']} 날림 {taken['launch']} 홈런 {taken['smash']}, 가장 낮은 체력 {min(r.get('lowestHealth', 100) for r in rounds)}")
        print(f"  막기 {block['starts']}번 {block['seconds']:.0f}초, 막아 낸 공격 {block['blocked']}, 깨짐 {block['broken']}")
        print(f"  상자 가러 감 {total('crateTrips')}번 (다른 지붕 {total('crateFar')}), 주운 무기 {pickups or '-'}, 무기별 맞힘 {weapons}")
        print(f"  떨어질 칸 위에서 예고를 봄 {total('carsWarned')}번 (피하기 시작한 횟수 {total('carEscapes')}, 같은 칸에서 다시 시작한 것 포함)")
        states = {}
        for r in rounds:
            for k, v in (r.get("states") or {}).items():
                states[k] = states.get(k, 0) + v
        if states:
            print("  상태별 초: " + ", ".join(f"{STATES.get(k, k)} {v:.0f}" for k, v in sorted(states.items(), key=lambda kv: -kv[1])))
        ends = " / ".join("%s %.0f초" % (end_of(r), r["fightSeconds"]) for r in rounds)
        print(f"  판마다: {ends}")
        errors = [r["error"] for r in rounds if r.get("error")]
        if errors:
            print(f"  오류: {errors[:2]}")
        every.extend(rounds)
    if every:
        print("== 전체")
        lengths = [r["fightSeconds"] for r in every]
        outs = [r for r in every if r.get("out")]
        firsts = [falls_of(r)[0]["t"] for r in every if falls_of(r)]
        falls = [f for r in every for f in falls_of(r)]
        dealt = {k: sum(r["dealt"].get(k, 0) for r in every) for k in ("light", "launch", "smash")}
        print(f"  {len(every)}판, 판 길이 평균 {sum(lengths) / len(lengths):.0f}초 ({min(lengths):.0f}~{max(lengths):.0f}), 승리 {sum(1 for r in every if r.get('won'))}판")
        print(f"  처음 떨어지기까지 평균 {sum(firsts) / max(1, len(firsts)):.0f}초 ({len(firsts)}판), 탈락까지 평균 {sum(r['aliveSeconds'] for r in outs) / max(1, len(outs)):.0f}초 ({len(outs)}판), 끝까지 남음 {sum(1 for r in every if not r.get('out'))}판")
        print(f"  떨어짐 {len(falls)}번: {dict((k, sum(1 for f in falls if f['how'] == k)) for k in ('fall', 'homerun'))}, 떨어져 나가는 칸 때문 {sum(1 for f in falls if with_car(f))}")
        print(f"  맞힘 약 {dealt['light']} : 날림+홈런 {dealt['launch'] + dealt['smash']}, 주운 무기 {sum(sum((r.get('pickups') or {}).values()) for r in every)}번")
        feed = [e for r in every for e in (r.get("feed") or [])]
        if feed:
            print(f"  알림 {len(feed)}건: 홈런 {sum(1 for e in feed if e['how'] == 'homerun')}, 낙하 {sum(1 for e in feed if e['how'] == 'fall')} (그중 누구에게도 안 맞고 {sum(1 for e in feed if e['how'] == 'fall' and not e.get('by'))}), 탈락 {sum(1 for e in feed if e.get('out'))}")


if __name__ == "__main__":
    main()
