class_name SnakeGame
extends RefCounted

## Deterministic Snake rules. Presentation advances this model one grid tick at a time.

enum StepResult {
	WAITING_FOR_INPUT,
	MOVED,
	ATE_FOOD,
	HIT_WALL,
	HIT_SELF,
	FILLED_BOARD,
}

var rules: GameRules
var board: GridBoard
var snake := SnakeState.new()
var food_cell := Vector2i(-1, -1)
var score := 0
var game_over := false
var tick_count := 0

var _random: RandomNumberGenerator

func _init(game_rules: GameRules, random: RandomNumberGenerator) -> void:
	rules = game_rules
	_random = random
	board = GridBoard.new(rules.board_size_cells())

func reset() -> void:
	score = 0
	game_over = false
	tick_count = 0
	snake.reset(Vector2i(board.size.x / 2, board.size.y / 2))
	food_cell = board.choose_available_cell(snake.body, _random)

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

	var ate_food := next_head == food_cell
	if snake.would_hit_self(next_head, ate_food):
		snake.mark_dead()
		game_over = true
		return StepResult.HIT_SELF

	snake.advance(next_head, ate_food)
	if not ate_food:
		return StepResult.MOVED

	score += rules.points_per_food
	food_cell = board.choose_available_cell(snake.body, _random)
	if food_cell == Vector2i(-1, -1):
		game_over = true
		return StepResult.FILLED_BOARD
	return StepResult.ATE_FOOD

func current_tick_seconds() -> float:
	return rules.tick_seconds_for_length(snake.body.size())

func is_cell_occupied(cell: Vector2i) -> bool:
	return cell in snake.body
