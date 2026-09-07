extends SceneTree

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
	var audio := AudioService.new()
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
	gameplay.cleanup()
	await process_frame
	check.expect_false(is_instance_valid(consumed), "cleanup retires owned food even during its eat animation")
	check.expect_true(is_instance_valid(decoration), "cleanup leaves unrelated food-like siblings alone")
	gameplay.start_game()
	await process_frame
	check.expect_true(is_instance_valid(decoration), "starting a round also preserves unrelated siblings")
	world.free()
	check.finish(self, "Presentation test")
