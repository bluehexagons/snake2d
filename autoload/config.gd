extends RefCounted

@export var GRID_SIZE: int = 32
@export var GRID_WIDTH: int = 23
@export var GRID_HEIGHT: int = 18

@export var MAX_HIGH_SCORES: int = 100
@export var STARTING_SPEED: float = 7.0
@export var SPEED_INCREMENT: float = 0.5
@export var MAX_SPEED: float = 20.0

@export var CAMERA_LOOK_AHEAD: float = 3.0
@export var CAMERA_SMOOTHING: float = 0.115
@export var CENTER_PULL_WEIGHT: float = 0.4
@export var FOOD_ATTRACTION_WEIGHT: float = 0.5
@export var LOOK_AHEAD_WEIGHT: float = 0.66
@export var SNAKE_CENTER_WEIGHT: float = 0.3
@export var CAMERA_DAMPING: float = 0.9
@export var CAMERA_ACCELERATION: float = 0.02

@export var BASE_FREQUENCY: float = 420.0
@export var AUDIO_HARMONICS: int = 8

const HIGHSCORE_FILE := "user://highscore.dat"
const SETTINGS_FILE := "user://settings.dat"

static func get_game_width() -> int:
	return GRID_SIZE * GRID_WIDTH

static func get_game_height() -> int:
	return GRID_SIZE * GRID_HEIGHT
