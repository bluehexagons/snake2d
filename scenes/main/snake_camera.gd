class_name SnakeCamera
extends Camera2D

var target := Vector2.ZERO
var game_width := 0
var game_height := 0
var gameplay: Gameplay
var _rules: GameRules

func configure(game_rules: GameRules, gameplay_node: Gameplay) -> void:
	_rules = game_rules
	gameplay = gameplay_node
	game_width = _rules.board_size_pixels().x
	game_height = _rules.board_size_pixels().y
	reset_camera()

func _process(delta: float) -> void:
	var weight := clampf(1.0 - pow(0.001, delta), 0.0, 0.95)
	position = position.lerp(target, weight)

func _physics_process(_delta: float) -> void:
	if gameplay == null:
		return

	# Calculate camera target based on weighted factors:
	# - Look ahead: where the snake is heading
	# - Center pull: keeps camera near center of play area
	# - Food attraction: draws camera toward food
	# - Snake center: focuses on the snake's body mass center
	var center := Vector2(float(game_width)/2.0, float(game_height)/2.0)
	var snake_position: Vector2 = gameplay.get_snake_position()
	var look_ahead: Vector2 = snake_position + (
		gameplay.get_snake_direction()
		* _rules.cell_size
		* _rules.camera_look_ahead_cells
	)
	var food_pos: Vector2 = gameplay.get_food_position()
	var snake_center: Vector2 = gameplay.get_weighted_snake_center()
	
	var new_target: Vector2 = (
		look_ahead * _rules.look_ahead_weight +
		center * _rules.center_pull_weight +
		food_pos * _rules.food_attraction_weight +
		snake_center * _rules.snake_center_weight
	) / (
		_rules.look_ahead_weight
		+ _rules.center_pull_weight
		+ _rules.food_attraction_weight
		+ _rules.snake_center_weight
	)
	
	target = target.lerp(new_target, _rules.camera_smoothing)

func reset_camera() -> void:
	target = Vector2(float(game_width)/2.0, float(game_height)/2.0)
	position = target
