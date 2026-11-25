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
	root.size = Vector2i(844, 390)
	root.add_child(main)
	main.ui_state_manager.set_reduced_motion(true)
	main.game_session.start_new_round(GameMode.Value.PITFALL)
	for frame in 8:
		await process_frame
	check.expect_true(main.gameplay_hud.size.y <= 42.0, "the landscape HUD shrinks after the first label wrap settles")
	main.game_session.return_to_menu()
	var sizes: Array[Vector2i] = [Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 568), Vector2i(1280, 720), Vector2i(800, 410), Vector2i(820, 390), Vector2i(1280, 480)]
	# KDE may constrain oversized native windows, changing the requested aspect.
	# Headless coverage can exercise the full ultrawide size at every density.
	if DisplayServer.get_name() == "headless":
		sizes.append(Vector2i(2560, 1080))
	for density in [1.0, 1.35, 2.0]:
		for dimensions in sizes:
			root.size = Vector2i(Vector2(dimensions) * density)
			for frame in 5:
				await process_frame
			var layer := main.get_node("UILayer") as ResponsiveUILayer
			if density == 1.0:
				check.expect_true(main.main_menu.size.distance_to(root.get_visible_rect().size / layer.scale) <= 2.0, "automatic resize fits the viewport")
				check.expect_true(main.main_menu.position.length() <= 1.0, "automatic resize retains the menu origin")
			layer.fit_to_viewport(density)
			for frame in 5:
				await process_frame
			var pixel_scale: float = root.get_stretch_transform().get_scale().x * layer.scale.x / density
			print("UI dimensions: ", dimensions, " viewport: ", root.get_visible_rect().size, " density: ", density, " CSS UI scale: ", pixel_scale)
			check.expect_true(pixel_scale >= 0.99, "menu text never shrinks below authored pixels")
			for state in main.ui_state_manager.ui_elements:
				main.ui_state_manager.change_state(state)
				var menu := main.ui_state_manager.ui_elements[state] as ScrollContainer
				if menu is GameOverPanel:
					menu.show_result(20, SnakeGame.StepResult.FILLED_BOARD, GameMode.Value.OBSTACLES, true)
				for frame in 5:
					await process_frame
				if menu is GameOverPanel and dimensions == Vector2i(1280, 720):
					check.expect_equal(menu.title_label.get_line_count(), 1, "the desktop completion heading fits on one line")
				var captures := OS.get_environment("SNAKE_UI_CAPTURE_DIR")
				if not captures.is_empty() and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					var image := root.get_texture().get_image()
					check.expect_equal(image.save_png(captures.path_join("%dx%d-%s-dpi%s.png" % [dimensions.x, dimensions.y, menu.name, density])), OK, "save layout capture")
				var panel := menu.get_node("Content/PanelContainer") as Control
				var layout := panel.get_node("MarginContainer/MenuLayout") as ResponsiveMenuLayout
				var primary := layout.get_node("Primary") as Control
				var actions := layout.get_node("Actions") as Control
				var expect_wide: bool = dimensions.x >= 720 and dimensions.x >= dimensions.y * 2
				check.expect_equal(not layout.vertical, expect_wide, "aspect ratio selects layout: %s at %s" % [menu.name, dimensions])
				if expect_wide:
					check.expect_true(primary.position.x + primary.size.x < actions.position.x, "wide menu groups sit side by side: %s" % menu.name)
					check.expect_true(panel.size.y <= menu.size.y + 1.0, "wide menu fits without scrolling: %s at %s" % [menu.name, dimensions])
				else:
					check.expect_true(primary.position.y + primary.size.y < actions.position.y, "regular menu groups stack: %s" % menu.name)
				check.expect_true(menu.position.length() <= 1.0, "menu origin survives minimum-size changes: %s at %s (%s)" % [menu.name, dimensions, menu.position])
				check.expect_true(panel.size.x <= menu.size.x + 1.0, "panel fits width: %s at %s (%s vs %s)" % [menu.name, dimensions, panel.size, menu.size])
				if menu is OptionsMenu and dimensions == Vector2i(320, 568):
					check.expect_true(panel.size.y <= menu.size.y + 1.0, "portrait Options fits without scrolling")
				for button in menu.get_buttons():
					for path in [button.focus_neighbor_top, button.focus_neighbor_bottom]:
						if not path.is_empty():
							check.expect_true(button.get_node_or_null(path) is Control, "focus neighbor resolves: %s/%s" % [menu.name, button.name])
					check.expect_true(button.size.y * pixel_scale >= 43.9, "44px target: %s at %s" % [button.name, dimensions])
					button.grab_focus()
					for frame in 3:
						await process_frame
					var top: float = button.global_position.y
					# Scroll offsets are integers while stretch/centering can be fractional.
					check.expect_true(top >= -2.0 and top + button.size.y <= menu.size.y + 2.0, "focused button scrolls into view: %s/%s at %s" % [menu.name, button.name, dimensions])
				if menu is OptionsMenu:
					menu.reset_settings_button.grab_focus()
					for frame in 3:
						await process_frame
					_click(menu.reset_settings_button)
					for frame in 5:
						await process_frame
					var dialog := menu.get_child(menu.get_child_count() - 1) as ConfirmationDialog
					check.expect_true(dialog != null and dialog.visible, "pointer opens reset confirmation")
					if dialog != null:
						check.expect_true((Vector2(dialog.position) + Vector2(dialog.size) / 2.0).distance_to(root.get_visible_rect().size / 2.0) <= 2.0, "dialog stays centered after minimum size settles")
						var dialog_scale: float = root.get_stretch_transform().get_scale().x * dialog.content_scale_factor / density
						check.expect_true(dialog_scale >= 0.99, "dialog text retains CSS pixel size")
						check.expect_true(dialog.size.x * root.get_stretch_transform().get_scale().x / density <= dimensions.x, "dialog fits narrow viewport")
						check.expect_true(dialog.get_cancel_button().size.y * dialog_scale >= 43.9, "dialog cancel has 44px target")
						check.expect_true(dialog.get_ok_button().size.x * dialog_scale >= 43.9, "dialog OK has 44px width")
						var resized := Vector2i(320, 568) if dimensions.x > 600 else Vector2i(1280, 720)
						root.size = Vector2i(Vector2(resized) * density)
						for frame in 5:
							await process_frame
						layer.fit_to_viewport(density)
						for frame in 5:
							await process_frame
						check.expect_true(is_equal_approx(dialog.content_scale_factor, layer.scale.x), "open dialog follows menu scale after resize")
						check.expect_true(dialog.size.x <= root.get_visible_rect().size.x, "open dialog fits after resize")
						check.expect_true((Vector2(dialog.position) + Vector2(dialog.size) / 2.0).distance_to(root.get_visible_rect().size / 2.0) <= 2.0, "open dialog recenters after resize")
						dialog.canceled.emit()
						await process_frame
						root.size = Vector2i(Vector2(dimensions) * density)
						for frame in 5:
							await process_frame
						layer.fit_to_viewport(density)
						for frame in 5:
							await process_frame

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
				root.get_texture().get_image().save_png(capture_dir.path_join("%dx%d-ModePopup-dpi%s.png" % [dimensions.x, dimensions.y, density]))
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
			for frame in 3:
				await process_frame
			check.expect_equal(main.game_session.state, GameSession.State.PLAYING, "pointer starts a round through the scaled menu")
			var tutorial := main.controls_tutorial
			check.expect_true(tutorial.visible, "the tutorial is visible before the first turn")
			check.expect_true(tutorial.size.is_equal_approx(root.get_visible_rect().size / layer.scale), "the tutorial fits the responsive UI")
			var hint := main.first_move_hint
			var hint_rect := hint.get_global_rect()
			check.expect_true(Rect2(Vector2.ZERO, tutorial.size).grow(1.0).encloses(hint_rect), "the first-move prompt fits the viewport: %s in %s" % [hint_rect, tutorial.size])
			check.expect_false(hint_rect.intersects(main.gameplay_hud.get_rect()), "the first-move prompt clears the HUD")
			var board := main.play_area_background
			var board_rect := board.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, board.size)
			check.expect_true(board_rect.position.y >= layer.gameplay_top_inset(), "the HUD stays above the board")
			if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(capture_dir.path_join("%dx%d-Ready-dpi%s.png" % [dimensions.x, dimensions.y, density]))
			_key(KEY_P)
			check.expect_false(tutorial.visible, "pausing hides the tutorial")
			_key(KEY_P)
			check.expect_true(tutorial.visible, "resuming before the first turn restores the tutorial")
			_key(KEY_RIGHT)
			check.expect_false(tutorial.visible, "the first turn hides the tutorial")
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
			check.expect_false(tutorial.visible, "resuming after a turn keeps the tutorial hidden")
			var pause_button := main.gameplay_pause_button
			check.expect_true(pause_button.visible, "pointer pause is available during gameplay")
			check.expect_true(pause_button.size.y * pixel_scale >= 43.9, "pointer pause has a 44px target")
			_click(pause_button)
			check.expect_equal(main.game_session.state, GameSession.State.PAUSED, "pointer pauses through engine event routing")
			check.expect_false(pause_button.visible, "the in-game pause control leaves the pause menu unobstructed")
			for frame in 5:
				await process_frame
			_click(main.pause_menu.menu_button)
			await process_frame
			check.expect_equal(main.game_session.state, GameSession.State.MAIN_MENU, "pointer returns to the menu after pause")
	# Reflow the live seed editor in both directions without recreating controls.
	main.ui_state_manager.change_state(UIStateManager.UIState.MAIN_MENU)
	main.main_menu.mode_selector.select(GameMode.Value.OBSTACLES)
	main.main_menu.mode_selector.item_selected.emit(GameMode.Value.OBSTACLES)
	main.main_menu.world_seed_spin_box.value = 123456
	var seed_input := main.main_menu.world_seed_spin_box.get_line_edit()
	seed_input.grab_focus()
	for dimensions in [Vector2i(844, 390), Vector2i(390, 844), Vector2i(1280, 480)]:
		root.size = dimensions
		for frame in 8:
			await process_frame
		check.expect_equal(root.gui_get_focus_owner(), seed_input, "resize retains seed input focus")
		check.expect_equal(main.main_menu.mode_selector.get_selected_id(), GameMode.Value.OBSTACLES, "resize retains mode")
		check.expect_equal(roundi(main.main_menu.world_seed_spin_box.value), 123456, "resize retains seed")
	_key(KEY_DOWN)
	await process_frame
	check.expect_equal(root.gui_get_focus_owner(), main.main_menu.start_button, "Down moves from seed across columns to Start")
	_key(KEY_TAB)
	await process_frame
	check.expect_equal(root.gui_get_focus_owner(), main.main_menu.scores_button, "Tab advances through horizontal menu actions")
	await _expect_board_stays_visible_after_resize(main)
	# Let the final 50 ms focus cue finish before tearing down the native mixer.
	await create_timer(0.1).timeout
	main.free()
	await process_frame
	files.cleanup()
	check.finish(self, "UI layout test")

func _expect_board_stays_visible_after_resize(main: Main) -> void:
	main.start_new_round()
	var camera_rules := main.game_rules.duplicate() as GameRules
	camera_rules.camera_look_ahead_cells = 100.0
	camera_rules.camera_smoothing = 1.0
	main.camera_node.configure(camera_rules, main.gameplay)
	for frame in 5:
		await physics_frame
	var wide_camera_x := main.camera_node.position.x
	main.game_session.pause_round()
	root.size = Vector2i(320, 568)
	for frame in 5:
		await process_frame
	var board := main.play_area_background
	var border := board.get_theme_stylebox("panel") as StyleBoxFlat
	var outline := Rect2(Vector2.ZERO, board.size).grow(border.get_expand_margin(SIDE_LEFT))
	var visible_board := board.get_global_transform_with_canvas() * outline
	check.expect_true(main.camera_node.position.x < wide_camera_x, "a narrower window reduces camera travel even while paused")
	check.expect_true(root.get_visible_rect().grow(1.0).encloses(visible_board), "camera travel keeps the board outline inside the viewport")
	main.game_session.return_to_menu()

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
