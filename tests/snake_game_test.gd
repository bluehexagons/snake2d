extends SceneTree

var check := TestAssertions.new()

func _initialize() -> void:
	_a_snake_waits_for_its_first_direction()
	_only_one_turn_is_queued_per_tick()
	_a_snake_dies_at_the_board_boundary()
	_a_snake_dies_when_it_hits_its_body()
	_the_departing_tail_cell_is_legal()
	_food_is_deterministic_and_never_occupies_the_snake()
	_pitfall_adds_safely_placed_pits_on_schedule()
	_obstacle_worlds_are_seeded_and_protect_the_spawn()
	_colliding_with_an_obstacle_ends_the_round()
	_eating_updates_score_length_and_speed()
	_speed_progress_tracks_the_configured_tick_range()
	_filling_the_board_completes_the_round()
	_reset_restores_initial_state()
	check.finish(self, "Snake game model test")

func _a_snake_waits_for_its_first_direction() -> void:
	var game := _new_game(Vector2i(5, 5), 1)
	check.expect_equal(
		game.step(),
		SnakeGame.StepResult.WAITING_FOR_INPUT,
		"a snake waits for its first direction"
	)

func _only_one_turn_is_queued_per_tick() -> void:
	var game := _new_game(Vector2i(5, 5), 2)
	check.expect_true(game.request_direction(Vector2i.UP), "the first turn before a tick is accepted")
	check.expect_false(game.request_direction(Vector2i.LEFT), "a second turn before the same tick is rejected")
	game.step()
	check.expect_equal(game.snake.direction, Vector2i.UP, "the accepted direction is committed on the tick")
	check.expect_false(game.request_direction(Vector2i.DOWN), "a direct reversal is rejected")

func _a_snake_dies_at_the_board_boundary() -> void:
	var game := _new_game(Vector2i(3, 3), 3)
	game.request_direction(Vector2i.RIGHT)
	check.expect_equal(game.step(), SnakeGame.StepResult.MOVED, "the snake reaches the final in-bounds cell")
	check.expect_equal(game.step(), SnakeGame.StepResult.HIT_WALL, "the next cell beyond the board hits a wall")

func _a_snake_dies_when_it_hits_its_body() -> void:
	var game := _new_game(Vector2i(4, 4), 4)
	game.snake.body.assign([
		Vector2i(1, 1),
		Vector2i(1, 2),
		Vector2i(0, 2),
		Vector2i(0, 1),
	])
	game.snake.waiting_for_input = false
	game.snake.queued_direction = Vector2i.DOWN
	game.food_cell = Vector2i(3, 3)
	check.expect_equal(game.step(), SnakeGame.StepResult.HIT_SELF, "moving into a body cell causes self-collision")

func _the_departing_tail_cell_is_legal() -> void:
	var game := _new_game(Vector2i(4, 4), 5)
	game.snake.body.assign([
		Vector2i(1, 1),
		Vector2i(1, 2),
		Vector2i(0, 2),
		Vector2i(0, 1),
	])
	game.snake.waiting_for_input = false
	game.snake.queued_direction = Vector2i.LEFT
	game.food_cell = Vector2i(3, 3)
	check.expect_equal(game.step(), SnakeGame.StepResult.MOVED, "moving into the departing tail cell is legal")

func _food_is_deterministic_and_never_occupies_the_snake() -> void:
	var first := _new_game(Vector2i(6, 6), 12345)
	var second := _new_game(Vector2i(6, 6), 12345)
	check.expect_equal(first.food_cell, second.food_cell, "equal seeds choose equal food cells")
	check.expect_false(first.is_cell_occupied(first.food_cell), "food never starts on the snake")

func _pitfall_adds_safely_placed_pits_on_schedule() -> void:
	var rules := GameRules.new()
	rules.columns = 11
	rules.rows = 11
	rules.foods_per_pit = 1
	rules.pit_safe_distance_cells = 3
	var random := RandomNumberGenerator.new()
	random.seed = 90210
	var game := SnakeGame.new(rules, random, GameMode.Value.PITFALL)
	game.reset()
	game.food_cell = game.snake.body[0] + Vector2i.RIGHT
	game.request_direction(Vector2i.RIGHT)
	check.expect_equal(game.step(), SnakeGame.StepResult.ATE_FOOD, "Pitfall still awards eaten food")
	check.expect_equal(game.obstacle_cells.size(), 1, "Pitfall adds one pit at the configured cadence")
	var pit := game.obstacle_cells[0]
	var projected_next := game.snake.body[0] + game.snake.direction
	check.expect_false(pit == projected_next, "a pit is not placed directly ahead of the snake")
	for segment in game.snake.body:
		var distance := absi(pit.x - segment.x) + absi(pit.y - segment.y)
		check.expect_true(distance >= rules.pit_safe_distance_cells, "a pit keeps its safe distance")
		check.expect_false(pit.x == segment.x and pit.y > segment.y, "a pit avoids cells below the snake")

func _obstacle_worlds_are_seeded_and_protect_the_spawn() -> void:
	var first := _new_game(Vector2i(23, 18), 11, GameMode.Value.OBSTACLES, 777)
	var second := _new_game(Vector2i(23, 18), 99, GameMode.Value.OBSTACLES, 777)
	check.expect_equal(first.obstacle_pattern_name, second.obstacle_pattern_name, "equal world seeds choose equal patterns")
	check.expect_equal(first.obstacle_cells, second.obstacle_cells, "equal world seeds create equal wall cells")
	check.expect_true(not first.obstacle_cells.is_empty(), "an obstacle world starts with walls")
	var spawn := first.snake.body[0]
	for cell in first.obstacle_cells:
		var distance := absi(cell.x - spawn.x) + absi(cell.y - spawn.y)
		check.expect_true(distance > 2, "seeded walls protect the snake's spawn area")
	check.expect_false(first.food_cell in first.obstacle_cells, "food never spawns inside a wall")

func _colliding_with_an_obstacle_ends_the_round() -> void:
	var game := _new_game(Vector2i(7, 7), 12)
	var collision_cell := game.snake.body[0] + Vector2i.RIGHT
	game.obstacle_cells.assign([collision_cell])
	game.food_cell = Vector2i.ZERO
	game.request_direction(Vector2i.RIGHT)
	check.expect_equal(game.step(), SnakeGame.StepResult.HIT_OBSTACLE, "entering a blocked cell hits an obstacle")
	check.expect_true(game.game_over, "an obstacle collision ends the round")

func _eating_updates_score_length_and_speed() -> void:
	var game := _new_game(Vector2i(5, 5), 6)
	game.food_cell = game.snake.body[0] + Vector2i.RIGHT
	game.request_direction(Vector2i.RIGHT)
	check.expect_equal(game.step(), SnakeGame.StepResult.ATE_FOOD, "entering the food cell eats the food")
	check.expect_equal(game.score, game.rules.points_per_food, "eating awards the configured score")
	check.expect_equal(game.snake.body.size(), 2, "eating grows the snake by one cell")
	check.expect_true(
		game.current_tick_seconds() < game.rules.initial_tick_seconds,
		"eating decreases the tick duration"
	)
	check.expect_false(game.is_cell_occupied(game.food_cell), "respawned food avoids the grown snake")

func _speed_progress_tracks_the_configured_tick_range() -> void:
	var rules := GameRules.new()
	check.expect_true(
		is_zero_approx(rules.speed_progress_for_length(1)),
		"speed progress starts at zero"
	)
	check.expect_true(
		is_equal_approx(rules.speed_progress_for_length(16), 0.5),
		"speed progress reaches one half after half the configured acceleration"
	)
	check.expect_true(
		is_equal_approx(rules.speed_progress_for_length(31), 1.0),
		"speed progress reaches one at the minimum tick duration"
	)
	check.expect_true(
		is_equal_approx(rules.speed_progress_for_length(1000), 1.0),
		"speed progress remains clamped after reaching maximum speed"
	)

func _filling_the_board_completes_the_round() -> void:
	var game := _new_game(Vector2i(2, 1), 7)
	game.food_cell = Vector2i(0, 0)
	game.request_direction(Vector2i.LEFT)
	check.expect_equal(game.step(), SnakeGame.StepResult.FILLED_BOARD, "eating the final free cell fills the board")
	check.expect_true(game.game_over, "a full board completes the round")

func _reset_restores_initial_state() -> void:
	var game := _new_game(Vector2i(5, 5), 8)
	game.food_cell = game.snake.body[0] + Vector2i.RIGHT
	game.request_direction(Vector2i.RIGHT)
	game.step()
	game.reset()
	check.expect_equal(game.score, 0, "reset clears score")
	check.expect_equal(game.snake.body.size(), 1, "reset restores one body cell")
	check.expect_true(game.snake.waiting_for_input, "reset waits for fresh input")
	check.expect_false(game.game_over, "reset clears game-over state")

func _new_game(
	board_size: Vector2i,
	seed_value: int,
	mode: GameMode.Value = GameMode.Value.CLASSIC,
	world_seed: int = 0
) -> SnakeGame:
	var rules := GameRules.new()
	rules.columns = board_size.x
	rules.rows = board_size.y
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var game := SnakeGame.new(rules, random, mode, world_seed)
	game.reset()
	return game
