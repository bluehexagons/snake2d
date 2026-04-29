extends Control

const ConfigData = preload("res://autoload/config.gd")
const SaveDataUtil = preload("res://autoload/save_data.gd")
const GameManagerScript = preload("res://autoload/game_manager.gd")

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
@onready var game_manager: Node = get_node_or_null("/root/GameManager")
@onready var play_area_background: Panel = $GameLayer/GameViewport/GameWorld/PlayArea/Background
@onready var camera_node: Camera2D = %Camera2D

@onready var main_menu: CenterContainer = $UILayer/MainMenu
@onready var options_menu: OptionsMenu = $UILayer/OptionsMenu
@onready var credits_screen: CreditsScreen = $UILayer/CreditsScreen
@onready var high_scores_menu: HighScoresMenu = $UILayer/HighScoresMenu
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
	
	if not game_manager:
		var game_manager_instance = GameManagerScript.new()
		add_child(game_manager_instance)
		game_manager_instance.name = "GameManager"
		game_manager = game_manager_instance
	
	game_manager.set_gameplay(gameplay)
	game_manager.set_save_data_util(SaveDataUtil)
	game_manager.set_config(ConfigData)
	game_manager.set_ui_state_manager(ui_state_manager)
	camera_node.game_manager = gameplay
	
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
	
	get_tree().paused = true
	ui_background.visible = false
	main_menu.visible = true
	options_menu.visible = false
	score_display_label.visible = false
	game_world.visible = false
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	for button in _get_all_buttons():
		if not button.focus_entered.is_connected(AudioManager.play_focus):
			button.focus_entered.connect(AudioManager.play_focus)
		_install_button_polish(button)
	
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
	ui_state_manager.change_state(ui_state_manager.UIState.GAMEPLAY)
	ui_background.visible = false
	score_display_label.visible = true
	game_world.visible = true
	get_tree().paused = false
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
			get_tree().paused = true
			if not is_mobile:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui_state_manager.UIState.PAUSED:
			ui_background.visible = true
			if not is_mobile:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui_state_manager.UIState.GAME_OVER:
			in_game = false
			if not is_mobile:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_:
			if old_state == ui_state_manager.UIState.GAMEPLAY:
				ui_background.visible = true

	_update_menu_focus()

func _on_pause_state_changed(is_paused: bool) -> void:
	if game_manager:
		if is_paused:
			game_manager.pause_game()
		else:
			game_manager.resume_game()

func _cleanup_game() -> void:
	in_game = false
	if gameplay and gameplay.has_method("cleanup"):
		gameplay.cleanup()
	get_tree().paused = true

func _get_all_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	var containers := [
		main_menu_box,
		options_menu_box,
		credits_menu_box,
		high_scores_menu_box,
		pause_menu_box,
		game_over_menu_box,
	]
	for container in containers:
		if container == null:
			continue
		for node in container.get_children():
			if node is Button:
				buttons.append(node)
	return buttons

# Adds a subtle scale animation on focus/hover/press transitions for any Button.
func _install_button_polish(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
	)
	var animate_to := func(target_scale: Vector2, duration: float) -> void:
		var tween := get_tree().create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(btn, "scale", target_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	btn.focus_entered.connect(func() -> void: animate_to.call(Vector2(1.06, 1.06), 0.14))
	btn.focus_exited.connect(func() -> void: animate_to.call(Vector2.ONE, 0.18))
	btn.mouse_entered.connect(func() -> void:
		if btn.has_focus():
			return
		animate_to.call(Vector2(1.04, 1.04), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		if btn.has_focus():
			return
		animate_to.call(Vector2.ONE, 0.16)
	)
	btn.button_down.connect(func() -> void: animate_to.call(Vector2(0.96, 0.96), 0.06))
	btn.button_up.connect(func() -> void:
		var dest := Vector2(1.06, 1.06) if btn.has_focus() else Vector2.ONE
		animate_to.call(dest, 0.12)
	)

func _update_menu_focus() -> void:
	var current_state = ui_state_manager.current_state
	if current_state in ui_state_manager.focus_targets:
		ui_state_manager.focus_targets[current_state].grab_focus()

func _process(_delta) -> void:
	if (
		Input.is_action_just_pressed("up")
		or Input.is_action_just_pressed("down")
		or Input.is_action_just_pressed("left")
		or Input.is_action_just_pressed("right")
	):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is not Button:
			_update_menu_focus()

	if ui_state_manager.current_state == ui_state_manager.UIState.GAMEPLAY and Input.is_action_just_pressed("pause"):
		_toggle_pause()

func _on_scores_pressed() -> void:
	high_scores_menu.update_scores(high_scores)
	ui_state_manager.change_state(ui_state_manager.UIState.HIGH_SCORES)

func _on_options_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.OPTIONS_MENU)

func _on_credits_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.CREDITS_SCREEN)

func _on_quit_game_pressed() -> void:
	get_tree().quit()

func _on_quit_to_menu_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.MAIN_MENU)
	_update_menu_focus()

func _on_restart_pressed() -> void:
	game_manager.start_game()

func _on_options_back_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.MAIN_MENU)
	_update_menu_focus()

func _on_credits_back_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.MAIN_MENU)
	_update_menu_focus()

func _on_high_scores_back_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.MAIN_MENU)
	_update_menu_focus()

func reset_high_scores() -> void:
	SaveDataUtil.save_high_scores([])
	high_scores = SaveDataUtil.load_high_scores()

func _on_score_updated(new_score: int) -> void:
	score = new_score
	score_display_label.text = "Score: " + str(new_score)

func _on_high_scores_updated(new_high_scores: Array[int]) -> void:
	high_scores = new_high_scores

func _on_window_resize() -> void:
	_update_game_area()
