extends Node

const GRID_SIZE := 32
const GRID_WIDTH := 23
const GRID_HEIGHT := 18

const MAX_HIGH_SCORES := 100
const STARTING_SPEED := 7.0
const SPEED_INCREMENT := 0.5
const MAX_SPEED := 20.0

const CAMERA_LOOK_AHEAD := 3.0
const CAMERA_SMOOTHING := 0.115
const CENTER_PULL_WEIGHT := 0.4
const FOOD_ATTRACTION_WEIGHT := 0.5
const LOOK_AHEAD_WEIGHT := 0.66
const SNAKE_CENTER_WEIGHT := 0.3
const CAMERA_DAMPING := 0.9
const CAMERA_ACCELERATION := 0.02

const BASE_FREQUENCY := 420.0
const AUDIO_HARMONICS := 8

const HIGHSCORE_FILE := "user://highscore.dat"
const SETTINGS_FILE := "user://settings.dat"

func get_game_width() -> int:
	return GRID_SIZE * GRID_WIDTH

func get_game_height() -> int:
	return GRID_SIZE * GRID_HEIGHT
