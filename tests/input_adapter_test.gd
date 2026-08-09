extends SceneTree

var check := TestAssertions.new()

func _initialize() -> void:
	check.expect_equal(SnakeInputAdapter.cardinal_direction(Vector2(20, 3)), Vector2i.RIGHT, "a rightward vector maps right")
	check.expect_equal(SnakeInputAdapter.cardinal_direction(Vector2(-20, 3)), Vector2i.LEFT, "a leftward vector maps left")
	check.expect_equal(SnakeInputAdapter.cardinal_direction(Vector2(3, -20)), Vector2i.UP, "an upward vector maps up")
	check.expect_equal(SnakeInputAdapter.cardinal_direction(Vector2(3, 20)), Vector2i.DOWN, "a downward vector maps down")
	check.expect_equal(SnakeInputAdapter.cardinal_direction(Vector2.ZERO), Vector2i.ZERO, "a zero vector produces no direction")
	_expect_tap_classification()
	_expect_responsive_swipe()
	_expect_scale_aware_threshold()
	_expect_engine_event_translation()
	check.finish(self, "Input adapter test")

func _expect_tap_classification() -> void:
	var tap := TouchGesture.new(Vector2(120.0, 90.0))
	check.expect_true(tap.is_tap(false), "a stationary touch is a tap")
	check.expect_false(tap.is_tap(true), "a canceled touch is not a tap")

func _expect_responsive_swipe() -> void:
	var swipe := TouchGesture.new(Vector2(100.0, 100.0))
	check.expect_equal(
		swipe.update_drag(Vector2(108.0, 102.0), Vector2(8.0, 2.0), 16.0),
		Vector2i.ZERO,
		"motion below the drag threshold stays undecided"
	)
	check.expect_equal(
		swipe.update_drag(Vector2(118.0, 103.0), Vector2(10.0, 1.0), 16.0),
		Vector2i.RIGHT,
		"a swipe resolves immediately when accumulated motion crosses the threshold"
	)
	check.expect_equal(
		swipe.update_drag(Vector2(118.0, 130.0), Vector2(0.0, 27.0), 16.0),
		Vector2i.ZERO,
		"one touch gesture emits at most one turn"
	)
	check.expect_false(swipe.is_tap(false), "a committed swipe is not also emitted as a tap")

func _expect_scale_aware_threshold() -> void:
	check.expect_equal(
		TouchGesture.threshold_for_window(Vector2i(800, 600), 0.025, 16.0),
		16.0,
		"small windows retain an accessible minimum swipe threshold"
	)
	check.expect_equal(
		TouchGesture.threshold_for_window(Vector2i(2560, 1440), 0.025, 16.0),
		36.0,
		"large windows scale the swipe threshold with their shortest side"
	)

func _expect_engine_event_translation() -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	var gameplay := Gameplay.new()
	world.add_child(gameplay)
	var adapter := SnakeInputAdapter.new()
	world.add_child(adapter)
	adapter.configure(gameplay)
	adapter.set_enabled(true)
	adapter.drag_threshold_window_ratio = 0.0
	adapter.minimum_drag_threshold_pixels = 16.0

	var emitted_directions: Array[Vector2i] = []
	adapter.direction_requested.connect(
		func(direction: Vector2i) -> void: emitted_directions.append(direction)
	)

	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 1
	touch_press.position = Vector2(100.0, 100.0)
	touch_press.pressed = true
	adapter._unhandled_input(touch_press)
	check.expect_true(emitted_directions.is_empty(), "touch press waits to distinguish a tap from a swipe")

	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 1
	touch_drag.position = Vector2(100.0, 80.0)
	touch_drag.relative = Vector2(0.0, -20.0)
	touch_drag.screen_relative = Vector2(0.0, -20.0)
	adapter._unhandled_input(touch_drag)
	check.expect_equal(emitted_directions, [Vector2i.UP], "screen-relative drag emits immediately at the threshold")

	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 1
	touch_release.position = touch_drag.position
	touch_release.pressed = false
	adapter._unhandled_input(touch_release)
	check.expect_equal(emitted_directions.size(), 1, "swipe release does not also emit a tap")

	var tap_press := InputEventScreenTouch.new()
	tap_press.index = 2
	tap_press.position = Vector2(80.0, 0.0)
	tap_press.pressed = true
	adapter._unhandled_input(tap_press)
	var tap_release := InputEventScreenTouch.new()
	tap_release.index = 2
	tap_release.position = tap_press.position
	tap_release.pressed = false
	adapter._unhandled_input(tap_release)
	check.expect_equal(emitted_directions.back(), Vector2i.RIGHT, "tap direction resolves on release")

	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.device = InputEvent.DEVICE_ID_EMULATION
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse.position = Vector2(0.0, 80.0)
	emulated_mouse.pressed = true
	adapter._unhandled_input(emulated_mouse)
	check.expect_equal(emitted_directions.size(), 2, "emulated mouse input does not duplicate touch input")
	adapter.set_enabled(false)
	adapter._unhandled_input(touch_drag)
	check.expect_equal(emitted_directions.size(), 2, "disabled gameplay input ignores events behind menus")

	world.free()
