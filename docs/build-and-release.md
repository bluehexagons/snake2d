# Building and releasing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for setup, source checks, and project conventions.

## Build exports

The game can be built for different platforms using the provided build script.
Basaltwater on Debian is the reference development environment; its
[shared standards and skills](https://github.com/bluehexagons/basaltwater/blob/main/docs/agents/project-standards.md)
provide environment support. Native Godot workflows remain available with manual
setup, including on CachyOS and Windows 11. POSIX scripts use Bash; native
Windows has PowerShell entry points and the editor's export presets. A Windows export
from Linux still needs native Windows runtime testing.

### Requirements

- Godot Engine (version 4.7.2) and matching export templates installed
- The Godot executable available in your PATH
- Bash and GNU coreutils (`timeout`) for the Bash scripts
- The build script auto-detects `godot`, `godot4`, and the `GODOT`/`GODOT4` paths exported by `setup-godot`

### Usage
```bash
# Build all platforms (Web, Windows, Linux)
./build.sh

# Build a specific platform
./build.sh web
./build.sh windows
./build.sh linux
```

The exported files will be placed in the `out/` directory after the launcher
and its required companion files pass validation. Bash commands enforce
a 120-second deadline per engine process; set `GODOT_TIMEOUT_SECONDS` (1–3600)
for a deliberate override. A timed-out process group receives TERM, then KILL
if it has not exited within five seconds. Engine discovery honors `GODOT_BIN`
first, then `GODOT`, `GODOT4`, `BASALTWATER_GODOT_EXE`, `godot`, and `godot4`.
A missing explicit `GODOT_BIN` fails instead of selecting another engine.

See [Basaltwater integration](basaltwater.md) for optional CachyOS checks.
The Linux export smoke runs from an empty temporary directory, isolates Godot's
data through `XDG_DATA_HOME`, and requires no installed editor.

### Serving the Web build

Serve the Web export files together over HTTPS, or use localhost for testing.
Set the WASM response type to `application/wasm` and enable HTTP
compression for it. The engine file measured 39.5 MB uncompressed and 10.1 MB
with gzip. A compressed release ZIP only reduces the download of the archive.

For example, NGINX can serve a precompressed companion generated with
`gzip -6 -kf out/html/index.wasm`. Enable `gzip_static on` and `gzip_vary on`
for the game location, and regenerate the companion whenever the WASM changes.
On a managed static host, use its HTTP compression instead. Check the deployed
URL with `curl --compressed -sI https://example.com/snake/index.wasm` and confirm
`Content-Type: application/wasm` and a `Content-Encoding` such as `gzip` or `br`.
[NGINX precompressed file documentation](https://nginx.org/en/docs/http/ngx_http_gzip_static_module.html)

### Native Windows

Run from PowerShell with the matching standard Godot engine. Basaltwater's
optional `-Godot` selection supplies the engine; matching export templates
remain a project prerequisite. These commands also work without Basaltwater:

```powershell
godot --headless --version
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test.ps1 source
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 windows
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test.ps1 windows-export
```

`test.ps1 all` runs those source/build/export checks together. The source suite
needs no export templates. `build.ps1` accepts `web`, `windows`, `linux`, or
`all`, defaulting to Windows; it uses the same presets/output paths as Bash.
The export smoke needs no installed editor and starts the packaged executable
in a fresh temporary directory, with a child-only `APPDATA` override for Godot's
saves and logs. Source files cannot mask missing package data, and startup
cannot migrate player settings. The runner waits for GUI
executables explicitly and enforces a 120-second deadline per engine process,
including process-tree cleanup on timeout. Use `-TimeoutSeconds N` for a
deliberate per-command budget. It establishes headless
startup, not controller, graphics or audio quality; use the
[manual interaction checklist](manual-testing.md).

For an extracted Windows ZIP, pass its executable explicitly:
`test.ps1 windows-export -WindowsExportPath 'C:\release candidate\snake.exe'`.
CI tests the Linux-built archive on Windows as well as building natively.

Set `$env:GODOT_BIN = 'C:\path to Godot\Godot_v4.7.2-stable_win64_console.exe'`
to choose a specific engine. Resolution honors that explicit selection first,
then `GODOT`, `GODOT4`, Basaltwater's `BASALTWATER_GODOT_EXE`, and commands on
PATH. A missing explicit `GODOT_BIN` fails instead of using another version.
Use an actual `.exe`, not a batch shim, for native process supervision.
The native scripts prefer the real executable over a `.cmd` launcher so
literal percent signs in project paths survive argument forwarding. For Git
Bash with a Basaltwater launcher, set `GODOT_BIN` to the real executable too;
Bash does not discover `godot.cmd` as `godot`.

## Testing from the CLI

Run the source suite in headless mode:

```bash
./test.sh source
```

For the built Linux export, run:

```bash
./build.sh linux
./test.sh linux-export
```

`test.sh all` runs both paths end-to-end. The source suite imports and parses the project, tests audio synthesis, session lifecycle, deterministic rules, input translation, persistence, and input actions, then instantiates the main scene and verifies that a playable round starts without opening a game window. Persistence and composed-scene tests inject disposable save paths so they do not read or overwrite player settings or scores. Bash and PowerShell share the source suite list in `tests/source-suites.txt` and require each success marker, not just exit code zero.

## Releasing

Releases are created from a clean, up-to-date `main` branch:

```bash
./bump_patch.sh
```

The helper runs the source test suite, increments `application/config/version`, creates the version commit and matching `v*` tag, then atomically pushes both. Pushing the tag triggers the GitHub release workflow, which tests and exports the Web, Windows, and Linux builds before publishing their archives.
If the push fails, the helper prints the command to retry the same commit and tag.

Publication waits for a separate Windows runner to extract and start the actual
Windows archive without an installed editor. The tested archives are retained
as one immutable build artifact and downloaded again for publication; the publish
job does not rebuild them. CI uses the same flat archive layout and package check.

After the release is published, the workflow deploys the same Web archive to
[GitHub Pages](https://bluehexagons.github.io/snake2d/).
