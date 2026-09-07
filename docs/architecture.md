# Architecture

snake2d uses explicit scene composition: every runtime service and controller is owned by the main scene, and there are no Autoload singletons.

## Owned scene tree

```text
Main
├── Services
│   ├── AudioService
│   ├── HighScoreStore
│   └── SettingsService
├── GameSession
├── UIStateManager
├── GameLayer
│   └── GameWorld
│       ├── Gameplay
│       ├── SnakeInputAdapter
│       ├── PlayArea
│       └── SnakeCamera
├── UILayer
│   ├── MainMenu
│   ├── OptionsMenu
│   ├── HighScoresMenu
│   ├── CreditsScreen
│   ├── PauseMenu
│   ├── HUDScoreLabel
│   └── GameOverPanel
└── DebugLayer
    └── DebugOverlay
```

`Main` is the composition root. It injects authored dependencies after every child has entered the tree. A component receives only services it actually uses: `Gameplay` receives rules and audio, `OptionsMenu` receives settings, and `GameSession` receives gameplay and high-score storage.

## Runtime flow

```text
device event
  → SnakeInputAdapter
  → Gameplay.request_direction(Vector2i)
  → SnakeGame / SnakeState validation
  → SnakeGame.step()
  → Gameplay scene and audio updates
  → GameSession score or round transition
  → Main maps application state to UIStateManager presentation
```

The layers have deliberately different responsibilities:

| Layer | Responsibility | Godot dependency |
| --- | --- | --- |
| `SnakeState`, `GridBoard`, `SnakeGame` | Grid rules, modes, collision, growth, food, obstacles, score, timing | `RefCounted`, value types, RNG |
| `Gameplay` | Model ticking, scenes, interpolation, pooling, gameplay audio | `Node2D` and scene tree |
| `GameSession` | Application state, pause ownership, round lifecycle, high scores | `Node` and `SceneTree.paused` |
| `UIStateManager` | Visibility, focus, and transitions between UI panels | `Control`, signals, tweens |
| Services | Audio playback, settings, and persistence | Explicitly owned nodes |

## State and pause ownership

`GameSession.State` is the single application-state machine:

```text
MAIN_MENU → PLAYING ⇄ PAUSED
                ↓
             GAME_OVER
                ↓
             MAIN_MENU
```

Only `GameSession` writes `SceneTree.paused`. `Main`, services, session state, and UI inherit an always-processing mode so menus continue to work while paused. `GameWorld` explicitly uses the pausable process mode, which stops gameplay, input, and camera callbacks without per-node pause checks.

`GameSession` initializes the model and views before publishing `PLAYING`, so a state observer can inspect the new round immediately. Reconfiguration disconnects the previous gameplay dependency. Removing the session releases `SceneTree.paused`, which would otherwise survive the removed main scene.

`GameSession` commits its game-over state before emitting round notifications. Ordinary signal connections run synchronously, so observers must see the completed state; otherwise a listener can end the same round twice or have its own menu transition overwritten. Starting an already active round, including a paused one, is a no-op.

`UIStateManager` does not own application state. It is a presentation helper that fades registered panels and restores focus after `Main` maps a session transition to the corresponding UI state. Registered panels are `Control` nodes, and a default focus target may be any `Control` (including a slider). Outgoing panels immediately disable processing, recursive mouse input, and recursive focus while their fade finishes. Transition tweens belong to the manager, and enabling reduced motion settles in-flight panel transitions. See the [Control input inheritance reference](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-property-mouse-behavior-recursive).

## Coordinates and timing

The model uses `Vector2i` cells. Presentation converts cells to pixel positions using `GameRules.cell_size`. Keeping that conversion at the adapter boundary prevents interpolation or camera motion from affecting collision rules.

`Gameplay` uses a bounded accumulator in `_physics_process`. It can catch up after a long frame without allowing an unbounded spiral of simulation work. `SnakeGame` advances only through `step()`, and interpolation changes only the displayed node positions. `Gameplay` tracks its transient eaten-food views explicitly, so cleanup cannot delete unrelated siblings. Food views cancel their spawn tween before starting consumption; button polish likewise has one active tween per button. Enabling reduced motion cancels and settles existing button polish.

## Data and randomness

`GameRules` is an Inspector-editable `Resource` assigned to `Main`. Board dimensions, score values, tick timing, and camera tuning can be changed without editing scripts.

`SnakeGame` receives a `RandomNumberGenerator`. Normal play randomizes it; tests supply a seed. Tail colors are a deterministic presentation gradient and do not consume model randomness. Obstacle mode also sends the selected world seed through `ObstaclePatternGenerator`; that independent generator chooses and parameterizes a Gates, Islands, or Ribbons layout, so the same world seed always produces the same walls regardless of food placement.

Pitfall mode adds a blocked cell at the configured food cadence. Its placement tiers prefer cells that are not directly ahead, are outside the snake's safety radius, and are not vertically below any body segment. Those preferences relax only when the remaining free cells make the safer tier impossible. Food selection excludes all blocked cells and is restricted to the connected region reachable from the snake. This reachability query treats the moving body as traversable and walls as permanent: it prevents food across a sealed wall, but does not promise that a legal sequence of turns can reach it. `FILLED_BOARD` means no free food cell remains in that region, which may be smaller than the whole board. Terminal steps retain their original outcome and reject new direction requests.

## Persistence and audio

`HighScoreStore` owns the versioned, per-mode high-score file. It migrates old array-only and v1 saves into the Classic table and fails closed on malformed or unsupported data.

`SettingsService` owns a versioned `ConfigFile`, migrates the old two-byte settings file, validates field types and finite volume values before applying them, and applies mute, effects volume, fullscreen, reduced motion, and gameplay-grid visibility. `GameplayGrid` draws its interior boundaries from `GameRules`, keeping the guide aligned when the board or cell size changes. `AudioService` is intentionally limited to procedural synthesis and playback. It renders click-safe attack/release envelopes and phase-continuous frequency sweeps, then reuses quantized PCM streams through a bounded cache. Cue gain is applied by the player rather than baked into PCM, so the same waveform can be reused at different volumes. The movement cue follows normalized game-speed progress from `GameRules`, not elapsed movement count. Overflow is dropped instead of cutting an active waveform, and a reserved voice keeps the death sound available without channel stealing.

## Verification

The source suite covers four boundaries:

- Model specifications cover movement, collisions, growth, deterministic food, board completion, and timing.
- Service tests cover session idempotency and synchronous signal listeners, persistence, migration, malformed settings, and procedural PCM generation.
- UI tests cover focus ownership, inactive-panel input, and interrupted transitions.
- The smoke scene instantiates `Main`, starts a round through its public API, and verifies the composed world reaches a playable state.

Run all source checks with `./test.sh source`. Each suite must print its explicit success marker as well as exit without errors; reaching the smoke scene frame limit is not success. Persistence tests and the composed scene use per-process disposable save paths, injected before configuration runs.
