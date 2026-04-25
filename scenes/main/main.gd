extends Control

const ConfigData = preload("res://autoload/config.gd")
const SaveDataUtil = preload("res://autoload/save_data.gd")
const GameManager = preload("res://autoload/game_manager.gd")

var GAME_WIDTH: int
var GAME_HEIGHT: int
var high_scores: Array[int] = []

var score := 0
var snake_camera: Camera2D
var in_game := false
var is_mobile := false

@onready var ui_state_manager: Node = $UIStateManager
@onready var ui_background: ColorRect = $UILayer/Background
@onready var score_display_label: Label = $UILayer/ScoreLabel
@onready var game_over_score_label: Label = $UILayer/GameOverContainer/PanelContainer/MarginContainer/VBoxContainer/ScoreLabel

@onready var game_world: Node2D = %GameWorld
@onready var gameplay: Node = %GameManager
@onready var game_manager: Node = $/root/GameManager
@onready var play_area_background: Panel = $GameLayer/GameViewport/GameWorld/PlayArea/Background
@onready var camera_node: Camera2D = %Camera2D

@onready var main_menu: CenterContainer = $UILayer/MainMenu
@onready var options_menu: CenterContainer = $UILayer/OptionsMenu
@onready var credits_screen: CenterContainer = $UILayer/CreditsScreen
@onready var high_scores_menu: CenterContainer = $UILayer/HighScoresMenu
@onready var pause_menu: CenterContainer = $UILayer/PauseMenu
@onready var game_over_container: CenterContainer = $UILayer/GameOverContainer

@onready var main_menu_box: VBoxContainer = $UILayer/MainMenu/PanelContainer/MarginContainer/VBoxContainer
@onready var options_menu_box: VBoxContainer = $UILayer/OptionsMenu/PanelContainer/MarginContainer/VBoxContainer
@onready var credits_menu_box: VBoxContainer = $UILayer/CreditsScreen/PanelContainer/MarginContainer/VBoxContainer
@onready var high_scores_menu_box: VBoxContainer = $UILayer/HighScoresMenu/PanelContainer/MarginContainer/VBoxContainer
@onready var pause_menu_box: VBoxContainer = $UILayer/PauseMenu/PanelContainer/MarginContainer/VBoxContainer
@onready var game_over_menu_box: VBoxContainer = $UILayer/GameOverContainer/PanelContainer/MarginContainer/VBoxContainer

func _ready() -> void:
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	GAME_WIDTH = ConfigData.get_game_width()
	GAME_HEIGHT = ConfigData.get_game_height()
	
	if not GameManager.get_singleton():
		var game_manager_instance = GameManager.new()
		add_child(game_manager_instance)
		game_manager_instance.name = "GameManager"
	
	game_manager = GameManager.get_singleton()
	
	game_manager.set_gameplay(gameplay)
	game_manager.set_save_data_util(SaveDataUtil)
	game_manager.set_config(ConfigData)
	game_manager.set_ui_state_manager(ui_state_manager)
	
	ui_state_manager.state_changed.connect(_on_ui_state_changed)
	ui_state_manager.pause_state_changed.connect(_on_pause_state_changed)
	
	ui_state_manager.register_ui_element(ui_state_manager.UIState.MAIN_MENU, main_menu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.OPTIONS_MENU, options_menu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.CREDITS_SCREEN, credits_screen)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.HIGH_SCORES, high_scores_menu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.PAUSED, pause_menu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.GAME_OVER, game_over_container)
	
	ui_state_manager.register_focus_target(ui_state_manager.UIState.MAIN_MENU, main_menu_box.get_node("StartButton"))
	ui_state_manager.register_focus_target(ui_state_manager.UIState.OPTIONS_MENU, options_menu_box.get_node("SoundButton"))
	ui_state_manager.register_focus_target(ui_state_manager.UIState.CREDITS_SCREEN, credits_menu_box.get_node("BackButton"))
	ui_state_manager.register_focus_target(ui_state_manager.UIState.HIGH_SCORES, high_scores_menu_box.get_node("BackButton"))
	ui_state_manager.register_focus_target(ui_state_manager.UIState.PAUSED, pause_menu_box.get_node("ResumeButton"))
	ui_state_manager.register_focus_target(ui_state_manager.UIState.GAME_OVER, game_over_menu_box.get_node("RestartButton"))
	
	is_mobile = DisplayServer.get_name() in ["android", "ios", "web"]
	high_scores = SaveDataUtil.load_high_scores()
	
	var start_button: Button = main_menu_box.get_node("StartButton")
	start_button.pressed.connect(_on_start_pressed)
	start_button.button_down.connect(AudioManager.play_click)
	
	var scores_button: Button = main_menu_box.get_node("ScoresButton")
	scores_button.pressed.connect(_on_scores_pressed)
	scores_button.button_down.connect(AudioManager.play_click)
	
	var options_button: Button = main_menu_box.get_node("OptionsButton")
	options_button.pressed.connect(_on_options_pressed)
	options_button.button_down.connect(AudioManager.play_click)
	
	var credits_button: Button = main_menu_box.get_node("CreditsButton")
	credits_button.pressed.connect(_on_credits_pressed)
	credits_button.button_down.connect(AudioManager.play_click)
	
	var quit_button: Button = main_menu_box.get_node("QuitButton")
	quit_button.pressed.connect(_on_quit_game_pressed)
	quit_button.button_down.connect(AudioManager.play_click)
	
	options_menu.options_closed.connect(_on_options_back_pressed)
	options_menu.reset_scores_requested.connect(reset_high_scores)
	credits_screen.credits_screen_closed.connect(_on_credits_back_pressed)
	high_scores_menu.high_scores_closed.connect(_on_high_scores_back_pressed)
	
	var resume_button: Button = pause_menu_box.get_node("ResumeButton")
	resume_button.pressed.connect(_on_resume_pressed)
	resume_button.button_down.connect(AudioManager.play_click)
	
	var pause_quit: Button = pause_menu_box.get_node("QuitButton")
	pause_quit.pressed.connect(_on_quit_to_menu_pressed)
	pause_quit.button_down.connect(AudioManager.play_click)
	
	var restart_button: Button = game_over_menu_box.get_node("RestartButton")
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.button_down.connect(AudioManager.play_click)
	
	var gameover_quit: Button = game_over_menu_box.get_node("QuitButton")
	gameover_quit.pressed.connect(_on_quit_to_menu_pressed)
	gameover_quit.button_down.connect(AudioManager.play_click)
	
	game_manager.game_started.connect(_on_game_started)
	game_manager.game_paused.connect(_on_game_paused)
	game_manager.game_resumed.connect(_on_game_resumed)
	game_manager.game_over.connect(_on_game_over)
	game_manager.score_updated.connect(_on_score_updated)
	game_manager.high_scores_updated.connect(_on_high_scores_updated)
	
	get_tree().set_pause(true)
	ui_background.visible = false
	main_menu.visible = true
	options_menu.visible = false
	score_display_label.visible = false
	game_world.visible = false
	
	for button in _get_all_buttons():
		button.focus_entered.connect(AudioManager.play_focus)
	
	_update_menu_focus()
	
	get_tree().root.size_changed.connect(_on_window_resize)
	_on_window_resize()
	_update_game_area()

func _update_game_area() -> void:
	var window_size := DisplayServer.window_get_size()
	var game_size := Vector2(GAME_WIDTH, GAME_HEIGHT)
	game_world.position = (Vector2(window_size) - game_size) / 2.0
	play_area_background.size = game_size

func _toggle_pause() -> void:
	var is_currently_paused = ui_state_manager.current_state == ui_state_manager.UIState.PAUSED
	ui_state_manager.set_paused(not is_currently_paused)

	func _on_resume_pressed() -> void:
		ui_state_manager.set_paused(false)

	func _on_start_pressed() -> void:
		game_manager.start_game()

	func _on_game_started() -> void:
		# Called when game starts via GameManager
		in_game = true
		ui_background.visible = false
		score_display_label.visible = true
		game_world.visible = true
		get_tree().set_pause(false)
		if not is_mobile:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	func _on_game_paused() -> void:
		# Called when game is paused via GameManager
		ui_background.visible = true

	func _on_game_resumed() -> void:
		# Called when game is resumed via GameManager
		ui_background.visible = false
		if not is_mobile:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	func _on_game_over(final_score: int) -> void:
		# Called when game is over via GameManager
		in_game = false
		ui_state_manager.change_state(ui_state_manager.UIState.GAME_OVER)
		game_over_score_label.text = "Final Score: " + str(final_score)
		_update_menu_focus()

	func _on_ui_state_changed(old_state: int, new_state: int) -> void:
	match new_state:
		ui_state_manager.UIState.GAMEPLAY:
			ui_background.visible = false
			score_display_label.visible = true
			game_world.visible = true
		ui_state_manager.UIState.MAIN_MENU:
			ui_background.visible = false
			score_display_label.visible = false
			game_world.visible = false
			get_tree().set_pause(true)
		ui_state_manager.UIState.PAUSED:
			ui_background.visible = true
		ui_state_manager.UIState.GAME_OVER:
			in_game = false
		_:
			if old_state == ui_state_manager.UIState.GAMEPLAY:
				ui_background.visible = true

	_update_menu_focus()

func _on_pause_state_changed(is_paused: bool) -> void:
	if game_manager:
		game_manager.set_paused(is_paused)
