extends Control

const Snake = preload("res://scenes/snake/snake.tscn")
const Food = preload("res://scenes/food/food.tscn")

const GRID_SIZE = 32
const GRID_WIDTH = 24  # 768/32
const GRID_HEIGHT = 18  # 576/32
const GAME_WIDTH = GRID_WIDTH * GRID_SIZE
const GAME_HEIGHT = GRID_HEIGHT * GRID_SIZE

const BASE_TIMER_WAIT = 0.2
const MIN_TIMER_WAIT = 0.07  # Maximum speed
const SPEED_INCREASE_PER_SEGMENT = 0.005  # How much faster per segment

var game_world: Node2D
var snake
var food
var tail_segments = []
var tail_positions = []
var game_over = false
var score = 0
var score_label: Label
var camera: Camera2D
var paused = false
var high_score = 0
var in_game = false
var game_timer: Timer = null

func _ready():
	set_process_mode(Node.PROCESS_MODE_ALWAYS)  # Allow this node to process while paused
	get_tree().root.size_changed.connect(_on_window_resize)
	_on_window_resize()
	
	# Load high score
	if FileAccess.file_exists("user://highscore.dat"):
		var file = FileAccess.open("user://highscore.dat", FileAccess.READ)
		high_score = file.get_32()
	
	# Connect main menu buttons
	var main_menu = $UILayer/MainMenu
	main_menu.get_node("VBoxContainer/StartButton").pressed.connect(_on_start_pressed)
	main_menu.get_node("VBoxContainer/ScoresButton").pressed.connect(_on_scores_pressed)
	main_menu.get_node("VBoxContainer/QuitButton").pressed.connect(_on_quit_game_pressed)
	
	# Connect pause menu buttons
	var pause_menu = $UILayer/PauseMenu
	pause_menu.get_node("VBoxContainer/ResumeButton").pressed.connect(_on_resume_pressed)
	pause_menu.get_node("VBoxContainer/QuitButton").pressed.connect(_on_quit_to_menu_pressed)
	
	# Connect game over buttons
	var game_over_menu = $UILayer/GameOverContainer/VBoxContainer
	game_over_menu.get_node("RestartButton").pressed.connect(_on_restart_pressed)
	game_over_menu.get_node("QuitButton").pressed.connect(_on_quit_to_menu_pressed)
	
	# Start in menu state
	get_tree().paused = true
	$UIBackground.visible = true
	$UILayer/MainMenu.visible = true
	$UILayer/ScoreLabel.visible = false
	$GameViewport/SubViewport/GameWorld.visible = false

func _on_start_pressed():
	get_tree().paused = false
	$UIBackground.visible = false
	$UILayer/MainMenu.visible = false
	$UILayer/ScoreLabel.visible = true
	$GameViewport/SubViewport/GameWorld.visible = true
	_start_game()

func _start_game():
	in_game = true
	score = 0
	score_label = $UILayer/ScoreLabel  # Move this here
	score_label.text = "Score: 0"
	
	# Initialize game elements
	game_world = $GameViewport/SubViewport/GameWorld
	snake = Snake.instantiate()
	snake.process_mode = Node.PROCESS_MODE_INHERIT
	game_world.add_child(snake)
	snake.position = Vector2(GRID_WIDTH/2, GRID_HEIGHT/2) * GRID_SIZE
	snake.moved.connect(_on_snake_moved)
	snake.grew.connect(_on_snake_grew)
	snake.died.connect(_on_game_over)
	spawn_food()
	
	# Start the game timer
	game_timer = Timer.new()
	add_child(game_timer)
	game_timer.wait_time = BASE_TIMER_WAIT
	game_timer.timeout.connect(_on_timer_timeout)
	game_timer.start()
	
	camera = $GameViewport/SubViewport/GameWorld/Camera2D
	camera.position = snake.position

func _update_game_speed():
	if game_timer:
		var segment_count = tail_segments.size()
		var new_wait = max(
			BASE_TIMER_WAIT - (segment_count * SPEED_INCREASE_PER_SEGMENT),
			MIN_TIMER_WAIT
		)
		game_timer.wait_time = new_wait

func _on_scores_pressed():
	$UILayer/MainMenu/VBoxContainer/Title.text = "HIGH SCORE\n" + str(high_score)

func _on_quit_game_pressed():
	get_tree().quit()

func _on_quit_to_menu_pressed():
	_cleanup_game()
	get_tree().paused = true
	$UIBackground.visible = true
	$UILayer/MainMenu.visible = true
	$UILayer/PauseMenu.visible = false
	$UILayer/ScoreLabel.visible = false
	$GameViewport/SubViewport/GameWorld.visible = false

func _cleanup_game():
	# Clean up game objects
	if snake:
		snake.queue_free()
		snake = null
	if food:
		food.queue_free()
		food = null
	for segment in tail_segments:
		segment.queue_free()
	tail_segments.clear()
	tail_positions.clear()
	
	# Clean up timer
	if game_timer:
		game_timer.stop()
		game_timer.queue_free()
		game_timer = null
	
	# Reset game state
	game_over = false
	in_game = false
	
	# Reset UI
	$UILayer/GameOverContainer.visible = false
	$UILayer/PauseMenu.visible = false

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
	
	# Vary the color based on position in tail
	var base_color = Color(0.0862745, 0.741176, 0.0862745)
	var segment_count = tail_segments.size()
	
	if segment_count == 0:
		# First segment should be slightly darker than base
		segment.color = base_color.darkened(0.1)
	else:
		# Gradually lighten towards the tail end
		var progress = float(segment_count) / 20.0  # Max variation at length 20
		var hue_shift = randf_range(-0.02, 0.02)  # Subtle random hue variation
		var new_color = base_color.lightened(progress * 0.3)  # Gradual lightening
		new_color = new_color.from_hsv(
			fmod(new_color.h + hue_shift, 1.0),  # Shift hue slightly
			new_color.s,
			new_color.v
		)
		segment.color = new_color
	
	# Position the new segment
	if tail_segments.size() > 0:
		segment.position = tail_positions[-1]
	else:
		segment.position = tail_positions[0]
	
	game_world.add_child(segment)
	tail_segments.append(segment)
	spawn_food()
	
	# Update game speed
	_update_game_speed()
	
	# Update score
	score += 10
	score_label.text = "Score: " + str(score)

func _on_game_over():
	if score > high_score:
		high_score = score
		var file = FileAccess.open("user://highscore.dat", FileAccess.WRITE)
		file.store_32(high_score)
	
	game_over = true
	snake.modulate = Color.RED
	
	# Update game over UI and background
	$UIBackground.visible = true
	$UILayer/GameOverContainer.visible = true
	$UILayer/GameOverContainer/VBoxContainer/ScoreLabel.text = "Final Score: " + str(score)

func _on_restart_pressed():
	$UIBackground.visible = false
	$UILayer/GameOverContainer.visible = false
	_cleanup_game()
	_start_game()

func _process(_delta):
	# Handle pause input regardless of game state
	if in_game and not game_over and Input.is_action_just_pressed("pause"):
		if paused:
			_on_resume_pressed()
		else:
			_toggle_pause()
	
	# Only update game logic when not paused
	if in_game and not game_over and not paused:
		# Update camera position with smooth follow
		var target = snake.position
		camera.position = camera.position.lerp(target, 0.005)
	
	if game_over and Input.is_action_just_pressed("retry"):
		_on_restart_pressed()

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

func _toggle_pause():
	paused = !paused
	get_tree().paused = paused
	
	# Explicitly pause/unpause game elements
	if game_timer:
		game_timer.paused = paused
	if snake:
		snake.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	
	# Update UI
	$UIBackground.visible = paused
	$UILayer/PauseMenu.visible = paused

func _on_resume_pressed():
	_toggle_pause()

func _on_quit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
