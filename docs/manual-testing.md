# Manual interaction checks

Headless tests verify rules and scene behavior, but cannot establish real-device input, rendered layout, or audible quality. The matrix describes the full coverage target; the limited recorded run below does not establish native-device coverage. For each run, record commit, Godot version, OS/browser, device, and pass/fail with reproduction steps.

| Area | Steps | Expected result |
| --- | --- | --- |
| Desktop keyboard | Start, turn, pause, resume, lose, restart, return to menu | Exactly one legal turn per tick; paused rounds retain their board and score |
| Controller | Navigate all menus, select each mode, edit a seed, adjust volume, cancel and accept reset dialogs | Focus stays in the active panel; sliders and seed input remain usable |
| Fast menu changes | Open Options and immediately go back; press Start then immediately move or pause | Fading panels cannot take focus, activate buttons, or swallow gameplay input |
| Native touch | Tap, swipe, cancel a touch, add a second finger, pause/resume mid-gesture | One direction per gesture; no duplicate emulated mouse turn; old gestures are cleared |
| Web pointer | Switch between touch and mouse, drag outside the canvas and release, return to the game | No stuck drag or duplicate turn; direction matches the visible snake |
| Layout | Resize while playing and in every menu; try narrow/tall and wide/short windows | Controls remain reachable and grid, food, snake, and camera stay aligned |
| Reduced motion | Enable during a panel transition; visit every menu and disable it again | Panel transitions settle immediately; verify button animation behavior separately |
| Audio | Play at starting and maximum speed, eat, lose, pause; test mute and volume | No clicks or clipping; death cue is audible; settings take effect immediately |
| Save/reload | Change settings and earn scores in all modes; restart the application | Settings persist and scores remain separated by mode |

Use a temporary OS account or back up saves before manually testing reset actions. Automated persistence and smoke tests already use disposable paths.

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
