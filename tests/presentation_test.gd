extends SceneTree

class RecordingAudio extends AudioService:
	var moves := 0
	var meals := 0
	var collisions := 0

	func play_move(_speed_progress: float) -> void:
		moves += 1

	func play_eat() -> void:
		meals += 1

	func play_die() -> void:
		collisions += 1

var check := TestAssertions.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var food := FoodView.new()
	world.add_child(food)
	var spawn: Tween = food.get("_animation")
	spawn.custom_step(0.05)
	var eating := food.eat()
	check.expect_false(spawn.is_valid(), "eating cancels the unfinished spawn animation")
	check.expect_equal(food.eat(), eating, "repeated eating returns the same completion tween")
	eating.custom_step(FoodView.EAT_DURATION + 0.01)
	await process_frame
	check.expect_false(is_instance_valid(food), "consumed food retires after its animation")

	var gameplay := Gameplay.new()
	var audio := RecordingAudio.new()
	world.add_child(gameplay)
	world.add_child(audio)
	gameplay.configure(GameRules.new(), audio)
	var decoration := FoodView.new()
	world.add_child(decoration)
	gameplay.start_game()
	gameplay.model.food_cell = gameplay.model.snake.body[0] + Vector2i.RIGHT
	var consumed := gameplay.food
	gameplay.request_direction(Vector2i.RIGHT)
	gameplay.advance_one_tick()
	check.expect_equal(audio.meals, 1, "an eating tick plays the food cue")
	check.expect_equal(audio.moves, 0, "an eating tick leaves the food cue clear of a movement tone")
	gameplay.cleanup()
	await process_frame
	check.expect_false(is_instance_valid(consumed), "cleanup retires owned food even during its eat animation")
	check.expect_true(is_instance_valid(decoration), "cleanup leaves unrelated food-like siblings alone")
	gameplay.start_game()
	await process_frame
	check.expect_true(is_instance_valid(decoration), "starting a round also preserves unrelated siblings")
	_expect_collision_settles_movement(gameplay, audio)
	world.free()
	check.finish(self, "Presentation test")

func _expect_collision_settles_movement(gameplay: Gameplay, audio: RecordingAudio) -> void:
	var rules := GameRules.new()
	rules.columns = 4
	rules.rows = 4
	gameplay.configure(rules, audio)
	gameplay.start_game()
	gameplay.model.snake.body.append(Vector2i(1, 2))
	gameplay.model.food_cell = Vector2i.ZERO
	gameplay.request_direction(Vector2i.RIGHT)
	check.expect_equal(gameplay.advance_one_tick(), SnakeGame.StepResult.MOVED, "the snake reaches the board edge")
	check.expect_equal(audio.moves, 1, "an ordinary move plays one movement cue")
	gameplay.time_since_tick = gameplay.model.current_tick_seconds() * 0.5
	gameplay._apply_visual_interpolation()
	var head := gameplay.snake
	var retracting_tail := gameplay.tail_segments[gameplay.tail_retraction_index]
	check.expect_true(head.position != head.logical_position, "the previous move is still interpolating")
	check.expect_true(retracting_tail.visible, "the old tail is still retracting")
	check.expect_equal(gameplay.advance_one_tick(), SnakeGame.StepResult.HIT_WALL, "the next step collides")
	check.expect_equal(audio.collisions, 1, "the collision plays the death cue")
	check.expect_equal(audio.moves, 1, "the collision adds no movement cue")
	check.expect_equal(head.position, head.logical_position, "the dead head settles into its last valid cell")
	check.expect_false(retracting_tail.visible, "collision finishes the previous tail retraction")
