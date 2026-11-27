# snake2d — Remaining Improvement Roadmap

See the [architecture guide](architecture.md) for the current implementation
and the [learning path](learning-path.md) for a tour of the code.

## Priority 1 — Validate real-device interaction

The narrow-screen sizing issue identified in September is addressed by an
independently scaled menu layer, distance-field text, larger targets and
focus-following scrolling. Automated geometry and rendered native checks cover
320×568, 390×844, 844×390 and 1280×720. Chromium Web checks also cover these CSS
viewport sizes and high-DPI menu/dialog sizing. Real phones and other browser
engines still need touch, scrolling and readable-text qualification.
See the recorded evidence in [manual testing](manual-testing.md).

Headless tests cover direction translation, tap/swipe classification, threshold scaling, and model validation, but they cannot prove viewport transforms, native touch behavior, controller focus, safe areas, or browser-specific pointer behavior.

Use [the manual test matrix](manual-testing.md) to record results for:

- Android/iOS tap, swipe, cancellation, and multi-touch behavior with the active Camera2D
- Web touch, physical mouse switching, and pointer capture
- perceived audio latency and cue balance on native and Web at maximum movement speed
- controller-only navigation through the volume slider and confirmation dialogs
- resizing and aspect-ratio extremes
- reduced-motion behavior across every menu transition

Automate individual cases only where a regression has occurred or a stable platform runner is available.

## Priority 2 — Add runtime input rebinding if the project needs it

The current `InputMap` cleanly separates UI actions from gameplay actions, but bindings are authored in `project.godot`. A reusable next lesson would be a small controls screen that:

- captures one keyboard or gamepad event at a time
- rejects conflicts or explains how conflicts are resolved
- restores defaults
- persists a versioned, device-neutral binding description
- applies changes through `InputMap` without restarting

Keep this as a separate feature boundary. Do not move input interpretation back into `SnakeView` or the model.

## Priority 3 — Surface persistence failures in the UI

Both persistence services write through `SaveFile` and log a warning when a
write fails. Players currently get no feedback in the UI. If the project needs
that feedback:

- return typed error results from both persistence services
- distinguish missing files from corrupt or unsupported files
- show a non-blocking message when settings or scores cannot be saved
- add an explicit migration test whenever a save version changes

Avoid showing errors for a normal first run where no file exists yet.

## Priority 4 — Add visual regression coverage only when visuals stabilize

The UI layout suite can save screenshots, and the
[repeatable Classic playtest](basaltwater.md#repeatable-classic-playtest)
retains rendered milestones. Checks currently cover geometry, focus and game
behavior. If visual regressions become common, build on those captures with
image comparisons for one desktop renderer and a few stable states:

- main menu
- active round with several body segments
- paused overlay
- game over
- options with reduced motion enabled

Keep tolerances and renderer assumptions documented.

## Priority 5 — Profile before adding more rendering abstractions

The current body-segment scene pool is intentionally simple and readable. A single custom renderer, MultiMesh-style approach, or larger preallocated pool should be considered only after profiling shows node count or draw calls matter for realistic board sizes.

The learning value of authored scenes and straightforward pooling currently outweighs speculative optimization.

## Non-goals

- No separate exercise curriculum; the game, tests, debugger observations, and learning path are the teaching material.
- No replacement singleton, service locator, event bus, or dependency-injection framework.
- No second implementation of the game rules for comparison.
- No plugin dependency for functionality already covered clearly by native Godot APIs.

## Suggested next order

1. Perform and record results in the real-device interaction matrix.
2. Decide whether runtime rebinding is valuable enough to justify a controls screen.
3. Improve persistence error reporting when adding the next saved setting or score feature.
4. Add visual regression tests only in response to recurring visual bugs.

## Audit follow-ups

- Keep the shared `GameRules` resource immutable during a round. Inspector ranges are authoring hints, not runtime validation; an eventual runtime preset editor should validate positive board/timing values and pit cadence before constructing a model.
