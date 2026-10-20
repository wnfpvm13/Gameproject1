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


def luau_lsp_findings():
    """Runs luau-lsp analyze on an ASCII-path copy; returns unique findings with repo-relative paths."""
    with tempfile.TemporaryDirectory(prefix="bw-lint-", dir=ascii_temp_root()) as mirror:
        shutil.copytree(os.path.join(ROOT, "src"), os.path.join(mirror, "src"))
        shutil.copy(os.path.join(ROOT, "default.project.json"), mirror)
        shutil.copy(DEFS, os.path.join(mirror, "defs.d.luau"))
        sourcemap = run(["rojo", "sourcemap", "default.project.json", "-o", "sourcemap.json"], mirror)
        if sourcemap.returncode != 0:
            fail("rojo sourcemap failed", sourcemap.stdout + sourcemap.stderr)
        result = run(["luau-lsp", "analyze", "--platform=roblox", "--sourcemap=sourcemap.json",
                      "--definitions:@roblox=defs.d.luau", "src"], mirror)
    output = result.stdout + result.stderr
    findings = []
    for line in output.splitlines():
        if line.startswith("[INFO]") or line.startswith("[WARN]"):
            continue
        start = re.search(r"bw-lint-[^\\/]+[\\/](src[\\/].*)$", line)
        if start:  # a new finding: "<mirror>\src\x.luau [game/...](line,col): TypeError: ..."
            findings.append(re.sub(r" \[game/[^\]]*\]", "", start.group(1)).replace("\\", "/"))
        elif findings and line.strip():
            findings[-1] += " " + line.strip()
    broken = "[ERROR]" in output or "path does not exist" in output
    if broken or result.returncode not in (0, 1) or (result.returncode == 1 and not findings):
        fail("luau-lsp did not analyze src/", output)
    return sorted(set(findings))


def selene_findings():
    result = run(["selene", "--display-style=quiet", "src"], ROOT)
    findings = sorted(line.replace("\\", "/") for line in result.stdout.splitlines()
                      if re.match(r"^src[\\/].*: (error|warning)\[", line))
    if result.returncode not in (0, 1) or (result.returncode != 0 and not findings):
        fail("selene did not lint src/", result.stdout + result.stderr)
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
