# A Simple Snake Game

A Simple Snake Game is a simple snake game in which you simply snake.

## Controls

- **Movement**: Arrow keys, WASD, gamepad, mouse, or touch (tap/swipe)
- **Pause**: Space/Escape/P/or Start button
- **Menu Navigation**: 
  - Keyboard arrows/WASD
  - Gamepad D-pad/stick
  - Mouse
- **Select**: Enter/Space/A button
- **Back**: Escape/B button
- **Debug overlay**: F1 in debug builds
- **Single paused tick**: F2 while the debug overlay is visible and the game is paused

## Features

- Three game modes:
  - **Classic**: the original obstacle-free game of eating and growing
  - **Pitfall**: every third piece of food adds a pit, placed away from the snake whenever space allows
  - **Obstacles**: seeded worlds built from reproducible Gates, Islands, and Ribbons wall patterns
- Multiple control schemes:
  - Keyboard (Arrow keys or WASD)
  - Gamepad (D-pad or analog stick)
  - Mouse (click or drag toward the next direction)
  - Touch (tap toward a direction or swipe; swipes resolve as soon as the threshold is crossed)
- Top 100 high scores tracked separately for each game mode
- Pause functionality (Space/P/Start button)
- Full controller support with UI navigation
- Versioned settings for sound, effects volume, fullscreen, and reduced motion
- Inspector-editable board, timing, scoring, and camera rules
- Deterministic model tests and a debug teaching overlay

## Learning the project

Start with the [learning path](docs/learning-path.md), then use the [architecture guide](docs/architecture.md) as a map of ownership and runtime flow. The project deliberately uses explicit scene composition instead of Autoload singletons.

The main concepts demonstrated are scenes and node lifecycle, typed signals, Resources, input actions and touch events, pause-aware processing, fixed-tick models, interpolation, custom drawing, Camera2D, audio synthesis and buses, versioned persistence, headless tests, and exports.

## Building the Game

The game can be built for different platforms using the provided build script.

### Requirements

- Godot Engine (version 4.7.1 or later) and matching export templates installed
- The Godot executable available in your PATH
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

The exported files will be placed in the `out/` directory.

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

`test.sh all` runs both paths end-to-end. The source suite imports and parses the project, tests audio synthesis, session lifecycle, deterministic rules, input translation, persistence, and input actions, then instantiates the main scene and verifies that a playable round starts without opening a game window.

## Releasing

Releases are created from a clean, up-to-date `main` branch:

```bash
./bump_patch.sh
```

The helper runs the source test suite, increments `application/config/version`, creates the version commit and matching `v*` tag, then atomically pushes both. Pushing the tag triggers the GitHub release workflow, which tests and exports the Web, Windows, and Linux builds before publishing their archives.

## Technical Details

- Explicit scene composition with no Autoload singletons
- Pure `Vector2i` grid model with seeded randomness and bounded fixed-tick catch-up
- Inspector-editable `GameRules` Resource
- Owned and injected audio service with speed-aware movement tones, reusable swept PCM cues, click-safe voice pooling, and four waveforms
- Reusable, pooled snake segment scenes and a custom-drawn food view
- Responsive UI design
- Versioned high-score and settings persistence with legacy migration
- Explicit keyboard, gamepad, mouse, tap, and scale-aware swipe translation
- Weighted Camera2D system

## Credits

Created by bluehexagons in a few days as a learning project for Copilot-assisted Godot game development and release.

## Open Source

Feel free to use this code as a learning resource or base for your own projects.
