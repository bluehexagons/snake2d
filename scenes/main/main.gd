extends Control

const GAME_WIDTH := Gameplay.GRID_SIZE * Gameplay.GRID_WIDTH
const GAME_HEIGHT := Gameplay.GRID_SIZE * Gameplay.GRID_HEIGHT

const CAMERA_LOOK_AHEAD := 1.2
const CAMERA_SMOOTHING := 0.015
const CENTER_PULL_WEIGHT := 0.4
const FOOD_ATTRACTION_WEIGHT := 0.5
const LOOK_AHEAD_WEIGHT := 0.55
const SNAKE_CENTER_WEIGHT := 0.5
const CAMERA_DAMPING := 0.95
const CAMERA_ACCELERATION := 0.01

const MAX_HIGH_SCORES := 10
var high_scores: Array[int] = []

var camera_velocity := Vector2.ZERO

var game_world: Node2D
var game_manager: Gameplay
var score := 0
var score_display_label: Label
var camera: Camera2D
var paused := false
var high_score := 0
var in_game := false

# Platform detection for mobile UI
var is_mobile := false

func _ready():
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	# Check platform
	is_mobile = DisplayServer.get_name() in ["android", "ios", "web"]
	
	# Load high scores
	if FileAccess.file_exists("user://highscore.dat"):
		var file := FileAccess.open("user://highscore.dat", FileAccess.READ)
		while not file.eof_reached():
			var val := file.get_32()
			if val > 0:
				high_scores.append(val)
	
	high_scores.sort_custom(func(a, b): return a > b)  # Sort descending
	high_score = high_scores[0] if not high_scores.is_empty() else 0
	
	# Connect main menu buttons
	var main_menu := $UILayer/MainMenu
	var start_button := main_menu.get_node("VBoxContainer/StartButton")
	start_button.pressed.connect(_on_start_pressed)
	start_button.button_down.connect(AudioManager.play_click)
	
	var scores_button := main_menu.get_node("VBoxContainer/ScoresButton")
	scores_button.pressed.connect(_on_scores_pressed)
	scores_button.button_down.connect(AudioManager.play_click)
	
	var quit_button := main_menu.get_node("VBoxContainer/QuitButton")
	quit_button.pressed.connect(_on_quit_game_pressed)
	quit_button.button_down.connect(AudioManager.play_click)
	
	# Connect sound toggle buttons
	var main_sound_button := main_menu.get_node("VBoxContainer/SoundButton")
	main_sound_button.pressed.connect(_on_sound_toggled)
	
	# Connect fullscreen toggle button
	var fullscreen_button := main_menu.get_node("VBoxContainer/FullscreenButton")
	fullscreen_button.pressed.connect(_on_fullscreen_toggled)
	fullscreen_button.button_down.connect(AudioManager.play_click)
	_update_fullscreen_button()
	
	# Connect pause menu buttons
	var pause_menu := $UILayer/PauseMenu
	var resume_button := pause_menu.get_node("VBoxContainer/ResumeButton")
	resume_button.pressed.connect(_on_resume_pressed)
	resume_button.button_down.connect(AudioManager.play_click)
	
	var pause_quit := pause_menu.get_node("VBoxContainer/QuitButton")
	pause_quit.pressed.connect(_on_quit_to_menu_pressed)
	pause_quit.button_down.connect(AudioManager.play_click)
	
	var pause_sound_button := pause_menu.get_node("VBoxContainer/SoundButton")
	pause_sound_button.pressed.connect(_on_sound_toggled)
	
	# Connect game over buttons
	var game_over_menu := $UILayer/GameOverContainer/VBoxContainer
	var restart_button := game_over_menu.get_node("RestartButton")
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.button_down.connect(AudioManager.play_click)
	
	var gameover_quit := game_over_menu.get_node("QuitButton")
	gameover_quit.pressed.connect(_on_quit_to_menu_pressed)
	gameover_quit.button_down.connect(AudioManager.play_click)

	score_display_label = $UILayer/ScoreLabel
	game_world = $GameLayer/GameViewport/GameWorld
	game_manager = %GameManager
	
	# Connect GameManager signals
	game_manager.score_updated.connect(_on_score_updated)
	game_manager.game_over.connect(_on_game_over)
	
	# Set initial sound button states
	_update_sound_buttons()
	
	# Start in menu state
	get_tree().paused = true
	$UIBackground.visible = true
	$UILayer/MainMenu.visible = true
	$UILayer/ScoreLabel.visible = false
	game_world.visible = false  # Using our cached reference instead

	_update_scores_display(false)  # Initialize scores display
	
	# Connect focus sounds to all buttons
	for button in _get_all_buttons():
		button.focus_entered.connect(AudioManager.play_focus)
	
	# Set initial focus
	_update_menu_focus()

	get_tree().root.size_changed.connect(_on_window_resize)
	_on_window_resize()
	_update_game_area()

func _get_all_buttons() -> Array:
	var buttons := []
	buttons.append_array($UILayer/MainMenu/VBoxContainer.get_children().filter(func(n): return n is Button))
	buttons.append_array($UILayer/PauseMenu/VBoxContainer.get_children().filter(func(n): return n is Button))
	buttons.append_array($UILayer/GameOverContainer/VBoxContainer.get_children().filter(func(n): return n is Button))
	return buttons

func _update_menu_focus() -> void:
	if $UILayer/MainMenu.visible:
		$UILayer/MainMenu/VBoxContainer/StartButton.grab_focus()
	elif $UILayer/PauseMenu.visible:
		$UILayer/PauseMenu/VBoxContainer/ResumeButton.grab_focus()
	elif $UILayer/GameOverContainer.visible:
		$UILayer/GameOverContainer/VBoxContainer/RestartButton.grab_focus()

func _on_start_pressed() -> void:
	get_tree().paused = false
	$UIBackground.visible = false
	$UILayer/MainMenu.visible = false
	$UILayer/ScoreLabel.visible = true
	game_world.visible = true
	_start_game()
	_update_menu_focus()

func _start_game() -> void:
	_cleanup_game()

	in_game = true
	score = 0
	score_display_label.text = "Score: 0"
	
	# Start game through the GameManager
	game_manager.start_game()
	
	camera = $GameLayer/GameViewport/GameWorld/Camera2D
	@warning_ignore("integer_division")
	camera.position = Vector2(GAME_WIDTH/2, GAME_HEIGHT/2)
	camera_velocity = Vector2.ZERO
	
	get_tree().paused = false
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_scores_pressed() -> void:
	_update_scores_display(true)

func _update_scores_display(show_container: bool) -> void:
	var title_label := $UILayer/MainMenu/VBoxContainer/TitleLabel
	var scores_container := $UILayer/MainMenu/VBoxContainer/ScoresContainer
	var scores_list := $UILayer/MainMenu/VBoxContainer/ScoresContainer/ScrollContainer/ScoresList
	
	# Clear existing score labels
	for child in scores_list.get_children():
		child.queue_free()
	
	if show_container:
		title_label.text = "HIGH SCORES"
		scores_container.visible = true
		
		if high_scores.is_empty():
			var empty_label := Label.new()
			empty_label.text = "No scores yet!"
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			scores_list.add_child(empty_label)
		else:
			for i in high_scores.size():
				var score_label := Label.new()
				score_label.text = "%d. %d" % [i + 1, high_scores[i]]
				score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				scores_list.add_child(score_label)
	else:
		title_label.text = "A Simple Snake Game"
		scores_container.visible = false

func _on_quit_game_pressed() -> void:
	# Ensure mouse is free before showing dialog
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var dialog := ConfirmationDialog.new()
	dialog.title = "Quit Game"
	dialog.dialog_text = "Are you sure you want to quit?"
	dialog.confirmed.connect(get_tree().quit)
	add_child(dialog)
	dialog.popup_centered()

func _on_quit_to_menu_pressed() -> void:
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cleanup_game()
	get_tree().paused = true
	$UIBackground.visible = true
	$UILayer/MainMenu.visible = true
	$UILayer/PauseMenu.visible = false
	$UILayer/ScoreLabel.visible = false
	game_world.visible = false
	_update_scores_display(false)
	_update_menu_focus()

func _cleanup_game() -> void:
	# Let the GameManager clean up game elements
	game_manager.cleanup()
	
	# Reset game state
	in_game = false
	paused = false
	
	# Reset UI
	$UILayer/GameOverContainer.visible = false
	$UILayer/PauseMenu.visible = false
	camera_velocity = Vector2.ZERO
	
	# Return to normal mouse mode
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	get_tree().paused = paused

func _on_score_updated(new_score: int) -> void:
	score = new_score
	score_display_label.text = "Score: " + str(score)

func _on_game_over(final_score: int) -> void:
	# Update high scores
	var score_inserted := false
	for i in high_scores.size():
		if final_score > high_scores[i]:
			high_scores.insert(i, final_score)
			score_inserted = true
			break
	
	if not score_inserted and high_scores.size() < MAX_HIGH_SCORES:
		high_scores.append(final_score)
	
	if high_scores.size() > MAX_HIGH_SCORES:
		high_scores.resize(MAX_HIGH_SCORES)
	
	# Save all scores
	var file := FileAccess.open("user://highscore.dat", FileAccess.WRITE)
	for score_value in high_scores:
		file.store_32(score_value)
	
	high_score = high_scores[0] if not high_scores.is_empty() else 0
	
	# Update game over UI and background
	$UIBackground.visible = true
	$UILayer/GameOverContainer.visible = true
	$UILayer/GameOverContainer/VBoxContainer/ScoreLabel.text = "Final Score: " + str(final_score)
	_update_menu_focus()

func _on_restart_pressed() -> void:
	$UIBackground.visible = false
	$UILayer/GameOverContainer.visible = false
	_cleanup_game()
	_start_game()

func _process(_delta) -> void:
	# Check if we need to restore UI focus
	if (Input.is_action_just_pressed("ui_up") or 
		Input.is_action_just_pressed("ui_down") or
		Input.is_action_just_pressed("ui_left") or
		Input.is_action_just_pressed("ui_right")):
		var focused := get_viewport().gui_get_focus_owner()
		if not focused:
			_update_menu_focus()
	
	# Handle back button in menus
	if Input.is_action_just_pressed("ui_cancel"):
		if $UILayer/GameOverContainer.visible:
			_on_quit_to_menu_pressed()
		elif $UILayer/PauseMenu.visible:
			_on_resume_pressed()
		elif not in_game:
			_on_quit_game_pressed()
		else:
			_toggle_pause()
	
	# Handle pause input during gameplay
	if in_game and not paused and Input.is_action_just_pressed("pause"):
		_toggle_pause()

func _physics_process(_delta) -> void:
	# Only update game logic when not paused
	if in_game and not paused:
		# Calculate various camera target influences
		@warning_ignore("integer_division")
		var center := Vector2(GAME_WIDTH/2, GAME_HEIGHT/2)
		var snake_position := game_manager.get_snake_position()
		var look_ahead: Vector2 = snake_position + (game_manager.get_snake_direction() * 32 * CAMERA_LOOK_AHEAD)
		var food_pos := game_manager.get_food_position()
		var snake_center := game_manager.get_weighted_snake_center()
		
		var target := (
			look_ahead * LOOK_AHEAD_WEIGHT +
			center * CENTER_PULL_WEIGHT +
			food_pos * FOOD_ATTRACTION_WEIGHT +
			snake_center * SNAKE_CENTER_WEIGHT
		) / (LOOK_AHEAD_WEIGHT + CENTER_PULL_WEIGHT + FOOD_ATTRACTION_WEIGHT + SNAKE_CENTER_WEIGHT)
		
		var t := CAMERA_ACCELERATION
		t = t * t * (3.0 - 2.0 * t) 
		var desired_velocity := (target - camera.position) * t
		
		camera_velocity = camera_velocity * CAMERA_DAMPING + desired_velocity
		camera.position += camera_velocity

func _on_window_resize() -> void:
	_update_game_area()

func _update_game_area() -> void:
	var window_size := DisplayServer.window_get_size()
	var play_area := $GameLayer/GameViewport/GameWorld/PlayArea
	var background := play_area.get_node("Background")
	var border := play_area.get_node("Border")
	
	# Center the game world
	var game_size := Vector2(GAME_WIDTH, GAME_HEIGHT)
	game_world.position = (Vector2(window_size) - game_size) / 2.0
	
	# Update background and border
	background.size = game_size
	border.points = [
		Vector2.ZERO,
		Vector2(GAME_WIDTH, 0),
		Vector2(GAME_WIDTH, GAME_HEIGHT),
		Vector2(0, GAME_HEIGHT),
		Vector2.ZERO
	]

func _toggle_pause() -> void:
	paused = !paused
	get_tree().paused = paused
	
	# Explicitly pause/unpause game elements through GameManager
	game_manager.set_paused(paused)
	
	# Update UI
	$UIBackground.visible = paused
	$UILayer/PauseMenu.visible = paused
	_update_menu_focus()

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_sound_toggled() -> void:
	var is_muted := AudioManager.toggle_mute()
	_update_sound_buttons()
	# Still play click when unmuting
	if not is_muted:
		AudioManager.play_click()

func _update_sound_buttons() -> void:
	var text := "Sound: Off" if AudioManager.is_muted else "Sound: On"
	$UILayer/MainMenu/VBoxContainer/SoundButton.text = text
	$UILayer/PauseMenu/VBoxContainer/SoundButton.text = text

func _on_fullscreen_toggled() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_fullscreen_button()

func _update_fullscreen_button() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var button := $UILayer/MainMenu/VBoxContainer/FullscreenButton
	button.text = "Fullscreen: " + ("On" if is_fullscreen else "Off")
