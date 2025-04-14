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
var in_game := false
var in_options_menu := false

# Platform detection for mobile UI
var is_mobile := false
var in_high_scores_menu := false

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
	
	# Connect main menu buttons
	var main_menu := $UILayer/MainMenu
	var start_button := main_menu.get_node("VBoxContainer/StartButton")
	start_button.pressed.connect(_on_start_pressed)
	start_button.button_down.connect(AudioManager.play_click)
	
	var scores_button := main_menu.get_node("VBoxContainer/ScoresButton")
	scores_button.pressed.connect(_on_scores_pressed)
	scores_button.button_down.connect(AudioManager.play_click)
	
	var options_button := main_menu.get_node("VBoxContainer/OptionsButton")
	options_button.pressed.connect(_on_options_pressed)
	options_button.button_down.connect(AudioManager.play_click)
	
	var quit_button := main_menu.get_node("VBoxContainer/QuitButton")
	quit_button.pressed.connect(_on_quit_game_pressed)
	quit_button.button_down.connect(AudioManager.play_click)
	
	# Connect options menu signals
	var options_menu := $UILayer/OptionsMenu
	options_menu.options_closed.connect(_on_options_back_pressed)
	
	# Connect high scores menu signals
	var high_scores_menu := $UILayer/HighScoresMenu
	high_scores_menu.high_scores_closed.connect(_on_high_scores_back_pressed)
	
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
	
	# Start in menu state
	get_tree().paused = true
	$UIBackground.visible = true
	$UILayer/MainMenu.visible = true
	$UILayer/OptionsMenu.visible = false
	$UILayer/ScoreLabel.visible = false
	game_world.visible = false  # Using our cached reference instead

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
	buttons.append_array($UILayer/OptionsMenu/VBoxContainer.get_children().filter(func(n): return n is Button))
	buttons.append_array($UILayer/PauseMenu/VBoxContainer.get_children().filter(func(n): return n is Button))
	buttons.append_array($UILayer/GameOverContainer/VBoxContainer.get_children().filter(func(n): return n is Button))
	return buttons

func _update_menu_focus() -> void:
	if $UILayer/MainMenu.visible:
		$UILayer/MainMenu/VBoxContainer/StartButton.grab_focus()
	elif $UILayer/OptionsMenu.visible:
		$UILayer/OptionsMenu/VBoxContainer/SoundButton.grab_focus()
	elif $UILayer/PauseMenu.visible:
		$UILayer/PauseMenu/VBoxContainer/ResumeButton.grab_focus()
	elif $UILayer/GameOverContainer.visible:
		$UILayer/GameOverContainer/VBoxContainer/RestartButton.grab_focus()
	elif $UILayer/HighScoresMenu.visible:
		$UILayer/HighScoresMenu/VBoxContainer/BackButton.grab_focus()


func _on_start_pressed() -> void:
	get_tree().paused = false
	$UIBackground.visible = false
	$UILayer/MainMenu.visible = false
	$UILayer/OptionsMenu.visible = false
	$UILayer/ScoreLabel.visible = true
	game_world.visible = true
	_start_game()
	_update_menu_focus()

func _on_options_pressed() -> void:
	$UILayer/MainMenu.visible = false
	$UILayer/OptionsMenu.visible = true
	$UILayer/OptionsMenu.update_button_states()
	in_options_menu = true
	_update_menu_focus()

func _on_options_back_pressed() -> void:
	$UILayer/MainMenu.visible = true
	$UILayer/OptionsMenu.visible = false
	in_options_menu = false
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
	AudioManager.play_click()
	$UILayer/MainMenu.visible = false
	var high_scores_menu = $UILayer/HighScoresMenu
	high_scores_menu.visible = true
	high_scores_menu.update_scores(high_scores)
	in_high_scores_menu = true
	_update_menu_focus()

func _on_high_scores_back_pressed() -> void:
	$UILayer/HighScoresMenu.visible = false
	$UILayer/MainMenu.visible = true
	$UILayer/MainMenu.grab_focus()
	in_high_scores_menu = false
	_update_menu_focus()

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
	$UILayer/OptionsMenu.visible = false
	$UILayer/PauseMenu.visible = false
	$UILayer/ScoreLabel.visible = false
	game_world.visible = false
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

func _set_paused(paused_state: bool) -> void:
	if paused_state == paused:
		return

	paused = paused_state

	get_tree().paused = paused
	
	# Explicitly pause/unpause game elements through GameManager
	game_manager.set_paused(paused)
	
	# Update UI
	$UIBackground.visible = paused
	$UILayer/PauseMenu.visible = paused
	_update_menu_focus()

func _toggle_pause() -> void:
	_set_paused(not paused)

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_sound_toggled() -> void:
	AudioManager.toggle_mute()
	$UILayer/PauseMenu/VBoxContainer/SoundButton.text = "Sound: " + ("Off" if AudioManager.is_muted else "On")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if in_high_scores_menu:
			_on_high_scores_back_pressed()
			get_viewport().set_input_as_handled()
		elif in_options_menu:
			_on_options_back_pressed()
			get_viewport().set_input_as_handled()
		elif in_game and not paused:
			_set_paused(true)
			get_viewport().set_input_as_handled()
