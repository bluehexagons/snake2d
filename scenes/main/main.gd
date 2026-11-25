class_name Main
extends Control

@export var game_rules: GameRules

enum InputDevice { MOUSE, KEYBOARD, TOUCH, CONTROLLER }

const PAUSE_SCRIM_ALPHA := 0.86
const RESULT_SCRIM_ALPHA := 0.50

var high_scores_by_mode: Dictionary = {}

var _input_device := InputDevice.MOUSE
var using_mouse: bool:
	get:
		return _input_device == InputDevice.MOUSE
var _button_tweens: Dictionary[Button, Tween] = {}
var _game_size_pixels := Vector2i.ZERO
var _quitting := false

@onready var ui_state_manager: UIStateManager = $UIStateManager
@onready var audio_service: AudioService = %AudioService
@onready var high_score_store: HighScoreStore = %HighScoreStore
@onready var settings_service: SettingsService = %SettingsService
@onready var game_session: GameSession = %GameSession
@onready var ui_layer: ResponsiveUILayer = $UILayer
@onready var ui_background: ColorRect = %UIBackground
@onready var gameplay_hud: PanelContainer = %GameplayHUD
@onready var score_display_label: Label = %HUDScoreLabel
@onready var mode_display_label: Label = %HUDModeLabel
@onready var controls_tutorial: Control = %ControlsTutorial
@onready var first_move_hint: Label = controls_tutorial.get_node("HintArea/Panel/FirstMoveHint")
@onready var gameplay_pause_button: Button = %GameplayPauseButton

@onready var game_world: Node2D = %GameWorld
@onready var gameplay: Gameplay = %Gameplay
@onready var snake_input_adapter: SnakeInputAdapter = %SnakeInputAdapter
@onready var play_area_background: Panel = %PlayAreaBackground
@onready var gameplay_grid: GameplayGrid = %GameplayGrid
@onready var camera_node: SnakeCamera = %SnakeCamera

@onready var main_menu: MainMenu = %MainMenu
@onready var options_menu: OptionsMenu = %OptionsMenu
@onready var credits_screen: CreditsScreen = %CreditsScreen
@onready var high_scores_menu: HighScoresMenu = %HighScoresMenu
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var game_over_panel: GameOverPanel = %GameOverPanel
@onready var debug_overlay: DebugOverlay = %DebugOverlay

func _ready() -> void:
	set_process_mode(Node.PROCESS_MODE_ALWAYS)

	assert(game_rules != null, "Main requires a GameRules resource.")
	_game_size_pixels = game_rules.board_size_pixels()

	game_session.configure(gameplay, high_score_store)
	# Alt-Tab/minimize must not advance a round the player cannot control.
	# Focus returning leaves the pause menu up for an explicit resume.
	get_window().focus_exited.connect(game_session.pause_round)
	get_window().close_requested.connect(_quit_game)
	gameplay.configure(game_rules, audio_service)
	gameplay.first_direction_accepted.connect(controls_tutorial.hide)
	gameplay_grid.configure(game_rules)
	snake_input_adapter.configure(gameplay)
	snake_input_adapter.set_enabled(game_session.state == GameSession.State.PLAYING)
	snake_input_adapter.direction_requested.connect(gameplay.request_direction)
	debug_overlay.configure(game_session, gameplay)
	settings_service.configure(audio_service, ui_state_manager, gameplay_grid)
	options_menu.set_settings_service(settings_service)
	camera_node.configure(game_rules, gameplay)
	ui_layer.gameplay_inset_changed.connect(camera_node.set_top_inset)
	camera_node.set_top_inset(ui_layer.gameplay_top_inset())
	settings_service.settings_changed.connect(_apply_motion_setting)
	_apply_motion_setting()

	ui_state_manager.state_changed.connect(_on_ui_state_changed)

	ui_state_manager.register_ui_element(ui_state_manager.UIState.MAIN_MENU, main_menu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.OPTIONS_MENU, options_menu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.CREDITS_SCREEN, credits_screen)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.HIGH_SCORES, high_scores_menu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.PAUSED, pause_menu)
	ui_state_manager.register_ui_element(ui_state_manager.UIState.GAME_OVER, game_over_panel)

	ui_state_manager.register_focus_target(ui_state_manager.UIState.MAIN_MENU, main_menu.get_default_focus())
	ui_state_manager.register_focus_target(ui_state_manager.UIState.OPTIONS_MENU, options_menu.get_default_focus())
	ui_state_manager.register_focus_target(ui_state_manager.UIState.CREDITS_SCREEN, credits_screen.get_default_focus())
	ui_state_manager.register_focus_target(ui_state_manager.UIState.HIGH_SCORES, high_scores_menu.get_default_focus())
	ui_state_manager.register_focus_target(ui_state_manager.UIState.PAUSED, pause_menu.get_default_focus())
	ui_state_manager.register_focus_target(ui_state_manager.UIState.GAME_OVER, game_over_panel.get_default_focus())

	high_scores_by_mode = game_session.get_all_high_scores()

	main_menu.start_requested.connect(_on_start_pressed)
	main_menu.scores_requested.connect(_on_scores_pressed)
	main_menu.options_requested.connect(_on_options_pressed)
	main_menu.credits_requested.connect(_on_credits_pressed)
	main_menu.quit_requested.connect(_quit_game)
	options_menu.options_closed.connect(_on_options_back_pressed)
	options_menu.reset_scores_requested.connect(reset_high_scores)
	options_menu.volume_preview_requested.connect(audio_service.play_eat)
	credits_screen.credits_screen_closed.connect(_on_credits_back_pressed)
	high_scores_menu.high_scores_closed.connect(_on_high_scores_back_pressed)
	pause_menu.resume_requested.connect(_on_resume_pressed)
	pause_menu.menu_requested.connect(_on_quit_to_menu_pressed)
	gameplay_pause_button.pressed.connect(game_session.pause_round)
	game_over_panel.restart_requested.connect(_on_restart_pressed)
	game_over_panel.new_seed_requested.connect(_on_new_seed_pressed)
	game_over_panel.menu_requested.connect(_on_quit_to_menu_pressed)

	game_session.state_changed.connect(_on_session_state_changed)
	game_session.score_updated.connect(_on_score_updated)
	game_session.high_scores_updated.connect(_on_high_scores_updated)

	ui_background.visible = false
	main_menu.visible = true
	options_menu.visible = false
	gameplay_hud.visible = false
	game_world.visible = false
	if DisplayServer.is_touchscreen_available():
		_input_device = InputDevice.TOUCH
	_update_input_hints()
	_update_cursor_visibility()

	for button in _get_all_buttons():
		if not button.button_down.is_connected(audio_service.play_click):
			button.button_down.connect(audio_service.play_click)
		if not button.focus_entered.is_connected(audio_service.play_focus):
			button.focus_entered.connect(audio_service.play_focus)
		_install_button_polish(button)

	_update_menu_focus()
	get_tree().root.size_changed.connect(_on_window_resize)
	_on_window_resize()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and not _has_active_joypad_action(event):
		return
	var device := _input_device
	if (
		(event is InputEventMouseButton or event is InputEventMouseMotion)
		and event.device != InputEvent.DEVICE_ID_EMULATION
	):
		device = InputDevice.MOUSE
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		device = InputDevice.CONTROLLER
	elif event is InputEventKey:
		device = InputDevice.KEYBOARD
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		device = InputDevice.TOUCH
	if device != _input_device:
		_input_device = device
		_update_input_hints()
		_update_cursor_visibility()

func _update_input_hints() -> void:
	var menu_hint := "Enter  Select    Esc  Back"
	match _input_device:
		InputDevice.KEYBOARD:
			first_move_hint.text = "Arrow keys or WASD to move"
		InputDevice.MOUSE:
			first_move_hint.text = "Click to steer, or use arrows / WASD"
		InputDevice.TOUCH:
			first_move_hint.text = "Swipe or tap to move"
		InputDevice.CONTROLLER:
			first_move_hint.text = "D-pad or left stick to move"
			menu_hint = "A  Select    B  Back"
	for menu in ui_state_manager.ui_elements.values():
		var hint := menu.get_node("Content/PanelContainer/MarginContainer/MenuLayout/Actions/ButtonHints/Label") as Label
		hint.text = menu_hint
		hint.visible = _input_device != InputDevice.TOUCH

func _has_active_joypad_action(event: InputEventJoypadMotion) -> bool:
	# Neutral axes and stick drift must not hide a mouse-controlled cursor.
	for action in [&"up", &"down", &"left", &"right", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		if event.is_action_pressed(action):
			return true
	return false

func _update_cursor_visibility() -> void:
	var active_gameplay: bool = ui_state_manager.current_state == UIStateManager.UIState.GAMEPLAY
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (not active_gameplay or using_mouse) else Input.MOUSE_MODE_HIDDEN

func _update_game_area() -> void:
	var window_size := get_viewport_rect().size
	var game_size := Vector2(_game_size_pixels)
	game_world.position = (window_size - game_size) / 2.0
	play_area_background.size = game_size

func _toggle_pause() -> void:
	game_session.toggle_pause()

func _on_resume_pressed() -> void:
	game_session.resume_round()

func _on_start_pressed(mode: GameMode.Value, world_seed: int) -> void:
	game_session.start_new_round(mode, world_seed)

func _on_session_state_changed(old_state: GameSession.State, new_state: GameSession.State) -> void:
	snake_input_adapter.set_enabled(new_state == GameSession.State.PLAYING)
	match new_state:
		GameSession.State.MAIN_MENU:
			ui_state_manager.change_state(UIStateManager.UIState.MAIN_MENU)
		GameSession.State.PLAYING:
			if old_state != GameSession.State.PAUSED:
				camera_node.reset_camera()
			ui_state_manager.change_state(UIStateManager.UIState.GAMEPLAY)
		GameSession.State.PAUSED:
			ui_state_manager.change_state(UIStateManager.UIState.PAUSED)
		GameSession.State.GAME_OVER:
			game_over_panel.show_result(
				game_session.current_score,
				gameplay.get_round_result(),
				game_session.current_mode,
				game_session.new_personal_best
			)
			ui_state_manager.change_state(UIStateManager.UIState.GAME_OVER)

func _on_ui_state_changed(old_state: int, new_state: int) -> void:
	ui_layer.set_gameplay_pause_visible(new_state == UIStateManager.UIState.GAMEPLAY)
	controls_tutorial.visible = new_state == UIStateManager.UIState.GAMEPLAY and gameplay.is_waiting_for_input()
	match new_state:
		ui_state_manager.UIState.GAMEPLAY:
			ui_background.visible = false
			gameplay_hud.visible = true
			game_world.visible = true
			_update_cursor_visibility()
		ui_state_manager.UIState.MAIN_MENU:
			ui_background.visible = false
			gameplay_hud.visible = false
			game_world.visible = false
			_update_cursor_visibility()
		ui_state_manager.UIState.PAUSED:
			ui_background.color.a = PAUSE_SCRIM_ALPHA
			ui_background.visible = true
			_update_cursor_visibility()
		ui_state_manager.UIState.GAME_OVER:
			ui_background.color.a = RESULT_SCRIM_ALPHA
			ui_background.visible = true
			_update_cursor_visibility()
		_:
			if old_state == ui_state_manager.UIState.GAMEPLAY:
				ui_background.visible = true

	_update_menu_focus()

func is_round_active() -> bool:
	return game_session.is_round_active()

func start_new_round() -> void:
	game_session.start_new_round(game_session.current_mode, game_session.current_world_seed)

func get_current_ui_state() -> UIStateManager.UIState:
	return ui_state_manager.current_state

func _get_all_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	buttons.append_array(main_menu.get_buttons())
	buttons.append_array(options_menu.get_buttons())
	buttons.append_array(credits_screen.get_buttons())
	buttons.append_array(high_scores_menu.get_buttons())
	buttons.append_array(pause_menu.get_buttons())
	buttons.append_array(game_over_panel.get_buttons())
	buttons.append(gameplay_pause_button)
	return buttons

# Adds a subtle scale animation on focus/hover/press transitions for any Button.
func _install_button_polish(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
	)
	var animate_to := func(target_scale: Vector2, duration: float) -> void:
		if _button_tweens.has(btn):
			_button_tweens[btn].kill()
			_button_tweens.erase(btn)
		if settings_service.reduced_motion:
			btn.scale = Vector2.ONE
			return
		var tween := btn.create_tween()
		_button_tweens[btn] = tween
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

func _apply_motion_setting() -> void:
	camera_node.set_reduced_motion(settings_service.reduced_motion)
	if not settings_service.reduced_motion:
		return
	for button in _button_tweens:
		_button_tweens[button].kill()
		button.scale = Vector2.ONE
	_button_tweens.clear()

func _update_menu_focus() -> void:
	var current_state = ui_state_manager.current_state
	if current_state in ui_state_manager.focus_targets:
		ui_state_manager.focus_targets[current_state].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("up")
		or event.is_action_pressed("down")
		or event.is_action_pressed("left")
		or event.is_action_pressed("right")
	):
		if get_viewport().gui_get_focus_owner() == null:
			_update_menu_focus()
		return

	if event.is_action_pressed("pause"):
		if game_session.state == GameSession.State.PLAYING:
			game_session.pause_round()
		elif game_session.state == GameSession.State.PAUSED:
			game_session.resume_round()
		else:
			return
		get_viewport().set_input_as_handled()
		return

	if not event.is_action_pressed("ui_cancel"):
		return

	match game_session.state:
		GameSession.State.PLAYING:
			game_session.pause_round()
		GameSession.State.PAUSED:
			game_session.resume_round()
		GameSession.State.GAME_OVER:
			game_session.return_to_menu()
		GameSession.State.MAIN_MENU:
			if ui_state_manager.current_state == UIStateManager.UIState.MAIN_MENU:
				return
			ui_state_manager.go_back()

	get_viewport().set_input_as_handled()

func _on_scores_pressed() -> void:
	high_scores_menu.update_scores(high_scores_by_mode)
	ui_state_manager.change_state(ui_state_manager.UIState.HIGH_SCORES)

func _on_options_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.OPTIONS_MENU)

func _on_credits_pressed() -> void:
	ui_state_manager.change_state(ui_state_manager.UIState.CREDITS_SCREEN)

func _quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	await audio_service.drain_for_quit()
	get_tree().quit()

func _on_quit_to_menu_pressed() -> void:
	game_session.return_to_menu()

func _on_restart_pressed() -> void:
	start_new_round()

func _on_new_seed_pressed() -> void:
	if game_session.state == GameSession.State.GAME_OVER and game_session.current_mode == GameMode.Value.OBSTACLES:
		var seed := main_menu.take_next_world_seed(game_session.current_world_seed)
		game_session.start_new_round(GameMode.Value.OBSTACLES, seed)

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
	game_session.clear_high_scores()

func _on_score_updated(new_score: int) -> void:
	score_display_label.text = "Score: " + str(new_score)
	_update_mode_label()

func _on_high_scores_updated(mode: GameMode.Value, new_high_scores: Array[int]) -> void:
	high_scores_by_mode[GameMode.key(mode)] = new_high_scores

func _update_mode_label() -> void:
	var label_text := GameMode.display_name(game_session.current_mode)
	if game_session.current_mode == GameMode.Value.OBSTACLES:
		label_text += "  •  Seed %d" % game_session.current_world_seed
		if gameplay.model != null and not gameplay.model.obstacle_pattern_name.is_empty():
			label_text += "  •  %s" % gameplay.model.obstacle_pattern_name
	elif game_session.current_mode == GameMode.Value.PITFALL and gameplay.model != null:
		var remaining := gameplay.model.foods_until_next_pit()
		label_text += "  •  Next pit in %d %s" % [remaining, "meal" if remaining == 1 else "meals"]
	mode_display_label.text = label_text

func _on_window_resize() -> void:
	_update_game_area()
	camera_node.fit_to_viewport()
