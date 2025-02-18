extends Control

const Snake = preload("res://scenes/snake/snake.tscn")
const Food = preload("res://scenes/food/food.tscn")

const GRID_SIZE = 32
const GRID_WIDTH = 24  # 768/32
const GRID_HEIGHT = 18  # 576/32
const GAME_WIDTH = GRID_WIDTH * GRID_SIZE
const GAME_HEIGHT = GRID_HEIGHT * GRID_SIZE

var game_world: Node2D
var snake
var food
var tail_segments = []
var tail_positions = []
var game_over = false
var score = 0
var score_label: Label
var camera: Camera2D

func _ready():
	get_tree().root.size_changed.connect(_on_window_resize)
	_on_window_resize()
	
	game_world = $GameViewport/SubViewport/GameWorld
	
	# Remove score label creation since it's now in the scene tree
	score_label = $UILayer/ScoreLabel
	
	snake = Snake.instantiate()
	game_world.add_child(snake)
	snake.position = Vector2(GRID_WIDTH/2, GRID_HEIGHT/2) * GRID_SIZE
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
	
	camera = $GameViewport/SubViewport/GameWorld/Camera2D
	camera.position = snake.position

func spawn_food():
	if food:
		food.queue_free()
	food = Food.instantiate()
	game_world.add_child(food)
	
	# Random position within the playable grid
	var x = randi_range(0, GRID_WIDTH - 2)  # -2 to account for food size
	var y = randi_range(0, GRID_HEIGHT - 2)
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
	
	game_world.add_child(segment)  # Changed from add_child to game_world.add_child
	tail_segments.append(segment)
	spawn_food()
	
	# Update score
	score += 10
	score_label.text = "Score: " + str(score)

func _on_game_over():
	game_over = true
	snake.modulate = Color.RED
	
	# Update game over UI
	$UILayer/GameOverContainer.visible = true
	$UILayer/GameOverContainer/GameOverLabel.text = "Game Over!\nFinal Score: " + str(score) + "\nPress R to restart"

func _process(_delta):
	if not game_over:
		# Update camera position with smooth follow
		var target = snake.position
		camera.position = camera.position.lerp(target, 0.005)
	
	if game_over and Input.is_action_just_pressed("retry"):
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

func _on_window_resize():
	var viewport = $GameViewport/SubViewport
	viewport.size = DisplayServer.window_get_size()
	$GameViewport.custom_minimum_size = Vector2(GAME_WIDTH, GAME_HEIGHT)
	$GameViewport.size = viewport.size
	$GameViewport/SubViewport.size = Vector2i(GAME_WIDTH, GAME_HEIGHT)
