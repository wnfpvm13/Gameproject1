"""Run pure Foundation modules with the official Luau CLI, without Roblox Studio.

Only the temporary test copy rewrites Roblox script-relative require paths to
CLI-relative paths. Source files remain unchanged. Studio behavior is not tested.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default="luau")
    parser.add_argument("--compile", dest="compiler", default="luau-compile")
    parser.add_argument("--analyze", dest="analyzer", default="luau-analyze")
    args = parser.parse_args()
    project = Path(__file__).resolve().parent.parent
    files = sorted(project.joinpath("src").rglob("*.luau"))
    files += sorted(project.joinpath("tests").rglob("*.luau"))
    for source in files:
        subprocess.run([args.compiler, "--binary", str(source)], check=True,
                       stdout=subprocess.DEVNULL)
    print(f"Luau syntax compilation: {len(files)} files PASS", flush=True)

    pure = sorted(project.joinpath("src/shared").rglob("*.luau"))
    pure += sorted(project.joinpath("src/server/Services").rglob("*.luau"))
    pure += [project / "src/server/Adapters/StudioStores.luau", project / "src/server/ServerConfig.luau"]
    pure += sorted(project.joinpath("tests").rglob("*.luau"))
    require_pattern = re.compile(r"\brequire\(script((?:\.[A-Za-z_]\w*)+)\)")
    with tempfile.TemporaryDirectory(prefix="moncook-luau-tests-") as temporary:
        temp = Path(temporary)
        for source in pure:
            relative = source.relative_to(project)

            def cli_require(match: re.Match[str]) -> str:
                path = list(relative.with_suffix("").parts)
                for name in match.group(1).split(".")[1:]:
                    if name == "Parent":
                        if not path:
                            raise ValueError(f"require escapes project: {source}")
                        path.pop()
                    else:
                        path.append(name)
                target = project.joinpath(*path)
                if not Path(str(target) + ".luau").is_file():
                    raise ValueError(f"missing module: {target}")
                module = os.path.relpath(target, source.parent).replace(os.sep, "/")
                if not module.startswith("."):
                    module = "./" + module
                return "require(" + json.dumps(module) + ")"

            content = require_pattern.sub(cli_require, source.read_text(encoding="utf-8"))
            target = temp / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
        runner = temp / "run.luau"
        suites = sorted(project.joinpath("tests").glob("*.spec.luau"))
        statements = ["--!strict", "local total = 0"]
        for index, suite in enumerate(suites):
            name = suite.stem
            statements.append(f'local count{index} = require("./tests/{name}")()')
            statements.append(f'print(string.format("{name}: %d groups PASS", count{index}))')
            statements.append(f"total += count{index}")
        statements.append('print(string.format("Foundation total: %d groups PASS", total))')
        runner.write_text("\n".join(statements) + "\n", encoding="utf-8")
        subprocess.run([args.analyzer, *(str(temp / p.relative_to(project)) for p in pure),
                        str(runner)], check=True)
        print("Pure Foundation modules type analysis PASS", flush=True)
        subprocess.run([args.luau, str(runner)], check=True)


if __name__ == "__main__":
    main()
