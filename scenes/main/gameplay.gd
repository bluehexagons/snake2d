class_name Gameplay
extends Node2D

## Adapts the deterministic SnakeGame model to Godot scenes, animation, and audio.

signal score_updated(new_score: int)
signal game_over(final_score: int)
signal food_spawned(position: Vector2)
signal snake_moved(position: Vector2)
signal snake_grew(position: Vector2)
signal tick_completed(result: SnakeGame.StepResult)
signal first_direction_accepted

const SnakeViewScene := preload("res://scenes/snake/snake_view.tscn")
const SnakeSegmentScene := preload("res://scenes/snake/snake_segment.tscn")
const FoodViewScene := preload("res://scenes/food/food.tscn")
const ObstacleViewScene := preload("res://scenes/obstacle/obstacle.tscn")
const BODY_MID_COLOR := Color(0.075, 0.72, 0.16, 1)
const TAIL_END_COLOR := Color(0.10, 0.61, 0.18, 1)
const COLLISION_COLOR := Color(1.0, 0.63, 0.30)

var model: SnakeGame
var snake: SnakeView
var food: FoodView
var obstacle_views: Array[ObstacleView] = []
var _eaten_food_views: Array[FoodView] = []

var tail_segments: Array[SnakeSegment] = []
var tail_segment_pool: Array[SnakeSegment] = []
var tail_retraction_index := -1
var tail_retraction_origin := Vector2.ZERO
var tail_retraction_direction := Vector2i.ZERO

var time_since_tick := 0.0

var _rules: GameRules
var _audio_service: AudioService
var _model_random := RandomNumberGenerator.new()
var _randomize_on_start := true
var current_mode: GameMode.Value = GameMode.Value.CLASSIC
var current_world_seed := 0

@onready var game_world: Node2D = get_parent()

## Supplies authored dependencies before the first round starts.
func configure(game_rules: GameRules, audio_service: AudioService) -> void:
	_rules = game_rules
	_audio_service = audio_service

## Replaces randomized food placement with a caller-owned generator, primarily for tests.
func set_random_number_generator(random: RandomNumberGenerator) -> void:
	_model_random = random
	_randomize_on_start = false

func start_game(
	mode: GameMode.Value = GameMode.Value.CLASSIC,
	world_seed: int = 0
) -> void:
	assert(_rules != null, "Gameplay requires GameRules before starting.")
	assert(_audio_service != null, "Gameplay requires AudioService before starting.")

	_recycle_active_tail()
	_remove_current_snake()
	_remove_current_food()
	_remove_obstacle_views()
	_remove_eaten_food_views()

	if _randomize_on_start:
		_model_random.randomize()
	current_mode = mode
	current_world_seed = world_seed
	model = SnakeGame.new(_rules, _model_random, current_mode, current_world_seed)
	model.reset()
	queue_redraw()
	_render_all_obstacles()

	snake = SnakeViewScene.instantiate() as SnakeView
	snake.configure(_rules.cell_size)
	snake.snap_to_cell(model.snake.body[0])
	game_world.add_child(snake)

	if not model.game_over:
		_show_food(model.food_cell)
	time_since_tick = 0.0
	score_updated.emit(model.score)
	if model.game_over:
		_finish_round()

func _physics_process(delta: float) -> void:
	if model == null or model.game_over:
		return

	time_since_tick += delta
	var steps := 0
	while (
		time_since_tick >= model.current_tick_seconds()
		and steps < _rules.maximum_catch_up_steps
		and not model.game_over
	):
		time_since_tick -= model.current_tick_seconds()
		advance_one_tick()
		steps += 1

	if steps == _rules.maximum_catch_up_steps:
		time_since_tick = minf(time_since_tick, model.current_tick_seconds())

	_apply_visual_interpolation()

## Advances exactly one model tick. The debug overlay uses this while the tree is paused.
func advance_one_tick() -> SnakeGame.StepResult:
	if model == null:
		return SnakeGame.StepResult.NOT_RUNNING
	if model.game_over:
		return model.step()

	var previous_tail := model.snake.body[-1]
	var eaten_cell := model.food_cell
	var previous_obstacle_count := model.obstacle_cells.size()
	var result := model.step()

	if result == SnakeGame.StepResult.WAITING_FOR_INPUT:
		tick_completed.emit(result)
		return result

	if (
		result == SnakeGame.StepResult.HIT_WALL
		or result == SnakeGame.StepResult.HIT_SELF
		or result == SnakeGame.StepResult.HIT_OBSTACLE
	):
		_finish_round()
		tick_completed.emit(result)
		return result

	if result == SnakeGame.StepResult.MOVED:
		_audio_service.play_move(_rules.speed_progress_for_length(model.snake.body.size()))
	snake.move_to_cell(model.snake.body[0])
	if snake.queued_direction != model.snake.queued_direction:
		snake.show_queued_direction(model.snake.queued_direction)
	var grew := result == SnakeGame.StepResult.ATE_FOOD or result == SnakeGame.StepResult.FILLED_BOARD
	_sync_tail_presentation(previous_tail, grew)
	snake_moved.emit(_cell_to_pixel(model.snake.body[0]))

	if grew:
		_audio_service.play_eat()
		_consume_food_view()
		score_updated.emit(model.score)
		snake_grew.emit(_cell_to_pixel(eaten_cell))
		_render_new_obstacles(previous_obstacle_count)
		if result == SnakeGame.StepResult.ATE_FOOD:
			_show_food(model.food_cell)
		else:
			_finish_round()

	tick_completed.emit(result)
	return result

## Advances one paused tick and displays the resulting cells without interpolation.
func advance_one_tick_and_snap() -> SnakeGame.StepResult:
	var result := advance_one_tick()
	_snap_presentation_to_targets()
	time_since_tick = 0.0
	return result

func request_direction(direction: Vector2i) -> bool:
	if model == null or model.game_over:
		return false
	var waiting_for_input := model.snake.waiting_for_input
	var accepted := model.request_direction(direction)
	if accepted:
		if snake.queued_direction != model.snake.queued_direction:
			snake.show_queued_direction(model.snake.queued_direction)
		if waiting_for_input:
			first_direction_accepted.emit()
	return accepted

func is_waiting_for_input() -> bool:
	return model != null and not model.game_over and model.snake.waiting_for_input

func is_position_occupied(pixel_position: Vector2) -> bool:
	return model != null and model.is_cell_occupied(_pixel_to_cell(pixel_position))

func cleanup() -> void:
	_remove_current_snake()
	_remove_current_food()
	_remove_obstacle_views()
	_remove_eaten_food_views()

	for segment in tail_segments:
		segment.queue_free()
	tail_segments.clear()
	for segment in tail_segment_pool:
		segment.queue_free()
	tail_segment_pool.clear()
	_clear_tail_retraction()
	model = null
	time_since_tick = 0.0
	queue_redraw()

func get_snake_position() -> Vector2:
	return snake.position if snake else Vector2.ZERO

func get_snake_center() -> Vector2:
	return snake.position + Vector2.ONE * (snake.cell_size / 2.0) if snake else Vector2.ZERO

func is_board_complete() -> bool:
	return model != null and model.is_board_complete()

func get_round_result() -> SnakeGame.StepResult:
	return model.get_round_result() if model != null else SnakeGame.StepResult.NOT_RUNNING

func get_food_position() -> Vector2:
	return food.position if food else Vector2.ZERO

func get_snake_direction() -> Vector2:
	return Vector2(model.snake.direction) if model else Vector2.RIGHT

func get_weighted_snake_center() -> Vector2:
	if snake and not tail_segments.is_empty():
		var sum_position := snake.position * 2.0
		var total_weight := 2.0
		for i in tail_segments.size():
			var weight := 1.0 / (i + 2.0)
			sum_position += tail_segments[i].position * weight
			total_weight += weight
		return sum_position / total_weight
	return snake.position if snake else Vector2.ZERO

func get_debug_snapshot() -> Dictionary:
	if model == null:
		return {
			"round_ready": false,
			"accumulator": time_since_tick,
		}
	return {
		"round_ready": true,
		"tick": model.tick_count,
		"tick_seconds": model.current_tick_seconds(),
		"accumulator": time_since_tick,
		"head": model.snake.body[0],
		"body": model.snake.body.duplicate(),
		"food": model.food_cell,
		"mode": GameMode.key(model.mode),
		"world_seed": model.world_seed,
		"obstacles": model.obstacle_cells.duplicate(),
		"obstacle_pattern": model.obstacle_pattern_name,
		"direction": model.snake.direction,
		"queued_direction": model.snake.queued_direction,
		"waiting_for_input": model.snake.waiting_for_input,
		"score": model.score,
		"game_over": model.game_over,
	}

func _sync_tail_presentation(previous_tail: Vector2i, grew: bool) -> void:
	var logical_tail_segments := model.snake.body.size() - 1
	var retracts_tail := not grew and logical_tail_segments > 0
	var required_segments := logical_tail_segments + (1 if retracts_tail else 0)
	while tail_segments.size() < required_segments:
		tail_segments.append(_acquire_tail_segment())
	while tail_segments.size() > required_segments:
		var segment: SnakeSegment = tail_segments.pop_back()
		segment.hide()
		tail_segment_pool.append(segment)

	_clear_tail_retraction()
	for i in required_segments:
		tail_segments[i].set_alive_color(_segment_color_for_index(i, required_segments))
	for i in logical_tail_segments:
		tail_segments[i].position = _cell_to_pixel(model.snake.body[i + 1])
		tail_segments[i].show_full_size(_rules.cell_size)

	if retracts_tail:
		tail_retraction_index = required_segments - 1
		tail_retraction_origin = _cell_to_pixel(previous_tail)
		# The old tail retracts toward the last cell that remains occupied.
		tail_retraction_direction = model.snake.body[-1] - previous_tail
		tail_segments[tail_retraction_index].show_full_size(_rules.cell_size)
		tail_segments[tail_retraction_index].position = tail_retraction_origin

func _acquire_tail_segment() -> SnakeSegment:
	var segment: SnakeSegment
	if tail_segment_pool.is_empty():
		segment = SnakeSegmentScene.instantiate() as SnakeSegment
		game_world.add_child(segment)
	else:
		segment = tail_segment_pool.pop_back()

	segment.configure(_rules.cell_size, BODY_MID_COLOR)
	return segment

func _segment_color_for_index(index: int, segment_count: int) -> Color:
	if segment_count <= 1:
		return SnakeView.HEAD_COLOR.lerp(TAIL_END_COLOR, 0.5)
	var progress := float(index) / float(segment_count - 1)
	var end_gradient := SnakeView.HEAD_COLOR.lerp(TAIL_END_COLOR, progress)
	# The sine-shaped center lift keeps both two-segment end bands close to
	# their endpoint colors while giving the middle a readable, gentle highlight.
	var center_lift := sin(progress * PI) * 0.75
	return end_gradient.lerp(BODY_MID_COLOR, center_lift)

func _apply_visual_interpolation() -> void:
	if model == null or snake == null or model.game_over:
		return
	var progress := clampf(time_since_tick / model.current_tick_seconds(), 0.0, 1.0)
	snake.apply_visual_interpolation(progress)
	_apply_tail_retraction(progress)

func _apply_tail_retraction(progress: float) -> void:
	if tail_retraction_index < 0:
		return
	var eased := progress * progress * progress * (
		progress * (progress * 6.0 - 15.0) + 10.0
	)
	tail_segments[tail_retraction_index].apply_tail_retraction(
		tail_retraction_origin,
		tail_retraction_direction,
		eased,
		_rules.cell_size
	)

func _snap_presentation_to_targets() -> void:
	if snake:
		snake.apply_visual_interpolation(1.0)
	_apply_tail_retraction(1.0)

func _show_food(cell: Vector2i) -> void:
	food = FoodViewScene.instantiate() as FoodView
	food.configure(_rules.cell_size)
	food.position = _cell_to_pixel(cell)
	game_world.add_child(food)
	food_spawned.emit(food.position)

func _consume_food_view() -> void:
	if food == null:
		return
	var eaten_food := food
	food = null
	_eaten_food_views.append(eaten_food)
	eaten_food.tree_exited.connect(func() -> void:
		_eaten_food_views.erase(eaten_food)
	, CONNECT_ONE_SHOT)
	eaten_food.eat()

func _finish_round() -> void:
	if snake == null:
		return
	# The session pauses the world as soon as game_over is emitted.
	_snap_presentation_to_targets()
	if is_board_complete():
		_remove_eaten_food_views()
		snake.hide_direction_indicator()
	else:
		_audio_service.play_die()
		snake.mark_dead()
		for segment in tail_segments:
			segment.mark_dead()
		queue_redraw()
	game_over.emit(model.score)

func _draw() -> void:
	var result := get_round_result()
	if result not in [SnakeGame.StepResult.HIT_WALL, SnakeGame.StepResult.HIT_SELF, SnakeGame.StepResult.HIT_OBSTACLE]:
		return
	var cell := model.snake.next_head_cell().clamp(Vector2i.ZERO, model.board.size - Vector2i.ONE)
	var marker := Rect2(_cell_to_pixel(cell), Vector2.ONE * _rules.cell_size).grow(-2.0)
	draw_rect(marker, COLLISION_COLOR, false, 3.0)

func _recycle_active_tail() -> void:
	for segment in tail_segments:
		segment.hide()
		tail_segment_pool.append(segment)
	tail_segments.clear()
	_clear_tail_retraction()

func _clear_tail_retraction() -> void:
	tail_retraction_index = -1
	tail_retraction_origin = Vector2.ZERO
	tail_retraction_direction = Vector2i.ZERO

func _remove_current_snake() -> void:
	if snake:
		snake.queue_free()
		snake = null

func _remove_current_food() -> void:
	if food:
		food.queue_free()
		food = null

func _remove_eaten_food_views() -> void:
	# Only retire views created by this adapter, never unrelated world siblings.
	for eaten_food in _eaten_food_views:
		eaten_food.queue_free()
	_eaten_food_views.clear()

func _render_all_obstacles() -> void:
	_render_new_obstacles(0)

func _render_new_obstacles(start_index: int) -> void:
	if model == null:
		return
	for index in range(start_index, model.obstacle_cells.size()):
		var obstacle := ObstacleViewScene.instantiate() as ObstacleView
		obstacle.configure(_rules.cell_size, model.mode == GameMode.Value.PITFALL)
		obstacle.position = _cell_to_pixel(model.obstacle_cells[index])
		game_world.add_child(obstacle)
		obstacle_views.append(obstacle)

func _remove_obstacle_views() -> void:
	for obstacle in obstacle_views:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	obstacle_views.clear()

func _cell_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell * _rules.cell_size)

func _pixel_to_cell(pixel_position: Vector2) -> Vector2i:
	return Vector2i(pixel_position / float(_rules.cell_size))
