# A Simple Snake Game

A Simple Snake Game is a simple snake game in which you simply snake.

### Controls

- **Movement**: Arrow keys, WASD, Gamepad, or Mouse/Touch
- **Pause**: Space/Escape/P/or Start button
- **Menu Navigation**: 
  - Keyboard arrows/WASD
  - Gamepad D-pad/stick
  - Mouse
- **Select**: Enter/Space/A button
- **Back**: Escape/B button

## Features

- Multiple control schemes:
  - Keyboard (Arrow keys or WASD)
  - Gamepad (D-pad or analog stick)
  - Mouse/Touch (Click/tap where you want to go)
- Top 100 high scores system
- Pause functionality (Space/P/Start button)
- Full controller support with UI navigation
- Sound toggle option

### Building the Game

The game can be built for different platforms using the provided build script.

#### Requirements
- Godot Engine (version 4.6.2 or later) installed and available in your PATH
- The build script auto-detects `godot`, `godot4`, and the `GODOT`/`GODOT4` paths exported by `setup-godot`

#### Usage
```bash
# Build all platforms (Web, Windows, Linux)
./build.sh

# Build a specific platform
./build.sh web
./build.sh windows
./build.sh linux
```

The exported files will be placed in the `out/` directory.

### Technical Details

- Audio engine supporting multiple types of waveforms (sin, square, saw)
- Procedural color variations in the snake's tail
- Responsive UI design
- Save system for high scores
- Mobile-compatible design
- Smooth camera system

### Credits

Created by bluehexagons in a few days as a learning project for Copilot-assisted Godot game development and release.

### Open Source

Feel free to use this code as a learning resource or base for your own projects.
