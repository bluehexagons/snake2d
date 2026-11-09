extends SceneTree

const MAIN := preload("res://scenes/main/main.tscn")
var check := TestAssertions.new()
var files := TestFiles.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := MAIN.instantiate() as Main
	(main.get_node("Services/HighScoreStore") as HighScoreStore).save_path = files.path("scores.dat")
	var settings := main.get_node("Services/SettingsService") as SettingsService
	settings.settings_path = files.path("settings.cfg")
	settings.legacy_settings_path = files.path("legacy.dat")
	root.add_child(main)
	main.ui_state_manager.set_reduced_motion(true)
	await process_frame
	root.focus_exited.emit()
	check.expect_equal(main.game_session.state, GameSession.State.MAIN_MENU, "unfocused menus remain menus")
	main.start_new_round()
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
	files.cleanup()
	check.finish(self, "Window lifecycle test")
