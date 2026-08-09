This is a learning-oriented Snake clone targeting Godot 4.7.1 and typed GDScript.

- `Main` is the explicit composition root; the project intentionally has no Autoloads.
- `GameSession` alone owns application state and `SceneTree.paused`.
- Pure grid rules live under `models/`; scene scripts adapt them to nodes, pixels, audio, and input.
- Use `GameRules` for Inspector-editable gameplay and camera tuning.
- Preserve deterministic model behavior and add executable rule tests under `tests/`.
- Run `./test.sh source` after changes.
