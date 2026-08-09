# Godot 4.7.1 Learning Path

This project is intended to be read from ownership outward: begin with the main scene, follow one state transition into gameplay, then study the pure rules beneath the scene adapter.

## 1. Scenes, nodes, and composition

Start with `scenes/main/main.tscn` and `scenes/main/main.gd`.

- Observe how authored children appear in the editor before the game runs.
- Put a breakpoint in `Main._ready()` and inspect the typed `@onready` references.
- Notice that `Main` wires dependencies and signals but does not implement Snake rules.
- Change a UI theme value or move a panel in the editor and observe that no gameplay code changes.

Read `docs/architecture.md` alongside the scene tree.

## 2. Resources and the Inspector

Open `resources/game_rules.tres` and its `GameRules` script.

- Inspect exported categories and ranges.
- Change `initial_tick_seconds`, board dimensions, or camera weights in the Inspector.
- Compare `game_rules_slow.tres` and `game_rules_fast.tres`, then assign either preset to `Main`.
- Follow the resource from `Main` into `Gameplay` and `SnakeCamera`.

This demonstrates data-driven configuration without global constants or a custom configuration framework.

## 3. Application state and pausing

Read `core/game_session.gd`, then `scenes/ui/ui_state_manager.gd`.

- Break in `GameSession._transition_to()` and start, pause, resume, lose, and return to the menu.
- Inspect `SceneTree.paused` and the process modes of `Main` and `GameWorld` in the remote scene tree.
- Compare application state in `GameSession` with panel visibility state in `UIStateManager`.

The important distinction is that session state owns behavior; UI state owns presentation.

## 4. Input actions and device translation

Read the input actions in `project.godot`, followed by `TouchGesture`, `SnakeInputAdapter`, and `SnakeState.request_direction()`.

- Keyboard, gamepad, mouse, tap, and drag all become a cardinal `Vector2i`.
- A touch remains undecided until release makes it a tap or physical screen motion crosses the swipe threshold.
- `InputEventScreenDrag.screen_relative` keeps swipe motion independent of viewport content stretching.
- `GameSession` enables the gameplay adapter only while a round is playing; menu navigation keeps its own focus handling.
- The adapter does not reject reversals or rapid turns; the model does.
- Observe how `_unhandled_input()` lets UI controls consume events before gameplay.

Change `drag_threshold_window_ratio` and `minimum_drag_threshold_pixels` in the Inspector to see how touch interpretation changes independently of the rules. Compare the pure gesture tests with the node-level coordinate conversion in the adapter.

## 5. Deterministic game rules

Read the model in this order:

1. `models/grid_board.gd`
2. `models/snake_state.gd`
3. `models/snake_game.gd`
4. `tests/snake_game_test.gd`

Set a breakpoint in `SnakeGame.step()` and inspect one movement tick. The model uses cells rather than pixels and has no scene-node references. The tests show why entering the departing tail cell is legal and why only one turn is accepted per tick.

## 6. Physics ticks and visual interpolation

Read `Gameplay._physics_process()`, `advance_one_tick()`, and `_apply_visual_interpolation()`.

- The bounded accumulator advances deterministic grid ticks.
- `SnakeView` and pooled `SnakeSegment` nodes interpolate between old and new pixel positions.
- A separate visual RNG changes segment colors without consuming model randomness.

In a debug build, press F1 to open the teaching overlay. Pause and press F2 to advance one model tick at a time.

## 7. Custom drawing and reusable scenes

Compare three presentation techniques:

- `SnakeView` composes an authored `SnakeSegment` scene.
- Body segments instantiate and pool that same scene at runtime.
- `FoodView._draw()` renders rounded geometry procedurally and animates its drawing state with tweens.

These examples share a model boundary while demonstrating different Godot rendering workflows.

## 8. Signals and UI boundaries

Read one menu controller, such as `MainMenu`, and follow its request signal into `Main`.

- Menus expose intent such as `start_requested`; they do not reach into session state.
- `Main` connects generic click/focus sounds at the composition boundary.
- `UIStateManager` registers panels and default focus targets without knowing game rules.

Use the debugger's Signals view to inspect connections at runtime. The options volume slider is also a useful example of why focus restoration should run only when no `Control` owns focus.

## 9. Camera2D

Read `scenes/main/snake_camera.gd`.

The camera combines look-ahead, board-center pull, food attraction, and weighted snake center. The weights come from `GameRules`, making the behavior easy to tune in the Inspector.

## 10. Procedural audio and buses

Read `services/audio_service.gd` and `tests/audio_synth_test.gd`.

- Tones are rendered into PCM data in `AudioStreamWAV`.
- Attack and release envelopes make every complete stream begin and end at zero amplitude.
- A bounded cache reuses quantized tones instead of regenerating identical PCM data during play.
- The player pool never cuts an active waveform; it drops overflow and reserves one critical voice for death.
- A dedicated bus and limiter constrain combined output.
- Settings are injected from `SettingsService`; audio does not load files itself.

## 11. Persistence and settings

Read `HighScoreStore`, `SettingsService`, and `tests/persistence_test.gd`.

- High scores use a versioned variant document with legacy support.
- Settings use sectioned `ConfigFile` data and migrate the old format.
- The options menu changes services through a typed boundary.
- Reduced motion changes both panel and button animation behavior.

## 12. Headless tests and exports

Read `test.sh`, the files under `tests/`, and `export_presets.cfg`.

Run:

```bash
./test.sh source
./build.sh linux
./test.sh linux-export
```

The same source checks run in CI before platform exports are built.
