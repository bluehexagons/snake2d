extends Control
var GAME_WIDTH: int
var GAME_HEIGHT: int
var high_scores: Array[int] = []

var game_world: Node2D
var game_manager: Gameplay
var score := 0
var score_display_label: Label
var snake_camera: Camera2D
var in_game := false
var is_mobile := false

var ui_state_manager: Node

func _ready():
	set_process_mode(Node.PROCESS_MODE_ALWAYS)

	GAME_WIDTH = Config.get_game_width()
	GAME_HEIGHT = Config.get_game_height()
	
	ui_state_manager = $UIStateManager
	ui_state_manager.state_changed.connect(_on_ui_state_changed)
	ui_state_manager.pause_state_changed.connect(_on_pause_state_changed)
	
	ui_state_manager.register_ui_element(ui_state_manager.UIState.MAIN_MENU, $UILayer/MainMenu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.OPTIONS_MENU, $UILayer/OptionsMenu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.CREDITS_SCREEN, $UILayer/CreditsScreen)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.HIGH_SCORES, $UILayer/HighScoresMenu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.PAUSED, $UILayer/PauseMenu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.GAME_OVER, $UILayer/GameOverContainer)
	
	ui_state_manager.register_focus_target(ui_state_manager.UIState.MAIN_MENU, 
		$UILayer/MainMenu/PanelContainer/MarginContainer/VBoxContainer/StartButton)
	ui_state_manager.register_focus_target(ui_state_manager.UIState.OPTIONS_MENU, 
		$UILayer/OptionsMenu/PanelContainer/MarginContainer/VBoxContainer/SoundButton)
	ui_state_manager.register_focus_target(ui_state_manager.UIState.CREDITS_SCREEN, 
		$UILayer/CreditsScreen/PanelContainer/MarginContainer/VBoxContainer/BackButton)
	ui_state_manager.register_focus_target(ui_state_manager.UIState.HIGH_SCORES, 
		$UILayer/HighScoresMenu/PanelContainer/MarginContainer/VBoxContainer/BackButton)
	ui_state_manager.register_focus_target(ui_state_manager.UIState.PAUSED, 
		$UILayer/PauseMenu/PanelContainer/MarginContainer/VBoxContainer/ResumeButton)
	ui_state_manager.register_focus_target(ui_state_manager.UIState.GAME_OVER, 
		$UILayer/GameOverContainer/PanelContainer/MarginContainer/VBoxContainer/RestartButton)
	
	is_mobile = DisplayServer.get_name() in ["android", "ios", "web"]
	
	if FileAccess.file_exists("user://highscore.dat"):
		var file := FileAccess.open("user://highscore.dat", FileAccess.READ)
		while not file.eof_reached():
			var val := file.get_32()
			if val > 0:
				high_scores.append(val)
	
	high_scores.sort_custom(func(a, b): return a > b)
	
	var main_menu := $UILayer/MainMenu
	var start_button := main_menu.get_node("PanelContainer/MarginContainer/VBoxContainer/StartButton")
	start_button.pressed.connect(_on_start_pressed)
	start_button.button_down.connect(AudioManager.play_click)
	
	var scores_button := main_menu.get_node("PanelContainer/MarginContainer/VBoxContainer/ScoresButton")
	scores_button.pressed.connect(_on_scores_pressed)
	scores_button.button_down.connect(AudioManager.play_click)
	
	var options_button := main_menu.get_node("PanelContainer/MarginContainer/VBoxContainer/OptionsButton")
	options_button.pressed.connect(_on_options_pressed)
	options_button.button_down.connect(AudioManager.play_click)
	
	var credits_button := main_menu.get_node("PanelContainer/MarginContainer/VBoxContainer/CreditsButton")
	credits_button.pressed.connect(_on_credits_pressed)
	credits_button.button_down.connect(AudioManager.play_click)
	
	var quit_button := main_menu.get_node("PanelContainer/MarginContainer/VBoxContainer/QuitButton")
	quit_button.pressed.connect(_on_quit_game_pressed)
	quit_button.button_down.connect(AudioManager.play_click)
	
	var options_menu := $UILayer/OptionsMenu
	options_menu.options_closed.connect(_on_options_back_pressed)
	
	var credits_screen := $UILayer/CreditsScreen
	credits_screen.credits_screen_closed.connect(_on_credits_back_pressed)
	
	var high_scores_menu := $UILayer/HighScoresMenu
	high_scores_menu.high_scores_closed.connect(_on_high_scores_back_pressed)
	
	var pause_menu := $UILayer/PauseMenu
	var resume_button := pause_menu.get_node("PanelContainer/MarginContainer/VBoxContainer/ResumeButton")
	resume_button.pressed.connect(_on_resume_pressed)
	resume_button.button_down.connect(AudioManager.play_click)
	
	var pause_quit := pause_menu.get_node("PanelContainer/MarginContainer/VBoxContainer/QuitButton")
	pause_quit.pressed.connect(_on_quit_to_menu_pressed)
	pause_quit.button_down.connect(AudioManager.play_click)
	
	var game_over_menu := $UILayer/GameOverContainer/PanelContainer/MarginContainer/VBoxContainer
	var restart_button := game_over_menu.get_node("RestartButton")
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.button_down.connect(AudioManager.play_click)
	
	var gameover_quit := game_over_menu.get_node("QuitButton")
	gameover_quit.pressed.connect(_on_quit_to_menu_pressed)
	gameover_quit.button_down.connect(AudioManager.play_click)

	score_display_label = $UILayer/ScoreLabel
	game_world = $GameLayer/GameViewport/GameWorld
	game_manager = %GameManager
	
	game_manager.score_updated.connect(_on_score_updated)
	game_manager.game_over.connect(_on_game_over)
	
	get_tree().paused = true
	$UILayer/Background.visible = false
	$UILayer/MainMenu.visible = true
	$UILayer/OptionsMenu.visible = false
	$UILayer/ScoreLabel.visible = false
	game_world.visible = false

	for button in _get_all_buttons():
		button.focus_entered.connect(AudioManager.play_focus)
	
	_update_menu_focus()

	get_tree().root.size_changed.connect(_on_window_resize)
	_on_window_resize()
	_update_game_area()

func _get_all_buttons() -> Array:
	var buttons := []
	buttons.append_array($UILayer/MainMenu/PanelContainer/MarginContainer/VBoxContainer.get_children().filter(func(n): return n is Button))
	buttons.append_array($UILayer/OptionsMenu/PanelContainer/MarginContainer/VBoxContainer.get_children().filter(func(n): return n is Button))
	buttons.append_array($UILayer/PauseMenu/PanelContainer/MarginContainer/VBoxContainer.get_children().filter(func(n): return n is Button))
	buttons.append_array($UILayer/GameOverContainer/PanelContainer/MarginContainer/VBoxContainer.get_children().filter(func(n): return n is Button))
	return buttons

func _update_menu_focus() -> void:
	var current_state = ui_state_manager.current_state
	if current_state in ui_state_manager.focus_targets:
		ui_state_manager.focus_targets[current_state].grab_focus()

func _on_start_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.GAMEPLAY)
	_start_game()

func _on_options_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.OPTIONS_MENU)

func _on_options_back_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.MAIN_MENU)

func _on_credits_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.CREDITS_SCREEN)

func _on_credits_back_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.MAIN_MENU)

func _start_game() -> void:
	_cleanup_game()

	in_game = true
	score = 0
	score_display_label.text = "Score: 0"

	game_manager.start_game()
	
	snake_camera = $GameLayer/GameViewport/GameWorld/Camera2D
	snake_camera.game_manager = game_manager
	
	snake_camera.reset_camera()
	
	get_tree().paused = false
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_scores_pressed() -> void:
	AudioManager.play_click()
	
	ui_state_manager.change_state(ui_state_manager.UIState.HIGH_SCORES)
	var high_scores_menu = $UILayer/HighScoresMenu
	high_scores_menu.update_scores(high_scores)

func _on_high_scores_back_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.MAIN_MENU)

func reset_high_scores() -> void:
	high_scores.clear()
	
	var file := FileAccess.open("user://highscore.dat", FileAccess.WRITE)
	file.close()

func _on_quit_game_pressed() -> void:
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
	ui_state_manager.change_state(ui_state_manager.UIState.MAIN_MENU)

func _cleanup_game() -> void:
	game_manager.cleanup()
	
	in_game = false
	
	# Let the UI state manager handle visibility
	if snake_camera:
		snake_camera.reset_camera()
	
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_score_updated(new_score: int) -> void:
	score = new_score
	score_display_label.text = "Score: " + str(score)

func _on_game_over(final_score: int) -> void:
	var score_inserted := false
	for i in high_scores.size():
		if final_score > high_scores[i]:
			high_scores.insert(i, final_score)
			score_inserted = true
			break
	
	if not score_inserted and high_scores.size() < Config.MAX_HIGH_SCORES:
		high_scores.append(final_score)
	
	if high_scores.size() > Config.MAX_HIGH_SCORES:
		high_scores.resize(Config.MAX_HIGH_SCORES)
	
	var file := FileAccess.open("user://highscore.dat", FileAccess.WRITE)
	for score_value in high_scores:
		file.store_32(score_value)
	
	ui_state_manager.change_state(ui_state_manager.UIState.GAME_OVER)
	
	$UILayer/GameOverContainer/PanelContainer/MarginContainer/VBoxContainer/ScoreLabel.text = "Final Score: " + str(final_score)
	_update_menu_focus()

func _on_restart_pressed() -> void:
	_cleanup_game()
	ui_state_manager.change_state(ui_state_manager.UIState.GAMEPLAY)
	_start_game()

func _process(_delta) -> void:
	if (Input.is_action_just_pressed("up") or 
		Input.is_action_just_pressed("down") or
		Input.is_action_just_pressed("left") or
		Input.is_action_just_pressed("right")):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is not Button:
			_update_menu_focus()
	
	if ui_state_manager.current_state == ui_state_manager.UIState.GAMEPLAY and Input.is_action_just_pressed("pause"):
		_toggle_pause()
	
func _on_window_resize() -> void:
	_update_game_area()

func _update_game_area() -> void:
	var window_size := DisplayServer.window_get_size()
	var play_area := $GameLayer/GameViewport/GameWorld/PlayArea
	var background := play_area.get_node("Background")
	
	var game_size := Vector2(GAME_WIDTH, GAME_HEIGHT)
	game_world.position = (Vector2(window_size) - game_size) / 2.0
	
	background.size = game_size

func _toggle_pause() -> void:
	var is_currently_paused = ui_state_manager.current_state == ui_state_manager.UIState.PAUSED
	ui_state_manager.set_paused(not is_currently_paused)

func _on_resume_pressed() -> void:
	ui_state_manager.set_paused(false)

func _on_sound_toggled() -> void:
	AudioManager.toggle_mute()
	$UILayer/PauseMenu/PanelContainer/MarginContainer/VBoxContainer/SoundButton.text = "Sound: " + ("Off" if AudioManager.is_muted else "On")

func _on_ui_state_changed(old_state, new_state) -> void:
	match new_state:
		ui_state_manager.UIState.GAMEPLAY:
			$UILayer/Background.visible = false
			$UILayer/ScoreLabel.visible = true
			game_world.visible = true
		ui_state_manager.UIState.MAIN_MENU:
			$UILayer/Background.visible = false
			$UILayer/ScoreLabel.visible = false
			game_world.visible = false
			get_tree().paused = true
		ui_state_manager.UIState.PAUSED:
			$UILayer/Background.visible = true
		ui_state_manager.UIState.GAME_OVER:
			in_game = false
		_:
			if old_state == ui_state_manager.UIState.GAMEPLAY:
				$UILayer/Background.visible = true
	
	_update_menu_focus()

func _on_pause_state_changed(is_paused: bool) -> void:
	if game_manager:
		game_manager.set_paused(is_paused)
