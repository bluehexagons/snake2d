class_name SnakeGame
extends RefCounted

## Deterministic Snake rules. Presentation advances this model one grid tick at a time.

enum StepResult {
	WAITING_FOR_INPUT,
	MOVED,
	ATE_FOOD,
	HIT_WALL,
	HIT_SELF,
	HIT_OBSTACLE,
	FILLED_BOARD,
}

var rules: GameRules
var board: GridBoard
var snake := SnakeState.new()
var food_cell := Vector2i(-1, -1)
var score := 0
var game_over := false
var tick_count := 0
var mode: GameMode.Value
var world_seed: int
var obstacle_cells: Array[Vector2i] = []
var obstacle_pattern_name := ""
var foods_eaten := 0

var _random: RandomNumberGenerator

func _init(
	game_rules: GameRules,
	random: RandomNumberGenerator,
	game_mode: GameMode.Value = GameMode.Value.CLASSIC,
	selected_world_seed: int = 0
) -> void:
	rules = game_rules
	_random = random
	mode = game_mode
	world_seed = selected_world_seed
	board = GridBoard.new(rules.board_size_cells())

func reset() -> void:
	score = 0
	game_over = false
	tick_count = 0
	foods_eaten = 0
	snake.reset(Vector2i(board.size.x / 2, board.size.y / 2))
	obstacle_cells.clear()
	obstacle_pattern_name = ""
	if mode == GameMode.Value.OBSTACLES:
		var pattern := ObstaclePatternGenerator.generate(board.size, snake.body[0], world_seed)
		obstacle_pattern_name = pattern.name
		obstacle_cells.assign(pattern.cells)
	food_cell = _choose_food_cell()

func request_direction(direction: Vector2i) -> bool:
	return snake.request_direction(direction)

func step() -> StepResult:
	if snake.waiting_for_input:
		return StepResult.WAITING_FOR_INPUT
	if game_over:
		return StepResult.HIT_SELF
	tick_count += 1

	var next_head := snake.next_head_cell()
	if not board.contains(next_head):
		snake.mark_dead()
		game_over = true
		return StepResult.HIT_WALL
	if next_head in obstacle_cells:
		snake.mark_dead()
		game_over = true
		return StepResult.HIT_OBSTACLE

	var ate_food := next_head == food_cell
	if snake.would_hit_self(next_head, ate_food):
		snake.mark_dead()
		game_over = true
		return StepResult.HIT_SELF

	snake.advance(next_head, ate_food)
	if not ate_food:
		return StepResult.MOVED

	score += rules.points_per_food
	foods_eaten += 1
	if mode == GameMode.Value.PITFALL and foods_eaten % rules.foods_per_pit == 0:
		_place_pit()
	food_cell = _choose_food_cell()
	if food_cell == Vector2i(-1, -1):
		game_over = true
		return StepResult.FILLED_BOARD
	return StepResult.ATE_FOOD

func current_tick_seconds() -> float:
	return rules.tick_seconds_for_length(snake.body.size())

func is_cell_occupied(cell: Vector2i) -> bool:
	return cell in snake.body

func is_cell_blocked(cell: Vector2i) -> bool:
	return cell in obstacle_cells

func _choose_food_cell() -> Vector2i:
	var occupied := snake.body.duplicate()
	occupied.append_array(obstacle_cells)
	var candidates := board.available_cells(occupied)
	if candidates.is_empty():
		return Vector2i(-1, -1)

	var reachable := _reachable_cells_from(snake.body[0])
	var reachable_candidates: Array[Vector2i] = []
	for cell in candidates:
		if reachable.has(cell):
			reachable_candidates.append(cell)
	if reachable_candidates.is_empty():
		return Vector2i(-1, -1)
	return reachable_candidates[_random.randi_range(0, reachable_candidates.size() - 1)]

func _place_pit() -> void:
	var occupied := snake.body.duplicate()
	occupied.append_array(obstacle_cells)
	if food_cell != Vector2i(-1, -1):
		occupied.append(food_cell)
	var candidates := board.available_cells(occupied)
	if candidates.is_empty():
		return

	var next_cell := snake.body[0] + snake.direction
	var preferred: Array[Vector2i] = []
	var not_near: Array[Vector2i] = []
	for cell in candidates:
		if cell == next_cell or _is_too_near_snake(cell):
			continue
		not_near.append(cell)
		if _is_below_snake_segment(cell):
			continue
		preferred.append(cell)

	var pool := preferred
	if pool.is_empty():
		pool = not_near
	if pool.is_empty():
		for cell in candidates:
			if cell != next_cell:
				pool.append(cell)
	if pool.is_empty():
		pool = candidates
	obstacle_cells.append(pool[_random.randi_range(0, pool.size() - 1)])

func _is_too_near_snake(cell: Vector2i) -> bool:
	for segment in snake.body:
		var distance := absi(cell.x - segment.x) + absi(cell.y - segment.y)
		if distance < rules.pit_safe_distance_cells:
			return true
	return false

func _is_below_snake_segment(cell: Vector2i) -> bool:
	for segment in snake.body:
		if cell.x == segment.x and cell.y > segment.y:
			return true
	return false

func _reachable_cells_from(start: Vector2i) -> Dictionary[Vector2i, bool]:
	var reachable: Dictionary[Vector2i, bool] = {start: true}
	var frontier: Array[Vector2i] = [start]
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		for direction in SnakeState.CARDINAL_DIRECTIONS:
			var next := current + direction
			if board.contains(next) and next not in obstacle_cells and not reachable.has(next):
				reachable[next] = true
				frontier.append(next)
	return reachable
