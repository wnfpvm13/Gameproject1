"""Runs the tests that need no Studio: squash math with the Luau CLI (`luau` on PATH) + the dependency check.

  python -I tools/tests/run_tests.py

  squash  src/shared/Config.luau (real numbers), SquashSpring.luau, SquashPose.luau, CrankMotion.luau, CourseMath.luau,
          JumpArc.luau, src/server/CrewBook.luau:
          press speed and overshoot, the release bounce and wobble, frame-rate independence, hitches, part poses (a lying part,
          wheels on the rails, the chimney folding harder from its foot, the cap staying on top, exact return to
          rest), the rods' circle (direction, quarter-turn sides, squashing with the wheels), the legs' swing
          (opposite sides, limits, kick on press, flap on release, the shoes never below the rails), the run toward the
          bridges (clock, bridge places, when a bridge is over the locomotive, the server's pass check, the clearance),
          who drives and who rides (pairing in join order, the stand-in driver, leaving), mail, barrels, the jump and
          the gold mail (the arc, where the gold hangs, the jump clear of the bridges, only a jump together reaching it)
  deps    check_deps.py: every require in src/ follows the layer rules (one-way dependencies, no cycles)

The modules run unchanged; the only fakes are Color3.fromRGB and Vector3.new (Config's colours and face-window
directions), which plain Luau lacks.
"""
import io, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

MODULES = [
    ("Config", "src/shared/Config.luau"),
    ("SquashSpring", "src/shared/SquashSpring.luau"),
    ("SquashPose", "src/shared/SquashPose.luau"),
    ("CrankMotion", "src/shared/CrankMotion.luau"),
    ("CourseMath", "src/shared/CourseMath.luau"),
    ("JumpArc", "src/shared/JumpArc.luau"),
    ("CrewBook", "src/server/CrewBook.luau"),
]
PRELUDE = (
    "Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }\n"
    "Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }\n"
)


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
