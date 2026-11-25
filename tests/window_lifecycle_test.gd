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
	files.cleanup()
	check.finish(self, "Window lifecycle test")

func _create_main(rules: GameRules = null) -> Main:
	var main := MAIN.instantiate() as Main
	if rules != null:
		main.game_rules = rules
	(main.get_node("Services/HighScoreStore") as HighScoreStore).save_path = files.path("scores.dat")
	var settings := main.get_node("Services/SettingsService") as SettingsService
	settings.settings_path = files.path("settings.cfg")
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
	check.expect_equal(main.game_over_panel.title_label.text, "BOARD COMPLETE", "completion displays its own heading")
	check.expect_equal(main.game_over_panel.score_label.text, "Final Score: %d" % rules.points_per_food, "completion shows the final score")
	var head := main.gameplay.snake.get_node("Head") as SnakeSegment
	check.expect_equal(head.color, SnakeView.HEAD_COLOR, "the winning snake keeps its live color")
	main.start_new_round()
	main.gameplay.request_direction(Vector2i.RIGHT)
	check.expect_equal(main.gameplay.advance_one_tick(), SnakeGame.StepResult.HIT_WALL, "the next round can end in a collision")
	check.expect_equal(main.game_over_panel.title_label.text, "GAME OVER", "a collision restores the loss heading")
	main.free()

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
