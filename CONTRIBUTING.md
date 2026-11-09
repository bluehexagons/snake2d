# Contributing

## Requirements

- Godot 4.7.2 available as `godot`, `godot4`, `GODOT`, or `GODOT4`
- Bash and GNU coreutils (`timeout`) for POSIX scripts, or Windows PowerShell 5.1+ for native Windows scripts
- Export templates when building release artifacts

## Feedback loop

Run the complete source suite before submitting a change:

```bash
./test.sh source
```

The command imports the project, rejects parse/compile errors, runs deterministic model and service tests, and finishes with the composed-scene smoke test.

After Bash tooling changes, run `python3 tests/script_runner_test.py` (Python 3,
standard library only). It checks missing engines, failure exit codes, stderr
errors, missing success markers, deadlines, output validation, and packaged
startup outside the checkout using paths with spaces and non-ASCII characters.

See [Basaltwater integration](docs/basaltwater.md) for CachyOS prerequisite,
export-template and native runtime checks.

On Windows use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test.ps1 source`.
Run `tests\Run-ScriptTests.ps1` with the same PowerShell options after tooling
changes; repeat with `pwsh.exe` when available. Its temporary command and compiled
GUI executable fixtures check failure exit codes, Godot script errors reported
with exit zero, early exits without suite markers, stderr diagnostics, and
deadlines. Export fixtures also verify an empty working directory, isolated
player data, and startup without an installed editor. Fixture paths include
spaces, non-ASCII characters and literal percent expressions. It installs nothing.
For Bash fixtures with native Windows Python, set
`$env:BASH_BIN = 'C:\Program Files\Git\bin\bash.exe'` before running
`python3 tests/script_runner_test.py`, to select Git Bash instead of WSL.
Add new script suites to
`tests/source-suites.txt` so both native and Bash runners execute them.

## Project conventions

- Keep `Main` as the composition root; do not add Autoloads for ordinary dependencies.
- Keep grid rules in `models/` and pixel/node behavior in scene adapters.
- Use `Vector2i` cells in the model and convert to pixels at the presentation boundary.
- Route application transitions through `GameSession` and UI visibility through `UIStateManager`.
- Prefer typed signals, typed node references, unique node names, and public scene-controller APIs.
- Add executable rule tests for behavior changes.
- Explain non-obvious invariants and ownership decisions; avoid comments that merely restate syntax.
- Update the architecture and learning-path documents when boundaries change.

## Exports

`./build.sh` builds Web, Windows, and Linux exports into `out/`. Export templates are not required for source tests.
On Windows, `build.ps1 windows` builds the native preset and `test.ps1 all`
runs source tests, builds it and checks packaged startup. Use the explicit
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File` form above when
account script policy blocks direct execution; no saved policy change is needed.
`test.ps1 windows-export` requires only the built package, without resolving an
editor. Both export smoke runners use fresh temporary working/data directories
to keep source files and player saves out of qualification runs.
To qualify an extracted Windows archive, use `test.ps1 windows-export
-WindowsExportPath 'C:\release candidate\snake.exe'`. Relative paths resolve
against the caller's location before the child moves into its empty directory.
CI and release workflows run this check against the Linux-built Windows ZIP on
a separate Windows runner without installing Godot. Release publication depends
on that archive check and publishes the same retained build artifacts.

## Matching export templates on Basaltwater systems

Check the actual engine with `godot --version`. On managed Linux, run
`basaltw agent doctor --capability development --json`.
The [Basaltwater Godot guidance](https://github.com/bluehexagons/basaltwater/blob/main/docs/workstations/godot.md)
explains that the managed `web` bundle installs only the matching Web templates.
A healthy Web capability does not establish Linux or Windows export readiness.

Desktop exports also need the matching official desktop templates in
`~/.local/share/godot/export_templates/<version>.stable/` on Linux, or
`%APPDATA%\Godot\export_templates\<version>.stable\` on native Windows.
Self-contained editors use their own `editor_data/export_templates` directory.
Install them through
Godot's Export Template Manager using the matching official release. Basaltwater
setup is optional; do not copy its internal download code into this project.
Verify `templates/version.txt` against the running engine before installing.
Do not rename
an older template directory to make it appear compatible with a newer engine.

After an engine update, repeat the check: Web bundle maintenance does not install
desktop templates. Validate with `./build.sh all` and `./test.sh linux-export`.
For native Windows, validate with `test.ps1 all`. `basaltw info --json` reports
saved native setup selections; the Linux `agent doctor` command is unavailable
there and host engine discovery does not prove template readiness.
