"""Runs the virtual-clock tests with the Luau CLI (`luau` on PATH): no Studio needed.

  python -I tools/tests/run_tests.py

Each suite is one generated Luau file: a prelude (virtual clock, coroutine scheduler, fake Roblox objects) +
the REAL module sources from src/ + the test file. The modules run unchanged; only `game`, `workspace`, `task`,
`os.clock`, `Random`, `Instance` and the remotes (Net) are fakes.
  speech  src/client/Speech.luau: transcript start ranges, late texts, ~10 s cuts, waitSettled, unstable notice
  server  Config, Judge, WordBank, Themes, Match, JudgeService, WordService, MissionService: range judging,
          settle at the end of a round, per-player habit words, mission spacing with the real word schedule
"""
import io, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))

SERVER_MODULES = [
    ("Config", "src/shared/Config.luau"),
    ("Judge", "src/shared/Judge.luau"),
    ("WordBank", "src/server/content/WordBank.luau"),
    ("Themes", "src/server/content/Themes.luau"),
    ("Match", "src/server/Match.luau"),
    ("JudgeService", "src/server/services/JudgeService.luau"),
    ("WordService", "src/server/services/WordService.luau"),
    ("MissionService", "src/server/services/MissionService.luau"),
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


def build_server():
    parts = [read(os.path.join(HERE, "prelude_server.luau"))]
    for name, rel in SERVER_MODULES:
        parts.append("loaders.%s = function()\n%s\nend" % (name, module_source(rel)))
    parts.append(read(os.path.join(HERE, "server_tests.luau")))
    return "\n".join(parts)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    failed = False
    with tempfile.TemporaryDirectory() as tmp:
        for name, build in (("speech", build_speech), ("server", build_server)):
            path = os.path.join(tmp, name + ".luau")
            io.open(path, "w", encoding="utf-8", newline="\n").write(build())
            result = subprocess.run(["luau", path], capture_output=True, text=True, encoding="utf-8")
            print("== " + name)
            print(result.stdout.rstrip())
            if result.stderr.strip():
                print(result.stderr.rstrip())
            if result.returncode != 0 or "ALL PASS" not in result.stdout:
                failed = True
    print("RESULT: " + ("FAILED" if failed else "ALL SUITES PASS"))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
