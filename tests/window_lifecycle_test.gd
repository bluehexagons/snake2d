extends SceneTree

const MAIN := preload("res://scenes/main/main.tscn")
var check := TestAssertions.new()
var files := TestFiles.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := _create_main()
	main.ui_state_manager.set_reduced_motion(true)
	await process_frame
	if OS.has_feature("windows") and DisplayServer.get_name() != "headless":
		await _expect_minimized_fullscreen(main.settings_service)
	root.focus_exited.emit()
	check.expect_equal(main.game_session.state, GameSession.State.MAIN_MENU, "unfocused menus remain menus")
	await _expect_pointer_gameplay_input(main)
	main.start_new_round()
	_expect_mouse_mode_ignores_idle_controller(main)
	_expect_reduced_motion_camera(main)
	main.gameplay.request_direction(Vector2i.RIGHT)
	await physics_frame
	var adapter := main.snake_input_adapter
	var turns: Array[Vector2i] = []
	adapter.direction_requested.connect(func(direction: Vector2i) -> void: turns.append(direction))
	var touch := InputEventScreenTouch.new()
	touch.index = 5
	touch.position = Vector2(80, 80)
	touch.pressed = true
	adapter._unhandled_input(touch)
	root.focus_exited.emit()
	check.expect_equal(main.game_session.state, GameSession.State.PAUSED, "losing window focus pauses a live round")
	check.expect_true(paused, "focus loss uses the session's tree pause")
	var tick := main.gameplay.model.tick_count
	var interpolation := main.gameplay.time_since_tick
	for frame in 5:
		await physics_frame
	check.expect_equal(main.gameplay.model.tick_count, tick, "unfocused rounds do not advance ticks")
	check.expect_equal(main.gameplay.time_since_tick, interpolation, "unfocused rounds freeze interpolation")
	root.focus_entered.emit()
	check.expect_equal(main.game_session.state, GameSession.State.PAUSED, "returning focus waits for explicit resume")
	main.game_session.resume_round()
	check.expect_equal(main.game_session.state, GameSession.State.PLAYING, "an unfocused round can be resumed explicitly")
	touch.pressed = false
	adapter._unhandled_input(touch)
	check.expect_true(turns.is_empty(), "a touch from before focus loss cannot turn after resume")
	main.game_session.end_round(10)
	root.focus_exited.emit()
	check.expect_equal(main.game_session.state, GameSession.State.GAME_OVER, "focus loss does not replace game over")
	main.free()
	await process_frame
	check.expect_false(paused, "removing the scene releases tree pause")
	_expect_board_completion()
	_expect_pitfall_hud_and_results()
	_expect_obstacle_replay()
	_expect_submenu_focus()
	_expect_current_high_scores()
	_expect_pause_shortcuts()
	_expect_first_move_timing()
	_expect_idle_render_policy()
	_expect_gameplay_fps_limit()
	await _expect_buffered_keyboard_turns()
	_expect_stick_turns()
	if DisplayServer.get_name() != "headless":
		# Earlier fixtures free scenes mid-cue. Let the native mixer retire them.
		await create_timer(AudioService.SHUTDOWN_DRAIN_SECONDS).timeout
	files.cleanup()
	check.finish(self, "Window lifecycle test")

func _create_main(rules: GameRules = null, settings_filename := "settings.cfg") -> Main:
	var main := MAIN.instantiate() as Main
	if rules != null:
		main.game_rules = rules
	(main.get_node("Services/HighScoreStore") as HighScoreStore).save_path = files.path("scores.dat")
	var settings := main.get_node("Services/SettingsService") as SettingsService
	settings.settings_path = files.path(settings_filename)
	settings.legacy_settings_path = files.path("legacy.dat")
	root.add_child(main)
	return main

func _expect_board_completion() -> void:
	var rules := GameRules.new()
	rules.columns = 2
	rules.rows = 1
	var main := _create_main(rules)
	main.start_new_round()
	main.gameplay.request_direction(Vector2i.LEFT)
	var result := main.gameplay.advance_one_tick()
	check.expect_equal(result, SnakeGame.StepResult.FILLED_BOARD, "the only food completes the board")
	check.expect_equal(main.game_session.state, GameSession.State.GAME_OVER, "completion ends the round")
	check.expect_equal(main.game_over_panel.title_label.text, "Board Complete", "completion displays its own heading")
	check.expect_equal(main.game_over_panel.score_label.text, "Final Score: %d" % rules.points_per_food, "completion shows the final score")
	var head := main.gameplay.snake.get_node("Head") as SnakeSegment
	check.expect_equal(head.color, SnakeView.HEAD_COLOR, "the winning snake keeps its live color")
	main.start_new_round()
	main.gameplay.request_direction(Vector2i.RIGHT)
	check.expect_equal(main.gameplay.advance_one_tick(), SnakeGame.StepResult.HIT_WALL, "the next round can end in a collision")
	check.expect_equal(main.game_over_panel.title_label.text, "Game Over", "a collision restores the loss heading")
	check.expect_equal(main.game_over_panel.cause_label.text, "Hit the wall", "wall collisions explain the loss")
	main.free()

func _expect_pitfall_hud_and_results() -> void:
	var main := _create_main()
	main.game_session.start_new_round(GameMode.Value.PITFALL)
	var gameplay := main.gameplay
	check.expect_true(main.mode_display_label.text.ends_with("3 meals"), "Pitfall shows the starting cadence")
	gameplay.request_direction(Vector2i.RIGHT)
	for expected in ["2 meals", "1 meal", "3 meals"]:
		gameplay.model.food_cell = gameplay.model.snake.next_head_cell()
		check.expect_equal(gameplay.advance_one_tick(), SnakeGame.StepResult.ATE_FOOD, "food advances the pit cadence")
		check.expect_true(main.mode_display_label.text.ends_with(expected), "the HUD updates meals remaining")
	check.expect_equal(gameplay.model.obstacle_cells.size(), 1, "the countdown restarts when a pit appears")
	gameplay.model.obstacle_cells.append(gameplay.model.snake.next_head_cell())
	gameplay.advance_one_tick()
	check.expect_equal(main.game_over_panel.cause_label.text, "Fell into a pit", "Pitfall identifies its hazard")
	check.expect_true(main.game_over_panel.personal_best_label.visible, "the results show a new best for the mode")
	main.free()

func _expect_obstacle_replay() -> void:
	var main := _create_main()
	var results := main.game_over_panel
	main.game_session.start_new_round(GameMode.Value.OBSTACLES, 424242)
	var walls := main.gameplay.model.obstacle_cells.duplicate()
	main.game_session.end_round(0)
	check.expect_false(main.gameplay_hud.visible, "the results replace the gameplay HUD")
	check.expect_true(results.round_details_label.text.contains("424242"), "results identify the layout behind Retry")
	check.expect_equal(results.restart_button.text, "Retry Layout", "the seeded replay action names what it keeps")
	check.expect_equal(root.gui_get_focus_owner(), results.restart_button, "retry receives focus on the results screen")
	results.restart_button.pressed.emit()
	check.expect_equal(main.game_session.current_world_seed, 424242, "retry keeps the seed")
	check.expect_equal(main.gameplay.model.obstacle_cells, walls, "retry keeps the same walls")
	main.main_menu.world_seed_spin_box.value = 424242
	main.game_session.end_round(0)
	results.new_seed_button.pressed.emit()
	var new_seed := main.game_session.current_world_seed
	check.expect_true(new_seed != 424242, "New Seed starts a different world seed even if the menu seed matches")
	check.expect_equal(main.game_session.current_mode, GameMode.Value.OBSTACLES, "New Seed stays in Obstacles mode")
	check.expect_true(main.mode_display_label.text.contains(str(new_seed)), "the HUD shows the new seed")
	main.free()

func _expect_submenu_focus() -> void:
	var main := _create_main()
	main.main_menu.mode_selector.select(GameMode.Value.OBSTACLES)
	main.main_menu.scores_button.pressed.emit()
	check.expect_equal(main.high_scores_menu.mode_selector.get_selected_id(), GameMode.Value.OBSTACLES, "scores open to the selected game mode")
	_push_key(KEY_ESCAPE)
	check.expect_equal(root.gui_get_focus_owner(), main.main_menu.scores_button, "Escape returns focus to High Scores")
	main.main_menu.options_button.pressed.emit()
	main.options_menu.back_button.pressed.emit()
	check.expect_equal(root.gui_get_focus_owner(), main.main_menu.options_button, "Back returns focus to Options")
	main.main_menu.credits_button.pressed.emit()
	check.expect_equal(root.gui_get_focus_owner(), main.credits_screen.back_button, "Credits opens with Back focused")
	_push_key(KEY_UP)
	check.expect_equal(root.gui_get_focus_owner(), main.credits_screen.source_button, "Up reaches the GitHub source button")
	_push_key(KEY_ESCAPE)
	check.expect_equal(root.gui_get_focus_owner(), main.main_menu.credits_button, "Escape from the source button returns focus to Credits")
	main.free()

func _expect_current_high_scores() -> void:
	var main := _create_main()
	main.main_menu.mode_selector.select(GameMode.Value.OBSTACLES)
	main.game_session.start_new_round(GameMode.Value.OBSTACLES, 424242)
	main.game_session.end_round(12345)
	main.game_session.return_to_menu()
	main.main_menu.scores_button.pressed.emit()
	var rows := main.high_scores_menu.scores_list
	var first_score := rows.get_child(0).get_node_or_null("Score") as Label
	check.expect_true(first_score != null and first_score.text == "12345", "High Scores shows the latest completed round")
	_push_key(KEY_ESCAPE)
	main.reset_high_scores()
	main.main_menu.scores_button.pressed.emit()
	check.expect_equal(rows.get_child(0).text, "No scores in this mode yet", "reopening High Scores shows the cleared table")
	main.free()

func _expect_pause_shortcuts() -> void:
	var main := _create_main()
	main.start_new_round()
	_push_key(KEY_SPACE)
	check.expect_equal(main.game_session.state, GameSession.State.PAUSED, "Space pauses gameplay")
	var pause_hint := main.pause_menu.get_node("Content/PanelContainer/MarginContainer/MenuLayout/Actions/ButtonHints/Label") as Label
	check.expect_equal(pause_hint.text, "Enter  Select    Esc  Resume", "pause identifies Escape as Resume")
	_push_key(KEY_ESCAPE)
	check.expect_equal(main.game_session.state, GameSession.State.PLAYING, "the Escape prompt resumes the round")
	_push_key(KEY_SPACE)
	var controller_back := InputEventJoypadButton.new()
	controller_back.button_index = JOY_BUTTON_B
	controller_back.pressed = true
	root.push_input(controller_back, true)
	check.expect_equal(pause_hint.text, "A  Select    B  Resume", "pause identifies controller B as Resume")
	check.expect_equal(main.game_session.state, GameSession.State.PLAYING, "the controller prompt resumes the round")
	_push_key(KEY_SPACE)
	_push_key(KEY_DOWN)
	check.expect_equal(root.gui_get_focus_owner(), main.pause_menu.menu_button, "Down focuses End Run")
	var end_run_presses: Array[bool] = []
	main.pause_menu.menu_button.button_down.connect(func() -> void: end_run_presses.append(true))
	_push_key(KEY_SPACE)
	check.expect_equal(main.game_session.state, GameSession.State.PLAYING, "Space resumes even when End Run has focus")
	check.expect_true(end_run_presses.is_empty(), "Space never presses End Run while resuming")
	_push_key(KEY_SPACE)
	var repeat := InputEventKey.new()
	repeat.physical_keycode = KEY_SPACE
	repeat.keycode = KEY_SPACE
	repeat.pressed = true
	repeat.echo = true
	root.push_input(repeat, true)
	check.expect_equal(main.game_session.state, GameSession.State.PAUSED, "holding Space does not toggle pause again")
	_push_key(KEY_P)
	check.expect_equal(main.game_session.state, GameSession.State.PLAYING, "P resumes the round")
	_push_key(KEY_P)
	_push_key(KEY_DOWN)
	_push_key(KEY_ENTER)
	check.expect_equal(main.game_session.state, GameSession.State.MAIN_MENU, "Enter can still select End Run")
	main.main_menu.options_button.grab_focus()
	_push_key(KEY_SPACE)
	check.expect_equal(main.get_current_ui_state(), UIStateManager.UIState.OPTIONS_MENU, "Space still selects in the main menu")
	main.free()

func _expect_first_move_timing() -> void:
	var main := _create_main()
	main.start_new_round()
	var gameplay := main.gameplay
	var spawn := gameplay.model.snake.body[0]
	gameplay.model.food_cell = Vector2i.ZERO
	var tick_duration := gameplay.model.current_tick_seconds()
	gameplay._physics_process(tick_duration * 2.5)
	check.expect_equal(gameplay.time_since_tick, 0.0, "the ready prompt does not start the tick clock")
	check.expect_equal(gameplay.model.tick_count, 0, "waiting leaves the snake at spawn")
	gameplay.request_direction(Vector2i.RIGHT)
	gameplay._physics_process(tick_duration / 10.0)
	check.expect_equal(gameplay.model.snake.body[0], spawn + Vector2i.RIGHT, "the first physics frame after input moves the snake")
	gameplay._physics_process(tick_duration / 2.0)
	check.expect_equal(gameplay.model.tick_count, 1, "the second move waits for the normal tick interval")
	main.free()

func _expect_idle_render_policy() -> void:
	var previous_mode := OS.low_processor_usage_mode
	var main := _create_main()
	check.expect_true(OS.low_processor_usage_mode, "the main menu renders on demand")
	main.start_new_round()
	check.expect_true(OS.low_processor_usage_mode, "waiting for a direction renders on demand")
	check.expect_equal(main.camera_node.process_mode, Node.PROCESS_MODE_DISABLED, "the ready camera keeps its framing without per-frame scroll updates")
	main.game_session.pause_round()
	main.game_session.resume_round()
	check.expect_true(OS.low_processor_usage_mode, "resuming before the first direction stays idle")
	main.gameplay.request_direction(Vector2i.RIGHT)
	check.expect_false(OS.low_processor_usage_mode, "the first direction restores normal frame pacing")
	check.expect_equal(main.camera_node.process_mode, Node.PROCESS_MODE_INHERIT, "the moving camera follows the game world")
	main.game_session.pause_round()
	check.expect_true(OS.low_processor_usage_mode, "a paused round renders on demand")
	main.game_session.resume_round()
	check.expect_false(OS.low_processor_usage_mode, "resuming a moving round restores normal frame pacing")
	main.game_session.end_round(0)
	check.expect_true(OS.low_processor_usage_mode, "results render on demand")
	main.game_session.return_to_menu()
	check.expect_true(OS.low_processor_usage_mode, "returning to the menu keeps on-demand rendering")
	main.free()
	check.expect_equal(OS.low_processor_usage_mode, previous_mode, "removing Main restores the engine's rendering mode")

func _expect_gameplay_fps_limit() -> void:
	const SETTINGS_FILE := "frame-limit-settings.cfg"
	var previous_max_fps := Engine.max_fps
	Engine.max_fps = 60
	var main := _create_main(null, SETTINGS_FILE)
	var options := main.options_menu
	main.main_menu.options_button.pressed.emit()
	check.expect_false(options.fps_limit_button.button_pressed, "the frame limit starts off")
	options.grid_button.grab_focus()
	_push_key(KEY_DOWN)
	check.expect_equal(root.gui_get_focus_owner(), options.fps_limit_button, "the limit is reachable below Gameplay Grid")
	_push_key(KEY_ENTER)
	check.expect_true(main.settings_service.limit_gameplay_fps, "selecting the limit saves the preference")
	_push_key(KEY_ESCAPE)
	main.start_new_round()
	check.expect_equal(Engine.max_fps, 60, "waiting for input keeps normal frame pacing")
	main.gameplay.request_direction(Vector2i.RIGHT)
	check.expect_equal(Engine.max_fps, 30, "the first direction applies the gameplay limit")
	main.game_session.pause_round()
	check.expect_equal(Engine.max_fps, 60, "pause restores normal frame pacing")
	main.game_session.resume_round()
	check.expect_equal(Engine.max_fps, 30, "resume reapplies the gameplay limit")
	main.free()
	check.expect_equal(Engine.max_fps, 60, "removing Main restores the prior engine limit")
	Engine.max_fps = 24
	main = _create_main(null, SETTINGS_FILE)
	check.expect_true(main.options_menu.fps_limit_button.button_pressed, "reopening the game restores the toggle")
	main.start_new_round()
	main.gameplay.request_direction(Vector2i.RIGHT)
	check.expect_equal(Engine.max_fps, 24, "the gameplay option respects a lower launch limit")
	main.free()
	Engine.max_fps = previous_max_fps

func _expect_buffered_keyboard_turns() -> void:
	var main := _create_main()
	main.start_new_round()
	var gameplay := main.gameplay
	var spawn := gameplay.model.snake.body[0]
	gameplay.model.food_cell = Vector2i.ZERO
	_push_key(KEY_UP)
	_push_key(KEY_LEFT)
	check.expect_equal(gameplay.snake.queued_direction, Vector2i.UP, "the arrow shows the next tick's heading")
	main.game_session.pause_round()
	for frame in 3:
		await physics_frame
	check.expect_equal(gameplay.model.snake.body[0], spawn, "pausing freezes accepted turns")
	main.game_session.resume_round()
	gameplay.advance_one_tick_and_snap()
	check.expect_equal(gameplay.model.snake.body[0], spawn + Vector2i.UP, "the first turn survives pause")
	check.expect_equal(gameplay.snake.queued_direction, Vector2i.LEFT, "the arrow shows the follow-up after the first tick")
	main.game_session.pause_round()
	_push_key(KEY_DOWN)
	main.game_session.resume_round()
	gameplay.advance_one_tick_and_snap()
	check.expect_equal(gameplay.model.snake.body[0], spawn + Vector2i(-1, -1), "the follow-up survives pause")
	check.expect_equal(gameplay.snake.queued_direction, Vector2i.LEFT, "input while paused does not replace the heading")
	main.game_session.pause_round()
	await create_timer(0.1).timeout
	main.free()

func _push_key(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	root.push_input(key, true)
	key = key.duplicate() as InputEventKey
	key.pressed = false
	root.push_input(key, true)

func _expect_stick_turns() -> void:
	var main := _create_main()
	main.start_new_round()
	var gameplay := main.gameplay
	var spawn := gameplay.model.snake.body[0]
	gameplay.model.food_cell = Vector2i.ZERO
	_push_stick(JOY_AXIS_LEFT_X, 0.95)
	gameplay.advance_one_tick_and_snap()
	check.expect_equal(gameplay.model.snake.body[0], spawn + Vector2i.RIGHT, "deflecting the stick starts a round")
	_push_stick(JOY_AXIS_LEFT_Y, -0.95)
	_push_stick(JOY_AXIS_LEFT_X, 0.91)
	gameplay.advance_one_tick_and_snap()
	check.expect_equal(gameplay.model.snake.body[0], spawn + Vector2i(1, -1), "a new stick axis can turn while another is held")
	check.expect_equal(gameplay.snake.queued_direction, Vector2i.UP, "held-axis updates cannot queue a follow-up turn")
	gameplay.advance_one_tick_and_snap()
	check.expect_equal(gameplay.model.snake.body[0], spawn + Vector2i(1, -2), "a held axis leaves the snake on its chosen heading")
	_push_stick(JOY_AXIS_LEFT_X, 0.0)
	_push_stick(JOY_AXIS_LEFT_X, 0.95)
	gameplay.advance_one_tick_and_snap()
	check.expect_equal(gameplay.model.snake.body[0], spawn + Vector2i(2, -2), "releasing and deflecting a stick axis makes a fresh turn")
	_push_stick(JOY_AXIS_LEFT_Y, 0.95)
	_push_stick(JOY_AXIS_LEFT_X, 0.48)
	_push_stick(JOY_AXIS_LEFT_X, 0.55)
	gameplay.advance_one_tick_and_snap()
	check.expect_equal(gameplay.model.snake.body[0], spawn + Vector2i(2, -1), "the opposite sign on an axis can make a fresh turn")
	check.expect_equal(gameplay.snake.queued_direction, Vector2i.DOWN, "brief dips below the press threshold cannot rearm a held axis")
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_LEFT
	dpad.pressed = true
	root.push_input(dpad, true)
	gameplay.advance_one_tick_and_snap()
	check.expect_equal(gameplay.model.snake.body[0], spawn + Vector2i(1, -1), "D-pad turns remain independent of the stick")
	main.free()

func _push_stick(axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	root.push_input(motion, true)

func _expect_pointer_gameplay_input(main: Main) -> void:
	main.start_new_round()
	await process_frame
	var gameplay := main.gameplay
	var snake := gameplay.snake
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = snake.get_global_transform_with_canvas() * Vector2(snake.cell_size / 2.0, -2.0)
	click.pressed = true
	root.push_input(click, true)
	check.expect_false(gameplay.model.snake.waiting_for_input, "a click on the tutorial starts gameplay")
	check.expect_equal(gameplay.model.snake.queued_direction, Vector2i.UP, "a click above the visible head turns up")
	click.pressed = false
	root.push_input(click, true)
	main.game_session.return_to_menu()

	main.start_new_round()
	await process_frame
	snake = gameplay.snake
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.position = snake.get_global_transform_with_canvas() * Vector2(-2.0, snake.cell_size / 2.0)
	touch.pressed = true
	root.push_input(touch, true)
	check.expect_equal(main.first_move_hint.text, "Swipe or tap to move", "touch shows the gesture hint")
	check.expect_true(gameplay.model.snake.waiting_for_input, "a touch press waits for a tap or swipe")
	touch.pressed = false
	root.push_input(touch, true)
	check.expect_false(gameplay.model.snake.waiting_for_input, "a tap on the tutorial starts gameplay")
	check.expect_equal(gameplay.model.snake.queued_direction, Vector2i.LEFT, "a tap left of the visible head turns left")
	main.game_session.return_to_menu()

	main.start_new_round()
	await process_frame
	touch.position = gameplay.snake.get_global_transform_with_canvas() * Vector2.ONE
	touch.pressed = true
	root.push_input(touch, true)
	var drag := InputEventScreenDrag.new()
	drag.index = touch.index
	drag.relative = Vector2(0.0, main.snake_input_adapter.get_drag_threshold_pixels() + 1.0)
	drag.screen_relative = drag.relative
	drag.position = touch.position + drag.relative
	root.push_input(drag, true)
	check.expect_false(gameplay.model.snake.waiting_for_input, "a swipe on the tutorial starts gameplay before release")
	check.expect_equal(gameplay.model.snake.queued_direction, Vector2i.DOWN, "a swipe follows the drag direction")
	touch.position = drag.position
	touch.pressed = false
	root.push_input(touch, true)
	main.game_session.return_to_menu()

func _expect_mouse_mode_ignores_idle_controller(main: Main) -> void:
	var mouse := InputEventMouseMotion.new()
	root.push_input(mouse, true)
	check.expect_true(main.using_mouse, "mouse motion selects mouse input")
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	for value in [0.0, 0.49, -0.49]:
		motion.axis_value = value
		root.push_input(motion, true)
		check.expect_true(main.using_mouse, "neutral and drifting controllers do not hide mouse input")
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 1.0
	root.push_input(motion, true)
	check.expect_true(main.using_mouse, "unmapped controller axes do not change input mode")
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 1.0
	root.push_input(motion, true)
	check.expect_false(main.using_mouse, "mapped stick movement selects controller input")
	check.expect_equal(main.first_move_hint.text, "D-pad or left stick to move", "controller input shows the controller hint")
	root.push_input(mouse, true)
	check.expect_true(main.using_mouse, "mouse movement restores mouse input after a controller")
	check.expect_equal(main.first_move_hint.text, "Click to steer, or use arrows / WASD", "pointer hint also exposes keyboard bindings")
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key, true)
	check.expect_equal(main.first_move_hint.text, "Arrow keys or WASD to move", "a key switches to keyboard hints")

func _expect_reduced_motion_camera(main: Main) -> void:
	var center := Vector2(main.game_rules.board_size_pixels()) / 2.0
	main.camera_node.position = center + Vector2(20.0, 0.0)
	main.settings_service.toggle_reduced_motion()
	check.expect_equal(main.camera_node.position, center, "reduced motion centers the camera immediately")
	main.camera_node._physics_process(1.0 / 60.0)
	check.expect_equal(main.camera_node.target, center, "reduced motion keeps the camera centered during play")

func _expect_minimized_fullscreen(settings: SettingsService) -> void:
	settings.toggle_fullscreen()
	await create_timer(0.25).timeout
	check.expect_equal(DisplayServer.window_get_mode(), DisplayServer.WINDOW_MODE_FULLSCREEN, "native window enters fullscreen")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	await create_timer(0.25).timeout
	check.expect_equal(DisplayServer.window_get_mode(), DisplayServer.WINDOW_MODE_MINIMIZED, "native window minimizes")
	check.expect_true(settings.is_fullscreen, "native minimization keeps the fullscreen preference")
	var config := ConfigFile.new()
	config.load(settings.settings_path)
	check.expect_true(config.get_value("display", "fullscreen", false), "native minimization preserves fullscreen on disk")
	settings.toggle_fullscreen()
	await create_timer(0.25).timeout
	check.expect_equal(DisplayServer.window_get_mode(), DisplayServer.WINDOW_MODE_WINDOWED, "native window restores to windowed mode on request")
