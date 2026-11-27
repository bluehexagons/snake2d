# Basaltwater integration

[Basaltwater](https://github.com/bluehexagons/basaltwater) is the open-source
tooling used for AI-assisted development and playtesting on this project.
Basaltwater supplies optional environment tooling. The project owns its Godot
4.7.2 pin, export presets and native checks. Debian is the reference build
profile; CachyOS KDE supports native development/testing and Windows has native
PowerShell entry points. Windows CI copies setup-godot's extensionless engine
hard link to a temporary `.exe` and sets `GODOT_BIN`, so the native runner can
launch it through Windows process APIs. Follow [CONTRIBUTING.md](../CONTRIBUTING.md) for manual
setup without Basaltwater. No service, portal or account setup is required by
`build.sh`, `test.sh`, `build.ps1` or `test.ps1`.

## Refresh an existing Web preview

The managed development build is a copied Godot export. After changing the
game, list the configured sites and confirm `snake2d-playtest` belongs to the
active checkout before replacing it. Reuse its `godot` profile and release
`Web` preset.

```bash
basaltw agent doctor --capability development --json
basaltwater-web site list --json
basaltwater-web publish site snake2d-playtest --project . --profile godot --preset Web --verify --json
basaltwater-web site url snake2d-playtest
```

Check that the development doctor reports matching Web templates. Publication
rebuilds the export and verifies the files served over HTTPS. Open the exact
URL returned by the gateway for interaction checks. The GitHub Pages release
has its own [build and release workflow](build-and-release.md#releasing).

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

## Native Windows checks

Use the installed Windows workspace skill for host operation. The native
Basaltwater doctor checks tool discovery, not matching templates or game
behavior. Project-owned checks work without Basaltwater:

```powershell
basaltw doctor --json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-ScriptTests.ps1
pwsh.exe -NoProfile -File .\tests\Run-ScriptTests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test.ps1 all
```

For a bounded rendered composition check in the enabled interactive session:

```powershell
basaltw desktop develop run --project (Get-Location).Path --timeout 45 -- --scene res://tests/smoke_test.tscn --quit-after 300
basaltw desktop develop wait TASK_ID --timeout 45
basaltw desktop develop logs TASK_ID
```

Literal engine arguments follow `--`. Retain the returned task ID through
completion; inspect the exit status and `Smoke test passed.` marker. The scene
injects disposable saves before composition. For rendered layout/input coverage,
use `--script res://tests/ui_layout_test.gd` with a longer task deadline.
Use the native desktop observation/input workflow for export interaction checks,
with a disposable child `APPDATA` profile. Headless startup and synthetic density
tests do not establish audible quality, physical devices or Windows DPI behavior.
See the [recorded qualification and open checks](manual-testing.md).

## Repeatable Classic playtest

The project-owned scenario starts Classic, makes a move, pauses, resumes,
reaches a wall collision and retries. It injects game-side input and isolates
saves. In a rendered run it retains PNGs of the menu, ready board, pause,
results and retried board, plus `milestones.jsonl` with the observed stage
order and elapsed times. `scenario-result.json` records the assertion outcome
and last retained stage when the scenario exits. An interrupted process can
leave only the journal prefix, so check the supervisor's terminal receipt as
well. The source suite also runs the assertions headlessly.

On Windows, use the session guardian from the project directory:

```powershell
basaltw desktop develop run --project (Get-Location).Path --test-session --timeout 45 -- --script res://tests/native_playtest_test.gd
basaltw desktop develop ready TASK_ID --timeout 30
basaltw desktop develop wait TASK_ID --timeout 45
```

On CachyOS, use the declared Linux playtest profile with a recorder for this
project:

```bash
basaltw desktop --native evidence start --project "$PWD"
basaltw desktop --native develop playtest classic-lifecycle --project "$PWD"
basaltw desktop --native develop wait TASK_ID --timeout 45
basaltw desktop --native evidence finish --task TASK_ID
```

On Debian XRDP, use the same commands without `--native`. The task's
`artifacts` directory contains the project evidence on both platforms. This
scenario covers game behavior and rendering. Use guarded desktop input for
end-to-end input delivery and the manual matrix for physical devices and audio.

## Generated output and retention

`.basaltwater/cleanup.json` declares `out/` exports and `dist/` release staging
as generated output. Retain any build or archive still needed for release or
review. Stop running exports, tests and packaging jobs before cleanup. With an
updated Basaltwater installation, preview with:

```bash
basaltw agent storage project "$PWD" --json
basaltw agent storage clean-generated "$PWD" --rule generated-exports
```

Apply requires explicit cleanup authorization, `--apply` and project-root writes
for isolation. Without Basaltwater, review those exact paths and Git tracking,
then remove only authorized output with native filesystem tools. Preserve source,
export presets and player settings/scores (`user://`), which are not build output.
Use the shared [artifact curation guidance](https://github.com/bluehexagons/basaltwater/blob/main/docs/agents/project-cleanup.md)
for future screenshots or videos: keep selected originals and provenance in an
ignored `artifacts/archive/`, with uncurated captures in `artifacts/review/`.
Keep `artifacts/.gdignore` so Godot does not import local evidence.
Keep raw operational records outside Git.
Archiving on this disk does not free space. No cleanup script is duplicated here.
