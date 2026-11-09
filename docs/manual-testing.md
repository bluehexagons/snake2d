# Manual interaction checks

Headless tests verify rules and scene behavior, but cannot establish real-device input, rendered layout, or audible quality. The matrix describes the full coverage target; the limited recorded run below does not establish native-device coverage. For each run, record commit, Godot version, OS/browser, device, and pass/fail with reproduction steps.

| Area | Steps | Expected result |
| --- | --- | --- |
| Desktop keyboard | Start, turn, pause, resume, lose, restart, return to menu | Exactly one legal turn per tick; paused rounds retain their board and score |
| Focus loss | Start moving, Alt-Tab or minimize, return to the window, then resume | Focus loss pauses immediately; returning keeps the pause menu up; an old touch cannot turn after resume |
| Controller | Navigate all menus, select each mode, edit a seed, adjust volume, cancel and accept reset dialogs | Focus stays in the active panel; sliders and seed input remain usable |
| Controller at rest | Move the mouse during a round with a controller connected and untouched | Neutral/deadzone/unmapped axes do not hide the mouse cursor; mapped stick movement still switches to controller input |
| World seed bounds | Type or paste an oversized integer in Obstacles, then start with keyboard/controller | Input stays within nine characters and launches a seed in 1–999999999 without engine errors |
| Fast menu changes | Open Options and immediately go back; press Start then immediately move or pause | Fading panels cannot take focus, activate buttons, or swallow gameplay input |
| Native touch | Tap, swipe, cancel a touch, add a second finger, pause/resume mid-gesture | One direction per gesture; no duplicate emulated mouse turn; old gestures are cleared |
| Web pointer | Switch between touch and mouse, drag outside the canvas and release, return to the game | No stuck drag or duplicate turn; direction matches the visible snake |
| Layout | Resize while playing and in every menu; try narrow/tall and wide/short windows | Controls remain reachable and grid, food, snake, and camera stay aligned |
| Reduced motion | Enable during a panel transition; visit every menu and disable it again | Panel transitions settle immediately; verify button animation behavior separately |
| Audio | Play at starting and maximum speed, eat, lose, pause; test mute and volume | No clicks or clipping; death cue is audible; settings take effect immediately |
| Save/reload | Change settings and earn scores in all modes; restart the application | Settings persist and scores remain separated by mode |

Use a temporary OS account or back up saves before manually testing reset actions. Automated persistence and smoke tests already use disposable paths.

## Recorded Windows compatibility review — 2026-11-09

Revision `2562297`, standard Godot 4.7.2 stable on native Windows 11:

- `test.ps1 all` passed all nine source suites, composed-scene smoke, Windows
  release export and packaged headless startup. Git Bash source checks also
  passed. Matching official Windows templates came from an existing isolated
  self-contained editor; the archive matched its previously verified SHA-256
  digest and the template version matched the engine. Account templates were
  not replaced.
- PowerShell 5.1 and 7 script contracts passed, including a compiled GUI
  executable fixture, nonzero exits, errors on stderr with exit zero,
  deadlines, Unicode/space/literal-percent paths, and missing-editor startup.
  All eight Bash tooling contracts passed with native Windows Python and Git
  Bash. Fixtures now write LF explicitly instead of Windows-translated newlines.
- Review found that PowerShell's location did not reliably set the child CWD,
  so the earlier export check could inherit the source directory. The runner
  now sets `ProcessStartInfo.WorkingDirectory` explicitly. It also resolves
  Godot only for source/build checks, allowing export-only qualification
  without an installed editor.
- Packaged smoke now isolates Godot saves/logs with a child-only `APPDATA`
  override; the Linux runner uses `XDG_DATA_HOME`. Real Windows startup and
  legacy migration were verified inside a disposable profile. A relocated
  real Windows package passed from a path with spaces, non-ASCII text and
  literal `%TEMP%`. Removing its `.pck` produced the missing-data error and
  was rejected at a deliberately shortened three-second deadline.
- Basaltwater's supervised native rendered composition and UI layout suites
  passed without engine errors. Layout coverage includes narrow, short and
  wide windows, synthetic 1×/1.35×/2× densities, pointer hit testing, focus,
  confirmation resizing and keyboard pause/resume with frozen ticks.
- The release executable was also inspected on a 100% scale desktop using a
  disposable profile. Captures confirmed rendered main/options/gameplay,
  pause and game-over screens. Injected native pointer/keyboard input opened
  Options, toggled fullscreen on/off with the correct saved state, returned
  to the menu, started Classic, paused, and resumed into a normal game-over
  transition. The owned window closed cleanly.
- GitHub CI passed for this revision, including Linux source/build/package
  checks and Windows source/export/startup plus PowerShell 5.1/7 fixtures.

Still open: actual Windows display scales above 100% and mixed-DPI monitor
moves, physical controller/touch devices, audible quality/latency, and manual
save/reload across modes. Synthetic density cases do not establish Windows DPI
detection. Native Linux execution was not repeated on this Windows host; CI
covered the Linux export runner. The optional local cross-platform build also
reported absent Web templates; this did not block Windows qualification.
Raw logs, receipts, profiles and captures remain outside Git.

### Focus, damaged saves and release archives follow-up

Runtime revision `4049270` and package workflow revision `0d2bc49`:

- Reproduced focus loss advancing the round and retaining an unfinished touch.
  The new window lifecycle suite failed before the fix, then passed with the
  window wired to the session's pause API. It covers menu/game-over stability,
  frozen ticks and interpolation, explicit resume, and clearing old gestures.
- Reproduced engine errors from empty, header-truncated and payload-truncated
  score records. Length validation now rejects those records before decoding.
  Persistence tests include invalid payload lengths, preservation of damaged
  files during reads, and recovery by saving a complete new record.
  The Windows release executable also started without errors with a one-byte
  score file in a disposable profile; its hash remained unchanged.
- All ten source suites, composed smoke, native Windows release export and
  packaged startup passed. PowerShell 5.1/7 contracts and all eight Python/Git
  Bash tooling contracts passed. The lifecycle suite also passed as a rendered
  Basaltwater native task.
- Minimized and restored the real release executable through the native desktop
  adapter. Captures confirmed gameplay before minimizing and the pause menu
  after restoring. The restored window remained paused, then closed with exit
  zero and no engine errors. Its saves/logs used a disposable profile.
- A locally archived/extracted Windows package passed the explicit
  `-WindowsExportPath` runner from a Unicode/space/literal-percent path with a
  deliberately missing editor. Actionlint passed for the changed workflows.
  CI and release now share a Windows archive check; release publication depends
  on that check and downloads the same retained archives for publishing.
  [CI passed for `0d2bc49`](https://github.com/bluehexagons/snake2d/actions/runs/42702409798),
  including the Linux-built archive's startup on a separate Windows runner.
- A disposable two-process source probe wrote settings and distinct scores for
  all three modes, then restarted Godot and composed `Main` again. Scores, mute,
  volume, reduced motion and grid visibility reloaded correctly. This adds
  automated application-restart coverage; physical play/save/reload remains a
  separate manual check.

Actual mixed-DPI/above-100% Windows displays and physical devices remain open.
Godot's `screen_get_scale()` is not implemented on Windows, so the earlier Web
density handling cannot simply be extended by removing its platform guard.
See the [DisplayServer reference](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-screen-get-scale).

### Fullscreen, controller noise and seed bounds follow-up

Runtime revision `dd9c4a2`, native Windows Godot 4.7.2:

- A rendered fullscreen/minimize probe reproduced the saved fullscreen
  preference changing to false while minimized. The settings observer now
  preserves the last visible mode during minimization. Headless persistence
  tests cover notification/save behavior; the rendered window lifecycle suite
  enters fullscreen, minimizes, checks memory and disk, then restores windowed.
- A touch drag arriving after pause/resume or cancellation recreated a cleared
  gesture and emitted a turn. The adapter now ignores drags without a fresh
  tracked press. Regressions cover stale drag/release and a valid new swipe.
- Neutral, drifting and unmapped joystick motion previously selected controller
  input and could hide the mouse cursor. Routed engine-event tests now verify
  those events retain mouse input while mapped movement still switches modes.
- Typing twenty digits as a world seed reproduced integer-conversion engine
  errors and a negative overflowed seed. Text length/range limits and clamping
  before conversion now protect entry, launch, generation and gamepad adjustment.
  The new menu-input suite covers normal keyboard entry, twenty-digit typing,
  a thousand-character insertion through the text-edit path, zero and an
  externally assigned oversized numeric value.
- All eleven source suites and composed smoke passed through PowerShell and
  Git Bash. `test.ps1 all` also built and started the Windows release package.
  The menu-input and window-lifecycle suites both passed with native rendering,
  including actual fullscreen/minimize behavior, without engine errors.
- [CI passed for `dd9c4a2`](https://github.com/bluehexagons/snake2d/actions/runs/42705756978),
  including Linux source/exports, native Windows source/export checks and
  startup of the Linux-built Windows archive on a separate Windows runner.
- A disposable deterministic playout probe covered 300 runs across all three
  modes, with small boards, varied pit cadence and seeds including 999999999.
  Across 30,795 steps and 3,820 meals, paired models stayed deterministic and
  score, growth, body occupancy and food placement invariants held.
- A rendered native audio-bus recording probe mixed a burst of general cues
  with the reserved death cue. Its post-limiter PCM peak remained below
  clipping; recording after mute produced silent samples. This checks engine
  mixing/output and mute behavior, not speaker quality or perceived latency.

Joystick/touch events here were injected; this does not qualify physical
controllers or touch hardware. Higher/mixed display scales and audible quality
remain outside this machine's completed checks. Evidence stays outside Git.

## Recorded Windows automated qualification — 2026-10-28

Windows 11 Home (10.0.26100), standard Godot 4.7.2 stable, with the Windows
tooling and settings-migration changes committed with this record:

- PowerShell and Git Bash source suites passed, including all eight script
  suites and the composed-scene smoke. Native script failure-contract fixtures
  passed, including a deadline and paths with literal percent expressions.
- The native Windows release export passed headless startup from outside the
  checkout. Its GUI process was explicitly awaited. Removing the `.pck` caused
  a bounded failure; it was not accepted as a successful launch.
- Official 4.7.2 export templates were verified against the release SHA-256
  digest and used through an isolated self-contained editor under ignored
  `artifacts/review/windows-qualification/`, without replacing account templates.
- No rendered desktop, physical controller/touch, audible audio, or manual
  save/reload result is established by this automated run. The interaction
  matrix above remains open for those boundaries.

The local workload was repeated at commit
`d44b43bf0430fdccdc0a8799e538211487dc0193` using `test.ps1 all`:
all eight source suites, composed-scene smoke, Windows release export and
headless exported startup outside the checkout passed again. The matching
template archive still hashes to
`f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`;
the self-contained editor kept those templates separate from account settings.
The host operator reported successful reboots. This rerun adds no manual
interaction or fresh-machine installation evidence; retain those checks above.
Use the shared
[local Windows qualification report](https://github.com/bluehexagons/basaltwater/blob/main/docs/workstations/windows-qualification.md)
to record host and workload results separately.

## Recorded audit run — 2026-09-07

Engine: Godot 4.7.2 stable. VM-local managed Playwright Chromium on Linux,
release Web export over a loopback server. Code: `0681a75` plus the session
lifecycle changes committed with this record.

- Passed: main menu rendering, starting Classic, a short arrow-key movement,
  Escape pause/resume, quitting to the menu, opening Options, and toggling
  reduced motion. Two paused-frame captures 700 ms apart were byte-identical.
- At 1280×720, the inspected menu and options controls fit the viewport.
- **Usability finding at 390×844:** Options fits, but text and button targets
  become too small because the UI follows the game's viewport scaling. This
  needs responsive UI sizing before mobile usability can be considered passed.
- No browser console errors. Four Chromium GPU `ReadPixels` performance warnings
  were reported during capture; no context loss or rendering failure occurred.
- Source suite, all three release exports, and Linux export startup passed.
  Windows was exported but not executed.
- Still unverified: native touch/cancellation, physical controllers, audible
  quality/latency, browser switching between physical mouse and touch, and
  persistence across a full browser restart.

## Recorded CachyOS automated qualification — 2026-11-09

Maintenance revision `92d55df`, standard Godot 4.7.2 stable on CachyOS:

- All eight source suites and the composed-scene headless smoke passed through
  `./test.sh all`, followed by Linux release export and packaged startup.
- `./build.sh all` produced Web, Windows and Linux release exports using the
  matching official standard templates, verified against the upstream SHA-512
  checksum and template version before installation. This resolved the initial
  missing-template failure without changing the project's engine pin.
- Linux packaged startup passed outside the checkout. Temporarily removing
  its `.pck` produced the missing-project-data error and hit the deliberately
  shortened three-second deadline; it was rejected. Restoring the package
  restored successful startup.
- All eight Bash tooling contract tests passed, including process deadlines,
  errors reported with exit zero, required markers, Basaltwater engine
  discovery and paths with spaces/non-ASCII characters. Bash syntax checks and
  Git whitespace checks passed.
- The composed-scene smoke also passed as a rendered Basaltwater native
  development task in the KDE Wayland session. The engine reported OpenGL 4.6,
  Mesa 26.2.6, Compatibility renderer and Intel Arc graphics. This checks scene
  behavior with a graphics context; no screenshot/layout review, physical input
  or audible audio qualification is established.
- Basaltwater's project prerequisite and cleanup-policy inspection succeeded.
  Generated-output cleanup preview reported incomplete open-file inspection
  for non-dumpable account processes; no cleanup was applied.

Windows was exported here but not executed. Browser execution, controller,
physical touch, audio quality and the known narrow-screen sizing issue remain
covered by the open manual interaction matrix, not this automated run.

## Responsive UI and native input follow-up — 2026-11-09

Godot 4.7.2 on CachyOS, with the responsive menu changes committed alongside
this record:

- All nine source suites and the composed-scene smoke passed. The new layout
  suite covers 320×568, 390×844, 844×390 and 1280×720. It checks panel widths,
  authored pixel scale, 44-pixel button/seed targets, focus-following scroll,
  mode popup opening, scaled pointer hits and P/Escape pause/resume. Paused
  frames retain the model tick and interpolation accumulator. All saves use
  disposable injected paths.
- The same layout suite passed with the native Compatibility renderer and
  Intel Arc OpenGL context. Rendered captures were inspected for portrait
  Options, main menu/seed, Credits, mode popup, short-landscape scrolling and
  desktop main-menu layout. Distance-field fonts resolve the blur exposed by
  independent menu scaling. Raw captures remain private and outside Git.
- A separate desktop loop through existing owner-approved KDE portal access
  verified pointer Start, keyboard movement to wall collision, P pause/resume,
  Escape pause and pointer return to menu. A disposable fixture checked that
  tick/interpolation values survive pause/resume; it did not use player saves.
- Web, Windows and Linux exports and Linux packaged startup passed after the
  changes. Exporting establishes packaging, not native Windows/browser input.

The September narrow-screen sizing finding is addressed in the native layout.
Real-phone touch/scrolling, browser rendering, physical controllers and audible
quality remain unverified by this follow-up.

## Chromium Web follow-up — 2026-11-09

Godot 4.7.2 release Web export on the CachyOS workstation, served on loopback
HTTP and exercised through T3 Code 0.1.7 preview in an isolated incognito
profile. The observed engine was Chromium 152/Electron 44, WebGL 2 Compatibility,
single-threaded WebAssembly, with device pixel ratio 1.35. This record accompanies
the Web density, dialog and resize fixes:

- Reviewed 1280×720, 390×844, 320×568 and 844×390 CSS viewports. Menus retain
  their authored CSS text/button sizes on high-DPI screens. Portrait/landscape
  changes retain the full-screen origin and panel centering after wrapped
  text changes its minimum size. Short menus are reachable through keyboard
  focus scrolling and pointer-operated scrollbars.
- Classic: pointer Start, arrow-key movement to wall collision, P pause/resume,
  game over, Play Again, Escape pause and pointer return to menu passed. Two
  paused PNG captures taken more than 30 seconds apart were byte-identical.
- Obstacles: opened the mode popup, incremented the seed through the spin
  control, started the round and verified the selected seed in the HUD;
  Escape pause and pointer return passed at 320×568.
- Options: volume, reduced motion and grid changes survived a full page reload.
  Reset Settings Cancel preserved those values; Confirm restored the defaults.
  The confirmation inherits the shared theme, wraps text, stays centered and
  keeps 44-pixel button heights. Credits and High Scores render, and the
  Credits scrollbar exposes its Back button in the short viewport.
- No application console errors or warnings were observed. Export resources
  loaded successfully. Raw browser diagnostics/captures remain outside Git.
- All nine source suites and composed-scene smoke passed; geometry checks now
  cover all four sizes at 1×, 1.35× and 2× density, including modal scale,
  centering and menu origins. The native rendered layout suite, all three
  exports and Linux packaged startup also passed.

Viewport resizing retains the desktop user agent; it does not establish phone
coverage. Physical touch, wheel/touch scrolling, canvas text entry, physical
controllers, audible audio, browser-restart persistence and Firefox/Safari
remain unverified by this run. The preview typing helper requires a DOM editable
target, so the seed check used the canvas spin buttons instead.

## Display transitions and native mixer follow-up — 2026-11-09

Further CachyOS checks found and fixed two transition defects: an open
confirmation kept its previous scale after resizing, and fullscreen state
stayed enabled after an external exit, causing unrelated settings changes to
re-enter fullscreen.

- Chromium 152: entering fullscreen through Options worked. External browser
  exit now updates the label to Off, and toggling the grid retains windowed
  mode. Reloading with a previously saved fullscreen preference starts without
  a fullscreen permission error. The original failure was reproduced with
  browser Escape; the final external-exit check used the browser's
  `document.exitFullscreen()` API because preview Escape delivery did not
  consistently leave fullscreen. Game state was not changed through that API.
- Open reset confirmations remain centered, fit the viewport and update their
  text/button scale across 390×844, 320×568 and 844×390 browser resizes. The OK
  button now has both a 44-unit width and height. Browser resources loaded
  successfully and no new application console errors or warnings appeared.
- A disposable native fixture exercised KDE fullscreen entry and an external
  return to windowed mode, checked the live Options label and saved config,
  then changed grid/volume without changing display mode. All assertions passed.
- The same native process played the death cue through the configured synth
  bus: observed peak was approximately −18.6 dB, below clipping; mute reduced
  it to approximately −200 dB. This verifies the native mixer path, not physical
  speaker output, audible quality or end-to-end latency.
- All nine source suites, composed-scene smoke, the expanded native rendered
  layout suite, Web/Windows/Linux exports and Linux packaged startup passed.
  Native verbose runs completed without script errors or ObjectDB leak warnings.

The physical-device and other-browser gaps listed above remain open.

## Horizontal menu follow-up — 2026-11-09

Godot 4.7.2 on CachyOS, with the horizontal menu changes accompanying this
record:

- All six menus use two columns at aspect ratios of at least 2:1 and 720 UI
  units of available width. Other windows retain the stacked arrangement.
  Source checks cover eight viewport shapes, including both sides of the
  breakpoint, 1280×480 and 2560×1080, at 1×/1.35×/2× density. They verify
  non-overlapping groups, short-landscape fit, focus paths, navigation and
  retention of mode, seed and seed-editor focus across resize.
- The native Compatibility-renderer suite passed with seven viewport shapes
  at all three densities. Full 2560×1080 density simulations remain headless:
  KDE constrains oversized native windows and changes their requested aspect
  ratio. Inspected native captures show all six menus fitting at 844×390,
  with the portrait main menu still stacked. The final native run exited
  without script errors or ObjectDB warnings.
- Chromium 152 through T3 preview, release Web export over loopback HTTP,
  device pixel ratio 1.35: inspected all six menus in short landscape and
  the main/pause layout at 1280×480. Selected Obstacles, resized through
  portrait and ultrawide, and confirmed the unchanged seed in the next round's
  HUD. Pointer Start, Escape pause/resume, game over and menu actions worked.
  Reset Settings Cancel and an open confirmation's portrait resize worked.
- The browser reported the full 2560×1080 CSS viewport and 3456×1458 canvas,
  but the preview screenshot cropped that large surface. Full-frame geometry
  at this size is covered by the headless suite, not a complete browser capture.
  No application console warnings/errors or failed resource requests appeared.
- All nine source suites, composed-scene smoke, Web/Windows/Linux release
  exports and Linux packaged startup passed. Windows was exported, not run.

Physical-device and other-browser coverage remains as listed above. Raw logs
and captures remain private and outside Git.
