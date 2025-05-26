extends Camera2D

var velocity := Vector2.ZERO
var target := Vector2.ZERO
var game_width := 0
var game_height := 0
var game_manager: Gameplay = null

func _ready() -> void:
	game_width = Config.get_game_width()
	game_height = Config.get_game_height()

	@warning_ignore("integer_division")
	target = Vector2(game_width/2, game_height/2)
	position = target
	velocity = Vector2.ZERO

func _process(delta: float) -> void:
	if not get_tree().paused:
		var weight := clampf(1.0 - pow(0.001, delta), 0.0, 0.95)
		position = position.lerp(target, weight)

func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		return

	@warning_ignore("integer_division")
	var center := Vector2(game_width/2, game_height/2)
	var snake_position := game_manager.get_snake_position()
	var look_ahead := snake_position + (game_manager.get_snake_direction() * 32 * Config.CAMERA_LOOK_AHEAD)
	var food_pos := game_manager.get_food_position()
	var snake_center := game_manager.get_weighted_snake_center()
	
	var new_target := (
		look_ahead * Config.LOOK_AHEAD_WEIGHT +
		center * Config.CENTER_PULL_WEIGHT +
		food_pos * Config.FOOD_ATTRACTION_WEIGHT +
		snake_center * Config.SNAKE_CENTER_WEIGHT
	) / (Config.LOOK_AHEAD_WEIGHT + Config.CENTER_PULL_WEIGHT + Config.FOOD_ATTRACTION_WEIGHT + Config.SNAKE_CENTER_WEIGHT)
	
	var t := Config.CAMERA_ACCELERATION
	t = t * t * (3.0 - 2.0 * t)
	var desired_velocity := (new_target - target) * t
	
	velocity = velocity * Config.CAMERA_DAMPING + desired_velocity
	target += velocity

func reset_camera() -> void:
	@warning_ignore("integer_division")
	target = Vector2(game_width/2, game_height/2)
	position = target
	velocity = Vector2.ZERO
