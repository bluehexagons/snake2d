# Contributing

## Requirements

- Godot 4.7.2 available as `godot`, `godot4`, `GODOT`, or `GODOT4`
- Bash for POSIX scripts, or Windows PowerShell 5.1+ for native Windows scripts
- Export templates when building release artifacts

## Feedback loop

Run the complete source suite before submitting a change:

```bash
./test.sh source
```

The command imports the project, rejects parse/compile errors, runs deterministic model and service tests, and finishes with the composed-scene smoke test.

On Windows use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test.ps1 source`.
Run `tests\Run-ScriptTests.ps1` with the same PowerShell options after tooling
changes; its temporary command fixtures check failure exit codes, Godot script
errors reported with exit zero, early exits without suite markers, and stderr
diagnostics, with a deadline for hung processes. Fixture paths include spaces
and literal percent expressions. It installs nothing. Add new script suites to
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
