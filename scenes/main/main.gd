extends Control

const ConfigData = preload("res://autoload/config.gd")
const SaveDataUtil = preload("res://autoload/save_data.gd")
const GameManagerScript = preload("res://autoload/game_manager.gd")

var GAME_WIDTH: int
var GAME_HEIGHT: int
var high_scores: Array[int] = []

var in_game := false
var is_mobile := false
var using_mouse := true

@onready var ui_state_manager: UIStateManager = $UIStateManager
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

	_setup_game_dependencies()
	_register_ui_states()
	_connect_ui_signals()
	_connect_game_signals()
	_initialize_presentation()

	get_tree().root.size_changed.connect(_on_window_resize)
	_on_window_resize()

func _setup_game_dependencies() -> void:
	if not game_manager:
		var game_manager_instance := GameManagerScript.new()
		game_manager_instance.name = "GameManager"
		add_child(game_manager_instance)
		game_manager = game_manager_instance

	game_manager.set_gameplay(gameplay)
	game_manager.set_save_data_util(SaveDataUtil)
	game_manager.set_config(ConfigData)
	camera_node.gameplay = gameplay

func _register_ui_states() -> void:
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

func _connect_ui_signals() -> void:
	_connect_button(main_menu_box.get_node("StartButton"), _on_start_pressed)
	_connect_button(main_menu_box.get_node("ScoresButton"), _on_scores_pressed)
	_connect_button(main_menu_box.get_node("OptionsButton"), _on_options_pressed)
	_connect_button(main_menu_box.get_node("CreditsButton"), _on_credits_pressed)
	_connect_button(main_menu_box.get_node("QuitButton"), _on_quit_game_pressed)

	options_menu.options_closed.connect(_on_options_back_pressed)
	options_menu.reset_scores_requested.connect(reset_high_scores)
	credits_screen.credits_screen_closed.connect(_on_credits_back_pressed)
	high_scores_menu.high_scores_closed.connect(_on_high_scores_back_pressed)

	_connect_button(pause_menu_box.get_node("ResumeButton"), _on_resume_pressed)
	_connect_button(pause_menu_box.get_node("QuitButton"), _on_quit_to_menu_pressed)
	_connect_button(game_over_menu_box.get_node("RestartButton"), _on_restart_pressed)
	_connect_button(game_over_menu_box.get_node("QuitButton"), _on_quit_to_menu_pressed)

func _connect_button(button: Button, callback: Callable) -> void:
	button.pressed.connect(callback)
	button.button_down.connect(AudioManager.play_click)

func _connect_game_signals() -> void:
	game_manager.game_started.connect(_on_game_started)
	game_manager.game_paused.connect(_on_game_paused)
	game_manager.game_resumed.connect(_on_game_resumed)
	game_manager.game_over.connect(_on_game_over)
	game_manager.score_updated.connect(_on_score_updated)
	game_manager.high_scores_updated.connect(_on_high_scores_updated)

func _initialize_presentation() -> void:
	is_mobile = (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)
	high_scores = game_manager.get_high_scores()

	get_tree().paused = true
	ui_background.visible = false
	main_menu.visible = true
	options_menu.visible = false
	score_display_label.visible = false
	game_world.visible = false
	_update_cursor_visibility()

	for button in _get_all_buttons():
		if not button.focus_entered.is_connected(AudioManager.play_focus):
			button.focus_entered.connect(AudioManager.play_focus)
		_install_button_polish(button)

	_update_menu_focus()
	_update_game_area()

func _input(event: InputEvent) -> void:
	if is_mobile:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		if not using_mouse:
			using_mouse = true
			_update_cursor_visibility()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion \
			or event is InputEventKey \
			or event is InputEventScreenTouch or event is InputEventScreenDrag:
		if using_mouse:
			using_mouse = false
			_update_cursor_visibility()

func _update_cursor_visibility() -> void:
	if is_mobile:
		return
	var active_gameplay: bool = ui_state_manager.current_state == UIStateManager.UIState.GAMEPLAY
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (not active_gameplay or using_mouse) else Input.MOUSE_MODE_HIDDEN

func _update_game_area() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var game_size := Vector2(GAME_WIDTH, GAME_HEIGHT)
	game_world.position = (viewport_size - game_size) / 2.0
	play_area_background.size = game_size

func _toggle_pause() -> void:
	var is_currently_paused: bool = ui_state_manager.current_state == UIStateManager.UIState.PAUSED
	ui_state_manager.set_paused(not is_currently_paused)

func _on_resume_pressed() -> void:
	ui_state_manager.set_paused(false)

func _on_start_pressed() -> void:
	game_manager.start_game()

func _on_game_started() -> void:
	# Called when game starts via GameManager
	in_game = true
	camera_node.reset_camera()
	ui_state_manager.change_state(ui_state_manager.UIState.GAMEPLAY)
	ui_background.visible = false
	score_display_label.visible = true
	game_world.visible = true
	get_tree().paused = false
	_update_cursor_visibility()

func _on_game_paused() -> void:
	# Called when game is paused via GameManager
	ui_background.visible = true

func _on_game_resumed() -> void:
	# Called when game is resumed via GameManager
	ui_background.visible = false
	_update_cursor_visibility()

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
			_update_cursor_visibility()
		ui_state_manager.UIState.MAIN_MENU:
			ui_background.visible = false
			score_display_label.visible = false
			game_world.visible = false
			get_tree().paused = true
			_update_cursor_visibility()
		ui_state_manager.UIState.PAUSED:
			ui_background.visible = true
			_update_cursor_visibility()
		ui_state_manager.UIState.GAME_OVER:
			in_game = false
			_update_cursor_visibility()
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
	if game_manager and game_manager.has_method("stop_game"):
		game_manager.stop_game()
	elif gameplay and gameplay.has_method("cleanup"):
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
	_cleanup_game()
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
	game_manager.clear_high_scores()

func _on_score_updated(new_score: int) -> void:
	score_display_label.text = "Score: " + str(new_score)

func _on_high_scores_updated(new_high_scores: Array[int]) -> void:
	high_scores = new_high_scores

func _on_window_resize() -> void:
	_update_game_area()
