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
	NOT_RUNNING,
}

enum CellVisit { UNVISITED, BLOCKED, REACHABLE }

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
var _terminal_result := StepResult.NOT_RUNNING

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
	_terminal_result = StepResult.NOT_RUNNING
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
	if food_cell == Vector2i(-1, -1):
		_complete_round(StepResult.FILLED_BOARD)

func request_direction(direction: Vector2i) -> bool:
	return not game_over and snake.request_direction(direction)

func step() -> StepResult:
	if game_over:
		return _terminal_result
	if snake.waiting_for_input:
		return StepResult.WAITING_FOR_INPUT
	tick_count += 1

	var next_head := snake.next_head_cell()
	if not board.contains(next_head):
		return _complete_round(StepResult.HIT_WALL)
	if next_head in obstacle_cells:
		return _complete_round(StepResult.HIT_OBSTACLE)

	var ate_food := next_head == food_cell
	if snake.would_hit_self(next_head, ate_food):
		return _complete_round(StepResult.HIT_SELF)

	snake.advance(next_head, ate_food)
	if not ate_food:
		return StepResult.MOVED

	score += rules.points_per_food
	foods_eaten += 1
	if mode == GameMode.Value.PITFALL and foods_eaten % rules.foods_per_pit == 0:
		_place_pit()
	food_cell = _choose_food_cell()
	if food_cell == Vector2i(-1, -1):
		return _complete_round(StepResult.FILLED_BOARD)
	return StepResult.ATE_FOOD

func _complete_round(result: StepResult) -> StepResult:
	game_over = true
	if result != StepResult.FILLED_BOARD:
		snake.mark_dead()
	_terminal_result = result
	return result

func current_tick_seconds() -> float:
	return rules.tick_seconds_for_length(snake.body.size())

func is_board_complete() -> bool:
	return _terminal_result == StepResult.FILLED_BOARD

func get_round_result() -> StepResult:
	return _terminal_result

func foods_until_next_pit() -> int:
	return rules.foods_per_pit - foods_eaten % rules.foods_per_pit

func is_cell_occupied(cell: Vector2i) -> bool:
	return cell in snake.body

func is_cell_blocked(cell: Vector2i) -> bool:
	return cell in obstacle_cells

func _choose_food_cell() -> Vector2i:
	# Without walls, the entire board is connected.
	if obstacle_cells.is_empty():
		return board.choose_available_cell(snake.body, _random)

	var occupied := snake.body.duplicate()
	occupied.append_array(obstacle_cells)
	var candidates := board.available_cells(occupied)
	if candidates.is_empty():
		return Vector2i(-1, -1)

	var reachable_candidates := _reachable_food_candidates(candidates)
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

	var next_cell := snake.next_head_cell()
	var nearby := _cells_near_snake()
	var top_row_by_column: Dictionary[int, int] = {}
	for segment in snake.body:
		top_row_by_column[segment.x] = mini(top_row_by_column.get(segment.x, board.size.y), segment.y)
	var preferred: Array[Vector2i] = []
	var not_near: Array[Vector2i] = []
	for cell in candidates:
		if cell == next_cell or nearby.has(cell):
			continue
		not_near.append(cell)
		if cell.y <= top_row_by_column.get(cell.x, board.size.y):
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

func _cells_near_snake() -> Dictionary[Vector2i, bool]:
	# Expand one Manhattan-distance ring at a time from the whole snake.
	# Pits do not block distance, so every board cell is visited at most once.
	var nearby: Dictionary[Vector2i, bool] = {}
	var frontier: Array[Vector2i] = snake.body.duplicate()
	for segment in frontier:
		nearby[segment] = true
	var first := 0
	for _distance in range(1, rules.pit_safe_distance_cells):
		var end := frontier.size()
		if first == end:
			break
		for index in range(first, end):
			for direction in SnakeState.CARDINAL_DIRECTIONS:
				var next := frontier[index] + direction
				if not nearby.has(next) and board.contains(next):
					nearby[next] = true
					frontier.append(next)
		first = end
	return nearby

func _reachable_food_candidates(candidates: Array[Vector2i]) -> Array[Vector2i]:
	# The blocked border lets the flood fill check each neighbor with one lookup.
	var stride := board.size.y + 2
	var last_column := (board.size.x + 1) * stride
	var visits := PackedByteArray()
	visits.resize(last_column + stride)
	for y in stride:
		visits[y] = CellVisit.BLOCKED
		visits[last_column + y] = CellVisit.BLOCKED
	for column in range(stride, last_column, stride):
		visits[column] = CellVisit.BLOCKED
		visits[column + stride - 1] = CellVisit.BLOCKED
	for cell in obstacle_cells:
		if board.contains(cell):
			visits[_padded_cell_index(cell, stride)] = CellVisit.BLOCKED

	var start := _padded_cell_index(snake.body[0], stride)
	visits[start] = CellVisit.REACHABLE
	var frontier: Array[int] = [start]
	var neighbor_offsets: Array[int] = [-stride, -1, 1, stride]
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		for offset in neighbor_offsets:
			var next := current + offset
			if visits[next] == CellVisit.UNVISITED:
				visits[next] = CellVisit.REACHABLE
				frontier.append(next)

	# Keep the board's original column order for deterministic random selection.
	var reachable: Array[Vector2i] = []
	for cell in candidates:
		if visits[_padded_cell_index(cell, stride)] == CellVisit.REACHABLE:
			reachable.append(cell)
	return reachable

func _padded_cell_index(cell: Vector2i, stride: int) -> int:
	return (cell.x + 1) * stride + cell.y + 1
