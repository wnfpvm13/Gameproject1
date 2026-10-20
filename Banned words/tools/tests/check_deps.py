"""Dependency rules check for src/ (owner rule: one job per module, one-way dependencies, no cycles).

  python -I tools/tests/check_deps.py        (also run by tools/tests/run_tests.py)

Reads every `require(...)` in src/ (standard library only, no Roblox or luau needed). A small scanner blanks out
comments and string contents first, so requires inside comments or strings are ignored and `---[[` toggles stay
live code. The target is the last `WaitForChild("Name")` / `FindFirstChild("Name")` inside the call, so module
names must stay unique in src/. Every module belongs to a layer by its path, and a layer may only require the
layers listed in ALLOWED: services never require each other (RoundService wires them with callbacks), UI panels
share only Style, client parts and data (content) see only shared code, and nothing on one side requires the other.
A new folder has no layer until layer_of knows it (the check fails and says so).
A self-test with planted violations runs first, so a broken checker cannot pass silently.
"""
import io, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(os.path.dirname(os.path.dirname(HERE)), "src")

# layer -> layers it may require (anything else is a violation; cycles are checked separately)
ALLOWED = {
    "shared": {"shared"},
    "net": {"shared"},
    "match": {"shared", "net"},
    "content": {"shared"},
    "service": {"shared", "net", "match", "content"},
    "flow": {"shared", "net", "match", "content", "service"},
    "server_entry": {"shared", "net", "match", "flow"},
    "client_style": {"shared"},
    "client_ui": {"shared", "client_style"},
    "client_part": {"shared"},
    "client_entry": {"shared", "client_part", "client_ui", "client_style"},
}

CHILD = re.compile(r'(?:WaitForChild|FindFirstChild)\(\s*"([^"]+)"')
REQUIRE_CALL = re.compile(r"\brequire\s*\(")
REQUIRE_NO_PARENS = re.compile(r"\brequire\s*[\"'`\[]")  # require"X" / require[[X]]: cannot be named, so it fails
SUFFIXES = (".server.luau", ".client.luau", ".luau", ".server.lua", ".client.lua", ".lua")


def module_name(rel):
    """Rojo naming: X.luau -> X, X.server.luau -> X, init.*.luau -> its folder."""
    parts = rel.split("/")
    for suffix in SUFFIXES:
        if parts[-1].endswith(suffix):
            stem = parts[-1][: -len(suffix)]
            return parts[-2] if stem == "init" and len(parts) > 1 else stem
    return parts[-1]


def layer_of(rel):
    """rel: path under src/ with forward slashes, e.g. "server/services/WordService.luau". None = unknown place."""
    parts = rel.split("/")
    name = module_name(rel)
    if parts[0] == "shared":
        return "shared"
    if parts[0] == "server":
        if len(parts) == 3 and parts[1] == "services":
            return "service"
        if len(parts) == 3 and parts[1] == "content":
            return "content"
        if len(parts) == 2:
            return {"Net": "net", "Match": "match", "RoundService": "flow", "Main": "server_entry"}.get(name)
        return None
    if parts[0] == "client":
        if len(parts) == 2 and parts[1].startswith("init.client."):
            return "client_entry"
        if len(parts) == 3 and parts[1] == "UI":
            return "client_style" if name == "Style" else "client_ui"
        if len(parts) == 2:
            return "client_part"
        return None
    return None


def mask(source):
    """Returns (code, masked), both as long as `source`: `code` has comments blanked, `masked` also has string
    contents blanked, so positions found in `masked` can be read back from `code`."""
    n = len(source)
    code, masked = list(source), list(source)

    def blank(chars, a, b):
        for k in range(a, b):
            if chars[k] != "\n":
                chars[k] = " "

    def bracket_level(at):  # [[ -> 0, [==[ -> 2, anything else -> -1
        if at < n and source[at] == "[":
            j = at + 1
            while j < n and source[j] == "=":
                j += 1
            if j < n and source[j] == "[":
                return j - at - 1
        return -1

    def bracket_end(at, level):  # index just past the matching ]=*]
        close = "]" + "=" * level + "]"
        end = source.find(close, at + level + 2)
        return n if end < 0 else end + len(close)

    def string_end(at, quote):
        """Index just past the string opened at `at`, plus its literal parts (backtick {expressions} stay code)."""
        literal, j, start = [], at + 1, at + 1
        while j < n and source[j] != quote and source[j] != "\n":
            if source[j] == "\\":
                if source.startswith("\\z", j):  # \z skips the following whitespace, line breaks included
                    j += 2
                    while j < n and source[j] in " \t\r\n":
                        j += 1
                else:
                    j += 2
            elif quote == "`" and source[j] == "{":
                literal.append((start, j))
                depth, j = 1, j + 1
                while j < n and depth > 0:
                    if source[j] in "\"'":
                        j = string_end(j, source[j])[0]
                        continue
                    depth += {"{": 1, "}": -1}.get(source[j], 0)
                    j += 1
                start = j
            else:
                j += 1
        literal.append((start, min(j, n)))
        return min(j + 1, n), literal

    i = 0
    while i < n:
        c = source[i]
        if source.startswith("--", i):
            level = bracket_level(i + 2)
            if level >= 0:
                end = bracket_end(i + 2, level)
            else:
                end = source.find("\n", i)
                end = n if end < 0 else end
            blank(code, i, end)
            blank(masked, i, end)
            i = end
        elif c in "\"'`":
            end, literal = string_end(i, c)
            for a, b in literal:
                blank(masked, a, b)
            i = end
        elif bracket_level(i) >= 0:
            level = bracket_level(i)
            end = bracket_end(i, level)
            blank(masked, i + level + 2, max(i + level + 2, end - level - 2))
            i = end
        else:
            i += 1
    return "".join(code), "".join(masked)


def require_targets(source):
    """Names required by `source`, plus the raw text of any require whose target cannot be named."""
    code, masked = mask(source)
    names, unresolved = [], []
    for match in REQUIRE_CALL.finditer(masked):
        open_at = match.end() - 1
        depth, j = 0, open_at
        while j < len(masked):
            if masked[j] == "(":
                depth += 1
            elif masked[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        arg = code[open_at + 1 : j]
        found = CHILD.findall(arg)
        if found:
            names.append(found[-1])
        else:
            unresolved.append(" ".join(arg.split()))
    for match in REQUIRE_NO_PARENS.finditer(masked):
        unresolved.append(" ".join(code[match.start() : match.end() + 30].split()))
    return names, unresolved


def check(files):
    """files: {rel path: source}. Returns a list of violation messages (empty = all rules hold)."""
    problems = []
    names = {}
    for rel in files:
        if layer_of(rel) == "client_entry":
            continue  # an entry script, never required
        name = module_name(rel)
        if name in names:
            problems.append("duplicate module name %s: %s and %s (names must be unique)" % (name, names[name], rel))
        names[name] = rel
    graph = {}
    for rel, source in sorted(files.items()):
        layer = layer_of(rel)
        if layer is None:
            problems.append("%s: no layer for this path (add the folder to layer_of)" % rel)
            continue
        targets, unresolved = require_targets(source)
        for raw in unresolved:
            problems.append("%s: require(%s) has no WaitForChild(\"Name\") target" % (rel, raw))
        for target in targets:
            if target not in names:
                problems.append("%s: requires unknown module %s" % (rel, target))
                continue
            target_layer = layer_of(names[target])
            if target_layer not in ALLOWED[layer]:
                problems.append("%s (%s) must not require %s (%s)" % (rel, layer, names[target], target_layer))
            graph.setdefault(rel, set()).add(names[target])
    problems.extend(find_cycles(graph))
    return problems


def find_cycles(graph):
    problems, state, stack = [], {}, []

    def visit(node):
        state[node] = "open"
        stack.append(node)
        for nxt in sorted(graph.get(node, ())):
            if state.get(nxt) == "open":
                problems.append("cycle: " + " -> ".join(stack[stack.index(nxt):] + [nxt]))
            elif nxt not in state:
                visit(nxt)
        stack.pop()
        state[node] = "done"

    for node in sorted(graph):
        if node not in state:
            visit(node)
    return problems


def load_src():
    files = {}
    for root, _, names in os.walk(SRC):
        for n in names:
            if n.endswith(".luau") or n.endswith(".lua"):
                path = os.path.join(root, n)
                files[os.path.relpath(path, SRC).replace(os.sep, "/")] = io.open(path, encoding="utf-8").read()
    return files


def selftest():
    """Each planted case must give the expected problem; a clean miniature and harmless forms must give none."""
    ok = {
        "shared/Config.luau": "return {}",
        "shared/Types.luau": 'local C = require(script.Parent:WaitForChild("Config"))',
        "server/Net.luau": 'local C = require(RS:WaitForChild("BannedWords"):WaitForChild("Config"))',
        "server/Match.luau": 'local N = require(script.Parent:WaitForChild("Net"))',
        "server/services/A.luau": 'local M = require(script.Parent.Parent:WaitForChild("Match"))',
        "server/services/B.luau": "return {}",
        "server/RoundService.luau": 'local A = require(services:WaitForChild("A"))\nlocal B = require(services:WaitForChild("B"))',
        "client/UI/Style.luau": "return {}",
        "client/UI/Panel.luau": 'local S = require(script.Parent:WaitForChild("Style"))',
        "client/State.luau": "return {}",
        "client/init.client.luau": 'local P = require(UI:WaitForChild("Panel"))\nlocal S = require(script:WaitForChild("State"))',
    }
    bad_require = 'local A = require(script.Parent:WaitForChild("A"))'
    cases = [  # (label, file, source, expected text in a problem; None = must stay clean)
        ("service requires service", "server/services/B.luau", bad_require, "must not require"),
        ("UI panel requires UI panel", "client/UI/Other.luau", 'local P = require(x:WaitForChild("Panel"))', "must not require"),
        ("client requires server", "client/State.luau", 'local M = require(x:WaitForChild("Match"))', "must not require"),
        ("content requires Match", "server/content/Data.luau", 'local M = require(x:WaitForChild("Match"))', "must not require"),
        ("unnamed require", "server/services/B.luau", "local A = require(someVariable)", "no WaitForChild"),
        ("duplicate name", "client/UI/Net.luau", "return {}", "duplicate module name"),
        ("unknown folder", "client/Effects/Spark.luau", "return {}", "no layer"),
        ("require with a space", "server/services/B.luau", 'local A = require (script.Parent:WaitForChild("A"))', "must not require"),
        ("---[[ toggle keeps code live", "server/services/B.luau", "---[[\n" + bad_require + "\n--]]", "must not require"),
        ("after a string holding --", "server/services/B.luau", 'local s = "--" ' + bad_require, "must not require"),
        ("after a \\z line continuation", "server/services/B.luau", 'local s = "a\\z\n   b" ' + bad_require, "must not require"),
        ("inside a backtick {expression}", "server/services/B.luau", 'local s = `x{' + bad_require[10:] + '.y}`', "must not require"),
        ("require without parentheses", "server/services/B.luau", 'local A = require"A"', "no WaitForChild"),
        ("inside a block comment", "server/services/B.luau", "--[[\n" + bad_require + "\n]]\nreturn {}", None),
        ("inside a line comment", "server/services/B.luau", "-- " + bad_require + "\nreturn {}", None),
        ("inside a string", "server/services/B.luau", 'local s = [[' + bad_require + ']] local t = "--[["', None),
    ]
    failures = []
    if check(ok):
        failures.append("clean miniature reported: %s" % check(ok))
    for label, rel, source, expected in cases:
        planted = dict(ok)
        planted[rel] = source
        problems = check(planted)
        if expected is None and problems:
            failures.append("%s: wrongly reported %s" % (label, problems))
        elif expected is not None and not any(expected in p for p in problems):
            failures.append("%s: expected '%s', got %s" % (label, expected, problems))
    if not any("cycle" in p for p in find_cycles({"a": {"b"}, "b": {"a"}})):
        failures.append("cycle: missed")
    return failures, len(cases) + 1


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    failures, count = selftest()
    if failures:
        print("FAIL checker self-test: " + "; ".join(failures))
        sys.exit(1)
    files = load_src()
    problems = check(files)
    requires = sum(len(require_targets(s)[0]) for s in files.values())
    if problems:
        for p in problems:
            print("FAIL " + p)
        print("%d dependency problem(s)" % len(problems))
        sys.exit(1)
    print("PASS self-test (%d planted cases, each caught for the right reason or correctly ignored)" % count)
    print("PASS %d modules, %d requires: layer rules hold, no cycles" % (len(files), requires))
    print("ALL PASS")


if __name__ == "__main__":
    main()
