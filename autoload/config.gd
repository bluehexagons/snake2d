extends Node
# Configuration singleton that centralizes game settings

# Game grid settings
const GRID_SIZE := 32       # Size of each grid cell in pixels
const GRID_WIDTH := 24      # Number of grid cells horizontally
const GRID_HEIGHT := 18     # Number of grid cells vertically

# Game settings
const MAX_HIGH_SCORES := 100     # Maximum number of high scores to keep
const STARTING_SPEED := 7.0      # Initial snake movement speed
const SPEED_INCREMENT := 0.5     # How much speed increases with each food item
const MAX_SPEED := 20.0          # Maximum snake movement speed

# Camera settings
const CAMERA_LOOK_AHEAD := 1.2
const CAMERA_SMOOTHING := 0.015
const CENTER_PULL_WEIGHT := 0.4
const FOOD_ATTRACTION_WEIGHT := 0.5
const LOOK_AHEAD_WEIGHT := 0.66
const SNAKE_CENTER_WEIGHT := 0.3
const CAMERA_DAMPING := 0.97
const CAMERA_ACCELERATION := 0.02

# Audio settings
const BASE_FREQUENCY := 420.0     # Base frequency for sound generation (roughly A4 note)
const AUDIO_HARMONICS := 8        # Number of harmonics for complex waveforms

# File paths
const HIGHSCORE_FILE := "user://highscore.dat"
const SETTINGS_FILE := "user://settings.dat"

# Get the total game area dimensions in pixels
func get_game_width() -> int:
  return GRID_SIZE * GRID_WIDTH

func get_game_height() -> int:
  return GRID_SIZE * GRID_HEIGHT
