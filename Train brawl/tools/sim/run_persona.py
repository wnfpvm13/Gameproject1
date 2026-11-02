"""QA only: runs the persona testers one after another in the open Studio QA window (Play, solo practice) and saves what
each one's rounds logged (tools/sim/persona_play.luau) to .qa/sim/persona_<name>.json (git-ignored).

  python -I tools/sim/run_persona.py <studio_id> <path to studio_mcp_client.py> [rounds per persona] [only these names, comma-separated]

Studio must be in Play with the Workspace attribute TrainBrawlSolo on (the practice bots join every round).
"""
import json, os, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, ".qa", "sim")
FIGHT_SECONDS = 160  # Config.Round.MaxSeconds (150) and a little

# Two women, two men (owner 2026-10-28). Timings: react = seconds before the first press once in reach; jitter = extra
# seconds between presses; fullString = share of strings carried to the third (launching) hit; crate = chance a seen
# crate on its top is gone for; chase = runs after fighters (else waits for them to come near); retreat = health at or
# under which it keeps away; distracted = chance a second it looks away for 1-2.5 s; reachUse = how close to its
# weapon's full reach it attacks from. Added for the rerun after the persona fixes (2026-10-31; the ones above are
# kept as they were, so the two runs compare): block = chance it holds its block after a hit gets through (after its
# react time); blockHold = seconds it holds it; notice = seconds before it notices its car is coming off; patience =
# seconds a waiting persona waits for the other to come before it goes itself (the first run waited for good: one
# persona stood still 100 s at a roof's edge the bots never come to). Added for the fun pass (2026-11-02, decisions 23-26):
# counter = chance it lets go of its block to strike back right after a blocked hit.
PERSONAS = [
    {"name": "서윤", "react": [0.5, 1.0], "jitter": 0.25, "fullString": 0.5, "crate": 0.9, "chase": False, "retreat": 40, "distracted": 0.08, "reachUse": 0.8,
     "block": 0.35, "blockHold": [1.0, 2.0], "notice": [1.0, 2.0], "patience": 20, "counter": 0.2},
    {"name": "하은", "react": [0.2, 0.35], "jitter": 0.05, "fullString": 0.95, "crate": 0.5, "chase": True, "retreat": 0, "distracted": 0.01, "reachUse": 0.9,
     "block": 0.5, "blockHold": [0.4, 0.8], "notice": [0.4, 0.8], "counter": 0.6},
    {"name": "민준", "react": [0.3, 0.6], "jitter": 0.0, "fullString": 1.0, "crate": 1.0, "chase": True, "retreat": 0, "distracted": 0.03, "reachUse": 0.7,
     "block": 0.1, "blockHold": [0.3, 0.6], "notice": [0.8, 1.6], "counter": 0.3},
    {"name": "도현", "react": [0.3, 0.6], "jitter": 0.12, "fullString": 0.85, "crate": 0.6, "chase": False, "retreat": 35, "distracted": 0.04, "reachUse": 0.95,
     "block": 0.6, "blockHold": [0.5, 1.0], "notice": [0.4, 0.8], "patience": 8, "counter": 0.7},
]


def lua_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list):
        return "{ " + ", ".join(lua_value(x) for x in v) + " }"
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{k} = {lua_value(x)}" for k, x in v.items()) + " }"
    raise TypeError(v)


def run(client, studio, model, code):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8", newline="\n") as f:
        f.write(code)
        path = f.name
    try:
        out = subprocess.run([sys.executable, "-I", client, "call", "execute_luau", json.dumps({"studio_id": studio, "datamodel_type": model}), path],
                             capture_output=True, text=True, encoding="utf-8", timeout=120)
        return out.stdout.strip().splitlines()[-1] if out.stdout.strip() else out.stderr.strip()
    finally:
        os.remove(path)


def main():
    sys.stdout.reconfigure(encoding="utf-8")  # (-I ignores PYTHONIOENCODING; the names are Korean)
    studio, client = sys.argv[1], sys.argv[2]
    rounds = int(sys.argv[3]) if len(sys.argv) > 3 else 2
    only = sys.argv[4].split(",") if len(sys.argv) > 4 else None
    os.makedirs(OUT, exist_ok=True)
    source = open(os.path.join(HERE, "persona_play.luau"), encoding="utf-8").read()
    # Off the character: the mouse lock then leaves the character facing where it walks and attacks.
    run(client, studio, "Client", "workspace.CurrentCamera.CameraSubject = workspace.Terrain return 'cam'")
    for persona in PERSONAS:
        if only and persona["name"] not in only:
            continue
        persona = dict(persona, rounds=rounds)
        run(client, studio, "Client", "_G.PersonaLog = {} return 'clear'")
        print(persona["name"], run(client, studio, "Client", source.replace("__PERSONA__", lua_value(persona))), flush=True)
        started = time.time()
        # (plus the rest of a fight already running when it starts: it logs from the next one)
        while time.time() - started < rounds * 260 + FIGHT_SECONDS:
            time.sleep(10)
            if run(client, studio, "Client", "return tostring(_G.PersonaRunning)") == "false":
                break
        log = run(client, studio, "Client", "return game:GetService('HttpService'):JSONEncode(_G.PersonaLog or {})")
        with open(os.path.join(OUT, f"persona_{persona['name']}.json"), "w", encoding="utf-8") as f:
            f.write(log)
        print(persona["name"], "done in", int(time.time() - started), "s", flush=True)


if __name__ == "__main__":
    main()
