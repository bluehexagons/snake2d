# Project guidance

Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, checks and code conventions,
and [docs/architecture.md](docs/architecture.md) before changing ownership.

- Keep `Main` as the composition root, with no Autoloads. `GameSession` owns
  application state and tree pause; deterministic grid rules belong in `models/`.
- Run `./test.sh source` after code changes. For Bash tooling, also run
  `python3 tests/script_runner_test.py`; build/smoke changed export paths.
  Native Windows equivalents and tooling fixtures are in CONTRIBUTING.md.
- Register source suites in `tests/source-suites.txt`, shared by both runners.
  Tests must use disposable save paths and explicit success markers.
- Basaltwater remains optional. See [docs/basaltwater.md](docs/basaltwater.md)
  and use the installed project/workstation skills for environment operations.
- `.basaltwater/cleanup.json` describes artifact retention; it grants no
  deletion permission. Keep raw logs, captures and personal machine details
  outside Git. Preserve player data and unrelated work.
