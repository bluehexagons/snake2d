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
