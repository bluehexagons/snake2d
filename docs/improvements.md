# snake2d — Remaining Improvement Roadmap

This roadmap reflects the current Godot 4.7.1 project after the architecture and learning-environment refinement. Completed historical findings have been removed rather than retained as an ever-growing checklist.

## Current baseline

- There are no Autoloads. `Main` visibly owns services, session state, gameplay, UI, and debug tooling.
- `GameSession` is the sole owner of application state and `SceneTree.paused`.
- `SnakeGame`, `SnakeState`, and `GridBoard` implement deterministic `Vector2i` rules independently of scenes and pixels.
- `Gameplay` is a Godot adapter for ticking, interpolation, pooled views, signals, and audio.
- `TouchGesture` and `SnakeInputAdapter` classify taps and scale-aware swipes per finger, use unscaled screen-relative drag motion, and ignore emulated duplicate mouse events without owning turn legality. Gameplay input is enabled only in the playing session state.
- `GameRules` provides Inspector-editable presets for board, scoring, timing, and camera tuning.
- Audio, settings, and high-score persistence are explicitly owned services with typed consumers. Synth tones have zero-amplitude edges, phase-continuous sweeps, playback-time cue gain, bounded prewarmed PCM reuse, a limiter, and non-stealing player channels. Movement tone follows an eased game-speed curve rather than elapsed ticks.
- The F1 debug overlay exposes live state; F2 advances one paused tick.
- Model, session, persistence, audio, input, input-map, and composed-scene tests run through `./test.sh source` and CI.
- `docs/architecture.md` and `docs/learning-path.md` describe ownership and a recommended reading order.

## Priority 1 — Validate real-device interaction

Headless tests cover direction translation, tap/swipe classification, threshold scaling, and model validation, but they cannot prove viewport transforms, native touch behavior, controller focus, safe areas, or browser-specific pointer behavior.

Add a short manual test matrix for:

- Android/iOS tap, swipe, cancellation, and multi-touch behavior with the active Camera2D
- Web touch, physical mouse switching, and pointer capture
- native and Web audio latency, cue balance, and limiter behavior at maximum movement speed
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

`SettingsService` warns when `ConfigFile.save()` fails, while `HighScoreStore` currently treats file-open failures as an empty table or unsuccessful write. If this project grows beyond a learning sample:

- return typed error results from both persistence services
- distinguish missing files from corrupt or unsupported files
- show a non-blocking message when settings or scores cannot be saved
- add an explicit migration test whenever a save version changes

Avoid showing errors for a normal first run where no file exists yet.

## Priority 4 — Add visual regression coverage only when visuals stabilize

The headless smoke test verifies composition and startup behavior, not rendered output. If UI or interpolation regressions become common, add a small screenshot suite for one desktop renderer and a few stable states:

- main menu
- active round with several body segments
- paused overlay
- game over
- options with reduced motion enabled

Keep tolerances and renderer assumptions documented. Screenshot infrastructure is not currently worth adding solely for completeness.

## Priority 5 — Profile before adding more rendering abstractions

The current body-segment scene pool is intentionally simple and readable. A single custom renderer, MultiMesh-style approach, or larger preallocated pool should be considered only after profiling shows node count or draw calls matter for realistic board sizes.

The learning value of authored scenes and straightforward pooling currently outweighs speculative optimization.

## Non-goals

- No separate exercise curriculum; the game, tests, debugger observations, and learning path are the teaching material.
- No replacement singleton, service locator, event bus, or dependency-injection framework.
- No second implementation of the game rules for comparison.
- No plugin dependency for functionality already covered clearly by native Godot APIs.

## Suggested next order

1. Perform and document the real-device interaction matrix.
2. Decide whether runtime rebinding is valuable enough to justify a controls screen.
3. Improve persistence error reporting when adding the next saved setting or score feature.
4. Add visual regression tests only in response to recurring visual bugs.
