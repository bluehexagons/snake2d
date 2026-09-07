# Contributing

## Requirements

- Godot 4.7.1 available as `godot`, `godot4`, `GODOT`, or `GODOT4`
- Bash for the repository scripts
- Export templates when building release artifacts

## Feedback loop

Run the complete source suite before submitting a change:

```bash
./test.sh source
```

The command imports the project, rejects parse/compile errors, runs deterministic model and service tests, and finishes with the composed-scene smoke test.

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

## Matching export templates on infra-tools VMs

Check the actual engine with `godot --version` and run
`infra-tools agent doctor --capability development --json`.
The [infra-tools Godot guidance](https://github.com/bluehexagons/infra_tools/blob/main/docs/GODOT.md#workflow-bundles)
explains that the managed `web` bundle installs only the matching Web templates.
A healthy Web capability does not establish Linux or Windows export readiness.

Desktop exports also need the matching official desktop templates in
`~/.local/share/godot/export_templates/<version>.stable/`. Install them through
Godot's Export Template Manager, or use the infra-tools range-download implementation
in `common/godot_steps.py` to select the desktop members of the official matching
TPZ, as done during this audit. That implementation checks member ZIP CRCs;
verify `templates/version.txt` against the running engine before installing.
Stage on the destination filesystem when using an atomic rename. Do not rename
an older template directory to make it appear compatible with a newer engine.

After an engine update, repeat the check: Web bundle maintenance does not install
desktop templates. Validate with `./build.sh all` and `./test.sh linux-export`.
