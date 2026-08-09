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
| `SnakeState`, `GridBoard`, `SnakeGame` | Grid rules, collision, growth, food, score, timing | `RefCounted`, value types, RNG |
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

`UIStateManager` does not own application state. It is a presentation helper that fades registered panels and restores focus after `Main` maps a session transition to the corresponding UI state.

## Coordinates and timing

The model uses `Vector2i` cells. Presentation converts cells to pixel positions using `GameRules.cell_size`. Keeping that conversion at the adapter boundary prevents interpolation or camera motion from affecting collision rules.

`Gameplay` uses a bounded accumulator in `_physics_process`. It can catch up after a long frame without allowing an unbounded spiral of simulation work. `SnakeGame` advances only through `step()`, and interpolation changes only the displayed node positions.

## Data and randomness

`GameRules` is an Inspector-editable `Resource` assigned to `Main`. Board dimensions, score values, tick timing, and camera tuning can be changed without editing scripts.

`SnakeGame` receives a `RandomNumberGenerator`. Normal play randomizes it; tests supply a seed. Presentation uses a different generator for cosmetic tail colors so visual randomness cannot change food placement.

## Persistence and audio

`HighScoreStore` owns the versioned high-score file. It accepts old array-only saves and fails closed on malformed or unsupported data.

`SettingsService` owns a versioned `ConfigFile`, migrates the old two-byte settings file, and applies mute, effects volume, fullscreen, and reduced motion. `AudioService` is intentionally limited to procedural synthesis and playback. It renders click-safe attack/release envelopes, reuses quantized PCM streams through a bounded cache, and drops overflow instead of cutting an active waveform. A reserved voice keeps the death sound available without channel stealing.

## Verification

The source suite has three levels:

- Model specifications cover movement, collisions, growth, deterministic food, board completion, and timing.
- Service tests cover session idempotency, persistence, migration, settings, and procedural PCM generation.
- The smoke scene instantiates `Main`, starts a round through its public API, and verifies the composed world reaches a playable state.

Run all source checks with `./test.sh source`.
