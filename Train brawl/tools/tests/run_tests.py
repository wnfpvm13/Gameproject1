"""Runs the tests that need no Studio: the arena and bat math with the Luau CLI (`luau` on PATH) + the dependency check.

  python -I tools/tests/run_tests.py

  brawl   src/shared/Config.luau (real numbers), ArenaLayout.luau, BatMath.luau: where the trains, cars, planks and
          spawn spots are, the fall line, the cone a swing covers and the knock it gives, and that the tuning keeps its
          promises (the gap is wider than a jump, a knock carries more than half a roof and less than a whole one)
  deps    check_deps.py: every require in src/ follows the layer rules (one-way dependencies, no cycles)

The modules run unchanged; the only fakes are Color3.fromRGB and Vector3.new (Config's colours and sizes), which plain
Luau lacks. (Taken over from Western train's runner, with this game's modules.)
"""
import io, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

MODULES = [
    ("Config", "src/shared/Config.luau"),
    ("ArenaLayout", "src/shared/ArenaLayout.luau"),
    ("BatMath", "src/shared/BatMath.luau"),
]
PRELUDE = (
    "Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }\n"
    "Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }\n"
)


def read(path):
    return io.open(path, encoding="utf-8").read()


def build():
    parts = [PRELUDE]
    for name, rel in MODULES:
        source = read(os.path.join(ROOT, rel)).replace("--!strict\n", "", 1)
        parts.append("local %s = (function()\n%s\nend)()" % (name, source))
    parts.append(read(os.path.join(HERE, "brawl_tests.luau")))
    return "\n".join(parts)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    failed = False
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "brawl.luau")
        io.open(path, "w", encoding="utf-8", newline="\n").write(build())
        result = subprocess.run(["luau", path], capture_output=True, text=True, encoding="utf-8")
        print("== brawl")
        print(result.stdout.rstrip())
        if result.stderr.strip():
            print(result.stderr.rstrip())
        if result.returncode != 0 or "ALL PASS" not in result.stdout:
            failed = True
    print("== deps")
    deps = subprocess.run([sys.executable, "-I", os.path.join(HERE, "check_deps.py")], capture_output=True, text=True, encoding="utf-8")
    print(deps.stdout.rstrip())
    if deps.stderr.strip():
        print(deps.stderr.rstrip())
    if deps.returncode != 0:
        failed = True
    print("RESULT: " + ("FAILED" if failed else "ALL SUITES PASS"))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
