# Basaltwater integration

Basaltwater supplies optional environment tooling; the project owns its Godot
4.7.2 pin, export presets and native checks. Debian is the reference build
profile; CachyOS KDE supports native development/testing and Windows has native
PowerShell entry points. Windows CI copies setup-godot's extensionless engine
hard link to a temporary `.exe` and sets `GODOT_BIN`, so the native runner can
launch it through Windows process APIs. Follow [CONTRIBUTING.md](../CONTRIBUTING.md) for manual
setup without Basaltwater. No service, portal or account setup is required by
`build.sh`, `test.sh`, `build.ps1` or `test.ps1`.

## CachyOS prerequisites and checks

From the checkout, inspect the installed environment and matching templates:

```bash
basaltw agent manifest . --capability development --json
basaltw local cachyos-doctor --attention --json
basaltw desktop --native develop doctor --project "$PWD" --export-check --json
python3 tests/script_runner_test.py
./test.sh all
```

The doctor reports prerequisites, not application behavior. A missing template
inventory needs the matching official standard export templates; use the
installation procedure in CONTRIBUTING.md. Never rename old templates or change
the project pin to match a rolling workstation package. Template names alone do
not prove preset completeness: run the actual exports. `./build.sh all` also
checks Web and Windows packaging; Windows runtime qualification remains separate.

For a bounded rendered composition check in the owned KDE session:

```bash
basaltw desktop --native develop run --project "$PWD" \
  --scene res://tests/smoke_test.tscn --quit-after 300 --json
basaltw desktop --native develop wait TASK_ID --timeout 45 --json
```

Use the returned task ID, inspect its log for `Smoke test passed.` and errors,
and retain the handle through completion. The smoke injects disposable settings
and score paths before composing the game. Engine iterations are not a wall-clock
deadline; a wait timeout does not stop the task. Inspect the same task and use
`develop stop TASK_ID` when needed. Native launches require existing enabled
agent control; capture/input additionally require owner-approved portal access.
Use the installed `basaltwater-cachyos-desktop` skill for that session workflow.
A rendered smoke does not establish physical input or audible quality: use the
[manual testing matrix](manual-testing.md) for interaction qualification.

## Artifacts

Inspect `.basaltwater/cleanup.json` through `basaltw agent storage project
"$PWD" --json`. Exports in `out/` and release staging in `dist/` are generated;
review captures and curated archives follow the README retention guidance.
Preserve player settings/scores and active jobs. Cleanup preview grants no
standing deletion authority. Keep raw operational records outside Git.
