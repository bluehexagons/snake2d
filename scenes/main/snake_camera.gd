extends Camera2D

const ConfigData = preload("res://autoload/config.gd")

var velocity := Vector2.ZERO
var target := Vector2.ZERO
var game_width := 0
var game_height := 0
var game_manager: Node = null

func _ready() -> void:
	game_width = ConfigData.get_game_width()
	game_height = ConfigData.get_game_height()

	target = Vector2(float(game_width)/2.0, float(game_height)/2.0)
	position = target
	velocity = Vector2.ZERO

func _process(delta: float) -> void:
	if not get_tree().is_paused():
		var weight := clampf(1.0 - pow(0.001, delta), 0.0, 0.95)
		position = position.lerp(target, weight)

func _physics_process(_delta: float) -> void:
	if get_tree().is_paused():
		return

	# Calculate camera target based on weighted factors:
	# - Look ahead: where the snake is heading
	# - Center pull: keeps camera near center of play area
	# - Food attraction: draws camera toward food
	# - Snake center: focuses on the snake's body mass center
	var center := Vector2(float(game_width)/2.0, float(game_height)/2.0)
	var snake_position: Vector2 = game_manager.get_snake_position()
	var look_ahead: Vector2 = snake_position + (game_manager.get_snake_direction() * 32 * ConfigData.CAMERA_LOOK_AHEAD)
	var food_pos: Vector2 = game_manager.get_food_position()
	var snake_center: Vector2 = game_manager.get_weighted_snake_center()
	
	var new_target: Vector2 = (
		look_ahead * ConfigData.LOOK_AHEAD_WEIGHT +
		center * ConfigData.CENTER_PULL_WEIGHT +
		food_pos * ConfigData.FOOD_ATTRACTION_WEIGHT +
		snake_center * ConfigData.SNAKE_CENTER_WEIGHT
	) / (ConfigData.LOOK_AHEAD_WEIGHT + ConfigData.CENTER_PULL_WEIGHT + ConfigData.FOOD_ATTRACTION_WEIGHT + ConfigData.SNAKE_CENTER_WEIGHT)
	
	var t := ConfigData.CAMERA_ACCELERATION
	t = t * t * (3.0 - 2.0 * t)
	var desired_velocity: Vector2 = (new_target - target) * t
	
	velocity = velocity * ConfigData.CAMERA_DAMPING + desired_velocity
	target += velocity

func reset_camera() -> void:
	target = Vector2(float(game_width)/2.0, float(game_height)/2.0)
	position = target
	velocity = Vector2.ZERO
