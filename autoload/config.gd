extends RefCounted

const GRID_SIZE: int = 32
const GRID_WIDTH: int = 23
const GRID_HEIGHT: int = 18

const MAX_HIGH_SCORES: int = 100
const STARTING_SPEED: float = 7.0
const SPEED_INCREMENT: float = 0.5
const MAX_SPEED: float = 20.0

const CAMERA_LOOK_AHEAD: float = 3.0
const CAMERA_SMOOTHING: float = 0.115
const CENTER_PULL_WEIGHT: float = 0.4
const FOOD_ATTRACTION_WEIGHT: float = 0.5
const LOOK_AHEAD_WEIGHT: float = 0.66
const SNAKE_CENTER_WEIGHT: float = 0.3
const CAMERA_DAMPING: float = 0.9
const CAMERA_ACCELERATION: float = 0.02

const BASE_FREQUENCY: float = 420.0
const AUDIO_HARMONICS: int = 8

const HIGHSCORE_FILE := "user://highscore.dat"
const SETTINGS_FILE := "user://settings.dat"

static func get_game_width() -> int:
	return GRID_SIZE * GRID_WIDTH

static func get_game_height() -> int:
	return GRID_SIZE * GRID_HEIGHT
