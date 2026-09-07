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
