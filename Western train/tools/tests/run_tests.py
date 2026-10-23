"""Runs the tests that need no Studio: squash math with the Luau CLI (`luau` on PATH) + the dependency check.

  python -I tools/tests/run_tests.py

  squash  src/shared/Config.luau (real numbers), SquashSpring.luau, SquashPose.luau, CrankMotion.luau: press speed
          and overshoot, the release bounce and wobble, frame-rate independence, hitches, part poses (lying torso,
          wheels on the rails, the chimney folding harder from its foot, the cap staying on top, exact return to
          rest), the rods' circle (direction, quarter-turn sides, squashing with the wheels)
  deps    check_deps.py: every require in src/ follows the layer rules (one-way dependencies, no cycles)

The modules run unchanged; the only fake is Color3.fromRGB (Config's colours), which plain Luau lacks.
"""
import io, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

MODULES = [
    ("Config", "src/shared/Config.luau"),
    ("SquashSpring", "src/shared/SquashSpring.luau"),
    ("SquashPose", "src/shared/SquashPose.luau"),
    ("CrankMotion", "src/shared/CrankMotion.luau"),
]
PRELUDE = "Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }\n"


def read(path):
    return io.open(path, encoding="utf-8").read()


def build_squash():
    parts = [PRELUDE]
    for name, rel in MODULES:
        source = read(os.path.join(ROOT, rel)).replace("--!strict\n", "", 1)
        parts.append("local %s = (function()\n%s\nend)()" % (name, source))
    parts.append(read(os.path.join(HERE, "squash_tests.luau")))
    return "\n".join(parts)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    failed = False
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "squash.luau")
        io.open(path, "w", encoding="utf-8", newline="\n").write(build_squash())
        result = subprocess.run(["luau", path], capture_output=True, text=True, encoding="utf-8")
        print("== squash")
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
