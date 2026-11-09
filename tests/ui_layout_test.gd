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
	for dimensions in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 568), Vector2i(1280, 720)]:
		root.size = dimensions
		for frame in 5:
			await process_frame
		var layer := main.get_node("UILayer") as ResponsiveUILayer
		var pixel_scale := root.get_stretch_transform().get_scale().x * layer.scale.x
		print("UI dimensions: ", dimensions, " viewport: ", root.get_visible_rect().size, " UI scale: ", pixel_scale)
		check.expect_true(pixel_scale >= 0.99, "menu text never shrinks below authored pixels")
		for state in main.ui_state_manager.ui_elements:
			main.ui_state_manager.change_state(state)
			var menu := main.ui_state_manager.ui_elements[state] as ScrollContainer
			for frame in 5:
				await process_frame
			var captures := OS.get_environment("SNAKE_UI_CAPTURE_DIR")
			if not captures.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				check.expect_equal(image.save_png(captures.path_join("%dx%d-%s.png" % [dimensions.x, dimensions.y, menu.name])), OK, "save layout capture")
			var panel := menu.get_node("Content/PanelContainer") as Control
			check.expect_true(panel.size.x <= menu.size.x + 1.0, "panel fits width: %s at %s (%s vs %s)" % [menu.name, dimensions, panel.size, menu.size])
			for button in menu.get_buttons():
				check.expect_true(button.size.y * pixel_scale >= 43.9, "44px target: %s at %s" % [button.name, dimensions])
				button.grab_focus()
				for frame in 3:
					await process_frame
				var top: float = button.global_position.y
				# Scroll offsets are integers while stretch/centering can be fractional.
				check.expect_true(top >= -2.0 and top + button.size.y <= menu.size.y + 2.0, "focused button scrolls into view: %s/%s at %s" % [menu.name, button.name, dimensions])
		main.ui_state_manager.change_state(UIStateManager.UIState.MAIN_MENU)
		for frame in 5:
			await process_frame
		main.main_menu.mode_selector.grab_focus()
		for frame in 3:
			await process_frame
		_click(main.main_menu.mode_selector)
		for frame in 3:
			await process_frame
		var popup := main.main_menu.mode_selector.get_popup()
		check.expect_true(popup.visible, "mode selector opens its popup through pointer input")
		check.expect_true(popup.get_theme_constant("v_separation") >= 24, "mode choices retain usable vertical spacing")
		var capture_dir := OS.get_environment("SNAKE_UI_CAPTURE_DIR")
		if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_dir.path_join("%dx%d-ModePopup.png" % [dimensions.x, dimensions.y]))
		main.main_menu.mode_selector.select(GameMode.Value.OBSTACLES)
		main.main_menu.mode_selector.item_selected.emit(GameMode.Value.OBSTACLES)
		popup.hide()
		for frame in 5:
			await process_frame
		check.expect_true(main.main_menu.seed_row.visible, "Obstacles reveals the seed editor")
		check.expect_true(main.main_menu.seed_row.size.x <= main.main_menu.size.x, "seed row fits the menu")
		check.expect_true(main.main_menu.world_seed_spin_box.size.y * pixel_scale >= 43.9, "seed editor has a 44px target")
		main.main_menu.start_button.grab_focus()
		for frame in 3:
			await process_frame
		_click(main.main_menu.start_button)
		await process_frame
		check.expect_equal(main.game_session.state, GameSession.State.PLAYING, "pointer starts a round through the scaled menu")
		_key(KEY_RIGHT)
		await physics_frame
		_key(KEY_P)
		check.expect_equal(main.game_session.state, GameSession.State.PAUSED, "P pauses through engine event routing")
		var paused_tick := main.gameplay.model.tick_count
		var paused_time := main.gameplay.time_since_tick
		for frame in 5:
			await physics_frame
		check.expect_equal(main.gameplay.model.tick_count, paused_tick, "paused frames retain the model tick")
		check.expect_equal(main.gameplay.time_since_tick, paused_time, "paused frames retain visual interpolation")
		_key(KEY_P)
		check.expect_equal(main.game_session.state, GameSession.State.PLAYING, "P resumes through engine event routing")
		_key(KEY_ESCAPE)
		for frame in 5:
			await process_frame
		_click(main.pause_menu.menu_button)
		await process_frame
		check.expect_equal(main.game_session.state, GameSession.State.MAIN_MENU, "pointer returns to the menu after pause")

	main.free()
	files.cleanup()
	check.finish(self, "UI layout test")

func _click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_transform_with_canvas() * (control.size / 2.0)
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	root.push_input(event, true)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	root.push_input(event, true)
