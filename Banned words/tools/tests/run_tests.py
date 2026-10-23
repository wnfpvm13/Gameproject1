"""Runs the virtual-clock tests with the Luau CLI (`luau` on PATH): no Studio needed.

  python -I tools/tests/run_tests.py

Each suite is one generated Luau file: a prelude (virtual clock, coroutine scheduler, fake Roblox objects) +
the REAL module sources from src/ + the test file. The modules run unchanged; only `game`, `workspace`, `task`,
`os.clock`, `Random`, `Instance` and the remotes (Net) are fakes.
  speech  src/client/Speech.luau: transcript start ranges, late texts, ~10 s cuts, waitSettled, unstable notice
  server  Config, Judge, WordBank, Match, JudgeService, WordService: range judging, settle at the end of a round,
          per-player habit words (kept for phase 2 speech judging and the bundle 5 banned words), and no fixed UI
          text (Config.TEXT) containing a word-bank word
  round   Config, Match, LifeService, Timeline, MissionRunner, ChatService, RoundService (+ stub chairs, stands, voice,
          scores and a scripted mission): lives rules, the time budget, the final triggers, whole rounds, joining by chat
  mission Config, Match, QuizBank, Quiz, Roulette, VoteRules, OneWord(+Topics), TestMission, MissionRunner (+ a fake
          ctx): the quiz (answers, fails,
          the AFK report, no repeats, no words in play, the final bank), the roulette, the menu order, the real bank
  deps    check_deps.py: every require in src/ follows the layer rules (one-way dependencies, no cycles)
"""
import io, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))

SERVER_MODULES = [
    ("Config", "src/shared/Config.luau"),
    ("Judge", "src/shared/Judge.luau"),
    ("WordBank", "src/server/content/WordBank.luau"),
    ("Match", "src/server/Match.luau"),
    ("JudgeService", "src/server/services/JudgeService.luau"),
    ("WordService", "src/server/services/WordService.luau"),
]

ROUND_MODULES = [
    ("Config", "src/shared/Config.luau"),
    ("Match", "src/server/Match.luau"),
    ("Judge", "src/shared/Judge.luau"),
    ("WordBank", "src/server/content/WordBank.luau"),
    ("WordService", "src/server/services/WordService.luau"),
    ("LifeService", "src/server/services/LifeService.luau"),
    ("Timeline", "src/server/services/Timeline.luau"),
    ("MissionRunner", "src/server/services/MissionRunner.luau"),
    ("ChatService", "src/server/services/ChatService.luau"),
    ("PresenterService", "src/server/services/PresenterService.luau"),
    ("VoiceServiceReal", "src/server/services/VoiceService.luau"),  # section 9 (RoundService gets a stub)
    ("RoundService", "src/server/RoundService.luau"),
]

MISSION_MODULES = [
    ("Config", "src/shared/Config.luau"),
    ("Match", "src/server/Match.luau"),
    ("QuizBank", "src/server/content/QuizBank.luau"),
    ("Quiz", "src/server/missions/Quiz.luau"),
    ("Roulette", "src/server/missions/Roulette.luau"),
    ("VoteRules", "src/shared/VoteRules.luau"),
    ("OneWordTopics", "src/server/content/OneWordTopics.luau"),
    ("OneWord", "src/server/missions/OneWord.luau"),
    ("TestMission", "src/server/missions/TestMission.luau"),
    ("MissionRunner", "src/server/services/MissionRunner.luau"),
]


def read(path):
    return io.open(path, encoding="utf-8").read()


def module_source(rel):
    return read(os.path.join(REPO, rel)).replace("--!strict\n", "", 1)


def build_speech():
    return "\n".join([
        read(os.path.join(HERE, "prelude_client.luau")),
        "local Speech = (function()\n" + module_source("src/client/Speech.luau") + "\nend)()",
        read(os.path.join(HERE, "speech_tests.luau")),
    ])


def build_with_modules(modules, tests):
    parts = [read(os.path.join(HERE, "prelude_server.luau"))]
    for name, rel in modules:
        parts.append("loaders.%s = function()\n%s\nend" % (name, module_source(rel)))
    parts.append(read(os.path.join(HERE, tests)))
    return "\n".join(parts)


def build_server():
    return build_with_modules(SERVER_MODULES, "server_tests.luau")


def build_round():
    return build_with_modules(ROUND_MODULES, "round_tests.luau")


def build_mission():
    return build_with_modules(MISSION_MODULES, "mission_tests.luau")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    failed = False
    with tempfile.TemporaryDirectory() as tmp:
        for name, build in (("speech", build_speech), ("server", build_server), ("round", build_round),
                            ("mission", build_mission)):
            path = os.path.join(tmp, name + ".luau")
            io.open(path, "w", encoding="utf-8", newline="\n").write(build())
            result = subprocess.run(["luau", path], capture_output=True, text=True, encoding="utf-8")
            print("== " + name)
            print(result.stdout.rstrip())
            if result.stderr.strip():
                print(result.stderr.rstrip())
            if result.returncode != 0 or "ALL PASS" not in result.stdout:
                failed = True
    deps = subprocess.run([sys.executable, "-I", os.path.join(HERE, "check_deps.py")], capture_output=True, text=True, encoding="utf-8")
    print("== deps")
    print((deps.stdout + deps.stderr).rstrip())
    if deps.returncode != 0 or "ALL PASS" not in deps.stdout:
        failed = True
    print("RESULT: " + ("FAILED" if failed else "ALL SUITES PASS"))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
