# A Simple Snake Game

Eat food, grow, and beat your high score. Pick a mode from the main menu and press **Play**.
The snake waits for your first direction before it moves.

**[Play in your browser](https://bluehexagons.github.io/snake2d/)** · **[Download for Windows or Linux](https://github.com/bluehexagons/snake2d/releases/latest)**

## Game modes

- **Classic** starts with an open board. Avoid the edges and your own body.
- **Pitfall** adds a pit every third meal when there’s room.
- **Obstacles** starts with a wall layout. Enter the same seed to replay that layout or share it with a friend.

The game saves your top 100 scores for each mode. Open **High Scores** to see
them. With a keyboard or controller, focus the list and press Up or Down to scroll.

## Controls

| Input | Steer or navigate | Select | Pause or go back |
| --- | --- | --- | --- |
| Keyboard | Arrow keys or WASD | Enter. Space also selects outside a round. | Space, Esc, or P to pause or resume. Esc to go back. |
| Gamepad | D-pad or left stick | A | Start or B to pause or resume. B to go back. |
| Mouse | Click or drag to steer | Click | Use the on-screen Pause or Back button. |
| Touch | Tap or swipe to steer | Tap | Use the on-screen Pause or Back button. |

The game pauses when its window loses focus. Select **Resume** when you’re ready.

## Options

Adjust effects volume, mute sound, switch to fullscreen, or hide the grid.
**Reduced Motion** skips menu fades and keeps the whole board in view. In the
desktop download, **30 FPS Limit** reduces rendering work while the snake is
moving. The snake keeps the same speed.

## Credits and AI disclosure

Created by bluehexagons as a Godot learning project for agentic development, originally with Copilot. Development now uses AI coding agents on [Basaltwater](https://github.com/bluehexagons/basaltwater). The agents have helped implement and test the game and revise in-game text.

Game source is available under the [Apache 2.0 license](LICENSE). The [Averia Sans Libre font license](AveriaSansLibre-Regular%20OFL.txt) credits Dan Sayers.

## For developers

See the [contributor guide](CONTRIBUTING.md) for setup and tests and the
[Godot learning path](docs/learning-path.md) for a tour of the code.
