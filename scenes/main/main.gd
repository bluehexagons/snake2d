extends Node2D

const Snake = preload("res://scenes/snake/snake.tscn")
const Food = preload("res://scenes/food/food.tscn")

const GRID_SIZE = 32
var snake
var food
var tail_segments = []
var tail_positions = []
var game_over = false

func _ready():
	snake = Snake.instantiate()
	add_child(snake)
	snake.position = Vector2(5, 5) * GRID_SIZE
	snake.moved.connect(_on_snake_moved)
	snake.grew.connect(_on_snake_grew)
	snake.died.connect(_on_game_over)
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

func _on_snake_moved(new_position):
	if game_over:
		return
		
	# Check tail collision
	for segment in tail_segments:
		if segment.position == new_position:
			_on_game_over()
			return
	
	tail_positions.insert(0, new_position)
	
	# Move tail
	for i in tail_segments.size():
		tail_segments[i].position = tail_positions[i + 1]
	
	# Remove excess positions
	if tail_positions.size() > tail_segments.size() + 1:
		tail_positions.pop_back()

func _on_snake_grew():
	var segment = ColorRect.new()
	segment.size = Vector2(GRID_SIZE, GRID_SIZE)
	segment.color = Color(0.0862745, 0.741176, 0.0862745, 1)
	
	# Position the new segment
	if tail_segments.size() > 0:
		segment.position = tail_positions[-1]
	else:
		segment.position = tail_positions[0]
	
	add_child(segment)
	tail_segments.append(segment)
	spawn_food()

func _on_game_over():
	game_over = true
	# Optional: Add visual feedback
	snake.modulate = Color.RED
	
	# Optional: Show game over message
	var label = Label.new()
	label.text = "Game Over!\nPress R to restart"
	label.position = Vector2(576, 324)  # Center of screen
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)

func _process(_delta):
	if game_over and Input.is_action_just_pressed("retry"):  # R key
		get_tree().reload_current_scene()

func _on_timer_timeout():
	if game_over:
		return
	snake.can_move = false
	snake.move()
	
	# Check if snake ate food
	if snake.position == food.position:
		snake.grow()
		spawn_food()
