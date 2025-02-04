extends Node2D

const Snake = preload("res://scenes/snake/snake.tscn")
const Food = preload("res://scenes/food/food.tscn")

const GRID_SIZE = 32
var snake
var food

func _ready():
	snake = Snake.instantiate()
	add_child(snake)
	snake.position = Vector2(5, 5) * GRID_SIZE
	spawn_food()
	
	# Start the game timer
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.2
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func spawn_food():
	if food:
		food.queue_free()
	food = Food.instantiate()
	add_child(food)
	
	# Random position within the grid
	var x = randi_range(0, (1152 / GRID_SIZE) - 1)
	var y = randi_range(0, (648 / GRID_SIZE) - 1)
	food.position = Vector2(x, y) * GRID_SIZE

func _on_timer_timeout():
	snake.can_move = false
	snake.move()
	
	# Check if snake ate food
	if snake.position == food.position:
		spawn_food()
