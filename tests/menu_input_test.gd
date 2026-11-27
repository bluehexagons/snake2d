extends SceneTree

const MENU := preload("res://scenes/ui/main_menu.tscn")
const SCORES_MENU := preload("res://scenes/ui/high_scores_menu.tscn")
const OPTIONS_MENU := preload("res://scenes/ui/options_menu.tscn")
var check := TestAssertions.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu := MENU.instantiate() as MainMenu
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(menu)
	menu.mode_selector.select(GameMode.Value.OBSTACLES)
	menu.mode_selector.item_selected.emit(GameMode.Value.OBSTACLES)
	var seeds: Array[int] = []
	menu.start_requested.connect(func(_mode: GameMode.Value, world_seed: int) -> void: seeds.append(world_seed))
	var line := menu.world_seed_spin_box.get_line_edit()
	check.expect_equal(line.virtual_keyboard_type, LineEdit.KEYBOARD_TYPE_NUMBER, "the seed editor requests a numeric keypad")
	await _type_seed(line, "12345")
	await _start_through_keyboard()
	check.expect_equal(seeds, [12345], "typed seed is committed before keyboard start")
	await _type_seed(line, "9".repeat(20))
	check.expect_true(line.text.length() <= 9, "oversized typed seeds stay within nine digits")
	await _start_through_keyboard()
	check.expect_equal(seeds, [12345, MainMenu.MAX_WORLD_SEED], "oversized typed seeds start at the supported maximum")
	line.grab_focus()
	line.edit()
	for frame in 3:
		await process_frame
	line.clear()
	line.insert_text_at_caret("9".repeat(1000))
	line.text_changed.emit(line.text)
	await process_frame
	check.expect_true(line.text.length() <= 9, "pasted seed text has the same length bound")
	await _start_through_keyboard()
	check.expect_equal(seeds, [12345, MainMenu.MAX_WORLD_SEED, MainMenu.MAX_WORLD_SEED], "pasted seed text starts with a supported seed")
	await _type_seed(line, "0")
	await _start_through_keyboard()
	check.expect_equal(seeds, [12345, MainMenu.MAX_WORLD_SEED, MainMenu.MAX_WORLD_SEED, MainMenu.MIN_WORLD_SEED], "zero is clamped to the supported minimum")
	menu.world_seed_spin_box.allow_greater = true
	menu.world_seed_spin_box.value = 1.0e30
	menu.start_button.pressed.emit()
	check.expect_equal(seeds.back(), MainMenu.MAX_WORLD_SEED, "programmatic values cannot launch an out-of-range seed")
	menu.free()
	await process_frame
	await _expect_score_mode_starts_at_top()
	await _expect_volume_preview()
	check.finish(self, "Menu input test")

func _expect_score_mode_starts_at_top() -> void:
	root.size = Vector2i(800, 600)
	var scores := SCORES_MENU.instantiate() as HighScoresMenu
	scores.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(scores)
	var classic: Array[int] = []
	var pitfall: Array[int] = []
	for index in 100:
		classic.append(1000 - index)
		pitfall.append(2000 - index)
	scores.update_scores({"classic": classic, "pitfall": pitfall})
	for frame in 5:
		await process_frame
	scores.scroll_container.scroll_vertical = 500
	var position := scores.scroll_container.scroll_vertical
	check.expect_true(position > 0, "the first score table can scroll")
	scores.back_button.grab_focus()
	_key(KEY_UP)
	check.expect_equal(root.gui_get_focus_owner(), scores.scroll_container, "Up from Back focuses the score list")
	check.expect_equal(scores.scroll_container.scroll_vertical, position, "moving focus onto the list keeps its position")
	_key(KEY_DOWN)
	check.expect_true(scores.scroll_container.scroll_vertical > position, "Down scrolls the focused list")
	check.expect_equal(root.gui_get_focus_owner(), scores.scroll_container, "scrolling keeps focus on the list")
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_DPAD_UP
	controller.pressed = true
	root.push_input(controller, true)
	check.expect_equal(scores.scroll_container.scroll_vertical, position, "the D-pad scrolls the focused list")
	_key(KEY_RIGHT)
	check.expect_equal(root.gui_get_focus_owner(), scores.back_button, "Right leaves the middle of the list for Back")
	_key(KEY_UP)
	_key(KEY_LEFT)
	check.expect_equal(root.gui_get_focus_owner(), scores.mode_selector, "Left leaves the middle of the list for the mode picker")
	scores.mode_selector.show_popup()
	Input.action_press(&"ui_down")
	await create_timer(0.08).timeout
	Input.action_release(&"ui_down")
	check.expect_equal(scores.scroll_container.scroll_vertical, position, "mode picker input leaves the background table alone")
	scores.mode_selector.get_popup().hide()
	scores.mode_selector.select(GameMode.Value.PITFALL)
	scores.mode_selector.item_selected.emit(GameMode.Value.PITFALL)
	check.expect_equal(scores.scores_list.get_child_count(), 100, "switching modes replaces rows immediately")
	check.expect_equal(scores.scores_list.get_child(0).get_node("Score").text, "2000", "the new mode's highest score appears first")
	check.expect_equal(scores.scroll_container.scroll_vertical, 0, "each score table opens at rank one")
	scores.scroll_container.grab_focus()
	var repeated_up := InputEventKey.new()
	repeated_up.keycode = KEY_UP
	repeated_up.pressed = true
	repeated_up.echo = true
	root.push_input(repeated_up, true)
	check.expect_equal(root.gui_get_focus_owner(), scores.scroll_container, "a held key stops at the list boundary")
	_key(KEY_UP)
	check.expect_equal(root.gui_get_focus_owner(), scores.mode_selector, "a new press at the top moves focus to the mode picker")
	scores.free()

func _expect_volume_preview() -> void:
	var files := TestFiles.new()
	var settings := SettingsService.new()
	settings.settings_path = files.path("settings.cfg")
	settings.legacy_settings_path = files.path("settings.dat")
	var options := OPTIONS_MENU.instantiate() as OptionsMenu
	options.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(settings)
	root.add_child(options)
	options.set_settings_service(settings)
	var previews: Array[float] = []
	options.volume_preview_requested.connect(func() -> void: previews.append(settings.effects_volume_db))
	var timer := options.get_node("VolumePreviewTimer") as Timer

	settings.set_effects_volume_db(-10.0)
	check.expect_equal(options.volume_slider.value, -10.0, "settings updates synchronize the slider")
	check.expect_true(timer.is_stopped(), "settings synchronization schedules no preview")
	options.volume_slider.grab_focus()
	await process_frame
	_key(KEY_LEFT)
	_key(KEY_LEFT)
	check.expect_equal(settings.effects_volume_db, -12.0, "keyboard adjustment applies immediately")
	check.expect_equal(previews, [], "rapid adjustments wait for the slider to settle")
	if not timer.is_stopped():
		await timer.timeout
		await process_frame
	check.expect_equal(previews, [-12.0], "one preview uses the final adjusted level")

	_key(KEY_RIGHT)
	check.expect_false(timer.is_stopped(), "an adjustment queues a preview")
	options.process_mode = Node.PROCESS_MODE_DISABLED
	check.expect_true(timer.is_stopped(), "leaving Options cancels a pending preview")
	options.process_mode = Node.PROCESS_MODE_ALWAYS
	options.volume_slider.grab_focus()
	settings.toggle_mute()
	_key(KEY_LEFT)
	check.expect_equal(settings.effects_volume_db, -12.0, "muted adjustments still update the setting")
	check.expect_true(timer.is_stopped(), "muted adjustments schedule no preview")
	options.free()
	settings.free()
	files.cleanup()

func _type_seed(line: LineEdit, text: String) -> void:
	line.grab_focus()
	line.edit()
	for frame in 3:
		await process_frame
	line.select_all()
	for character in text:
		_key(character.unicode_at(0), character.unicode_at(0))
		await process_frame

func _start_through_keyboard() -> void:
	_key(KEY_DOWN)
	await process_frame
	_key(KEY_ENTER)
	await process_frame

func _key(code: int, unicode_value := 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode_value
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	root.push_input(event, true)
