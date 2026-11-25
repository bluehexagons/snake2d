extends SceneTree

var check := TestAssertions.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager := UIStateManager.new()
	manager.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(manager)
	var menu := Control.new()
	var options := Control.new()
	var menu_button := Button.new()
	var options_slider := HSlider.new()
	manager.add_child(menu)
	manager.add_child(options)
	menu.add_child(menu_button)
	options.add_child(options_slider)
	manager.register_ui_element(UIStateManager.UIState.MAIN_MENU, menu)
	manager.register_ui_element(UIStateManager.UIState.OPTIONS_MENU, options)
	manager.register_focus_target(UIStateManager.UIState.MAIN_MENU, menu_button)
	manager.register_focus_target(UIStateManager.UIState.OPTIONS_MENU, options_slider)
	check.expect_false(options.visible, "registration hides inactive panels")
	manager.change_state(UIStateManager.UIState.OPTIONS_MENU)
	check.expect_false(menu.visible, "the outgoing panel hides before the next one fades in")
	check.expect_equal(menu_button.get_mouse_filter_with_override(), Control.MOUSE_FILTER_IGNORE, "outgoing buttons ignore mouse immediately")
	check.expect_equal(menu_button.get_focus_mode_with_override(), Control.FOCUS_NONE, "outgoing buttons cannot regain focus")
	check.expect_false(menu.can_process(), "outgoing controllers stop processing input")
	check.expect_equal(root.gui_get_focus_owner(), options_slider, "a focus target may be any Control")
	check.expect_equal(options.scale, Vector2.ONE, "transitions leave control bounds steady")
	# Interrupt the active fade before it settles.
	manager.change_state(UIStateManager.UIState.MAIN_MENU, menu_button)
	manager.set_reduced_motion(true)
	check.expect_true(menu.visible, "reversing a transition preserves the active panel")
	check.expect_false(options.visible, "reversing a transition keeps the inactive panel hidden")
	await create_timer(0.25).timeout
	check.expect_equal(menu.modulate.a, 1.0, "the settled panel is opaque")
	manager.free()
	check.finish(self, "UI state manager test")
