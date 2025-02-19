extends Control

const Snake = preload("res://scenes/snake/snake.tscn")
const Food = preload("res://scenes/food/food.tscn")

const GRID_SIZE = 32
const GRID_WIDTH = 24
const GRID_HEIGHT = 18
const GAME_WIDTH = GRID_WIDTH * GRID_SIZE
const GAME_HEIGHT = GRID_HEIGHT * GRID_SIZE

const BASE_TIMER_WAIT = 0.2
const MIN_TIMER_WAIT = 0.05  # Maximum speed
const SPEED_INCREASE_PER_SEGMENT = 0.005  # How much faster per segment

const CAMERA_LOOK_AHEAD = 1.2
const CAMERA_SMOOTHING = 0.015
const CENTER_PULL_WEIGHT = 0.4
const FOOD_ATTRACTION_WEIGHT = 0.35
const LOOK_AHEAD_WEIGHT = 0.25
const SNAKE_CENTER_WEIGHT = 0.2
const CAMERA_DAMPING = 0.95
const CAMERA_ACCELERATION = 0.01

const MAX_HIGH_SCORES = 10
var high_scores: Array[int] = []

var camera_velocity = Vector2.ZERO

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

# Platform detection for mobile UI
var is_mobile = false

func _ready():
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	get_tree().root.size_changed.connect(_on_window_resize)
	_on_window_resize()
	
	# Check platform
	is_mobile = DisplayServer.get_name() in ["android", "ios", "web"]
	
	# Load high scores
	if FileAccess.file_exists("user://highscore.dat"):
		var file = FileAccess.open("user://highscore.dat", FileAccess.READ)
		while not file.eof_reached():
			var val = file.get_32()
			if val > 0:
				high_scores.append(val)
	
	high_scores.sort_custom(func(a, b): return a > b)  # Sort descending
	high_score = high_scores[0] if not high_scores.is_empty() else 0
	
	# Connect main menu buttons
	var main_menu = $UILayer/MainMenu
	var start_button = main_menu.get_node("VBoxContainer/StartButton")
	start_button.pressed.connect(_on_start_pressed)
	start_button.button_down.connect(AudioManager.play_click)
	
	var scores_button = main_menu.get_node("VBoxContainer/ScoresButton")
	scores_button.pressed.connect(_on_scores_pressed)
	scores_button.button_down.connect(AudioManager.play_click)
	
	var quit_button = main_menu.get_node("VBoxContainer/QuitButton")
	quit_button.pressed.connect(_on_quit_game_pressed)
	quit_button.button_down.connect(AudioManager.play_click)
	
	# Connect sound toggle buttons
	var main_sound_button = main_menu.get_node("VBoxContainer/SoundButton")
	main_sound_button.pressed.connect(_on_sound_toggled)
	
	# Connect pause menu buttons
	var pause_menu = $UILayer/PauseMenu
	var resume_button = pause_menu.get_node("VBoxContainer/ResumeButton")
	resume_button.pressed.connect(_on_resume_pressed)
	resume_button.button_down.connect(AudioManager.play_click)
	
	var pause_quit = pause_menu.get_node("VBoxContainer/QuitButton")
	pause_quit.pressed.connect(_on_quit_to_menu_pressed)
	pause_quit.button_down.connect(AudioManager.play_click)
	
	var pause_sound_button = pause_menu.get_node("VBoxContainer/SoundButton")
	pause_sound_button.pressed.connect(_on_sound_toggled)
	
	# Connect game over buttons
	var game_over_menu = $UILayer/GameOverContainer/VBoxContainer
	var restart_button = game_over_menu.get_node("RestartButton")
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.button_down.connect(AudioManager.play_click)
	
	var gameover_quit = game_over_menu.get_node("QuitButton")
	gameover_quit.pressed.connect(_on_quit_to_menu_pressed)
	gameover_quit.button_down.connect(AudioManager.play_click)
	
	# Set initial sound button states
	_update_sound_buttons()
	
	# Start in menu state
	get_tree().paused = true
	$UIBackground.visible = true
	$UILayer/MainMenu.visible = true
	$UILayer/ScoreLabel.visible = false
	$GameViewport/SubViewport/GameWorld.visible = false

	_update_scores_display(false)  # Initialize scores display
	
	# Connect focus sounds to all buttons
	for button in _get_all_buttons():
		button.focus_entered.connect(AudioManager.play_focus)
	
	# Set initial focus
	_update_menu_focus()

func _get_all_buttons() -> Array:
	var buttons = []
	buttons.append_array($UILayer/MainMenu/VBoxContainer.get_children().filter(func(n): return n is Button))
	buttons.append_array($UILayer/PauseMenu/VBoxContainer.get_children().filter(func(n): return n is Button))
	buttons.append_array($UILayer/GameOverContainer/VBoxContainer.get_children().filter(func(n): return n is Button))
	return buttons

func _update_menu_focus():
	if $UILayer/MainMenu.visible:
		$UILayer/MainMenu/VBoxContainer/StartButton.grab_focus()
	elif $UILayer/PauseMenu.visible:
		$UILayer/PauseMenu/VBoxContainer/ResumeButton.grab_focus()
	elif $UILayer/GameOverContainer.visible:
		$UILayer/GameOverContainer/VBoxContainer/RestartButton.grab_focus()

func _on_start_pressed():
	get_tree().paused = false
	$UIBackground.visible = false
	$UILayer/MainMenu.visible = false
	$UILayer/ScoreLabel.visible = true
	$GameViewport/SubViewport/GameWorld.visible = true
	_start_game()
	_update_menu_focus()

func _start_game():
	_cleanup_game()

	in_game = true
	score = 0
	score_label = $UILayer/ScoreLabel
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
	camera_velocity = Vector2.ZERO
	AudioManager.reset_pitch()
	
	get_tree().paused = false
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _update_game_speed():
	if game_timer:
		var segment_count = tail_segments.size()
		var new_wait = max(
			BASE_TIMER_WAIT - (segment_count * SPEED_INCREASE_PER_SEGMENT),
			MIN_TIMER_WAIT
		)
		game_timer.wait_time = new_wait

func _on_scores_pressed():
	_update_scores_display(true)

func _update_scores_display(show_container: bool):
	var title_label = $UILayer/MainMenu/VBoxContainer/TitleLabel
	var scores_container = $UILayer/MainMenu/VBoxContainer/ScoresContainer
	var scores_list = $UILayer/MainMenu/VBoxContainer/ScoresContainer/ScrollContainer/ScoresList
	
	# Clear existing score labels
	for child in scores_list.get_children():
		child.queue_free()
	
	if show_container:
		title_label.text = "HIGH SCORES"
		scores_container.visible = true
		
		if high_scores.is_empty():
			var empty_label = Label.new()
			empty_label.text = "No scores yet!"
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			scores_list.add_child(empty_label)
		else:
			for i in high_scores.size():
				var score_label = Label.new()
				score_label.text = "%d. %d" % [i + 1, high_scores[i]]
				score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				scores_list.add_child(score_label)
	else:
		title_label.text = "A Simple Snake Game"
		scores_container.visible = false

func _on_quit_game_pressed():
	# Ensure mouse is free before showing dialog
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var dialog = ConfirmationDialog.new()
	dialog.title = "Quit Game"
	dialog.dialog_text = "Are you sure you want to quit?"
	dialog.confirmed.connect(get_tree().quit)
	add_child(dialog)
	dialog.popup_centered()

func _on_quit_to_menu_pressed():
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cleanup_game()
	get_tree().paused = true
	$UIBackground.visible = true
	$UILayer/MainMenu.visible = true
	$UILayer/PauseMenu.visible = false
	$UILayer/ScoreLabel.visible = false
	$GameViewport/SubViewport/GameWorld.visible = false
	_update_scores_display(false)
	_update_menu_focus()

func _cleanup_game():
	# Reset nodes
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
	
	if game_timer:
		game_timer.stop()
		game_timer.queue_free()
		game_timer = null
	
	# Reset game state
	game_over = false
	in_game = false
	paused = false
	
	# Reset UI
	$UILayer/GameOverContainer.visible = false
	$UILayer/PauseMenu.visible = false
	camera_velocity = Vector2.ZERO
	AudioManager.reset_pitch()
	
	# Return to normal mouse mode
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	get_tree().paused = paused

func is_position_occupied(pos: Vector2) -> bool:
	# Check snake head
	if snake and snake.position == pos:
		return true
	
	# Check tail segments
	for segment in tail_segments:
		if segment.position == pos:
			return true
	
	return false

func spawn_food():
	if food:
		food.queue_free()
	
	# Find an unoccupied position
	var valid_position = false
	var x = 0
	var y = 0
	
	while not valid_position:
		x = randi_range(0, GRID_WIDTH - 2)
		y = randi_range(0, GRID_HEIGHT - 2)
		var test_pos = Vector2(x, y) * GRID_SIZE
		valid_position = not is_position_occupied(test_pos)
	
	food = Food.instantiate()
	game_world.add_child(food)
	food.position = Vector2(x, y) * GRID_SIZE

func _on_snake_moved(new_position):
	if game_over:
		return
	
	AudioManager.play_move()
	
	# Store the current position for tail
	tail_positions.insert(0, new_position)
	
	# Check if snake ate food
	var ate_food = food and (new_position == food.position)
	if ate_food:
		snake.grow()
		# Don't remove the last tail position when growing
		spawn_food()
	else:
		# Only remove last position if we didn't eat food
		if tail_positions.size() > tail_segments.size() + 1:
			tail_positions.pop_back()
	
	# Move tail
	for i in tail_segments.size():
		tail_segments[i].position = tail_positions[i + 1]
	
	# Check tail collision
	if not ate_food:  # Don't check collision if we just ate (prevents false positives)
		for segment in tail_segments:
			if segment.position == new_position:
				_on_game_over()
				return

func _on_snake_grew():
	AudioManager.play_eat()
	
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
		var progress = float(segment_count) / 20.0
		var hue_shift = randf_range(-0.02, 0.02)
		var new_color = base_color.lightened(progress * 0.3)
		new_color = Color.from_hsv(
			fmod(new_color.h + hue_shift, 1.0),
			new_color.s,
			new_color.v
		)
		segment.color = new_color
	
	# Position the new segment at the food location
	segment.position = food.position
	
	game_world.add_child(segment)
	tail_segments.append(segment)
	
	# Update game speed
	_update_game_speed()
	
	# Update score
	score += 10
	score_label.text = "Score: " + str(score)

func _on_game_over():
	AudioManager.play_die()
	AudioManager.reset_pitch()
	
	# Update high scores
	var score_inserted = false
	for i in high_scores.size():
		if score > high_scores[i]:
			high_scores.insert(i, score)
			score_inserted = true
			break
	
	if not score_inserted and high_scores.size() < MAX_HIGH_SCORES:
		high_scores.append(score)
	
	if high_scores.size() > MAX_HIGH_SCORES:
		high_scores.resize(MAX_HIGH_SCORES)
	
	# Save all scores
	var file = FileAccess.open("user://highscore.dat", FileAccess.WRITE)
	for score_value in high_scores:
		file.store_32(score_value)
	
	high_score = high_scores[0] if not high_scores.is_empty() else 0
	
	game_over = true
	
	# Change snake head color
	var head = snake.get_node("Head")
	if head:
		head.color = Color(0.8, 0.2, 0.2, 1)
	
	# Change tail segment colors to reddish versions of their current colors
	for segment in tail_segments:
		var current_color = segment.color
		segment.color = Color(
			lerp(current_color.g, 0.8, 0.5),
			current_color.r * 0.1,
			current_color.b * 0.1,
			current_color.a
		)
	
	# Update game over UI and background
	$UIBackground.visible = true
	$UILayer/GameOverContainer.visible = true
	$UILayer/GameOverContainer/VBoxContainer/ScoreLabel.text = "Final Score: " + str(score)
	_update_menu_focus()

func _on_restart_pressed():
	$UIBackground.visible = false
	$UILayer/GameOverContainer.visible = false
	_cleanup_game()
	_start_game()

func _process(_delta):
	# Handle back button in menus
	if Input.is_action_just_pressed("ui_cancel"):
		if $UILayer/GameOverContainer.visible:
			_on_quit_to_menu_pressed()
		elif $UILayer/PauseMenu.visible:
			_on_resume_pressed()
		elif not in_game:
			_on_quit_game_pressed()
	
	# Handle pause input during gameplay
	if in_game and not game_over and not paused and Input.is_action_just_pressed("pause"):
		_toggle_pause()
	
	# Only update game logic when not paused
	if in_game and not game_over and not paused:
		# Calculate various camera target influences
		var center = Vector2(GAME_WIDTH/2, GAME_HEIGHT/2)
		var look_ahead = snake.position + (snake.direction * GRID_SIZE * CAMERA_LOOK_AHEAD)
		var food_pos = food.position if food else snake.position
		var snake_center = snake.position
		
		# Calculate weighted center of mass of snake
		if not tail_segments.is_empty():
			var sum_pos = snake.position * 2.0
			var total_weight = 2.0
			for i in tail_segments.size():
				var weight = 1.0 / (i + 2.0)
				sum_pos += tail_segments[i].position * weight
				total_weight += weight
			snake_center = sum_pos / total_weight
		
		var target = (
			look_ahead * LOOK_AHEAD_WEIGHT +
			center * CENTER_PULL_WEIGHT +
			food_pos * FOOD_ATTRACTION_WEIGHT +
			snake_center * SNAKE_CENTER_WEIGHT
		) / (LOOK_AHEAD_WEIGHT + CENTER_PULL_WEIGHT + FOOD_ATTRACTION_WEIGHT + SNAKE_CENTER_WEIGHT)
		
		var t = CAMERA_ACCELERATION
		t = t * t * (3.0 - 2.0 * t) 
		var desired_velocity = (target - camera.position) * t
		
		camera_velocity = camera_velocity * CAMERA_DAMPING + desired_velocity
		camera.position += camera_velocity

func _on_timer_timeout():
	if game_over:
		return
	snake.can_move = false
	snake.move()

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
	_update_menu_focus()

func _on_resume_pressed():
	_toggle_pause()

func _on_sound_toggled():
	var is_muted = AudioManager.toggle_mute()
	_update_sound_buttons()
	# Still play click when unmuting
	if not is_muted:
		AudioManager.play_click()

func _update_sound_buttons():
	var text = "Sound: Off" if AudioManager.is_muted else "Sound: On"
	$UILayer/MainMenu/VBoxContainer/SoundButton.text = text
	$UILayer/PauseMenu/VBoxContainer/SoundButton.text = text
