"""Static checks for src/: luau-lsp (types against the Roblox API) and selene (lint, Roblox std).

  python -I tools/lint/run_lint.py                 report; exit 1 only for findings not in known_findings.txt
  python -I tools/lint/run_lint.py --update-known  accept the current findings as known (after the owner agrees)

Needs luau-lsp, selene and rojo on PATH (this PC: ~/.local/bin, installed 2026-10-20 from the official GitHub
releases, SHA-256 checked). Roblox type definitions ("None" security = game scripts) are downloaded once into .lint/
(git-ignored) and refreshed after a week. luau-lsp cannot open paths with Korean folder names, so it runs on a copy
of src/ in an ASCII temp folder; findings are printed with repo-relative paths, duplicates removed.
known_findings.txt holds findings already reviewed and waiting for a cleanup the owner schedules (line numbers are
left out, so edits elsewhere do not make them look new). Exit codes: 0 nothing new, 1 new findings, 2 a tool failed
(its output is printed - a failed tool must never look like a clean result).
"""
import collections, io, os, re, shutil, subprocess, sys, tempfile, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, ".lint")
KNOWN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "known_findings.txt")
DEFS_URL = "https://luau-lsp.pages.dev/type-definitions/globalTypes.None.d.luau"
DEFS = os.path.join(CACHE, "globalTypes.None.d.luau")
DEFS_MAX_AGE = 7 * 24 * 3600


def fail(message, output=""):
    """Prints the cause lines first (they can sit near the top of a huge output), then the head and tail."""
    print("TOOL FAILURE: " + message)
    text = output.strip()
    causes = [line for line in text.splitlines()
              if "[ERROR]" in line or "path does not exist" in line or line.startswith("ERROR")]
    for line in causes[:20]:
        print("  " + line)
    if len(text) > 3000:
        text = text[:1500] + "\n...\n" + text[-1500:]
    if text:
        print(text)
    sys.exit(2)


def need_tools():
    missing = [t for t in ("luau-lsp", "selene", "rojo") if shutil.which(t) is None]
    if missing:
        fail("missing on PATH: " + ", ".join(missing) + " (see docs/DESIGN_V2.md, 개발 도구)")


def ensure_definitions():
    os.makedirs(CACHE, exist_ok=True)
    if os.path.exists(DEFS) and time.time() - os.path.getmtime(DEFS) < DEFS_MAX_AGE:
        return
    try:
        with urllib.request.urlopen(DEFS_URL, timeout=60) as response:
            data = response.read()
        io.open(DEFS, "wb").write(data)
        print("downloaded Roblox type definitions (%d KB)" % (len(data) // 1024))
    except OSError as error:
        if not os.path.exists(DEFS):
            fail("cannot download Roblox type definitions: %s" % error)
        print("using cached Roblox type definitions (download failed: %s)" % error)


def ascii_temp_root():
    """luau-lsp needs an ASCII path; the user temp folder is not ASCII when the Windows user name is Korean."""
    for base in (tempfile.gettempdir(), os.path.join(os.environ.get("PUBLIC", r"C:\Users\Public"), "Temp")):
        if base.isascii():
            os.makedirs(base, exist_ok=True)
            return base
    fail("no ASCII temp folder for luau-lsp (set TEMP to an English-only path)")


def run(args, cwd):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")


# luau-lsp writes logs, findings and its own errors all to stderr. A finding (src/AnalyzeCli.cpp `report`) is
# "<path>(line,col): <Kind>: <message>" - type errors carry the mirror path, lint warnings (LocalUnused, ...) a path
# relative to it, and a message may continue on the next lines. The run's own errors start with:
TOOL_ERRORS = ("[ERROR]", "Error opening ", "Cannot get ", "Failed to ", "error: ", "WARNING: ", "warning: ")
MIRROR = re.compile(r"[A-Za-z]:\\[^'\"\n]*?bw-lint-[^\\/]+[\\/]")  # the temp copy's folder (spaces allowed), anywhere
FINDING = re.compile(r"^(src[\\/][^\[(\n]*?)(?: \[game/[^\]]*\])?\((\d+),(\d+)\): ([A-Za-z]\w*): (.*)$")


def classify_luau_lsp(output):
    """(findings with repo-relative paths, lines that show the run itself went wrong). The temp folder is cut out of
    every line first (messages can name other modules by path), so findings match known_findings.txt every run."""
    findings, problems = [], []
    for line in output.splitlines():
        if line.startswith("[INFO]") or line.startswith("[WARN]") or not line.strip():
            continue
        starts_with_mirror = MIRROR.match(line) is not None
        clean = MIRROR.sub("", line)
        match = FINDING.match(clean)
        if match:
            path, row, col, kind, message = match.groups()
            findings.append("%s(%s,%s): %s: %s" % (path.replace("\\", "/").rstrip(), row, col, kind, message))
        elif line.startswith(TOOL_ERRORS) or starts_with_mirror or not findings:
            problems.append(line)  # a tool error, or a path line that is not a finding (e.g. "<path>: <error>")
        else:
            findings[-1] += " " + clean.strip()  # the rest of a multi-line message
    return findings, problems


def selftest():
    """The output classifier must keep findings and catch tool errors; a broken classifier must not pass."""
    mirror = r"c:\Users\x\AppData\Local\Temp\bw-lint-ab12\src"
    finding = mirror + r"\client\A.luau [game/StarterPlayer/A](3,5): TypeError: Expected this to be"
    cases = [  # (output, findings expected, problems expected)
        (finding + "\n\t'Model'\nbut got\n\t'Model?'", 1, 0),
        (r"src\client\A.luau [game/StarterPlayer/A](7,1): LocalUnused: Variable 'x' is never used", 1, 0),
        ("[INFO] Loading definitions\n" + finding + "\nError opening src/server/Match.luau", 1, 1),
        ("[ERROR] Failed to read definitions file defs.d.luau", 0, 1),
        (finding + "\n" + mirror + r"\server\B.luau: cannot resolve", 1, 1),
        (r"Cannot get c:\x\src: path does not exist", 0, 1),
        (finding + "\ncaused by:\n  'T' from '" + mirror + r"\shared\TB.luau' is not 'T' from '" + mirror + r"\shared\TA.luau'", 1, 0),
        (r"c:\Users\Jane Doe\AppData\Local\Temp\bw-lint-ab12\src\client\A.luau [game/X](3,5): TypeError: x", 1, 0),
    ]
    failures = []
    for output, want_findings, want_problems in cases:
        found, problems = classify_luau_lsp(output)
        if len(found) != want_findings or len(problems) != want_problems:
            failures.append("%r -> %d finding(s), %d problem(s)" % (output[:60], len(found), len(problems)))
        elif any("bw-lint-" in f for f in found):
            failures.append("%r -> the temp folder stayed in a finding" % output[:60])
    return failures


def luau_lsp_findings():
    """Runs luau-lsp analyze on an ASCII-path copy; returns unique findings with repo-relative paths."""
    try:
        with tempfile.TemporaryDirectory(prefix="bw-lint-", dir=ascii_temp_root()) as mirror:
            shutil.copytree(os.path.join(ROOT, "src"), os.path.join(mirror, "src"))
            shutil.copy(os.path.join(ROOT, "default.project.json"), mirror)
            shutil.copy(DEFS, os.path.join(mirror, "defs.d.luau"))
            sourcemap = run(["rojo", "sourcemap", "default.project.json", "-o", "sourcemap.json"], mirror)
            if sourcemap.returncode != 0:
                fail("rojo sourcemap failed", sourcemap.stdout + sourcemap.stderr)
            result = run(["luau-lsp", "analyze", "--platform=roblox", "--sourcemap=sourcemap.json",
                          "--definitions:@roblox=defs.d.luau", "src"], mirror)
    except (OSError, shutil.Error) as error:
        fail("could not prepare the ASCII copy for luau-lsp: %s" % error)
    output = result.stdout + result.stderr
    findings, problems = classify_luau_lsp(output)
    if problems or result.returncode not in (0, 1) or (result.returncode == 1 and not findings):
        fail("luau-lsp did not analyze src/ cleanly", "\n".join(problems) + "\n" + output)
    return sorted(set(findings))


def selene_findings():
    """selene prints findings on stdout; anything on stderr (e.g. the Roblox std cannot be built) is a failure."""
    result = run(["selene", "--display-style=quiet", "src"], ROOT)
    findings = sorted(line.replace("\\", "/") for line in result.stdout.splitlines()
                      if re.match(r"^src[\\/].*: (error|warning)\[", line))
    if result.stderr.strip() or result.returncode not in (0, 1) or (result.returncode != 0 and not findings):
        fail("selene did not lint src/ cleanly", result.stderr + "\n" + result.stdout)
    return findings


def without_position(finding):
    """The same finding after unrelated edits: drop "(12,5)" (luau-lsp) and ":12:5" (selene)."""
    return re.sub(r"\(\d+,\d+\)|:\d+:\d+(?=:)", "", finding)


def read_known():
    if not os.path.exists(KNOWN):
        return collections.Counter()
    lines = io.open(KNOWN, encoding="utf-8").read().splitlines()
    return collections.Counter(line for line in lines if line.strip() and not line.startswith("#"))


def write_known(findings):
    header = ("# Known static-check findings, reviewed and accepted until a cleanup the owner schedules.\n"
              "# Written by tools/lint/run_lint.py --update-known; line numbers are left out on purpose.\n")
    io.open(KNOWN, "w", encoding="utf-8", newline="\n").write(header + "".join(without_position(f) + "\n" for f in findings))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    broken = selftest()
    if broken:
        fail("the luau-lsp output classifier failed its self-test: " + "; ".join(broken))
    need_tools()
    ensure_definitions()
    findings = luau_lsp_findings() + selene_findings()
    if "--update-known" in sys.argv:
        write_known(findings)
        print("known_findings.txt now lists %d finding(s)" % len(findings))
        return
    known = read_known()
    remaining = known.copy()
    new = []
    for finding in findings:
        key = without_position(finding)
        if remaining[key] > 0:
            remaining[key] -= 1
        else:
            new.append(finding)
    gone = sum(remaining.values())
    print("== new findings: %d" % len(new))
    for finding in new:
        print("  " + finding)
    print("== known findings still present: %d (known_findings.txt, cleanup timing with the owner)" % (len(findings) - len(new)))
    if gone:
        print("== %d known finding(s) are gone - run with --update-known to shrink the list" % gone)
    print("RESULT: " + ("NO NEW FINDINGS" if not new else "%d NEW FINDING(S)" % len(new)))
    sys.exit(1 if new else 0)


if __name__ == "__main__":
    main()
