extends SceneTree

const MENU := preload("res://scenes/ui/main_menu.tscn")
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
	check.finish(self, "Menu input test")

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
