class_name SnakeCamera
extends Camera2D

const EDGE_MARGIN := Vector2(12.0, 12.0)

var target := Vector2.ZERO
var gameplay: Gameplay
var _rules: GameRules
var _board_center := Vector2.ZERO
var _pan_limit := Vector2.ZERO

func configure(game_rules: GameRules, gameplay_node: Gameplay) -> void:
	_rules = game_rules
	gameplay = gameplay_node
	_board_center = Vector2(_rules.board_size_pixels()) / 2.0
	reset_camera()
	fit_to_viewport()

func fit_to_viewport() -> void:
	var visible_half_size := get_viewport_rect().size / zoom / 2.0
	var spare := visible_half_size - _board_center
	# Leave room for the outline on axes that fit. For a larger board, allow
	# travel through the excess so the player can still reach either edge.
	_pan_limit = (spare - EDGE_MARGIN).max(Vector2.ZERO) + (-spare).max(Vector2.ZERO)
	target = _clamp_to_board(target)
	position = _clamp_to_board(position)
	force_update_scroll()

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
	var snake_position: Vector2 = gameplay.get_snake_position()
	var look_ahead: Vector2 = snake_position + (
		gameplay.get_snake_direction()
		* _rules.cell_size
		* _rules.camera_look_ahead_cells
	)
	var food_pos: Vector2 = gameplay.get_food_position()
	var snake_center: Vector2 = gameplay.get_weighted_snake_center()
	
	var total_weight := (
		_rules.look_ahead_weight + _rules.center_pull_weight
		+ _rules.food_attraction_weight + _rules.snake_center_weight
	)
	# All weights can legitimately be zero in the Inspector.
	if is_zero_approx(total_weight):
		target = _board_center
		return

	var new_target: Vector2 = (
		look_ahead * _rules.look_ahead_weight +
		_board_center * _rules.center_pull_weight +
		food_pos * _rules.food_attraction_weight +
		snake_center * _rules.snake_center_weight
	) / total_weight
	
	target = _clamp_to_board(target.lerp(new_target, _rules.camera_smoothing))

func _clamp_to_board(point: Vector2) -> Vector2:
	return point.clamp(_board_center - _pan_limit, _board_center + _pan_limit)

func reset_camera() -> void:
	target = _board_center
	position = target
