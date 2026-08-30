extends Node

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const UIStateManagerScript := preload("res://scenes/ui/ui_state_manager.gd")

func _ready() -> void:
	call_deferred("_run_smoke_test")

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)

func _run_smoke_test() -> void:
	var main := MAIN_SCENE.instantiate() as Main
	if main == null:
		_fail("Expected the main scene to use Main.")
		return
	add_child(main)

	await get_tree().process_frame

	if main.audio_service == null:
		_fail("Expected Main to own an AudioService node.")
		return
	if not main.main_menu.visible:
		_fail("Expected the main menu to be visible after startup.")
		return

	var credits_text := main.get_node_or_null(
		"UILayer/CreditsScreen/PanelContainer/MarginContainer/VBoxContainer/CreditsRichText"
	) as RichTextLabel
	if credits_text == null:
		_fail("Expected the credits text to exist.")
		return
	var project_version := str(ProjectSettings.get_setting("application/config/version", "unknown"))
	var engine_version := Engine.get_version_info()
	var godot_version := "%d.%d.%d" % [
		engine_version.major,
		engine_version.minor,
		engine_version.patch,
	]
	if not credits_text.text.contains("Godot Engine " + godot_version):
		_fail("Expected the credits to show the runtime Godot version.")
		return
	if not credits_text.text.contains("Version: " + project_version):
		_fail("Expected the credits to show the configured project version.")
		return

	var start_button := main.main_menu.get_default_focus()
	start_button.button_down.emit()
	start_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().physics_frame

	if not main.is_round_active():
		_fail("Expected the game to enter gameplay after pressing Start.")
		return
	if main.get_current_ui_state() != UIStateManagerScript.UIState.GAMEPLAY:
		_fail("Expected UI state to switch to gameplay after pressing Start.")
		return
	if not main.game_world.visible:
		_fail("Expected the game world to be visible during gameplay.")
		return
	if not main.score_display_label.visible:
		_fail("Expected the score label to be visible during gameplay.")
		return
	if main.gameplay.snake == null:
		_fail("Expected gameplay to spawn a snake when the game starts.")
		return
	if main.gameplay.food == null:
		_fail("Expected gameplay to spawn food when the game starts.")
		return

	var expected_spawn_cell := Vector2i(
		main.game_rules.columns / 2,
		main.game_rules.rows / 2
	)
	var expected_spawn_position := Vector2(expected_spawn_cell * main.game_rules.cell_size)
	if main.gameplay.snake.logical_position != expected_spawn_position:
		_fail("Expected the snake to spawn on the center grid cell.")
		return

	var first_tutorial := main.game_world.get_node_or_null("ControlsTutorial")
	if first_tutorial == null:
		_fail("Expected a new round to show the controls tutorial.")
		return

	# A non-growing move keeps the old tail cell visible and retracts it in step
	# with the extending head, preserving the snake's visual length.
	var center := expected_spawn_cell
	var presentation_body: Array[Vector2i] = []
	for index in 7:
		presentation_body.append(center + Vector2i.LEFT * index)
	main.gameplay.model.snake.body.assign(presentation_body)
	main.gameplay.model.snake.direction = Vector2i.RIGHT
	main.gameplay.model.snake.queued_direction = Vector2i.RIGHT
	main.gameplay.model.snake.waiting_for_input = false
	main.gameplay.model.food_cell = Vector2i.ZERO
	main.gameplay.advance_one_tick()
	main.gameplay.time_since_tick = main.gameplay.model.current_tick_seconds() * 0.5
	main.gameplay.call("_apply_visual_interpolation")
	if main.gameplay.tail_retraction_index != 6:
		_fail("Expected the old tail cell to remain during a non-growing move.")
		return
	var terminal_tail := main.gameplay.tail_segments[main.gameplay.tail_retraction_index]
	var expected_half_size := main.game_rules.cell_size * 0.5
	if not is_equal_approx(terminal_tail.size.x, expected_half_size):
		_fail("Expected the tail end to shrink by half at half interpolation.")
		return
	var old_tail_position := Vector2((center + Vector2i.LEFT * 6) * main.game_rules.cell_size)
	if not is_equal_approx(terminal_tail.position.x, old_tail_position.x + expected_half_size):
		_fail("Expected the retracting tail to stay anchored toward the body.")
		return
	main.gameplay.call("_snap_presentation_to_targets")
	if terminal_tail.visible:
		_fail("Expected the retracted tail cell to disappear at the move target.")
		return
	var head_color := SnakeView.HEAD_COLOR
	var tail_color := Gameplay.TAIL_END_COLOR
	var middle_color := main.gameplay.tail_segments[3].color
	if main.gameplay.tail_segments[0].color != head_color:
		_fail("Expected the first body piece to match the head color.")
		return
	if _color_distance(main.gameplay.tail_segments[1].color, head_color) >= _color_distance(middle_color, head_color):
		_fail("Expected the second body piece to stay closer to the head color than the middle.")
		return
	if terminal_tail.color != tail_color:
		_fail("Expected the terminal piece to match the tail-end color.")
		return
	if _color_distance(main.gameplay.tail_segments[-2].color, tail_color) >= _color_distance(middle_color, tail_color):
		_fail("Expected the penultimate piece to stay closer to the tail color than the middle.")
		return

	main.gameplay.model.food_cell = center + Vector2i.RIGHT * 2
	main.gameplay.advance_one_tick()
	if main.gameplay.tail_retraction_index != -1:
		_fail("Expected a growing move to keep the tail end full-sized.")
		return
	if main.gameplay.tail_segments[-1].size != Vector2.ONE * main.game_rules.cell_size:
		_fail("Expected growth to preserve the complete terminal tail cell.")
		return

	main.game_session.end_round(0)
	main.camera_node.position = Vector2.ZERO
	main.start_new_round()
	await get_tree().process_frame

	var expected_camera_position := Vector2(main.game_rules.board_size_pixels()) / 2.0
	if main.camera_node.position != expected_camera_position:
		_fail("Expected a restarted game to reset the camera.")
		return
	var replacement_tutorial := main.game_world.get_node_or_null("ControlsTutorial")
	if replacement_tutorial == null or replacement_tutorial == first_tutorial:
		_fail("Expected a restarted game to replace the controls tutorial.")
		return

	main.call("_on_quit_to_menu_pressed")
	if main.gameplay.snake != null or main.gameplay.food != null:
		_fail("Expected quitting to the menu to clean up gameplay nodes.")
		return
	if main.game_session.state != GameSession.State.MAIN_MENU:
		_fail("Expected quitting to the menu to clear session state.")
		return

	main.main_menu.mode_selector.select(GameMode.Value.OBSTACLES)
	main.main_menu.call("_on_mode_selected", GameMode.Value.OBSTACLES)
	main.main_menu.world_seed_spin_box.value = 424242
	if not main.main_menu.seed_row.visible:
		_fail("Expected Obstacles mode to reveal the world seed input.")
		return
	main.main_menu.start_button.pressed.emit()
	await get_tree().process_frame
	if main.game_session.current_mode != GameMode.Value.OBSTACLES:
		_fail("Expected the selected Obstacles mode to start.")
		return
	if main.game_session.current_world_seed != 424242:
		_fail("Expected the selected world seed to reach the session.")
		return
	if main.gameplay.obstacle_views.is_empty():
		_fail("Expected a seeded Obstacles round to render walls.")
		return
	if main.gameplay.obstacle_views.size() != main.gameplay.model.obstacle_cells.size():
		_fail("Expected every model wall to have a matching view.")
		return
	main.call("_on_quit_to_menu_pressed")

	print("Smoke test passed.")
	get_tree().quit()

func _color_distance(first: Color, second: Color) -> float:
	return Vector3(first.r - second.r, first.g - second.g, first.b - second.b).length()
